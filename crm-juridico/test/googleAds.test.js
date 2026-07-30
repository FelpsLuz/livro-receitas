const assert = require('assert');
const {
  formatarDataHoraGoogle,
  obterAccessToken,
  enviarConversaoOffline,
  testarConexaoGoogleAds,
  normalizarCustomerId,
} = require('../src/googleAds');

// formatarDataHoraGoogle
const formatada = formatarDataHoraGoogle(new Date('2026-07-30T14:05:09'));
assert.ok(
  /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/.test(formatada),
  `formato inesperado: ${formatada}`
);
console.log('OK: formatarDataHoraGoogle (formato esperado pela Google Ads API)');

// normalizarCustomerId
assert.strictEqual(normalizarCustomerId('123-456-7890'), '1234567890');
assert.strictEqual(normalizarCustomerId('1234567890'), '1234567890');
console.log('OK: normalizarCustomerId');

// Mock de fetch para validar as chamadas HTTP sem depender de rede/credenciais reais
async function comFetchMockado(respostas, fn) {
  const original = global.fetch;
  let chamada = 0;
  const chamadas = [];
  global.fetch = async (url, opts) => {
    chamadas.push({ url, opts });
    const resposta = respostas[chamada++];
    return {
      ok: resposta.ok !== false,
      status: resposta.status || 200,
      json: async () => resposta.corpo,
    };
  };
  try {
    const resultado = await fn();
    return { resultado, chamadas };
  } finally {
    global.fetch = original;
  }
}

(async () => {
  // obterAccessToken
  {
    const { resultado, chamadas } = await comFetchMockado(
      [{ corpo: { access_token: 'token-123' } }],
      () =>
        obterAccessToken({
          googleAdsClientId: 'id',
          googleAdsClientSecret: 'segredo',
          googleAdsRefreshToken: 'refresh',
        })
    );
    assert.strictEqual(resultado, 'token-123');
    assert.ok(chamadas[0].url.includes('oauth2.googleapis.com/token'));
    console.log('OK: obterAccessToken');
  }

  // obterAccessToken com falha
  {
    let erro = null;
    await comFetchMockado(
      [{ ok: false, status: 400, corpo: { error_description: 'refresh token invalido' } }],
      async () => {
        try {
          await obterAccessToken({
            googleAdsClientId: 'id',
            googleAdsClientSecret: 'segredo',
            googleAdsRefreshToken: 'invalido',
          });
        } catch (e) {
          erro = e;
        }
      }
    );
    assert.ok(erro && erro.message.includes('refresh token invalido'));
    console.log('OK: obterAccessToken propaga erro do Google');
  }

  // enviarConversaoOffline - valida URL, headers e corpo da requisicao
  {
    const config = {
      googleAdsClientId: 'id',
      googleAdsClientSecret: 'segredo',
      googleAdsRefreshToken: 'refresh',
      googleAdsDeveloperToken: 'dev-token',
      googleAdsCustomerId: '123-456-7890',
      googleAdsConversionActionId: '999',
      googleAdsMoeda: 'BRL',
    };
    const { chamadas } = await comFetchMockado(
      [{ corpo: { access_token: 'token-abc' } }, { corpo: {} }],
      () =>
        enviarConversaoOffline(config, {
          gclid: 'GCLID123',
          valor: 5000,
          dataHora: new Date('2026-07-30T10:00:00'),
        })
    );

    const chamadaConversao = chamadas[1];
    assert.ok(chamadaConversao.url.includes('customers/1234567890:uploadClickConversions'));
    assert.strictEqual(chamadaConversao.opts.headers['developer-token'], 'dev-token');
    assert.strictEqual(chamadaConversao.opts.headers.Authorization, 'Bearer token-abc');

    const corpoEnviado = JSON.parse(chamadaConversao.opts.body);
    assert.strictEqual(corpoEnviado.conversions[0].gclid, 'GCLID123');
    assert.strictEqual(corpoEnviado.conversions[0].conversionValue, 5000);
    assert.strictEqual(corpoEnviado.conversions[0].currencyCode, 'BRL');
    assert.strictEqual(
      corpoEnviado.conversions[0].conversionAction,
      'customers/1234567890/conversionActions/999'
    );
    console.log('OK: enviarConversaoOffline (URL, headers e corpo da requisição)');
  }

  // enviarConversaoOffline sem gclid deve falhar antes de qualquer chamada de rede
  {
    let erro = null;
    let chamadasFeitas = 0;
    const original = global.fetch;
    global.fetch = async () => {
      chamadasFeitas += 1;
      throw new Error('fetch nao deveria ser chamado');
    };
    try {
      await enviarConversaoOffline({}, { gclid: '', valor: 100, dataHora: new Date() });
    } catch (e) {
      erro = e;
    } finally {
      global.fetch = original;
    }
    assert.ok(erro, 'deveria lançar erro sem gclid');
    assert.strictEqual(chamadasFeitas, 0, 'nao deveria chamar a rede sem gclid');
    console.log('OK: enviarConversaoOffline exige gclid (sem tocar na rede)');
  }

  // testarConexaoGoogleAds - falha da API deve virar erro com mensagem da Google
  {
    let erro = null;
    await comFetchMockado(
      [
        { corpo: { access_token: 'token-abc' } },
        { ok: false, status: 403, corpo: { error: { message: 'developer token invalido' } } },
      ],
      async () => {
        try {
          await testarConexaoGoogleAds({
            googleAdsClientId: 'id',
            googleAdsClientSecret: 'segredo',
            googleAdsRefreshToken: 'refresh',
            googleAdsDeveloperToken: 'invalido',
          });
        } catch (e) {
          erro = e;
        }
      }
    );
    assert.ok(erro && erro.message.includes('developer token invalido'));
    console.log('OK: testarConexaoGoogleAds propaga erro da API');
  }

  console.log('\nTodos os testes do Módulo 1 (Google Ads) passaram.');
})();
