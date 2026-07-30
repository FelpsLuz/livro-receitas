// Orquestracao do envio de conversoes offline ao Google Ads.
//
// Regras centrais:
//  - Uma conversao por (cliente, etapa). Nunca duas.
//  - O horario da conversao e o momento em que a etapa foi atingida (fixo),
//    entao reenviar e seguro: o Google trata como duplicata e ignora.
//  - Falhas (sem internet, token expirado) ficam numa fila e sao reenviadas
//    automaticamente, com espera crescente entre as tentativas.

const { etapasAtingidasAte, valorDaEtapa, acaoDaEtapa, obterEtapa } = require('./funil');
const { enviarConversaoOffline } = require('./googleAds');

const MAX_TENTATIVAS = 8;
// Espera antes de tentar de novo: 1min, 5min, 15min, 1h, 6h, 24h...
const ESPERA_MINUTOS = [1, 5, 15, 60, 360, 1440];

function configuracaoCompleta(config) {
  return Boolean(
    config.googleAdsRefreshToken &&
      config.googleAdsCustomerId &&
      config.googleAdsDeveloperToken &&
      config.googleAdsClientId &&
      config.googleAdsClientSecret
  );
}

function motivoNaoEnviavel(cliente, config) {
  if (!cliente.gclid) return 'Cliente sem GCLID (não veio de um anúncio, ou o GCLID não foi cadastrado).';
  if (!configuracaoCompleta(config)) return 'Google Ads não conectado (veja a aba Configurações).';
  return null;
}

function esperaParaTentativa(tentativas) {
  const minutos = ESPERA_MINUTOS[Math.min(tentativas, ESPERA_MINUTOS.length - 1)];
  return minutos * 60 * 1000;
}

function podeTentarAgora(conversao, agora = new Date()) {
  if (conversao.status === 'enviada') return false;
  if (conversao.tentativas >= MAX_TENTATIVAS) return false;
  if (!conversao.ultimaTentativaEm) return true;
  const decorrido = agora.getTime() - new Date(conversao.ultimaTentativaEm).getTime();
  return decorrido >= esperaParaTentativa(conversao.tentativas);
}

/**
 * Coloca na fila as conversoes de todas as etapas que o cliente atingiu.
 * Quem fecha contrato passou por qualificado e reuniao, mesmo sem o estagiario
 * ter clicado em cada etapa - e mandar o funil inteiro da muito mais sinal ao
 * algoritmo do que so o contrato final.
 */
function enfileirarEtapasDoCliente(store, cliente, config) {
  const enfileiradas = [];
  const etapasAlvo = config.googleAdsEnviarFunilCompleto
    ? etapasAtingidasAte(cliente.etapa)
    : [obterEtapa(cliente.etapa)].filter((e) => e.conversao);

  for (const etapa of etapasAlvo) {
    const acao = acaoDaEtapa(etapa, config);
    if (!acao) continue; // etapa sem acao de conversao configurada: ignora

    const quando = (cliente.etapasAtingidas || {})[etapa.id];
    if (!quando) continue;

    enfileiradas.push(
      store.enfileirarConversao({
        clienteId: cliente.id,
        etapa: etapa.id,
        gclid: cliente.gclid,
        valor: valorDaEtapa(etapa, cliente, config),
        conversionDateTime: quando,
      })
    );
  }

  return enfileiradas;
}

async function enviarUma(store, conversao, config, agora = new Date()) {
  const cliente = store.getCliente(conversao.clienteId);
  if (!cliente) {
    return store.atualizarConversao(conversao.id, {
      status: 'cancelada',
      erro: 'Cliente removido.',
    });
  }

  const etapa = obterEtapa(conversao.etapa);
  const acao = acaoDaEtapa(etapa, config);
  const impedimento = motivoNaoEnviavel(cliente, config) || (!acao ? 'Ação de conversão não configurada para esta etapa.' : null);

  if (impedimento) {
    return store.atualizarConversao(conversao.id, {
      status: 'pendente',
      erro: impedimento,
      ultimaTentativaEm: agora.toISOString(),
      tentativas: conversao.tentativas, // nao consome tentativa por falta de config
    });
  }

  try {
    await enviarConversaoOffline(config, {
      gclid: conversao.gclid,
      valor: conversao.valor,
      conversionDateTime: conversao.conversionDateTime,
      conversionActionId: acao,
    });
    return store.atualizarConversao(conversao.id, {
      status: 'enviada',
      enviadoEm: agora.toISOString(),
      ultimaTentativaEm: agora.toISOString(),
      tentativas: conversao.tentativas + 1,
      erro: null,
    });
  } catch (e) {
    const tentativas = conversao.tentativas + 1;
    return store.atualizarConversao(conversao.id, {
      status: tentativas >= MAX_TENTATIVAS ? 'falhou' : 'pendente',
      ultimaTentativaEm: agora.toISOString(),
      tentativas,
      erro: e.message,
    });
  }
}

/** Tenta enviar tudo que esta na fila e ja passou do tempo de espera. */
async function processarFila(store, { agora = new Date(), forcar = false } = {}) {
  const config = store.getConfig();
  const pendentes = store
    .listConversoesPendentes()
    .filter((c) => forcar || podeTentarAgora(c, agora));

  const resultados = [];
  for (const conversao of pendentes) {
    const atualizada = await enviarUma(
      store,
      forcar ? { ...conversao, tentativas: 0, ultimaTentativaEm: null } : conversao,
      config,
      agora
    );
    resultados.push(atualizada);
  }

  return {
    processadas: resultados.length,
    enviadas: resultados.filter((r) => r.status === 'enviada').length,
    pendentes: resultados.filter((r) => r.status === 'pendente').length,
    falhas: resultados.filter((r) => r.status === 'falhou').length,
    resultados,
  };
}

/** Move o cliente de etapa e ja tenta enviar as conversoes correspondentes. */
async function avancarEtapa(store, clienteId, idEtapa, { agora = new Date() } = {}) {
  const cliente = store.definirEtapaCliente(clienteId, idEtapa, agora);
  const config = store.getConfig();

  const etapa = obterEtapa(idEtapa);
  if (!etapa.conversao && idEtapa !== 'ContratoFechado') {
    return { cliente, enfileiradas: 0, enviadas: 0, aviso: null };
  }

  const aviso = motivoNaoEnviavel(cliente, config);
  const enfileiradas = enfileirarEtapasDoCliente(store, cliente, config);

  if (aviso) {
    return { cliente, enfileiradas: enfileiradas.length, enviadas: 0, aviso };
  }

  const resultado = await processarFila(store, { agora, forcar: true });
  const falhou = resultado.resultados.find((r) => r.erro && r.status !== 'enviada');

  return {
    cliente,
    enfileiradas: enfileiradas.length,
    enviadas: resultado.enviadas,
    aviso: falhou ? falhou.erro : null,
  };
}

module.exports = {
  MAX_TENTATIVAS,
  configuracaoCompleta,
  motivoNaoEnviavel,
  podeTentarAgora,
  esperaParaTentativa,
  enfileirarEtapasDoCliente,
  processarFila,
  avancarEtapa,
};
