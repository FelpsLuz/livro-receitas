const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function makeStore(userDataPath) {
  const prazosFile = path.join(userDataPath, 'prazos.json');
  const configFile = path.join(userDataPath, 'config.json');

  const defaultConfig = {
    telegramBotToken: '',
    telegramChatId: '',
    horarioVerificacao: '08:00',
    notificacoesAtivas: true,
  };

  function readJson(file, fallback) {
    try {
      return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (err) {
      return fallback;
    }
  }

  function writeJson(file, data) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
  }

  function listPrazos() {
    return readJson(prazosFile, []);
  }

  function savePrazos(prazos) {
    writeJson(prazosFile, prazos);
  }

  function addPrazo(prazo) {
    const prazos = listPrazos();
    const novo = {
      id: crypto.randomUUID(),
      processo: prazo.processo || '',
      cliente: prazo.cliente || '',
      acao: prazo.acao || '',
      advogadoResponsavel: prazo.advogadoResponsavel || '',
      dataVencimento: prazo.dataVencimento,
      status: 'Pendente',
      alertasEnviados: [],
      createdAt: new Date().toISOString(),
    };
    prazos.push(novo);
    savePrazos(prazos);
    return novo;
  }

  function updatePrazo(id, changes) {
    const prazos = listPrazos();
    const idx = prazos.findIndex((p) => p.id === id);
    if (idx === -1) throw new Error('Prazo nao encontrado');
    prazos[idx] = { ...prazos[idx], ...changes };
    savePrazos(prazos);
    return prazos[idx];
  }

  function deletePrazo(id) {
    const prazos = listPrazos().filter((p) => p.id !== id);
    savePrazos(prazos);
  }

  function getConfig() {
    return { ...defaultConfig, ...readJson(configFile, {}) };
  }

  function saveConfig(config) {
    writeJson(configFile, { ...getConfig(), ...config });
    return getConfig();
  }

  return {
    listPrazos,
    savePrazos,
    addPrazo,
    updatePrazo,
    deletePrazo,
    getConfig,
    saveConfig,
  };
}

module.exports = { makeStore };
