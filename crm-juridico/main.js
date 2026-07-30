const { app, BrowserWindow, ipcMain, Notification, dialog, shell, safeStorage } = require('electron');
const path = require('path');
const cron = require('node-cron');

const { makeStore } = require('./src/store');
const { makeLogger } = require('./src/log');
const {
  prazosParaAlertar,
  formatarMensagem,
  situacao,
  diasRestantes,
  registrarAlertaEnviado,
} = require('./src/prazos');
const { enviarMensagemTelegram, testarConexaoTelegram } = require('./src/telegram');
const { detectarTags } = require('./src/docxTemplate');
const { gerarContrato } = require('./src/geradorContratos');
const {
  testarConexaoGoogleAds,
  buscarCustosCampanhas,
  buscarOrigemDosCliques,
  API_VERSION_PADRAO,
} = require('./src/googleAds');
const { autorizarGoogleAds } = require('./src/googleOAuth');
const { processarFila, avancarEtapa, motivoNaoEnviavel } = require('./src/servicoConversoes');
const { montarDashboard } = require('./src/relatorios');
const { ETAPAS } = require('./src/funil');

const INTERVALO_FILA_MS = 5 * 60 * 1000; // reprocessa a fila de conversoes a cada 5 min

let mainWindow;
let store;
let log = () => {};
let tarefaAgendada = null;
let timerFila = null;

// Adaptador de criptografia baseado no safeStorage do Electron, que usa o
// cofre do proprio sistema (DPAPI no Windows, Keychain no Mac). Sem isso os
// tokens do Google Ads ficariam legiveis em texto puro no disco.
function criarCripto() {
  const disponivel = safeStorage.isEncryptionAvailable();
  return {
    disponivel,
    encrypt: (texto) => safeStorage.encryptString(texto).toString('base64'),
    decrypt: (b64) => safeStorage.decryptString(Buffer.from(b64, 'base64')),
  };
}

function criarJanela() {
  mainWindow = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 900,
    minHeight: 600,
    icon: path.join(__dirname, 'assets', 'icone.png'),
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  mainWindow.setMenuBarVisibility(false);
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.once('ready-to-show', () => mainWindow.show());
}

