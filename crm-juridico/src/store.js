const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function makeStore(userDataPath) {
  const prazosFile = path.join(userDataPath, 'prazos.json');
  const configFile = path.join(userDataPath, 'config.json');
  const clientesFile = path.join(userDataPath, 'clientes.json');
  const templatesMetaFile = path.join(userDataPath, 'templates.json');
  const contratosFile = path.join(userDataPath, 'contratos.json');
  const templatesDir = path.join(userDataPath, 'templates');
  const contratosDir = path.join(userDataPath, 'contratos');

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

  // ----- Clientes -----

  function listClientes() {
    return readJson(clientesFile, []);
  }

  function saveClientes(clientes) {
    writeJson(clientesFile, clientes);
  }

  function addCliente(cliente) {
    const clientes = listClientes();
    const novo = {
      id: crypto.randomUUID(),
      nome: '',
      cpf: '',
      endereco: '',
      telefone: '',
      valorHonorarios: 0,
      formaPagamento: '',
      createdAt: new Date().toISOString(),
      ...cliente,
    };
    clientes.push(novo);
    saveClientes(clientes);
    return novo;
  }

  function updateCliente(id, changes) {
    const clientes = listClientes();
    const idx = clientes.findIndex((c) => c.id === id);
    if (idx === -1) throw new Error('Cliente nao encontrado');
    clientes[idx] = { ...clientes[idx], ...changes };
    saveClientes(clientes);
    return clientes[idx];
  }

  function deleteCliente(id) {
    saveClientes(listClientes().filter((c) => c.id !== id));
  }

  // ----- Modelos de contrato -----

  function listTemplates() {
    return readJson(templatesMetaFile, []);
  }

  function saveTemplatesMeta(templates) {
    writeJson(templatesMetaFile, templates);
  }

  function addTemplateFromFile(caminhoOrigem, nomeExibicao) {
    fs.mkdirSync(templatesDir, { recursive: true });
    const id = crypto.randomUUID();
    const destino = path.join(templatesDir, `${id}.docx`);
    fs.copyFileSync(caminhoOrigem, destino);

    const templates = listTemplates();
    const novo = {
      id,
      nome: nomeExibicao,
      arquivo: destino,
      importadoEm: new Date().toISOString(),
    };
    templates.push(novo);
    saveTemplatesMeta(templates);
    return novo;
  }

  function deleteTemplate(id) {
    const templates = listTemplates();
    const alvo = templates.find((t) => t.id === id);
    if (alvo && fs.existsSync(alvo.arquivo)) {
      fs.unlinkSync(alvo.arquivo);
    }
    saveTemplatesMeta(templates.filter((t) => t.id !== id));
  }

  function garantirTemplatePadrao(caminhoOrigemPadrao) {
    if (listTemplates().length > 0) return;
    if (fs.existsSync(caminhoOrigemPadrao)) {
      addTemplateFromFile(caminhoOrigemPadrao, 'Modelo Padrão de Honorários');
    }
  }

  // ----- Contratos gerados (histórico) -----

  function listContratos() {
    return readJson(contratosFile, []);
  }

  function addContratoHistorico(registro) {
    const contratos = listContratos();
    const novo = { id: crypto.randomUUID(), ...registro };
    contratos.push(novo);
    writeJson(contratosFile, contratos);
    return novo;
  }

  function listContratosPorCliente(clienteId) {
    return listContratos().filter((c) => c.clienteId === clienteId);
  }

  return {
    listPrazos,
    savePrazos,
    addPrazo,
    updatePrazo,
    deletePrazo,
    getConfig,
    saveConfig,
    listClientes,
    addCliente,
    updateCliente,
    deleteCliente,
    listTemplates,
    addTemplateFromFile,
    deleteTemplate,
    garantirTemplatePadrao,
    listContratos,
    addContratoHistorico,
    listContratosPorCliente,
    templatesDir,
    contratosDir,
  };
}

module.exports = { makeStore };
