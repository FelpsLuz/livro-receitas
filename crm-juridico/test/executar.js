// Runner minimo de testes, sem dependencia externa.
let suiteAtual = '';
const falhas = [];
let total = 0;

function suite(nome) {
  suiteAtual = nome;
  console.log(`\n── ${nome} ──`);
}

function teste(nome, fn) {
  total += 1;
  try {
    const r = fn();
    if (r && typeof r.then === 'function') {
      return r.then(
        () => console.log(`  ✓ ${nome}`),
        (e) => {
          falhas.push({ suite: suiteAtual, nome, erro: e });
          console.log(`  ✗ ${nome}\n      ${e.message}`);
        }
      );
    }
    console.log(`  ✓ ${nome}`);
  } catch (e) {
    falhas.push({ suite: suiteAtual, nome, erro: e });
    console.log(`  ✗ ${nome}\n      ${e.message}`);
  }
  return Promise.resolve();
}

function resumo() {
  console.log('');
  if (falhas.length) {
    console.log(`${falhas.length} de ${total} teste(s) FALHARAM.`);
    for (const f of falhas) console.log(`  - [${f.suite}] ${f.nome}: ${f.erro.message}`);
    process.exitCode = 1;
  } else {
    console.log(`Todos os ${total} testes passaram.`);
  }
}

module.exports = { suite, teste, resumo };