function notificarDesktop(prazo, dias) {
  if (!Notification.isSupported()) return;
  const titulo =
    dias < 0 ? `Prazo VENCIDO há ${Math.abs(dias)} dia(s)` : dias === 0 ? 'Prazo vence HOJE' : `Prazo vence em ${dias} dia(s)`;
  const notificacao = new Notification({
    title: titulo,
    body: `${prazo.processo}${prazo.cliente ? ` — ${prazo.cliente}` : ''}`,
    urgency: 'critical',
  });
  notificacao.on('click', () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
  notificacao.show();
}

async function verificarPrazos() {
  const config = store.getConfig();
  const alertas = prazosParaAlertar(store.listPrazos());
  const resultado = [];

  for (const alerta of alertas) {
    const { prazo, dias } = alerta;
    notificarDesktop(prazo, dias);

    let telegramOk = false;
    let erro = null;
    if (config.notificacoesAtivas && config.telegramBotToken && config.telegramChatId) {
      try {
        await enviarMensagemTelegram({
          token: config.telegramBotToken,
          chatId: config.telegramChatId,
          texto: formatarMensagem(alerta),
        });
        telegramOk = true;
      } catch (e) {
        erro = e.message;
        log(`Falha ao enviar alerta pelo Telegram: ${e.message}`);
      }
    }

    store.updatePrazo(prazo.id, {
      alertasEnviados: registrarAlertaEnviado(prazo, alerta, telegramOk),
    });
    resultado.push({ prazo: prazo.processo, dias, telegramOk, erro });
  }

  if (resultado.length) log(`Verificacao de prazos: ${resultado.length} alerta(s) disparado(s).`);
  return resultado;
}

function agendarVerificacaoDiaria() {
  if (tarefaAgendada) tarefaAgendada.stop();
  const config = store.getConfig();
  const [hora, minuto] = (config.horarioVerificacao || '08:00').split(':');
  const expressao = `${parseInt(minuto, 10) || 0} ${parseInt(hora, 10) || 8} * * *`;
  tarefaAgendada = cron.schedule(expressao, () => {
    verificarPrazos().catch((e) => log(`Erro na verificacao agendada: ${e.message}`));
  });
  log(`Verificacao diaria agendada para ${config.horarioVerificacao}.`);
}

function aplicarAutostart() {
  const config = store.getConfig();
  // Em dev (rodando via `electron .`) registrar autostart apontaria para o
  // binario do Electron, nao para o app instalado - entao so aplicamos no app
  // empacotado.
  if (!app.isPackaged) return;
  app.setLoginItemSettings({
    openAtLogin: Boolean(config.iniciarComWindows),
    args: ['--iniciado-pelo-sistema'],
  });
}

function iniciarProcessamentoDaFila() {
  if (timerFila) clearInterval(timerFila);
  timerFila = setInterval(() => {
    processarFila(store)
      .then((r) => {
        if (r.processadas) log(`Fila de conversoes: ${r.enviadas} enviada(s), ${r.pendentes} pendente(s).`);
      })
      .catch((e) => log(`Erro ao processar fila de conversoes: ${e.message}`));
  }, INTERVALO_FILA_MS);
}

// Uma unica instancia: abrir de novo apenas foca a janela existente.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });

  app.whenReady().then(async () => {
    const userData = app.getPath('userData');
    log = makeLogger(userData);
    log(`--- CRM Juridico ${app.getVersion()} iniciando ---`);

    const cripto = criarCripto();
    if (!cripto.disponivel) {
      log('AVISO: cofre do sistema indisponivel - os segredos ficarao sem criptografia.');
    }

    store = makeStore(userData, { cripto, log });
    store.migrar();
    store.garantirTemplatePadrao(path.join(__dirname, 'assets', 'templates', 'modelo-padrao.docx'));

    criarJanela();
    agendarVerificacaoDiaria();
    aplicarAutostart();
    iniciarProcessamentoDaFila();

    // Catch-up: roda a verificacao na abertura para recuperar alertas que
    // deveriam ter disparado enquanto o computador estava desligado.
    verificarPrazos().catch((e) => log(`Erro na verificacao inicial: ${e.message}`));
    processarFila(store).catch((e) => log(`Erro ao processar fila na abertura: ${e.message}`));

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) criarJanela();
    });
  });
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// Envolve os handlers para que qualquer excecao vire uma mensagem legivel na UI
// em vez de um "Error invoking remote method" cru.
function handle(canal, fn) {
  ipcMain.handle(canal, async (evento, ...args) => {
    try {
      return await fn(evento, ...args);
    } catch (e) {
      log(`Erro em ${canal}: ${e.message}`);
      throw new Error(e.message);
    }
  });
}

// ----- Prazos -----

handle('prazos:listar', () => {
  const clientes = new Map(store.listClientes().map((c) => [c.id, c.nome]));
  return store.listPrazos().map((p) => ({
    ...p,
    cliente: p.clienteId ? clientes.get(p.clienteId) || p.cliente : p.cliente,
    dias: diasRestantes(p.dataVencimento),
    situacao: situacao(p),
  }));
});

handle('prazos:adicionar', (_e, prazo) => store.addPrazo(prazo));
handle('prazos:atualizar', (_e, { id, changes }) => store.updatePrazo(id, changes));
handle('prazos:excluir', (_e, id) => {
  store.deletePrazo(id);
  return true;
});
handle('prazos:concluir', (_e, id) => store.updatePrazo(id, { status: 'Concluido' }));
handle('prazos:reabrir', (_e, id) => store.updatePrazo(id, { status: 'Pendente' }));
handle('prazos:verificarAgora', () => verificarPrazos());

// ----- Configuracoes -----

handle('config:obter', () => {
  const config = store.getConfig();
  return { ...config, googleAdsApiVersion: config.googleAdsApiVersion || API_VERSION_PADRAO };
});

handle('config:salvar', (_e, config) => {
  const salvo = store.saveConfig(config);
  agendarVerificacaoDiaria();
  aplicarAutostart();
  return salvo;
});

handle('config:testarTelegram', async (_e, { telegramBotToken, telegramChatId }) => {
  await testarConexaoTelegram({ token: telegramBotToken, chatId: telegramChatId });
  return true;
});

// ----- Clientes -----

