// Cliente HTTP minimo para a Google Ads API (sem SDK oficial), usado para
// enviar conversoes offline (contrato fechado) associadas ao GCLID do
// clique original do anuncio.
//
// Documentacao de referencia: https://developers.google.com/google-ads/api/docs/conversions/upload-clicks

const API_VERSION = 'v18';
const BASE_URL = `https://googleads.googleapis.com/${API_VERSION}`;

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
  return String(customerId || '').replace(/-/g, '');
}

function montarCabecalhos(accessToken, developerToken) {
  return {
    Authorization: `Bearer ${accessToken}`,
    'developer-token': developerToken,
    'Content-Type': 'application/json',
  };
}

// Chamada somente-leitura: valida se o developer token + credenciais OAuth
// tem acesso a Google Ads API, sem enviar nenhum dado de conversao.
async function testarConexaoGoogleAds(config) {
  const accessToken = await obterAccessToken(config);
  const resposta = await fetch(`${BASE_URL}/customers:listAccessibleCustomers`, {
    headers: montarCabecalhos(accessToken, config.googleAdsDeveloperToken),
  });
  const dados = await resposta.json();
  if (!resposta.ok) {
    const mensagem = (dados.error && dados.error.message) || `HTTP ${resposta.status}`;
    throw new Error(`Falha na conexão com Google Ads: ${mensagem}`);
  }
  return dados;
}

// Google Ads exige o formato "yyyy-MM-dd HH:mm:ss+HH:mm" para conversionDateTime.
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

async function enviarConversaoOffline(config, { gclid, valor, dataHora = new Date() }) {
  if (!gclid) {
    throw new Error('Cliente nao possui GCLID cadastrado - conversao nao pode ser enviada.');
  }

  const accessToken = await obterAccessToken(config);
  const customerId = normalizarCustomerId(config.googleAdsCustomerId);

  const corpo = {
    conversions: [
      {
        gclid,
        conversionAction: `customers/${customerId}/conversionActions/${config.googleAdsConversionActionId}`,
        conversionDateTime: formatarDataHoraGoogle(dataHora),
        conversionValue: Number(valor) || 0,
        currencyCode: config.googleAdsMoeda || 'BRL',
      },
    ],
    partialFailure: true,
  };

  const resposta = await fetch(`${BASE_URL}/customers/${customerId}:uploadClickConversions`, {
    method: 'POST',
    headers: montarCabecalhos(accessToken, config.googleAdsDeveloperToken),
    body: JSON.stringify(corpo),
  });
  const dados = await resposta.json();

  if (!resposta.ok) {
    const mensagem = (dados.error && dados.error.message) || `HTTP ${resposta.status}`;
    throw new Error(`Falha ao enviar conversão offline: ${mensagem}`);
  }
  if (dados.partialFailureError) {
    throw new Error(`Falha parcial ao enviar conversão: ${dados.partialFailureError.message}`);
  }

  return dados;
}

module.exports = {
  obterAccessToken,
  testarConexaoGoogleAds,
  enviarConversaoOffline,
  formatarDataHoraGoogle,
  normalizarCustomerId,
};
