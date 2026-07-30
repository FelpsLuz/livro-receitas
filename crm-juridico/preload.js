const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // Prazos
  listarPrazos: () => ipcRenderer.invoke('prazos:listar'),
  adicionarPrazo: (prazo) => ipcRenderer.invoke('prazos:adicionar', prazo),
  atualizarPrazo: (id, changes) => ipcRenderer.invoke('prazos:atualizar', { id, changes }),
  excluirPrazo: (id) => ipcRenderer.invoke('prazos:excluir', id),
  concluirPrazo: (id) => ipcRenderer.invoke('prazos:concluir', id),
  reabrirPrazo: (id) => ipcRenderer.invoke('prazos:reabrir', id),
  verificarAgora: () => ipcRenderer.invoke('prazos:verificarAgora'),

  // Configuracoes
  obterConfig: () => ipcRenderer.invoke('config:obter'),
  salvarConfig: (config) => ipcRenderer.invoke('config:salvar', config),
  testarTelegram: (config) => ipcRenderer.invoke('config:testarTelegram', config),

  // Clientes
  listarClientes: () => ipcRenderer.invoke('clientes:listar'),
  adicionarCliente: (cliente) => ipcRenderer.invoke('clientes:adicionar', cliente),
  atualizarCliente: (id, changes) => ipcRenderer.invoke('clientes:atualizar', { id, changes }),
  excluirCliente: (id) => ipcRenderer.invoke('clientes:excluir', id),
  avancarEtapa: (id, etapa) => ipcRenderer.invoke('clientes:avancarEtapa', { id, etapa }),
  reprocessarConversoes: () => ipcRenderer.invoke('clientes:reprocessarConversoes'),
  listarConversoesPorCliente: (id) => ipcRenderer.invoke('clientes:listarConversoes', id),
  obterFichaCliente: (id) => ipcRenderer.invoke('clientes:ficha', id),
  listarEtapasFunil: () => ipcRenderer.invoke('funil:etapas'),

  // Modelos de contrato
  listarTemplates: () => ipcRenderer.invoke('templates:listar'),
  importarTemplate: () => ipcRenderer.invoke('templates:importar'),
  excluirTemplate: (id) => ipcRenderer.invoke('templates:excluir', id),

  // Contratos
  gerarContrato: (clienteId, templateId) => ipcRenderer.invoke('contratos:gerar', { clienteId, templateId }),
  listarContratosPorCliente: (clienteId) => ipcRenderer.invoke('contratos:listarPorCliente', clienteId),

  // Dashboard
  obterDashboard: (dias) => ipcRenderer.invoke('dashboard:obter', dias),
  sincronizarAds: (dias) => ipcRenderer.invoke('dashboard:sincronizarAds', dias),

  // Google Ads
  autorizarGoogleAds: (clientId, clientSecret) =>
    ipcRenderer.invoke('config:autorizarGoogleAds', { clientId, clientSecret }),
  desconectarGoogleAds: () => ipcRenderer.invoke('config:desconectarGoogleAds'),
  testarGoogleAds: () => ipcRenderer.invoke('config:testarGoogleAds'),

  // Sistema
  abrirCaminho: (caminho) => ipcRenderer.invoke('sistema:abrirCaminho', caminho),
  abrirExterno: (url) => ipcRenderer.invoke('sistema:abrirExterno', url),
  abrirWhatsapp: (telefone, mensagem) => ipcRenderer.invoke('sistema:abrirWhatsapp', { telefone, mensagem }),
  abrirPastaDados: () => ipcRenderer.invoke('sistema:abrirPastaDados'),
  infoSistema: () => ipcRenderer.invoke('sistema:info'),
  exportarBackup: () => ipcRenderer.invoke('sistema:exportarBackup'),
});