handle('clientes:listar', () => {
  // Junta tudo numa consulta so: a UI antes fazia uma chamada IPC por cliente
  // para buscar as conversoes, o que travava a tela com muitos cadastros.
  const conversoes = store.listConversoes();
  const contratos = store.listContratos();
  const prazos = store.listPrazos();

  const agrupar = (lista, chave) => {
    const mapa = new Map();
    for (const item of lista) {
      const k = item[chave];
      if (!mapa.has(k)) mapa.set(k, []);
      mapa.get(k).push(item);
    }
    return mapa;
  };

  const convPorCliente = agrupar(conversoes, 'clienteId');
  const contrPorCliente = agrupar(contratos, 'clienteId');
  const prazosPorCliente = agrupar(prazos, 'clienteId');

  return store.listClientes().map((c) => {
    const conv = convPorCliente.get(c.id) || [];
    return {
      ...c,
      resumoConversoes: {
        enviadas: conv.filter((x) => x.status === 'enviada').length,
        pendentes: conv.filter((x) => x.status === 'pendente').length,
        falhas: conv.filter((x) => x.status === 'falhou').length,
        ultimoErro: (conv.find((x) => x.erro && x.status !== 'enviada') || {}).erro || null,
      },
      totalContratos: (contrPorCliente.get(c.id) || []).length,
      prazosAbertos: (prazosPorCliente.get(c.id) || []).filter((p) => p.status !== 'Concluido').length,
    };
  });
});

handle('clientes:adicionar', (_e, cliente) => store.addCliente(cliente));
handle('clientes:atualizar', (_e, { id, changes }) => store.updateCliente(id, changes));
handle('clientes:excluir', (_e, id) => {
  store.deleteCliente(id);
  return true;
});

handle('clientes:avancarEtapa', async (_e, { id, etapa }) => avancarEtapa(store, id, etapa));

handle('clientes:reprocessarConversoes', async () => processarFila(store, { forcar: true }));

handle('clientes:listarConversoes', (_e, clienteId) => store.listConversoesPorCliente(clienteId));

// Ficha 360: tudo que existe sobre um cliente, em uma chamada.
handle('clientes:ficha', (_e, clienteId) => {
  const cliente = store.getCliente(clienteId);
  if (!cliente) throw new Error('Cliente não encontrado');
  return {
    cliente,
    prazos: store.listPrazosPorCliente(clienteId).map((p) => ({
      ...p,
      dias: diasRestantes(p.dataVencimento),
      situacao: situacao(p),
    })),
    contratos: store.listContratosPorCliente(clienteId),
    conversoes: store.listConversoesPorCliente(clienteId),
    impedimentoConversao: motivoNaoEnviavel(cliente, store.getConfig()),
  };
});

handle('funil:etapas', () => ETAPAS);

// ----- Modelos de contrato -----

handle('templates:listar', () =>
  store.listTemplates().map((t) => {
    try {
      return { ...t, tags: detectarTags(t.arquivo) };
    } catch (e) {
      return { ...t, tags: [], erro: 'Arquivo do modelo não encontrado ou inválido.' };
    }
  })
);

handle('templates:importar', async () => {
  const resultado = await dialog.showOpenDialog(mainWindow, {
    title: 'Selecionar modelo de contrato (.docx)',
    filters: [{ name: 'Documento Word', extensions: ['docx'] }],
    properties: ['openFile'],
  });
  if (resultado.canceled || !resultado.filePaths[0]) return null;

  const caminho = resultado.filePaths[0];
  const template = store.addTemplateFromFile(caminho, path.basename(caminho, path.extname(caminho)));
  return { ...template, tags: detectarTags(template.arquivo) };
});

handle('templates:excluir', (_e, id) => {
  store.deleteTemplate(id);
  return true;
});

// ----- Contratos -----

