const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  listarPrazos: () => ipcRenderer.invoke('prazos:listar'),
  adicionarPrazo: (prazo) => ipcRenderer.invoke('prazos:adicionar', prazo),
  atualizarPrazo: (id, changes) => ipcRenderer.invoke('prazos:atualizar', { id, changes }),
  excluirPrazo: (id) => ipcRenderer.invoke('prazos:excluir', id),
  concluirPrazo: (id) => ipcRenderer.invoke('prazos:concluir', id),
  obterConfig: () => ipcRenderer.invoke('config:obter'),
  salvarConfig: (config) => ipcRenderer.invoke('config:salvar', config),
  testarTelegram: (config) => ipcRenderer.invoke('config:testarTelegram', config),
  verificarAgora: () => ipcRenderer.invoke('prazos:verificarAgora'),

  listarClientes: () => ipcRenderer.invoke('clientes:listar'),
  adicionarCliente: (cliente) => ipcRenderer.invoke('clientes:adicionar', cliente),
  atualizarCliente: (id, changes) => ipcRenderer.invoke('clientes:atualizar', { id, changes }),
  excluirCliente: (id) => ipcRenderer.invoke('clientes:excluir', id),
  fecharContratoCliente: (id) => ipcRenderer.invoke('clientes:fecharContrato', id),
  reabrirCliente: (id) => ipcRenderer.invoke('clientes:reabrir', id),
  reenviarConversao: (id) => ipcRenderer.invoke('clientes:reenviarConversao', id),
  listarConversoesPorCliente: (id) => ipcRenderer.invoke('clientes:listarConversoes', id),

  listarTemplates: () => ipcRenderer.invoke('templates:listar'),
  importarTemplate: () => ipcRenderer.invoke('templates:importar'),
  excluirTemplate: (id) => ipcRenderer.invoke('templates:excluir', id),

  gerarContrato: (clienteId, templateId) =>
    ipcRenderer.invoke('contratos:gerar', { clienteId, templateId }),
  listarContratosPorCliente: (clienteId) =>
    ipcRenderer.invoke('contratos:listarPorCliente', clienteId),

  abrirCaminho: (caminho) => ipcRenderer.invoke('sistema:abrirCaminho', caminho),
  abrirExterno: (url) => ipcRenderer.invoke('sistema:abrirExterno', url),
  abrirWhatsapp: (telefone, mensagem) =>
    ipcRenderer.invoke('sistema:abrirWhatsapp', { telefone, mensagem }),

  autorizarGoogleAds: (clientId, clientSecret) =>
    ipcRenderer.invoke('config:autorizarGoogleAds', { clientId, clientSecret }),
  desconectarGoogleAds: () => ipcRenderer.invoke('config:desconectarGoogleAds'),
  testarGoogleAds: () => ipcRenderer.invoke('config:testarGoogleAds'),
});
