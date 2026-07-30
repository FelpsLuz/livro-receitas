async function enviarMensagemTelegram({ token, chatId, texto }) {
  if (!token || !chatId) {
    throw new Error('Token ou Chat ID do Telegram nao configurado');
  }

  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const resposta = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text: texto }),
  });

  const dados = await resposta.json();
  if (!resposta.ok || !dados.ok) {
    const descricao = dados.description || `HTTP ${resposta.status}`;
    throw new Error(`Falha ao enviar Telegram: ${descricao}`);
  }
  return dados;
}

async function testarConexaoTelegram({ token, chatId }) {
  return enviarMensagemTelegram({
    token,
    chatId,
    texto: '✅ CRM Juridico conectado com sucesso! Os alertas de prazo serao enviados por aqui.',
  });
}

module.exports = { enviarMensagemTelegram, testarConexaoTelegram };
