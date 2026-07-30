const { app, BrowserWindow, ipcMain, Notification, dialog, shell } = require('electron');
const path = require('path');
const cron = require('node-cron');

const { makeStore } = require('./src/store');
const { prazosParaAlertar, formatarMensagem, situacao, diasRestantes } = require('./src/prazos');
const { enviarMensagemTelegram, testarConexaoTelegram } = require('./src/telegram');
const { detectarTags } = require('./src/docxTemplate');
const { gerarContrato } = require('./src/geradorContratos');
const { testarConexaoGoogleAds, enviarConversaoOffline } = require('./src/googleAds');
const { autorizarGoogleAds } = require('./src/googleOAuth');

let mainWindow;
let store;
let tarefaAgendada = null;

function criarJanela() {
  mainWindow = new BrowserWindow({
    width: 1000,
    height: 700,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

function notificarDesktop(prazo, dias) {
  if (!Notification.isSupported()) return;
  const titulo = dias === 0 ? 'Prazo vence HOJE' : `Prazo vence em ${dias} dia(s)`;
  new Notification({
    title: titulo,
    body: `${prazo.processo} - ${prazo.cliente}`,
  }).show();
}

async function verificarPrazos() {
  const config = store.getConfig();
  const prazos = store.listPrazos();
  const alertas = prazosParaAlertar(prazos);
  const resultado = [];

  for (const alerta of alertas) {
    const { prazo, dias, hojeStr } = alerta;
    const mensagem = formatarMensagem(alerta);

    notificarDesktop(prazo, dias);

    let telegramOk = false;
    let erro = null;
    if (config.notificacoesAtivas && config.telegramBotToken && config.telegramChatId) {
      try {
        await enviarMensagemTelegram({
          token: config.telegramBotToken,
          chatId: config.telegramChatId,
          texto: mensagem,
        });
        telegramOk = true;
      } catch (e) {
        erro = e.message;
      }
    }

    const alertasEnviados = prazo.alertasEnviados || [];
    alertasEnviados.push({ limiar: dias, data: hojeStr, telegramOk });
    store.updatePrazo(prazo.id, { alertasEnviados });

    resultado.push({ prazo: prazo.processo, dias, telegramOk, erro });
  }

  return resultado;
}

function agendarVerificacaoDiaria() {
  if (tarefaAgendada) {
    tarefaAgendada.stop();
  }
  const config = store.getConfig();
  const [hora, minuto] = (config.horarioVerificacao || '08:00').split(':');
  const expressao = `${parseInt(minuto, 10)} ${parseInt(hora, 10)} * * *`;
  tarefaAgendada = cron.schedule(expressao, () => {
    verificarPrazos().catch((e) => console.error('Erro na verificacao agendada:', e));
  });
}

app.whenReady().then(() => {
  store = makeStore(app.getPath('userData'));
  store.garantirTemplatePadrao(path.join(__dirname, 'assets', 'templates', 'modelo-padrao.docx'));
  criarJanela();
  agendarVerificacaoDiaria();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) criarJanela();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ----- IPC -----

ipcMain.handle('prazos:listar', () => {
  return store.listPrazos().map((p) => ({
    ...p,
    dias: diasRestantes(p.dataVencimento),
    situacao: situacao(p),
  }));
});

ipcMain.handle('prazos:adicionar', (_event, prazo) => store.addPrazo(prazo));

ipcMain.handle('prazos:atualizar', (_event, { id, changes }) => store.updatePrazo(id, changes));

ipcMain.handle('prazos:excluir', (_event, id) => {
  store.deletePrazo(id);
  return true;
});

ipcMain.handle('prazos:concluir', (_event, id) => store.updatePrazo(id, { status: 'Concluido' }));

ipcMain.handle('config:obter', () => store.getConfig());

ipcMain.handle('config:salvar', (_event, config) => {
  const salvo = store.saveConfig(config);
  agendarVerificacaoDiaria();
  return salvo;
});

ipcMain.handle('config:testarTelegram', async (_event, { telegramBotToken, telegramChatId }) => {
  await testarConexaoTelegram({ token: telegramBotToken, chatId: telegramChatId });
  return true;
});

ipcMain.handle('prazos:verificarAgora', () => verificarPrazos());

// ----- Clientes -----

ipcMain.handle('clientes:listar', () => store.listClientes());

ipcMain.handle('clientes:adicionar', (_event, cliente) => store.addCliente(cliente));

ipcMain.handle('clientes:atualizar', (_event, { id, changes }) => store.updateCliente(id, changes));

ipcMain.handle('clientes:excluir', (_event, id) => {
  store.deleteCliente(id);
  return true;
});

async function tentarEnviarConversao(cliente) {
  const config = store.getConfig();

  if (!cliente.gclid) {
    return { enviouConversao: false, erro: 'Cliente nao possui GCLID cadastrado.' };
  }
  if (!config.googleAdsRefreshToken || !config.googleAdsCustomerId || !config.googleAdsConversionActionId) {
    return { enviouConversao: false, erro: 'Configuração do Google Ads incompleta (veja a aba Configurações).' };
  }

  try {
    await enviarConversaoOffline(config, {
      gclid: cliente.gclid,
      valor: cliente.valorHonorarios,
      dataHora: new Date(),
    });
    store.addConversaoHistorico({
      clienteId: cliente.id,
      gclid: cliente.gclid,
      valor: cliente.valorHonorarios,
      enviadoEm: new Date().toISOString(),
      sucesso: true,
      erro: null,
    });
    return { enviouConversao: true, erro: null };
  } catch (e) {
    store.addConversaoHistorico({
      clienteId: cliente.id,
      gclid: cliente.gclid,
      valor: cliente.valorHonorarios,
      enviadoEm: new Date().toISOString(),
      sucesso: false,
      erro: e.message,
    });
    return { enviouConversao: false, erro: e.message };
  }
}

ipcMain.handle('clientes:fecharContrato', async (_event, id) => {
  const cliente = store.updateCliente(id, {
    status: 'Contrato Fechado',
    fechadoEm: new Date().toISOString(),
  });
  const resultado = await tentarEnviarConversao(cliente);
  return { cliente, ...resultado };
});

ipcMain.handle('clientes:reabrir', (_event, id) =>
  store.updateCliente(id, { status: 'Lead', fechadoEm: null })
);

ipcMain.handle('clientes:reenviarConversao', async (_event, id) => {
  const cliente = store.listClientes().find((c) => c.id === id);
  if (!cliente) throw new Error('Cliente nao encontrado');
  return tentarEnviarConversao(cliente);
});

ipcMain.handle('clientes:listarConversoes', (_event, clienteId) =>
  store.listConversoesPorCliente(clienteId)
);

// ----- Modelos de contrato -----

ipcMain.handle('templates:listar', () => {
  return store.listTemplates().map((t) => ({ ...t, tags: detectarTags(t.arquivo) }));
});

ipcMain.handle('templates:importar', async () => {
  const resultado = await dialog.showOpenDialog(mainWindow, {
    title: 'Selecionar modelo de contrato (.docx)',
    filters: [{ name: 'Documento Word', extensions: ['docx'] }],
    properties: ['openFile'],
  });
  if (resultado.canceled || !resultado.filePaths[0]) return null;

  const caminho = resultado.filePaths[0];
  const nome = path.basename(caminho, path.extname(caminho));
  const template = store.addTemplateFromFile(caminho, nome);
  return { ...template, tags: detectarTags(template.arquivo) };
});

ipcMain.handle('templates:excluir', (_event, id) => {
  store.deleteTemplate(id);
  return true;
});

// ----- Contratos -----

ipcMain.handle('contratos:gerar', async (_event, { clienteId, templateId }) => {
  const cliente = store.listClientes().find((c) => c.id === clienteId);
  const template = store.listTemplates().find((t) => t.id === templateId);
  if (!cliente) throw new Error('Cliente nao encontrado');
  if (!template) throw new Error('Modelo de contrato nao encontrado');

  const { caminhoDocx, caminhoPdf } = await gerarContrato({
    cliente,
    template: { nome: template.nome, caminhoAbsoluto: template.arquivo },
    pastaBaseContratos: store.contratosDir,
    timestamp: new Date(),
  });

  return store.addContratoHistorico({
    clienteId,
    templateId,
    templateNome: template.nome,
    arquivoDocx: caminhoDocx,
    arquivoPdf: caminhoPdf,
    geradoEm: new Date().toISOString(),
  });
});

ipcMain.handle('contratos:listarPorCliente', (_event, clienteId) =>
  store.listContratosPorCliente(clienteId)
);

// ----- Sistema (arquivos / WhatsApp) -----

ipcMain.handle('sistema:abrirCaminho', (_event, caminho) => {
  shell.showItemInFolder(caminho);
  return true;
});

ipcMain.handle('sistema:abrirExterno', (_event, url) => {
  shell.openExternal(url);
  return true;
});

ipcMain.handle('sistema:abrirWhatsapp', (_event, { telefone, mensagem }) => {
  const numero = (telefone || '').replace(/\D/g, '');
  const url = `https://wa.me/${numero}?text=${encodeURIComponent(mensagem || '')}`;
  shell.openExternal(url);
  return true;
});

// ----- Google Ads (conversões offline) -----

ipcMain.handle('config:autorizarGoogleAds', async (_event, { clientId, clientSecret }) => {
  const { refreshToken } = await autorizarGoogleAds({
    clientId,
    clientSecret,
    abrirNavegador: (url) => shell.openExternal(url),
  });
  return store.saveConfig({
    googleAdsClientId: clientId,
    googleAdsClientSecret: clientSecret,
    googleAdsRefreshToken: refreshToken,
  });
});

ipcMain.handle('config:desconectarGoogleAds', () =>
  store.saveConfig({ googleAdsRefreshToken: '' })
);

ipcMain.handle('config:testarGoogleAds', async () => {
  await testarConexaoGoogleAds(store.getConfig());
  return true;
});
