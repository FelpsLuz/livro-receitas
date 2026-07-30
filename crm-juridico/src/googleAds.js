// Cliente HTTP da Google Ads API (sem SDK oficial).
//
// Faz duas coisas:
//  1. Envia conversoes offline (funil: qualificado / reuniao / contrato fechado)
//  2. Le metricas de custo das campanhas, para cruzar com a receita do CRM
//
// A versao da API e configuravel porque o Google descontinua versoes antigas
// periodicamente (cada versao vive ~1 ano). Se as chamadas comecarem a falhar
// com erro de versao, basta trocar em Configuracoes, sem reinstalar o app.
const API_VERSION_PADRAO = 'v21';

function baseUrl(config) {
  const versao = config.googleAdsApiVersion || API_VERSION_PADRAO;
  return `https://googleads.googleapis.com/${versao}`;
}

async function obterAccessToken(config) {
  const resposta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: config.googleAdsClientId,
      client_secret: config.googleAdsClientSecret,
      refresh_token: config.googleAdsRefreshToken,
      grant_type: 'refresh_token',
    }),
  });
  const dados = await resposta.json();
  if (!resposta.ok) {
    throw new Error(
      dados.error_description || dados.error || `Falha ao obter access token do Google (HTTP ${resposta.status})`
    );
  }
  return dados.access_token;
}

function normalizarCustomerId(customerId) {
  return String(customerId || '').replace(/\D/g, '');
}

function montarCabecalhos(accessToken, config) {
  const cabecalhos = {
    Authorization: `Bearer ${accessToken}`,
    'developer-token': config.googleAdsDeveloperToken,
    'Content-Type': 'application/json',
  };
  // Necessario quando a conta e gerenciada por uma MCC (conta de agencia).
  const mcc = normalizarCustomerId(config.googleAdsLoginCustomerId);
  if (mcc) cabecalhos['login-customer-id'] = mcc;
  return cabecalhos;
}

function extrairMensagemErro(dados, status) {
  if (dados && dados.error) {
    const detalhe =
      dados.error.details &&
      dados.error.details[0] &&
      dados.error.details[0].errors &&
      dados.error.details[0].errors[0];
    if (detalhe && detalhe.message) return detalhe.message;
    if (dados.error.message) return dados.error.message;
  }
  return `HTTP ${status}`;
}

// Chamada somente leitura: valida credenciais sem enviar nenhuma conversao.
async function testarConexaoGoogleAds(config) {
  const accessToken = await obterAccessToken(config);
  const resposta = await fetch(`${baseUrl(config)}/customers:listAccessibleCustomers`, {
    headers: montarCabecalhos(accessToken, config),
  });
  const dados = await resposta.json();
  if (!resposta.ok) {
    throw new Error(`Falha na conexão com Google Ads: ${extrairMensagemErro(dados, resposta.status)}`);
  }
  return dados;
}

// Google Ads exige "yyyy-MM-dd HH:mm:ss+HH:mm" para conversionDateTime.
function formatarDataHoraGoogle(data) {
  const pad = (n) => String(n).padStart(2, '0');
  const d = new Date(data);
  const offsetMin = -d.getTimezoneOffset();
  const sinal = offsetMin >= 0 ? '+' : '-';
  const offsetH = pad(Math.floor(Math.abs(offsetMin) / 60));
  const offsetM = pad(Math.abs(offsetMin) % 60);
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
    `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}${sinal}${offsetH}:${offsetM}`
  );
}

/**
 * Envia uma conversao offline.
 *
 * `conversionDateTime` vem de fora e e SEMPRE o momento em que a etapa foi
 * atingida (gravado no cliente), nunca `new Date()`. Isso e essencial: o Google
 * deduplica por (gclid + acao + horario), entao um timestamp fixo faz um
 * reenvio ser ignorado como duplicata. Se usassemos a hora do envio, cada
 * tentativa viraria uma conversao NOVA, inflando o relatorio e ensinando o
 * algoritmo com dados falsos.
 */
async function enviarConversaoOffline(config, { gclid, valor, conversionDateTime, conversionActionId }) {
  if (!gclid) {
    throw new Error('Cliente não possui GCLID cadastrado — a conversão não pode ser enviada.');
  }
  if (!conversionActionId) {
    throw new Error('Ação de conversão não configurada para esta etapa do funil.');
  }
  if (!conversionDateTime) {
    throw new Error('Horário da conversão ausente.');
  }

  const accessToken = await obterAccessToken(config);
  const customerId = normalizarCustomerId(config.googleAdsCustomerId);
  if (!customerId) throw new Error('Customer ID do Google Ads não configurado.');

  const corpo = {
    conversions: [
      {
        gclid,
        conversionAction: `customers/${customerId}/conversionActions/${conversionActionId}`,
        conversionDateTime: formatarDataHoraGoogle(conversionDateTime),
        conversionValue: Number(valor) || 0,
        currencyCode: config.googleAdsMoeda || 'BRL',
      },
    ],
    partialFailure: true,
  };

  const resposta = await fetch(`${baseUrl(config)}/customers/${customerId}:uploadClickConversions`, {
    method: 'POST',
    headers: montarCabecalhos(accessToken, config),
    body: JSON.stringify(corpo),
  });
  const dados = await resposta.json();

  if (!resposta.ok) {
    throw new Error(`Falha ao enviar conversão: ${extrairMensagemErro(dados, resposta.status)}`);
  }
  if (dados.partialFailureError) {
    throw new Error(`Falha ao enviar conversão: ${dados.partialFailureError.message}`);
  }

  return dados;
}

