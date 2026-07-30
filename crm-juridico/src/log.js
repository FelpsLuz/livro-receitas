const fs = require('fs');
const path = require('path');

const LIMITE_BYTES = 1024 * 1024; // 1 MB antes de rotacionar

// Log em arquivo para diagnosticar problemas na maquina do usuario, onde nao ha
// console aberto. Nunca registra o conteudo de tokens ou dados de clientes.
function makeLogger(userDataPath) {
  const arquivo = path.join(userDataPath, 'crm-juridico.log');

  function rotacionarSeNecessario() {
    try {
      if (fs.existsSync(arquivo) && fs.statSync(arquivo).size > LIMITE_BYTES) {
        fs.renameSync(arquivo, `${arquivo}.1`);
      }
    } catch (_) {
      /* log nunca deve derrubar o app */
    }
  }

  return function log(mensagem) {
    const linha = `[${new Date().toISOString()}] ${mensagem}\n`;
    try {
      fs.mkdirSync(userDataPath, { recursive: true });
      rotacionarSeNecessario();
      fs.appendFileSync(arquivo, linha, 'utf8');
    } catch (_) {
      /* ignora */
    }
    if (process.env.NODE_ENV !== 'production') console.log(mensagem.trim());
  };
}

module.exports = { makeLogger };
