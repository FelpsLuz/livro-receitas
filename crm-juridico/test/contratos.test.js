const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { formatarMoeda, slugify, dadosParaTemplate, gerarContrato } = require('../src/geradorContratos');
const { detectarTags, preencherTemplate } = require('../src/docxTemplate');
const { makeStore } = require('../src/store');

// formatarMoeda
assert.strictEqual(formatarMoeda(5000), 'R$ 5.000,00');
assert.strictEqual(formatarMoeda('abc'), 'R$ 0,00');
console.log('OK: formatarMoeda');

// slugify
assert.strictEqual(slugify('João da Silva'), 'joao-da-silva');
assert.strictEqual(slugify(''), 'cliente');
assert.strictEqual(slugify('Maria   D`Ávila!!'), 'maria-d-avila');
console.log('OK: slugify');

// dadosParaTemplate
const dados = dadosParaTemplate(
  {
    nome: 'Ana',
    cpf: '111.111.111-11',
    endereco: 'Rua A, 1',
    telefone: '11988887777',
    valorHonorarios: 1500,
    formaPagamento: 'à vista',
  },
  new Date('2026-07-30T12:00:00')
);
assert.strictEqual(dados.NOME_CLIENTE, 'Ana');
assert.strictEqual(dados.VALOR_HONORARIOS, 'R$ 1.500,00');
assert.strictEqual(dados.DATA_GERACAO, '30/07/2026');
console.log('OK: dadosParaTemplate');

// detectarTags no modelo padrao real
const caminhoModeloPadrao = path.join(__dirname, '..', 'assets', 'templates', 'modelo-padrao.docx');
const tags = detectarTags(caminhoModeloPadrao);
['NOME_CLIENTE', 'CPF', 'ENDERECO', 'VALOR_HONORARIOS', 'FORMA_PAGAMENTO', 'DATA_GERACAO'].forEach((t) => {
  assert.ok(tags.includes(t), `esperava encontrar a tag ${t}`);
});
console.log('OK: detectarTags (modelo padrão)');

// preencherTemplate: garante que nenhuma tag {{...}} sobra no documento final
const bufferPreenchido = preencherTemplate(caminhoModeloPadrao, {
  NOME_CLIENTE: 'Carlos Teste',
  CPF: '000.000.000-00',
  ENDERECO: 'Av. Teste, 100',
  TELEFONE: '11900000000',
  VALOR_HONORARIOS: 'R$ 1.000,00',
  FORMA_PAGAMENTO: '2x',
  DATA_GERACAO: '30/07/2026',
});
const PizZip = require('pizzip');
const zipResultado = new PizZip(bufferPreenchido);
const xmlResultado = zipResultado.file('word/document.xml').asText();
assert.ok(xmlResultado.includes('Carlos Teste'));
assert.ok(!/\{\{[A-Z_]+\}\}/.test(xmlResultado.replace(/<[^>]+>/g, '')));
console.log('OK: preencherTemplate (sem tags residuais)');

// gerarContrato: fluxo completo salvando em pasta temporaria
(async () => {
  const pastaTemp = fs.mkdtempSync(path.join(os.tmpdir(), 'crm-juridico-test-'));
  const store = makeStore(pastaTemp);
  store.garantirTemplatePadrao(caminhoModeloPadrao);
  const template = store.listTemplates()[0];
  assert.ok(template, 'modelo padrão deveria ter sido semeado');

  const cliente = store.addCliente({
    nome: 'Beatriz Exemplo',
    cpf: '222.222.222-22',
    endereco: 'Rua B, 2',
    telefone: '11977776666',
    valorHonorarios: 3000,
    formaPagamento: 'à vista',
  });

  const { caminhoDocx } = await gerarContrato({
    cliente,
    template: { nome: template.nome, caminhoAbsoluto: template.arquivo },
    pastaBaseContratos: store.contratosDir,
    timestamp: new Date('2026-07-30T08:00:00'),
  });

  assert.ok(fs.existsSync(caminhoDocx), 'arquivo do contrato deveria existir em disco');
  assert.ok(caminhoDocx.includes('beatriz-exemplo'), 'pasta deveria usar slug do nome do cliente');

  store.addContratoHistorico({
    clienteId: cliente.id,
    templateId: template.id,
    templateNome: template.nome,
    arquivoDocx: caminhoDocx,
    arquivoPdf: null,
    geradoEm: new Date().toISOString(),
  });
  const historico = store.listContratosPorCliente(cliente.id);
  assert.strictEqual(historico.length, 1);

  fs.rmSync(pastaTemp, { recursive: true, force: true });
  console.log('OK: gerarContrato + store (fluxo completo)');
  console.log('\nTodos os testes do Módulo 2 passaram.');
})();
