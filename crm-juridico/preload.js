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
});