handle('contratos:gerar', async (_e, { clienteId, templateId }) => {
  const cliente = store.getCliente(clienteId);
  const template = store.listTemplates().find((t) => t.id === templateId);
  if (!cliente) throw new Error('Cliente não encontrado');
  if (!template) throw new Error('Modelo de contrato não encontrado');

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

handle('contratos:listarPorCliente', (_e, clienteId) => store.listContratosPorCliente(clienteId));

// ----- Dashboard -----

handle('dashboard:obter', (_e, dias = 30) => {
  const metricas = store.getMetricasAds();
  return montarDashboard({
    clientes: store.listClientes(),
    conversoes: store.listConversoes(),
    metricas,
    origemPorGclid: metricas.origemPorGclid || {},
    dias,
  });
});

// Puxa custos e origem dos cliques do Google Ads e guarda localmente.
handle('dashboard:sincronizarAds', async (_e, dias = 30) => {
  const config = store.getConfig();
  const periodoGaql = dias <= 7 ? 'LAST_7_DAYS' : dias <= 14 ? 'LAST_14_DAYS' : 'LAST_30_DAYS';

  const metricas = await buscarCustosCampanhas(config, periodoGaql);

  // Descobre campanha/palavra-chave dos GCLIDs que temos cadastrados.
  // click_view so cobre os ultimos 90 dias, entao consultamos as datas em que
  // os clientes com gclid entraram.
  const datas = new Set();
  const limite = new Date();
  limite.setDate(limite.getDate() - 89);

  for (const cliente of store.listClientes()) {
    if (!cliente.gclid) continue;
    const entrada = (cliente.etapasAtingidas || {}).Lead || cliente.createdAt;
    if (!entrada) continue;
    const d = new Date(entrada);
    if (d < limite) continue;
    datas.add(d.toISOString().slice(0, 10));
  }

  let origemPorGclid = {};
  if (datas.size) {
    const mapa = await buscarOrigemDosCliques(config, Array.from(datas).sort());
    origemPorGclid = Object.fromEntries(mapa);
  }

  const salvo = { ...metricas, origemPorGclid };
  store.saveMetricasAds(salvo);
  log(`Metricas do Google Ads sincronizadas: ${metricas.campanhas.length} campanha(s).`);
  return salvo;
});

// ----- Google Ads (conexão) -----

handle('config:autorizarGoogleAds', async (_e, { clientId, clientSecret }) => {
  const { refreshToken } = await autorizarGoogleAds({
    clientId,
    clientSecret,
    abrirNavegador: (url) => shell.openExternal(url),
  });
  log('Conta do Google Ads conectada.');
  return store.saveConfig({
    googleAdsClientId: clientId,
    googleAdsClientSecret: clientSecret,
    googleAdsRefreshToken: refreshToken,
  });
});

handle('config:desconectarGoogleAds', () => {
  log('Conta do Google Ads desconectada.');
  return store.saveConfig({ googleAdsRefreshToken: '' });
});

handle('config:testarGoogleAds', async () => {
  await testarConexaoGoogleAds(store.getConfig());
  return true;
});

// ----- Sistema -----

handle('sistema:abrirCaminho', (_e, caminho) => {
  shell.showItemInFolder(caminho);
  return true;
});

handle('sistema:abrirExterno', (_e, url) => {
  if (!/^https?:\/\//i.test(url)) throw new Error('URL inválida');
  shell.openExternal(url);
  return true;
});

handle('sistema:abrirWhatsapp', (_e, { telefone, mensagem }) => {
  const numero = (telefone || '').replace(/\D/g, '');
  if (!numero) throw new Error('Cliente sem telefone cadastrado.');
  shell.openExternal(`https://wa.me/${numero}?text=${encodeURIComponent(mensagem || '')}`);
  return true;
});

handle('sistema:abrirPastaDados', () => {
  shell.openPath(app.getPath('userData'));
  return true;
});

handle('sistema:info', () => ({
  versao: app.getVersion(),
  pastaDados: app.getPath('userData'),
  criptografiaAtiva: safeStorage.isEncryptionAvailable(),
}));

// Exporta todos os dados para um arquivo unico - backup que o usuario controla.
handle('sistema:exportarBackup', async () => {
  const { canceled, filePath } = await dialog.showSaveDialog(mainWindow, {
    title: 'Salvar backup dos dados',
    defaultPath: `backup-crm-juridico-${new Date().toISOString().slice(0, 10)}.json`,
    filters: [{ name: 'Backup JSON', extensions: ['json'] }],
  });
  if (canceled || !filePath) return null;

  const fs = require('fs');
  const dados = {
    exportadoEm: new Date().toISOString(),
    versaoApp: app.getVersion(),
    clientes: store.listClientes(),
    prazos: store.listPrazos(),
    contratos: store.listContratos(),
    conversoes: store.listConversoes(),
    // A configuracao NAO entra no backup: contem tokens de acesso.
  };
  fs.writeFileSync(filePath, JSON.stringify(dados, null, 2), 'utf8');
  log(`Backup exportado para ${filePath}`);
  return filePath;
});
