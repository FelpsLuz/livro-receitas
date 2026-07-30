const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { suite, teste, resumo } = require('./executar');

const { makeStore } = require('../src/store');
const prazosLib = require('../src/prazos');
const funil = require('../src/funil');
const relatorios = require('../src/relatorios');
const servico = require('../src/servicoConversoes');
const googleAds = require('../src/googleAds');
const gerador = require('../src/geradorContratos');
const { detectarTags, preencherTemplate } = require('../src/docxTemplate');
const PizZip = require('pizzip');

const MODELO_PADRAO = path.join(__dirname, '..', 'assets', 'templates', 'modelo-padrao.docx');

function pastaTemp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'crm-test-'));
}
function novoStore() {
  return makeStore(pastaTemp());
}
function maisDias(base, dias) {
  const d = new Date(base);
  d.setDate(d.getDate() + dias);
  return d.toISOString().slice(0, 10);
}

// Mock de fetch: devolve respostas na ordem e registra as chamadas feitas.
async function comFetch(respostas, fn) {
  const original = global.fetch;
  const chamadas = [];
  let i = 0;
  global.fetch = async (url, opts) => {
    chamadas.push({ url, opts });
    const r = respostas[Math.min(i++, respostas.length - 1)];
    return { ok: r.ok !== false, status: r.status || 200, json: async () => r.corpo };
  };
  try {
    return { resultado: await fn(), chamadas };
  } finally {
    global.fetch = original;
  }
}

