const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Campos de configuracao que nunca devem ficar em texto puro no disco:
// dao acesso a conta de anuncios e ao bot de notificacoes.
const CAMPOS_SECRETOS = [
  'telegramBotToken',
  'googleAdsDeveloperToken',
  'googleAdsClientSecret',
  'googleAdsRefreshToken',
];

const VERSAO_SCHEMA = 2;

/**
 * @param {string} userDataPath  pasta de dados do app
 * @param {object} [opcoes]
 * @param {object} [opcoes.cripto]  adaptador { disponivel, encrypt(txt)->b64, decrypt(b64)->txt }.
 *   Injetado pelo main process (Electron safeStorage) para manter este modulo testavel.
 * @param {function} [opcoes.log]
 */
function makeStore(userDataPath, opcoes = {}) {
  const cripto = opcoes.cripto || null;
  const log = opcoes.log || (() => {});

  const arquivos = {
    prazos: path.join(userDataPath, 'prazos.json'),
    config: path.join(userDataPath, 'config.json'),
    clientes: path.join(userDataPath, 'clientes.json'),
    templates: path.join(userDataPath, 'templates.json'),
    contratos: path.join(userDataPath, 'contratos.json'),
    conversoes: path.join(userDataPath, 'conversoes.json'),
    metricas: path.join(userDataPath, 'metricas-ads.json'),
    meta: path.join(userDataPath, 'meta.json'),
  };
  const templatesDir = path.join(userDataPath, 'templates');
  const contratosDir = path.join(userDataPath, 'contratos');

  const defaultConfig = {
    telegramBotToken: '',
    telegramChatId: '',
    horarioVerificacao: '08:00',
    notificacoesAtivas: true,
    iniciarComWindows: true,
    // Google Ads
    googleAdsDeveloperToken: '',
    googleAdsClientId: '',
    googleAdsClientSecret: '',
    googleAdsRefreshToken: '',
    googleAdsCustomerId: '',
    // Acoes de conversao por etapa do funil
    googleAdsAcaoContrato: '',
    googleAdsAcaoQualificado: '',
    googleAdsAcaoReuniao: '',
    googleAdsValorQualificado: 0,
    googleAdsValorReuniao: 0,
    googleAdsMoeda: 'BRL',
    googleAdsEnviarFunilCompleto: true,
    // Compatibilidade com a versao anterior (migrado para googleAdsAcaoContrato)
    googleAdsConversionActionId: '',
    googleAdsNomeConversao: 'Contrato_Fechado',
  };

  // ---------------------------------------------------------------
  // Camada de persistencia: escrita atomica + backup + recuperacao
  // ---------------------------------------------------------------

  // Grava em arquivo temporario, forca o flush para o disco e so entao
  // renomeia por cima do original. Rename e atomico no mesmo volume, entao
  // uma queda de energia deixa OU o arquivo antigo intacto OU o novo completo -
  // nunca um JSON pela metade.
  function writeJson(file, data) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const conteudo = JSON.stringify(data, null, 2);
    const temp = `${file}.tmp`;

    const fd = fs.openSync(temp, 'w');
    try {
      fs.writeFileSync(fd, conteudo, 'utf8');
      fs.fsyncSync(fd);
    } finally {
      fs.closeSync(fd);
    }

    // Guarda a ultima versao boa antes de sobrescrever.
    if (fs.existsSync(file)) {
      try {
        fs.copyFileSync(file, `${file}.bak`);
      } catch (e) {
        log(`Nao foi possivel criar backup de ${path.basename(file)}: ${e.message}`);
      }
    }

    fs.renameSync(temp, file);
  }

  function tentarLer(file) {
    if (!fs.existsSync(file)) return { ok: false, vazio: true };
    try {
      const bruto = fs.readFileSync(file, 'utf8');
      if (bruto.trim() === '') return { ok: false, vazio: true };
      return { ok: true, dados: JSON.parse(bruto) };
    } catch (e) {
      return { ok: false, erro: e };
    }
  }

  // Le o arquivo principal; se estiver corrompido, restaura automaticamente do
  // .bak em vez de devolver vazio silenciosamente (o que faria a proxima escrita
  // apagar todos os dados de verdade).
  function readJson(file, fallback) {
    const principal = tentarLer(file);
    if (principal.ok) return principal.dados;

    if (principal.erro) {
      log(`ATENCAO: ${path.basename(file)} esta corrompido (${principal.erro.message}). Tentando backup...`);

      const backup = tentarLer(`${file}.bak`);
      if (backup.ok) {
        const quarentena = `${file}.corrompido-${Date.now()}`;
        try {
          fs.copyFileSync(file, quarentena);
        } catch (_) {
          /* melhor esforco: preservar o arquivo ruim para diagnostico */
        }
        writeJson(file, backup.dados);
        log(`Backup restaurado com sucesso. Arquivo corrompido salvo em ${path.basename(quarentena)}`);
        return backup.dados;
      }

      // Sem backup utilizavel: preserva o arquivo ruim e NAO sobrescreve,
      // para que os dados possam ser recuperados manualmente.
      const quarentena = `${file}.corrompido-${Date.now()}`;
      try {
        fs.renameSync(file, quarentena);
        log(`Sem backup disponivel. Arquivo preservado em ${path.basename(quarentena)} para recuperacao manual.`);
      } catch (_) {
        /* ignora */
      }
    }

    return fallback;
  }

  // ---------------------------------------------------------------
  // Criptografia dos campos sensiveis
  // ---------------------------------------------------------------

  function criptografarSegredos(config) {
    if (!cripto || !cripto.disponivel) return config;
    const saida = { ...config };
    for (const campo of CAMPOS_SECRETOS) {
      const valor = saida[campo];
      if (typeof valor === 'string' && valor !== '') {
        try {
          saida[campo] = { __enc: cripto.encrypt(valor) };
        } catch (e) {
          log(`Falha ao criptografar ${campo}: ${e.message}`);
        }
      }
    }
    return saida;
  }

  function descriptografarSegredos(config) {
    const saida = { ...config };
    for (const campo of CAMPOS_SECRETOS) {
      const valor = saida[campo];
      if (valor && typeof valor === 'object' && valor.__enc) {
        if (cripto && cripto.disponivel) {
          try {
            saida[campo] = cripto.decrypt(valor.__enc);
          } catch (e) {
            log(`Falha ao descriptografar ${campo}: ${e.message}`);
            saida[campo] = '';
          }
        } else {
          saida[campo] = '';
        }
      }
    }
    return saida;
  }

  function getConfig() {
    const bruto = readJson(arquivos.config, {});
    return { ...defaultConfig, ...descriptografarSegredos(bruto) };
  }

  function saveConfig(mudancas) {
    const atual = getConfig();
    const combinado = { ...atual, ...mudancas };
    writeJson(arquivos.config, criptografarSegredos(combinado));
    return getConfig();
  }

  // ---------------------------------------------------------------
  // Prazos
  // ---------------------------------------------------------------

  function listPrazos() {
    return readJson(arquivos.prazos, []);
  }

  function savePrazos(prazos) {
    writeJson(arquivos.prazos, prazos);
  }

  function addPrazo(prazo) {
    const prazos = listPrazos();
    const novo = {
      id: crypto.randomUUID(),
      processo: '',
      clienteId: null,
      cliente: '',
      acao: '',
      advogadoResponsavel: '',
      dataVencimento: null,
      status: 'Pendente',
      alertasEnviados: [],
      createdAt: new Date().toISOString(),
      ...prazo,
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
    savePrazos(listPrazos().filter((p) => p.id !== id));
  }

  function listPrazosPorCliente(clienteId) {
    return listPrazos().filter((p) => p.clienteId === clienteId);
  }

  // ---------------------------------------------------------------
  // Clientes
  // ---------------------------------------------------------------

  function listClientes() {
    return readJson(arquivos.clientes, []);
  }

  function saveClientes(clientes) {
    writeJson(arquivos.clientes, clientes);
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
      gclid: '',
      etapa: 'Lead',
      // Momento em que cada etapa foi atingida. Este timestamp e FIXO e e o que
      // vai como conversionDateTime ao Google Ads - reenviar nao muda a hora,
      // entao o Google deduplica corretamente em vez de contar duas vezes.
      etapasAtingidas: { Lead: new Date().toISOString() },
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

  function getCliente(id) {
    return listClientes().find((c) => c.id === id) || null;
  }

  // Registra a etapa atual e carimba a hora em que ela foi atingida (apenas na
  // primeira vez, para o timestamp da conversao ficar estavel).
  function definirEtapaCliente(id, idEtapa, quando = new Date()) {
    const cliente = getCliente(id);
    if (!cliente) throw new Error('Cliente nao encontrado');
    const etapasAtingidas = { ...(cliente.etapasAtingidas || {}) };
    if (!etapasAtingidas[idEtapa]) {
      etapasAtingidas[idEtapa] = quando.toISOString();
    }
    return updateCliente(id, { etapa: idEtapa, etapasAtingidas });
  }

  function deleteCliente(id) {
    saveClientes(listClientes().filter((c) => c.id !== id));
    // Remove os registros dependentes para nao deixar orfaos no historico.
    writeJson(arquivos.contratos, listContratos().filter((c) => c.clienteId !== id));
    writeJson(arquivos.conversoes, listConversoes().filter((c) => c.clienteId !== id));
    savePrazos(listPrazos().map((p) => (p.clienteId === id ? { ...p, clienteId: null } : p)));
  }

  // ---------------------------------------------------------------
  // Modelos de contrato
  // ---------------------------------------------------------------

  function listTemplates() {
    return readJson(arquivos.templates, []);
  }

  function saveTemplatesMeta(templates) {
    writeJson(arquivos.templates, templates);
  }

  function addTemplateFromFile(caminhoOrigem, nomeExibicao) {
    fs.mkdirSync(templatesDir, { recursive: true });
    const id = crypto.randomUUID();
    const destino = path.join(templatesDir, `${id}.docx`);
    fs.copyFileSync(caminhoOrigem, destino);

    const templates = listTemplates();
    const novo = { id, nome: nomeExibicao, arquivo: destino, importadoEm: new Date().toISOString() };
    templates.push(novo);
    saveTemplatesMeta(templates);
    return novo;
  }

  function deleteTemplate(id) {
    const templates = listTemplates();
    const alvo = templates.find((t) => t.id === id);
    if (alvo && fs.existsSync(alvo.arquivo)) {
      try {
        fs.unlinkSync(alvo.arquivo);
      } catch (e) {
        log(`Nao foi possivel remover o arquivo do modelo: ${e.message}`);
      }
    }
    saveTemplatesMeta(templates.filter((t) => t.id !== id));
  }

  function garantirTemplatePadrao(caminhoOrigemPadrao) {
    if (listTemplates().length > 0) return;
    if (fs.existsSync(caminhoOrigemPadrao)) {
      addTemplateFromFile(caminhoOrigemPadrao, 'Modelo Padrão de Honorários');
    }
  }

  // ---------------------------------------------------------------
  // Contratos gerados
  // ---------------------------------------------------------------

  function listContratos() {
    return readJson(arquivos.contratos, []);
  }

  function addContratoHistorico(registro) {
    const contratos = listContratos();
    const novo = { id: crypto.randomUUID(), ...registro };
    contratos.push(novo);
    writeJson(arquivos.contratos, contratos);
    return novo;
  }

  function listContratosPorCliente(clienteId) {
    return listContratos().filter((c) => c.clienteId === clienteId);
  }

  // ---------------------------------------------------------------
  // Conversoes offline (fila com retry)
  // ---------------------------------------------------------------

  function listConversoes() {
    return readJson(arquivos.conversoes, []);
  }

  function saveConversoes(conversoes) {
    writeJson(arquivos.conversoes, conversoes);
  }

  // Uma conversao por (cliente, etapa). Se ja existe, devolve a existente em vez
  // de criar outra - e o que impede o envio duplicado inflar o Google Ads.
  function enfileirarConversao({ clienteId, etapa, gclid, valor, conversionDateTime }) {
    const conversoes = listConversoes();
    const existente = conversoes.find((c) => c.clienteId === clienteId && c.etapa === etapa);
    if (existente) return existente;

    const nova = {
      id: crypto.randomUUID(),
      clienteId,
      etapa,
      gclid,
      valor,
      conversionDateTime,
      status: 'pendente',
      tentativas: 0,
      ultimaTentativaEm: null,
      enviadoEm: null,
      erro: null,
      criadoEm: new Date().toISOString(),
    };
    conversoes.push(nova);
    saveConversoes(conversoes);
    return nova;
  }

  function atualizarConversao(id, changes) {
    const conversoes = listConversoes();
    const idx = conversoes.findIndex((c) => c.id === id);
    if (idx === -1) throw new Error('Conversao nao encontrada');
    conversoes[idx] = { ...conversoes[idx], ...changes };
    saveConversoes(conversoes);
    return conversoes[idx];
  }

  function listConversoesPendentes() {
    return listConversoes().filter((c) => c.status === 'pendente' || c.status === 'falhou');
  }

  function listConversoesPorCliente(clienteId) {
    return listConversoes().filter((c) => c.clienteId === clienteId);
  }

  // ---------------------------------------------------------------
  // Metricas do Google Ads (custos sincronizados)
  // ---------------------------------------------------------------

  function getMetricasAds() {
    return readJson(arquivos.metricas, { sincronizadoEm: null, campanhas: [], totalCusto: 0 });
  }

  function saveMetricasAds(metricas) {
    writeJson(arquivos.metricas, metricas);
  }

  // ---------------------------------------------------------------
  // Migracoes
  // ---------------------------------------------------------------

  function getMeta() {
    return readJson(arquivos.meta, { versaoSchema: 0 });
  }

  // Atualiza dados gravados por versoes anteriores do app para o formato atual.
  function migrar() {
    const meta = getMeta();
    if (meta.versaoSchema >= VERSAO_SCHEMA) return { migrado: false };

    log(`Migrando dados da versao ${meta.versaoSchema} para ${VERSAO_SCHEMA}...`);

    // Clientes: status "Lead"/"Contrato Fechado" -> etapa do funil + carimbos
    const clientes = listClientes().map((c) => {
      if (c.etapa && c.etapasAtingidas) return c;
      const etapa = c.status === 'Contrato Fechado' ? 'ContratoFechado' : 'Lead';
      const etapasAtingidas = { Lead: c.createdAt || new Date().toISOString() };
      if (etapa === 'ContratoFechado') {
        etapasAtingidas.ContratoFechado = c.fechadoEm || c.createdAt || new Date().toISOString();
      }
      const { status, fechadoEm, ...resto } = c;
      return { ...resto, etapa, etapasAtingidas };
    });
    if (clientes.length) saveClientes(clientes);

    // Prazos: garante o campo clienteId e tenta casar pelo nome ja digitado
    const prazos = listPrazos();
    if (prazos.length) {
      const porNome = new Map(
        clientes.map((c) => [String(c.nome || '').trim().toLowerCase(), c.id])
      );
      savePrazos(
        prazos.map((p) => {
          if (p.clienteId !== undefined) return p;
          const chave = String(p.cliente || '').trim().toLowerCase();
          return { ...p, clienteId: porNome.get(chave) || null };
        })
      );
    }

    // Conversoes: formato antigo (sucesso: bool) -> fila com status/etapa
    const conversoes = listConversoes();
    if (conversoes.length) {
      saveConversoes(
        conversoes.map((c) => {
          if (c.status) return c;
          return {
            ...c,
            etapa: c.etapa || 'ContratoFechado',
            status: c.sucesso ? 'enviada' : 'falhou',
            tentativas: 1,
            ultimaTentativaEm: c.enviadoEm || null,
            conversionDateTime: c.conversionDateTime || c.enviadoEm || null,
          };
        })
      );
    }

    // Config: acao de conversao unica -> acao da etapa de contrato
    const config = getConfig();
    if (config.googleAdsConversionActionId && !config.googleAdsAcaoContrato) {
      saveConfig({ googleAdsAcaoContrato: config.googleAdsConversionActionId });
    }

    writeJson(arquivos.meta, { ...meta, versaoSchema: VERSAO_SCHEMA, migradoEm: new Date().toISOString() });
    log('Migracao concluida.');
    return { migrado: true };
  }

  return {
    // prazos
    listPrazos,
    savePrazos,
    addPrazo,
    updatePrazo,
    deletePrazo,
    listPrazosPorCliente,
    // config
    getConfig,
    saveConfig,
    // clientes
    listClientes,
    getCliente,
    addCliente,
    updateCliente,
    definirEtapaCliente,
    deleteCliente,
    // templates
    listTemplates,
    addTemplateFromFile,
    deleteTemplate,
    garantirTemplatePadrao,
    // contratos
    listContratos,
    addContratoHistorico,
    listContratosPorCliente,
    // conversoes
    listConversoes,
    enfileirarConversao,
    atualizarConversao,
    listConversoesPendentes,
    listConversoesPorCliente,
    // metricas
    getMetricasAds,
    saveMetricasAds,
    // manutencao
    migrar,
    getMeta,
    templatesDir,
    contratosDir,
    arquivos,
  };
}

module.exports = { makeStore, CAMPOS_SECRETOS, VERSAO_SCHEMA };
