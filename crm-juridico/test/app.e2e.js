// Teste ponta a ponta do app real: abre o Electron, opera a interface como um
// usuario faria e confere o que aparece na tela. Roda com Xvfb (sem monitor).
const { _electron: electron } = require('playwright');
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const RAIZ = path.join(__dirname, '..');
const CAPTURAS = path.join(RAIZ, 'capturas');

(async () => {
  const perfil = fs.mkdtempSync(path.join(os.tmpdir(), 'crm-e2e-'));
  fs.mkdirSync(CAPTURAS, { recursive: true });

  const app = await electron.launch({
    args: [RAIZ, `--user-data-dir=${perfil}`],
    env: { ...process.env, NODE_ENV: 'test' },
  });

  const janela = await app.firstWindow();
  await janela.waitForLoadState('domcontentloaded');
  await janela.waitForTimeout(1500);

  const erros = [];
  janela.on('console', (m) => {
    if (m.type() === 'error') erros.push(m.text());
  });
  janela.on('pageerror', (e) => erros.push(e.message));

  const passos = [];
  // Fecha qualquer modal aberto: se um passo falha no meio, o modal restante
  // nao pode bloquear os cliques dos passos seguintes.
  const fecharModais = () => janela.keyboard.press('Escape').catch(() => {});

  const passo = async (nome, fn) => {
    try {
      await fn();
      passos.push(`  ✓ ${nome}`);
    } catch (e) {
      passos.push(`  ✗ ${nome}\n      ${e.message.split('\n')[0]}`);
      process.exitCode = 1;
    }
    await fecharModais();
  };

  await passo('o app abre com o título correto', async () => {
    assert.strictEqual(await janela.title(), 'CRM Jurídico');
  });

  await passo('o dashboard carrega sem erro de inicialização', async () => {
    await janela.waitForSelector('#dash-cards .card', { timeout: 8000 });
    const cards = await janela.locator('#dash-cards .card').count();
    assert.ok(cards > 0, 'o dashboard deveria mostrar cards');
  });

  await passo('cadastra um cliente pela interface', async () => {
    await janela.click('[data-tab="clientes"]');
    await janela.click('#btn-novo-cliente');
    await janela.fill('#cliente-nome', 'João <script> da Silva & Cia');
    await janela.fill('#cliente-cpf', '123.456.789-00');
    await janela.fill('#cliente-telefone', '11999998888');
    await janela.fill('#cliente-honorarios', '5000');
    await janela.fill('#cliente-gclid', 'Ola, quero atendimento (GCLID:CjwKTESTE123)');
    await janela.click('#form-cliente button[type="submit"]');
    await janela.waitForTimeout(700);

    const linhas = await janela.locator('#corpo-tabela-clientes tr').count();
    assert.strictEqual(linhas, 1, 'deveria haver 1 cliente na tabela');
  });

  await passo('o GCLID é extraído do texto colado do WhatsApp', async () => {
    const clientes = await janela.evaluate(() => window.api.listarClientes());
    assert.strictEqual(clientes[0].gclid, 'CjwKTESTE123', 'deveria extrair só o código');
  });

  await passo('nome com HTML aparece como texto, não é interpretado', async () => {
    const texto = await janela.locator('#corpo-tabela-clientes tr').first().innerText();
    assert.ok(texto.includes('<script>'), 'o texto literal deve aparecer na tela');
    const injetado = await janela.locator('#corpo-tabela-clientes script').count();
    assert.strictEqual(injetado, 0, 'não pode ter criado um elemento <script> real');
  });

  await passo('cadastra um prazo vinculado ao cliente', async () => {
    await janela.click('[data-tab="prazos"]');
    await janela.click('#btn-novo-prazo');
    await janela.fill('#prazo-processo', '1002345-88.2026.8.26.0100');
    await janela.fill('#prazo-acao', 'Réplica à Contestação');
    await janela.fill('#prazo-advogado', 'Dra. Maria');

    const daqui2Dias = new Date();
    daqui2Dias.setDate(daqui2Dias.getDate() + 2);
    await janela.fill('#prazo-data', daqui2Dias.toISOString().slice(0, 10));

    const opcoes = await janela.locator('#prazo-cliente-id option').count();
    assert.ok(opcoes > 1, 'o select deveria listar o cliente cadastrado');
    await janela.selectOption('#prazo-cliente-id', { index: 1 });

    await janela.click('#form-prazo button[type="submit"]');
    await janela.waitForTimeout(700);
    assert.strictEqual(await janela.locator('#corpo-tabela-prazos tr').count(), 1);
  });

  await passo('o prazo aparece como urgente e ligado ao cliente', async () => {
    const linha = await janela.locator('#corpo-tabela-prazos tr').first().innerText();
    assert.ok(linha.includes('Urgente'), `esperava situação urgente, veio: ${linha}`);
    assert.ok(linha.includes('João'), 'deveria mostrar o nome do cliente vinculado');
  });

  await passo('a busca filtra os prazos', async () => {
    await janela.fill('#busca-prazos', 'inexistente-xyz');
    await janela.waitForTimeout(300);
    assert.strictEqual(await janela.locator('#corpo-tabela-prazos .vazio').count(), 1);
    await janela.fill('#busca-prazos', 'Réplica');
    await janela.waitForTimeout(300);
    assert.strictEqual(await janela.locator('#corpo-tabela-prazos tr').count(), 1);
    await janela.fill('#busca-prazos', '');
  });

  await passo('avança o cliente no funil e avisa que falta configurar o Google Ads', async () => {
    janela.on('dialog', (d) => d.accept());
    await janela.click('[data-tab="clientes"]');
    await janela.click('#corpo-tabela-clientes button.sucesso');
    await janela.waitForTimeout(900);

    const clientes = await janela.evaluate(() => window.api.listarClientes());
    assert.strictEqual(clientes[0].etapa, 'Qualificado', 'o cliente deveria ter avançado de etapa');
    const status = await janela.locator('#status-clientes').innerText();
    assert.ok(/Google Ads|não enviada|Etapa atualizada/i.test(status), `mensagem inesperada: ${status}`);
  });

  await passo('o modelo padrão de contrato já vem instalado', async () => {
    await janela.click('[data-tab="modelos"]');
    await janela.waitForTimeout(500);
    assert.strictEqual(await janela.locator('#corpo-tabela-modelos tr').count(), 1);
    const texto = await janela.locator('#corpo-tabela-modelos tr').first().innerText();
    assert.ok(texto.includes('NOME_CLIENTE'), 'deveria listar as tags detectadas');
  });

  await passo('gera um contrato de verdade e grava o arquivo em disco', async () => {
    await janela.click('[data-tab="clientes"]');
    await janela.click('#corpo-tabela-clientes button:has-text("Contrato")');
    await janela.waitForTimeout(500);
    await janela.click('#btn-gerar-contrato');
    await janela.waitForTimeout(2500);

    const texto = await janela.locator('#contrato-resultado').innerText();
    assert.ok(texto.includes('Contrato gerado'), `resultado inesperado: ${texto}`);

    const caminho = texto.match(/(\/[^\s]+\.docx)/);
    assert.ok(caminho, 'deveria informar o caminho do arquivo');
    assert.ok(fs.existsSync(caminho[1]), 'o arquivo .docx deveria existir em disco');
    await janela.click('#btn-fechar-contrato');
  });

  await passo('o dashboard reflete o cliente cadastrado', async () => {
    await janela.click('[data-tab="dashboard"]');
    await janela.waitForTimeout(900);
    const texto = await janela.locator('#dash-cards').innerText();
    assert.ok(/Novos leads/i.test(texto));
    const funil = await janela.locator('#dash-funil').innerText();
    assert.ok(/Lead/.test(funil), 'o funil deveria mostrar as etapas');
  });

  await passo('a ficha 360 mostra prazo e contrato do cliente', async () => {
    await janela.click('[data-tab="clientes"]');
    await janela.click('#corpo-tabela-clientes button:has-text("Ficha")');
    await janela.waitForSelector('#modal-ficha:not(.oculto)', { timeout: 5000 });
    const ficha = await janela.locator('#ficha-conteudo').innerText();
    assert.ok(ficha.includes('1002345-88'), 'a ficha deveria mostrar o prazo vinculado');
    // O título da seção é exibido em maiúsculas via CSS, e innerText reflete isso.
    assert.ok(/Contratos \(1\)/i.test(ficha), 'a ficha deveria mostrar o contrato gerado');
    assert.ok(ficha.includes('CjwKTESTE123'), 'a ficha deveria mostrar o GCLID');
    await janela.click('#btn-fechar-ficha');
  });

  await passo('as configurações carregam e mostram o estado da criptografia', async () => {
    await janela.click('[data-tab="config"]');
    await janela.waitForTimeout(600);
    const info = await janela.locator('#info-sistema').innerText();
    assert.ok(/Vers(ã|a)o/i.test(info));
    assert.ok(/cofre do sistema|Tokens protegidos/i.test(info));
  });

  await passo('nenhum erro de JavaScript durante todo o fluxo', () => {
    assert.deepStrictEqual(erros, [], `erros no console: ${erros.join(' | ')}`);
  });

  console.log('\n── Teste ponta a ponta do aplicativo ──');
  passos.forEach((p) => console.log(p));
  console.log(
    process.exitCode ? '\nAlguns passos FALHARAM.' : `\nTodos os ${passos.length} passos passaram.`
  );

  // Capturas para conferencia visual
  for (const aba of ['dashboard', 'prazos', 'clientes', 'config']) {
    try {
      await fecharModais();
      await janela.click(`[data-tab="${aba}"]`, { timeout: 5000 });
      await janela.waitForTimeout(700);
      await janela.screenshot({ path: path.join(CAPTURAS, `${aba}.png`) });
    } catch (e) {
      console.log(`  (não foi possível capturar a aba ${aba}: ${e.message.split('\n')[0]})`);
    }
  }

  await app.close();
  fs.rmSync(perfil, { recursive: true, force: true });
})().catch((e) => {
  console.error('Falha ao executar o teste do app:', e);
  process.exit(1);
});
