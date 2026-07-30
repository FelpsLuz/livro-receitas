const { app, BrowserWindow, ipcMain, Notification } = require('electron');
const path = require('path');
const cron = require('node-cron');

const { makeStore } = require('./src/store');
const { prazosParaAlertar, formatarMensagem, situacao, diasRestantes } = require('./src/prazos');
const { enviarMensagemTelegram, testarConexaoTelegram } = require('./src/telegram');

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
