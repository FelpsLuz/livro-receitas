// Fluxo de autorizacao OAuth2 "installed app" usando um servidor HTTP local
// temporario para capturar o codigo de autorizacao, evitando a necessidade
// de ferramentas externas (como o OAuth Playground) para gerar o
// refresh_token usado nas chamadas a Google Ads API.

const http = require('http');

const ESCOPO_GOOGLE_ADS = 'https://www.googleapis.com/auth/adwords';
const TIMEOUT_MS = 5 * 60 * 1000;

function paginaHtml(titulo) {
  return `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>CRM Jurídico</title></head>
<body style="font-family: sans-serif; padding: 40px; text-align: center;"><h2>${titulo}</h2></body></html>`;
}

// abrirNavegador: function(url) => void — injetado pelo main process (shell.openExternal),
// para manter este modulo independente do Electron.
function autorizarGoogleAds({ clientId, clientSecret, abrirNavegador }) {
  return new Promise((resolve, reject) => {
    let finalizado = false;

    const finalizar = (fn, valor) => {
      if (finalizado) return;
      finalizado = true;
      clearTimeout(timeoutId);
      try {
        servidor.close();
      } catch (_) {
        /* ignora erro ao fechar servidor ja fechado */
      }
      fn(valor);
    };

    const servidor = http.createServer(async (req, res) => {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname !== '/') {
        res.writeHead(404).end();
        return;
      }

      const erro = url.searchParams.get('error');
      const code = url.searchParams.get('code');

      if (erro) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(paginaHtml('Autorização cancelada. Você já pode fechar esta aba.'));
        finalizar(reject, new Error(`Autorização cancelada: ${erro}`));
        return;
      }
      if (!code) {
        res.writeHead(400).end('Código de autorização ausente.');
        return;
      }

      try {
        const porta = servidor.address().port;
        const tokenResposta = await fetch('https://oauth2.googleapis.com/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            client_id: clientId,
            client_secret: clientSecret,
            code,
            grant_type: 'authorization_code',
            redirect_uri: `http://localhost:${porta}`,
          }),
        });
        const tokenDados = await tokenResposta.json();

        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });

        if (!tokenResposta.ok || !tokenDados.refresh_token) {
          res.end(
            paginaHtml(
              'Falha ao obter o token de acesso. Você já pode fechar esta aba e conferir o erro no CRM Jurídico.'
            )
          );
          finalizar(
            reject,
            new Error(
              tokenDados.error_description ||
                'O Google não retornou um refresh_token. Revogue o acesso anterior em ' +
                  'https://myaccount.google.com/permissions e tente novamente.'
            )
          );
          return;
        }

        res.end(paginaHtml('Conectado com sucesso! Você já pode fechar esta aba e voltar ao CRM Jurídico.'));
        finalizar(resolve, {
          refreshToken: tokenDados.refresh_token,
          accessToken: tokenDados.access_token,
        });
      } catch (e) {
        finalizar(reject, e);
      }
    });

    const timeoutId = setTimeout(() => {
      finalizar(reject, new Error('Tempo esgotado aguardando autorização no navegador.'));
    }, TIMEOUT_MS);

    servidor.on('error', (e) => finalizar(reject, e));

    servidor.listen(0, '127.0.0.1', () => {
      const porta = servidor.address().port;
      const redirectUri = `http://localhost:${porta}`;
      const parametros = new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirectUri,
        response_type: 'code',
        scope: ESCOPO_GOOGLE_ADS,
        access_type: 'offline',
        prompt: 'consent',
      });
      abrirNavegador(`https://accounts.google.com/o/oauth2/v2/auth?${parametros.toString()}`);
    });
  });
}

module.exports = { autorizarGoogleAds, ESCOPO_GOOGLE_ADS };