(async () => {
  // =========================================================
  suite('Persistência: escrita atômica e recuperação');

  await teste('grava e relê os dados', () => {
    const store = novoStore();
    store.addPrazo({ processo: 'A', dataVencimento: '2026-08-10' });
    assert.strictEqual(store.listPrazos().length, 1);
  });

  await teste('crash no meio da escrita NÃO perde dados (arquivo temporário descartado)', () => {
    const dir = pastaTemp();
    const store = makeStore(dir);
    for (let i = 1; i <= 5; i++) store.addPrazo({ processo: `P${i}`, dataVencimento: '2026-08-10' });
    // Queda de energia durante o write: sobra um .tmp incompleto.
    fs.writeFileSync(path.join(dir, 'prazos.json.tmp'), '[{"id":"x","proc');
    assert.strictEqual(store.listPrazos().length, 5, 'os 5 prazos devem sobreviver intactos');
    store.addPrazo({ processo: 'P6', dataVencimento: '2026-08-10' });
    assert.strictEqual(store.listPrazos().length, 6);
  });

  await teste('arquivo corrompido é restaurado do backup em vez de zerar os dados', () => {
    const dir = pastaTemp();
    const store = makeStore(dir);
    store.addPrazo({ processo: 'IMPORTANTE', dataVencimento: '2026-08-10' });
    store.addPrazo({ processo: 'OUTRO', dataVencimento: '2026-08-11' });

    const arquivo = path.join(dir, 'prazos.json');
    fs.writeFileSync(arquivo, '{{{ lixo corrompido');

    const recuperados = store.listPrazos();
    assert.ok(recuperados.length > 0, 'deveria recuperar do backup, não devolver lista vazia');
    assert.ok(fs.readdirSync(dir).some((f) => f.includes('corrompido')), 'deve preservar o arquivo ruim');
  });

  await teste('sem backup utilizável, o arquivo ruim é preservado para recuperação manual', () => {
    const dir = pastaTemp();
    const store = makeStore(dir);
    fs.writeFileSync(path.join(dir, 'clientes.json'), 'nao e json');
    assert.deepStrictEqual(store.listClientes(), []);
    assert.ok(fs.readdirSync(dir).some((f) => f.startsWith('clientes.json.corrompido')));
  });

  // =========================================================
  suite('Criptografia de segredos');

  await teste('segredos não ficam em texto puro no disco', () => {
    const dir = pastaTemp();
    const cripto = {
      disponivel: true,
      encrypt: (t) => Buffer.from(`cofre:${t}`).toString('base64'),
      decrypt: (b) => Buffer.from(b, 'base64').toString('utf8').replace(/^cofre:/, ''),
    };
    const store = makeStore(dir, { cripto });
    store.saveConfig({ googleAdsRefreshToken: 'TOKEN-SUPER-SECRETO', telegramChatId: '12345' });

    const bruto = fs.readFileSync(path.join(dir, 'config.json'), 'utf8');
    assert.ok(!bruto.includes('TOKEN-SUPER-SECRETO'), 'o token não pode aparecer em texto puro');
    assert.ok(bruto.includes('12345'), 'campos não sensíveis seguem legíveis');
    assert.strictEqual(store.getConfig().googleAdsRefreshToken, 'TOKEN-SUPER-SECRETO', 'deve descriptografar na leitura');
  });

  await teste('sem cofre disponível, não quebra (apenas não criptografa)', () => {
    const store = makeStore(pastaTemp(), { cripto: { disponivel: false } });
    store.saveConfig({ googleAdsRefreshToken: 'abc' });
    assert.strictEqual(store.getConfig().googleAdsRefreshToken, 'abc');
  });

  // =========================================================
  suite('Alertas de prazo');

  const hoje = new Date('2026-07-30T09:00:00');

  await teste('dispara nos limiares 7, 3, 1 e 0', () => {
    for (const dias of [7, 3, 1, 0]) {
      const p = { id: 'x', dataVencimento: maisDias(hoje, dias), status: 'Pendente', alertasEnviados: [] };
      assert.strictEqual(prazosLib.prazosParaAlertar([p], hoje).length, 1, `deveria alertar faltando ${dias} dias`);
    }
  });

  await teste('CATCH-UP: recupera alertas perdidos com o computador desligado', () => {
    // Prazo vence em 2 dias; o app ficou fechado nos dias de 7 e 3 dias.
    const p = { id: 'x', dataVencimento: maisDias(hoje, 2), status: 'Pendente', alertasEnviados: [] };
    const alertas = prazosLib.prazosParaAlertar([p], hoje);
    assert.strictEqual(alertas.length, 1, 'deve alertar mesmo fora do dia exato do limiar');
    assert.deepStrictEqual(alertas[0].limiaresCobertos, [7, 3], 'deve marcar os dois limiares perdidos');
  });

  await teste('não repete o mesmo limiar duas vezes', () => {
    let p = { id: 'x', dataVencimento: maisDias(hoje, 3), status: 'Pendente', alertasEnviados: [] };
    const primeiro = prazosLib.prazosParaAlertar([p], hoje);
    p = { ...p, alertasEnviados: prazosLib.registrarAlertaEnviado(p, primeiro[0], true) };
    assert.strictEqual(prazosLib.prazosParaAlertar([p], hoje).length, 0, 'não deve alertar de novo no mesmo dia');
  });

  await teste('prazo vencido cobra todo dia, mas só uma vez por dia', () => {
    let p = { id: 'x', dataVencimento: maisDias(hoje, -5), status: 'Pendente', alertasEnviados: [] };
    const a1 = prazosLib.prazosParaAlertar([p], hoje);
    assert.strictEqual(a1.length, 1);
    assert.strictEqual(a1[0].limiar, 'vencido');

    p = { ...p, alertasEnviados: prazosLib.registrarAlertaEnviado(p, a1[0], true) };
    assert.strictEqual(prazosLib.prazosParaAlertar([p], hoje).length, 0, 'não repete no mesmo dia');

    const amanha = new Date('2026-07-31T09:00:00');
    assert.strictEqual(prazosLib.prazosParaAlertar([p], amanha).length, 1, 'volta a cobrar no dia seguinte');
  });

  await teste('prazo concluído nunca alerta', () => {
    const p = { id: 'x', dataVencimento: maisDias(hoje, -5), status: 'Concluido', alertasEnviados: [] };
    assert.strictEqual(prazosLib.prazosParaAlertar([p], hoje).length, 0);
  });

  await teste('situação é classificada corretamente', () => {
    const casos = [[-1, 'vencido'], [0, 'hoje'], [2, 'urgente'], [5, 'atencao'], [30, 'ok']];
    for (const [dias, esperado] of casos) {
      assert.strictEqual(
        prazosLib.situacao({ dataVencimento: maisDias(hoje, dias), status: 'Pendente' }, hoje),
        esperado
      );
    }
  });

  // =========================================================
  suite('Funil de vendas');

  await teste('avançar para contrato marca as etapas anteriores', () => {
    const etapas = funil.etapasAtingidasAte('ContratoFechado').map((e) => e.id);
    assert.deepStrictEqual(etapas, ['Qualificado', 'Reuniao', 'ContratoFechado']);
  });

  await teste('etapa de contrato usa o valor real dos honorários', () => {
    const etapa = funil.obterEtapa('ContratoFechado');
    assert.strictEqual(funil.valorDaEtapa(etapa, { valorHonorarios: 5000 }, {}), 5000);
  });

  await teste('etapas intermediárias usam o valor estimado da configuração', () => {
    const etapa = funil.obterEtapa('Qualificado');
    assert.strictEqual(funil.valorDaEtapa(etapa, { valorHonorarios: 5000 }, { googleAdsValorQualificado: 150 }), 150);
  });

  await teste('"Perdido" não gera conversão', () => {
    assert.deepStrictEqual(funil.etapasAtingidasAte('Perdido'), []);
  });

  // =========================================================
  suite('Conversões: timestamp fixo e idempotência');

  const configAds = {
    googleAdsClientId: 'id',
    googleAdsClientSecret: 'segredo',
    googleAdsRefreshToken: 'refresh',
    googleAdsDeveloperToken: 'dev',
    googleAdsCustomerId: '123-456-7890',
    googleAdsMoeda: 'BRL',
  };

  await teste('envia com o timestamp da etapa, não com a hora do envio', async () => {
    const { chamadas } = await comFetch(
      [{ corpo: { access_token: 'tk' } }, { corpo: {} }],
      () =>
        googleAds.enviarConversaoOffline(configAds, {
          gclid: 'GCL1',
          valor: 5000,
          conversionDateTime: '2026-07-01T10:00:00.000Z',
          conversionActionId: '999',
        })
    );
    const corpo = JSON.parse(chamadas[1].opts.body);
    assert.ok(corpo.conversions[0].conversionDateTime.startsWith('2026-07-01'), 'deve usar a data da etapa');
    assert.strictEqual(corpo.conversions[0].conversionAction, 'customers/1234567890/conversionActions/999');
    assert.strictEqual(corpo.conversions[0].conversionValue, 5000);
  });

  await teste('DUPLICAÇÃO: reenviar não cria uma segunda conversão na fila', () => {
    const store = novoStore();
    const c = store.addCliente({ nome: 'Ana', gclid: 'GCL1', valorHonorarios: 5000 });
    const p1 = store.enfileirarConversao({ clienteId: c.id, etapa: 'ContratoFechado', gclid: 'GCL1', valor: 5000, conversionDateTime: '2026-07-01T10:00:00Z' });
    const p2 = store.enfileirarConversao({ clienteId: c.id, etapa: 'ContratoFechado', gclid: 'GCL1', valor: 5000, conversionDateTime: '2026-07-02T11:00:00Z' });
    assert.strictEqual(p1.id, p2.id, 'deve reaproveitar a conversão existente');
    assert.strictEqual(store.listConversoes().length, 1, 'não pode haver duas conversões para a mesma etapa');
  });

  await teste('reenvio mantém o mesmo horário (Google deduplica em vez de contar 2x)', async () => {
    const store = novoStore();
    store.saveConfig({ ...configAds, googleAdsAcaoContrato: '999' });
    const cliente = store.addCliente({ nome: 'Ana', gclid: 'GCL1', valorHonorarios: 5000 });
    store.definirEtapaCliente(cliente.id, 'ContratoFechado', new Date('2026-07-01T10:00:00'));

    const horarios = [];
    const capturar = async () => {
      const { chamadas } = await comFetch([{ corpo: { access_token: 'tk' } }, { corpo: {} }], () =>
        servico.processarFila(store, { forcar: true })
      );
      const envio = chamadas.find((c) => String(c.url).includes('uploadClickConversions'));
      if (envio) horarios.push(JSON.parse(envio.opts.body).conversions[0].conversionDateTime);
    };

    servico.enfileirarEtapasDoCliente(store, store.getCliente(cliente.id), store.getConfig());
    await capturar();
    await capturar();

    assert.ok(horarios.length >= 1, 'deveria ter enviado ao menos uma vez');
    if (horarios.length > 1) {
      assert.strictEqual(horarios[0], horarios[1], 'o horário da conversão deve ser idêntico entre reenvios');
    }
  });

  await teste('sem GCLID a conversão nem chega a tocar a rede', async () => {
    let tocouRede = false;
    const original = global.fetch;
    global.fetch = async () => { tocouRede = true; throw new Error('não deveria chamar'); };
    try {
      await assert.rejects(() =>
        googleAds.enviarConversaoOffline(configAds, { gclid: '', valor: 1, conversionDateTime: 'x', conversionActionId: '1' })
      );
    } finally {
      global.fetch = original;
    }
    assert.strictEqual(tocouRede, false);
  });

  await teste('falha no envio mantém na fila para retry, com o erro registrado', async () => {
    const store = novoStore();
    store.saveConfig({ ...configAds, googleAdsAcaoContrato: '999' });
    const cliente = store.addCliente({ nome: 'Ana', gclid: 'GCL1', valorHonorarios: 5000 });
    store.definirEtapaCliente(cliente.id, 'ContratoFechado', new Date('2026-07-01T10:00:00'));
    servico.enfileirarEtapasDoCliente(store, store.getCliente(cliente.id), store.getConfig());

    await comFetch(
      [{ corpo: { access_token: 'tk' } }, { ok: false, status: 500, corpo: { error: { message: 'servidor fora do ar' } } }],
      () => servico.processarFila(store, { forcar: true })
    );

    const conv = store.listConversoes()[0];
    assert.strictEqual(conv.status, 'pendente', 'deve continuar na fila para nova tentativa');
    assert.ok(conv.erro.includes('servidor fora do ar'));
    assert.strictEqual(conv.tentativas, 1);
  });

  await teste('backoff cresce entre as tentativas', () => {
    const e1 = servico.esperaParaTentativa(0);
    const e3 = servico.esperaParaTentativa(3);
    assert.ok(e3 > e1, 'a espera deve aumentar a cada falha');
  });

  await teste('desiste após o limite de tentativas', () => {
    const conv = { status: 'pendente', tentativas: servico.MAX_TENTATIVAS, ultimaTentativaEm: null };
    assert.strictEqual(servico.podeTentarAgora(conv), false);
  });

  // =========================================================
  suite('Migração de dados da versão anterior');

  await teste('converte status antigo em etapa do funil e liga prazos por clienteId', () => {
    const dir = pastaTemp();
    // Simula dados gravados pela versão 1 do app.
    fs.writeFileSync(
      path.join(dir, 'clientes.json'),
      JSON.stringify([
        { id: 'c1', nome: 'João Silva', status: 'Contrato Fechado', fechadoEm: '2026-06-01T10:00:00Z', createdAt: '2026-05-01T10:00:00Z', valorHonorarios: 5000 },
        { id: 'c2', nome: 'Maria Souza', status: 'Lead', createdAt: '2026-05-02T10:00:00Z' },
      ])
    );
    fs.writeFileSync(
      path.join(dir, 'prazos.json'),
      JSON.stringify([{ id: 'p1', processo: '123', cliente: 'João Silva', status: 'Pendente', dataVencimento: '2026-08-01' }])
    );

    const store = makeStore(dir);
    store.migrar();

    const joao = store.listClientes().find((c) => c.id === 'c1');
    assert.strictEqual(joao.etapa, 'ContratoFechado');
    assert.strictEqual(joao.etapasAtingidas.ContratoFechado, '2026-06-01T10:00:00Z', 'preserva a data original do fechamento');
    assert.strictEqual(store.listClientes().find((c) => c.id === 'c2').etapa, 'Lead');
    assert.strictEqual(store.listPrazos()[0].clienteId, 'c1', 'liga o prazo ao cliente pelo nome');
  });

  await teste('migração não roda duas vezes', () => {
    const store = novoStore();
    assert.strictEqual(store.migrar().migrado, true);
    assert.strictEqual(store.migrar().migrado, false);
  });

  await teste('excluir cliente remove o histórico e desvincula prazos', () => {
    const store = novoStore();
    const c = store.addCliente({ nome: 'Ana' });
    store.addPrazo({ processo: 'P1', clienteId: c.id });
    store.addContratoHistorico({ clienteId: c.id, templateNome: 'X' });
    store.enfileirarConversao({ clienteId: c.id, etapa: 'ContratoFechado', gclid: 'g', valor: 1, conversionDateTime: 'x' });

    store.deleteCliente(c.id);
    assert.strictEqual(store.listClientes().length, 0);
    assert.strictEqual(store.listContratos().length, 0, 'contratos órfãos devem sumir');
    assert.strictEqual(store.listConversoes().length, 0, 'conversões órfãs devem sumir');
    assert.strictEqual(store.listPrazos()[0].clienteId, null, 'prazo é desvinculado, não apagado');
  });

  // =========================================================
  suite('Dashboard de ROI');

  const periodo = relatorios.periodoUltimosDias(30, new Date('2026-07-30T12:00:00'));
  const clientesDemo = [
    { id: '1', nome: 'A', gclid: 'g1', valorHonorarios: 5000, etapasAtingidas: { Lead: '2026-07-10T10:00:00', Qualificado: '2026-07-11T10:00:00', ContratoFechado: '2026-07-15T10:00:00' } },
    { id: '2', nome: 'B', gclid: 'g2', valorHonorarios: 3000, etapasAtingidas: { Lead: '2026-07-12T10:00:00', ContratoFechado: '2026-07-20T10:00:00' } },
    { id: '3', nome: 'C', gclid: 'g3', valorHonorarios: 0, etapasAtingidas: { Lead: '2026-07-13T10:00:00' } },
  ];
  const metricasDemo = { totalCusto: 2000, campanhas: [{ nome: 'Trabalhista', custo: 2000, cliques: 400 }] };

  await teste('calcula receita, lucro, ROI e ROAS', () => {
    const r = relatorios.calcularResumo(clientesDemo, metricasDemo, periodo);
    assert.strictEqual(r.receita, 8000);
    assert.strictEqual(r.investimento, 2000);
    assert.strictEqual(r.lucro, 6000);
    assert.strictEqual(r.roi, 300);
    assert.strictEqual(r.roas, 4);
  });

  await teste('calcula CAC, ticket médio e taxa de conversão', () => {
    const r = relatorios.calcularResumo(clientesDemo, metricasDemo, periodo);
    assert.strictEqual(r.cac, 1000, '2000 investidos / 2 contratos');
    assert.strictEqual(r.ticketMedio, 4000);
    assert.ok(Math.abs(r.taxaConversao - 66.67) < 0.1, '2 de 3 leads viraram contrato');
  });

  await teste('funciona sem os dados de custo (Google Ads não conectado)', () => {
    const r = relatorios.calcularResumo(clientesDemo, null, periodo);
    assert.strictEqual(r.receita, 8000);
    assert.strictEqual(r.roi, null);
    assert.strictEqual(r.temDadosDeCusto, false);
  });

  await teste('não divide por zero quando não há investimento nem contratos', () => {
    const r = relatorios.calcularResumo([], { totalCusto: 0, campanhas: [] }, periodo);
    assert.strictEqual(r.roi, null);
    assert.strictEqual(r.cac, null);
    assert.strictEqual(r.ticketMedio, 0);
  });

  await teste('atribui receita à campanha certa pelo GCLID', () => {
    const origem = { g1: { campanha: 'Trabalhista', palavraChave: 'advogado trabalhista' } };
    const linhas = relatorios.calcularDesempenhoPorCampanha(clientesDemo, metricasDemo, origem, periodo);
    const trab = linhas.find((l) => l.campanha === 'Trabalhista');
    assert.strictEqual(trab.contratos, 1);
    assert.strictEqual(trab.receita, 5000);
    assert.strictEqual(trab.cac, 2000);

    const semAtribuicao = linhas.find((l) => l.campanha === 'Não identificada');
    assert.ok(semAtribuicao, 'clientes sem origem conhecida aparecem separados');
    assert.strictEqual(semAtribuicao.receita, 3000);
  });

  await teste('ranking de palavras-chave é por receita, não por cliques', () => {
    const origem = {
      g1: { campanha: 'C', palavraChave: 'barata-muitos-cliques' },
      g2: { campanha: 'C', palavraChave: 'cara-poucos-cliques' },
    };
    const linhas = relatorios.calcularDesempenhoPorPalavraChave(clientesDemo, origem, periodo);
    assert.strictEqual(linhas[0].palavraChave, 'barata-muitos-cliques');
    assert.strictEqual(linhas[0].receita, 5000);
  });

  await teste('conta corretamente cada etapa do funil', () => {
    const f = relatorios.calcularFunil(clientesDemo, periodo);
    const porId = Object.fromEntries(f.map((x) => [x.id, x.quantidade]));
    assert.strictEqual(porId.Lead, 3);
    assert.strictEqual(porId.Qualificado, 1);
    assert.strictEqual(porId.ContratoFechado, 2);
  });

  await teste('ignora movimentos fora do período', () => {
    const antigos = [{ id: 'x', valorHonorarios: 9999, etapasAtingidas: { ContratoFechado: '2020-01-01T10:00:00' } }];
    assert.strictEqual(relatorios.calcularResumo(antigos, null, periodo).receita, 0);
  });

  // =========================================================
  suite('Google Ads: API');

  await teste('formata a data no padrão exigido pela API', () => {
    const f = googleAds.formatarDataHoraGoogle(new Date('2026-07-30T14:05:09'));
    assert.ok(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/.test(f), `formato inesperado: ${f}`);
  });

  await teste('normaliza o Customer ID com ou sem hífen', () => {
    assert.strictEqual(googleAds.normalizarCustomerId('123-456-7890'), '1234567890');
    assert.strictEqual(googleAds.normalizarCustomerId('1234567890'), '1234567890');
  });

  await teste('propaga a mensagem de erro real da API do Google', async () => {
    await comFetch(
      [{ corpo: { access_token: 'tk' } }, { ok: false, status: 403, corpo: { error: { message: 'developer token inválido' } } }],
      async () => {
        await assert.rejects(
          () => googleAds.testarConexaoGoogleAds(configAds),
          (e) => e.message.includes('developer token inválido')
        );
      }
    );
  });

  await teste('envia login-customer-id quando é conta de agência (MCC)', async () => {
    const { chamadas } = await comFetch([{ corpo: { access_token: 'tk' } }, { corpo: {} }], () =>
      googleAds.enviarConversaoOffline(
        { ...configAds, googleAdsLoginCustomerId: '999-888-7777' },
        { gclid: 'g', valor: 1, conversionDateTime: '2026-07-01T10:00:00Z', conversionActionId: '1' }
      )
    );
    assert.strictEqual(chamadas[1].opts.headers['login-customer-id'], '9998887777');
  });

  await teste('soma o custo das campanhas vindo em micros por dia', async () => {
    const { resultado } = await comFetch(
      [
        { corpo: { access_token: 'tk' } },
        {
          corpo: {
            results: [
              { campaign: { id: '1', name: 'Trabalhista' }, metrics: { costMicros: '1500000', clicks: '10', impressions: '100', conversions: 1 } },
              { campaign: { id: '1', name: 'Trabalhista' }, metrics: { costMicros: '2500000', clicks: '20', impressions: '200', conversions: 2 } },
            ],
          },
        },
      ],
      () => googleAds.buscarCustosCampanhas(configAds)
    );
    assert.strictEqual(resultado.campanhas.length, 1, 'agrupa as linhas diárias por campanha');
    assert.strictEqual(resultado.campanhas[0].custo, 4, 'R$ 4,00 = 4.000.000 micros');
    assert.strictEqual(resultado.campanhas[0].cliques, 30);
  });

  // =========================================================
  suite('Gerador de contratos');

  await teste('formata moeda e nome de pasta', () => {
    // Normaliza o espaço: toLocaleString usa espaço não separável (U+00A0).
    const semNbsp = (s) => s.replace(/ /g, ' ');
    assert.strictEqual(semNbsp(gerador.formatarMoeda(5000)), 'R$ 5.000,00');
    assert.strictEqual(gerador.slugify('João da Silva'), 'joao-da-silva');
    assert.strictEqual(gerador.slugify(''), 'cliente');
  });

  await teste('o modelo padrão tem todas as tags esperadas', () => {
    const tags = detectarTags(MODELO_PADRAO);
    for (const t of ['NOME_CLIENTE', 'CPF', 'ENDERECO', 'VALOR_HONORARIOS', 'FORMA_PAGAMENTO', 'DATA_GERACAO']) {
      assert.ok(tags.includes(t), `faltou a tag ${t}`);
    }
  });

  await teste('não sobra nenhuma tag {{...}} no contrato gerado', () => {
    const buffer = preencherTemplate(MODELO_PADRAO, {
      NOME_CLIENTE: 'Carlos', CPF: '000', ENDERECO: 'Rua A', TELEFONE: '11',
      VALOR_HONORARIOS: 'R$ 1.000,00', FORMA_PAGAMENTO: '2x', DATA_GERACAO: '30/07/2026',
    });
    const xml = new PizZip(buffer).file('word/document.xml').asText().replace(/<[^>]+>/g, '');
    assert.ok(xml.includes('Carlos'));
    assert.ok(!/\{\{[A-Z_]+\}\}/.test(xml), 'sobrou tag não substituída');
  });

  await teste('gera o arquivo na pasta do cliente', async () => {
    const store = novoStore();
    store.garantirTemplatePadrao(MODELO_PADRAO);
    const template = store.listTemplates()[0];
    const cliente = store.addCliente({ nome: 'Beatriz Exemplo', valorHonorarios: 3000 });

    const { caminhoDocx } = await gerador.gerarContrato({
      cliente,
      template: { nome: template.nome, caminhoAbsoluto: template.arquivo },
      pastaBaseContratos: store.contratosDir,
      timestamp: new Date('2026-07-30T08:00:00'),
    });

    assert.ok(fs.existsSync(caminhoDocx));
    assert.ok(caminhoDocx.includes('beatriz-exemplo'));
  });

  resumo();
})();