// Executa uma consulta GAQL e devolve as linhas.
async function consultar(config, query) {
  const accessToken = await obterAccessToken(config);
  const customerId = normalizarCustomerId(config.googleAdsCustomerId);
  if (!customerId) throw new Error('Customer ID do Google Ads não configurado.');

  const resposta = await fetch(`${baseUrl(config)}/customers/${customerId}/googleAds:search`, {
    method: 'POST',
    headers: montarCabecalhos(accessToken, config),
    body: JSON.stringify({ query, pageSize: 1000 }),
  });
  const dados = await resposta.json();

  if (!resposta.ok) {
    throw new Error(`Falha na consulta ao Google Ads: ${extrairMensagemErro(dados, resposta.status)}`);
  }
  return dados.results || [];
}

const microsParaReais = (micros) => (Number(micros) || 0) / 1_000_000;

/**
 * Busca o custo por campanha no periodo, para cruzar com a receita do CRM.
 * `periodo` usa a sintaxe de data do GAQL (LAST_30_DAYS, THIS_MONTH, etc).
 */
async function buscarCustosCampanhas(config, periodo = 'LAST_30_DAYS') {
  const query = `
    SELECT campaign.id, campaign.name, campaign.status,
           metrics.cost_micros, metrics.clicks, metrics.impressions, metrics.conversions
    FROM campaign
    WHERE segments.date DURING ${periodo}
      AND metrics.impressions > 0
  `;
  const linhas = await consultar(config, query);

  // A API devolve uma linha por dia; somamos por campanha.
  const porCampanha = new Map();
  for (const linha of linhas) {
    const id = linha.campaign.id;
    const atual = porCampanha.get(id) || {
      id,
      nome: linha.campaign.name,
      status: linha.campaign.status,
      custo: 0,
      cliques: 0,
      impressoes: 0,
      conversoesAds: 0,
    };
    atual.custo += microsParaReais(linha.metrics.costMicros);
    atual.cliques += Number(linha.metrics.clicks) || 0;
    atual.impressoes += Number(linha.metrics.impressions) || 0;
    atual.conversoesAds += Number(linha.metrics.conversions) || 0;
    porCampanha.set(id, atual);
  }

  const campanhas = Array.from(porCampanha.values()).sort((a, b) => b.custo - a.custo);
  return {
    periodo,
    sincronizadoEm: new Date().toISOString(),
    campanhas,
    totalCusto: campanhas.reduce((s, c) => s + c.custo, 0),
    totalCliques: campanhas.reduce((s, c) => s + c.cliques, 0),
  };
}

/**
 * Descobre de qual campanha/palavra-chave veio cada GCLID.
 *
 * Limite da propria API: click_view so tem dados dos ultimos 90 dias e exige
 * consulta dia a dia. Por isso a busca e por data, e GCLIDs mais antigos que
 * isso simplesmente nao retornam (a atribuicao vira "não identificada").
 */
async function buscarOrigemDosCliques(config, datas) {
  const origem = new Map();

  for (const data of datas) {
    const query = `
      SELECT click_view.gclid, click_view.keyword_info.text, campaign.name, ad_group.name
      FROM click_view
      WHERE segments.date = '${data}'
    `;
    let linhas;
    try {
      linhas = await consultar(config, query);
    } catch (e) {
      // Um dia fora da janela de 90 dias nao deve derrubar a sincronizacao toda.
      continue;
    }
    for (const linha of linhas) {
      const gclid = linha.clickView && linha.clickView.gclid;
      if (!gclid) continue;
      origem.set(gclid, {
        campanha: (linha.campaign && linha.campaign.name) || null,
        grupoAnuncios: (linha.adGroup && linha.adGroup.name) || null,
        palavraChave:
          (linha.clickView.keywordInfo && linha.clickView.keywordInfo.text) || null,
      });
    }
  }

  return origem;
}

module.exports = {
  API_VERSION_PADRAO,
  obterAccessToken,
  testarConexaoGoogleAds,
  enviarConversaoOffline,
  formatarDataHoraGoogle,
  normalizarCustomerId,
  consultar,
  buscarCustosCampanhas,
  buscarOrigemDosCliques,
  microsParaReais,
};
