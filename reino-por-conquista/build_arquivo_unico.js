// ============================================================
// GERA A VERSÃO EM ARQUIVO ÚNICO: ReinoPorConquista.html
// Tudo embutido (código, fonte e as 150+ imagens em data URI):
// abre com dois cliques em qualquer navegador — PC ou celular —
// sem instalador, sem antivírus reclamar, 100% offline.
//   uso: node build_arquivo_unico.js
// ============================================================
'use strict';
const fs = require('fs');
const path = require('path');

const RAIZ = __dirname;
const ler = (p) => fs.readFileSync(path.join(RAIZ, p));
const dataUri = (p, mime) => `data:${mime};base64,${ler(p).toString('base64')}`;

// ---- 1. todas as imagens viram data URI
const EMBUTIDOS = {};
(function varre(dir) {
  for (const nome of fs.readdirSync(path.join(RAIZ, dir))) {
    const rel = dir + '/' + nome;
    if (fs.statSync(path.join(RAIZ, rel)).isDirectory()) varre(rel);
    else if (nome.endsWith('.png')) EMBUTIDOS[rel] = dataUri(rel, 'image/png');
  }
})('img');

// ---- 2. CSS com fonte e molduras embutidas
let css = ler('css/style.css').toString();
css = css.replace(/url\('\.\.\/([^']+)'\)/g, (_, rel) =>
  `url('${rel.endsWith('.ttf') ? dataUri(rel, 'font/ttf') : (EMBUTIDOS[rel] || rel)}')`);

// ---- 3. corpo do index com os <img> estáticos já resolvidos
const indexHtml = ler('index.html').toString();
let corpo = indexHtml.slice(indexHtml.indexOf('<body>') + 6, indexHtml.indexOf('<script src'));
corpo = corpo.replace(/src="(img\/[^"]+)"/g, (m, rel) => EMBUTIDOS[rel] ? `src="${EMBUTIDOS[rel]}"` : m);

// ---- 4. shim: armazém de save à prova de sandbox + imagens embutidas
const shim = `
// arquivo único: imagens embutidas + save resiliente
let ARMAZEM;
try { localStorage.setItem('__t', '1'); localStorage.removeItem('__t'); ARMAZEM = localStorage; }
catch (e) { const m = {}; ARMAZEM = { getItem: k => (k in m ? m[k] : null),
  setItem: (k, v) => { m[k] = String(v); }, removeItem: k => { delete m[k]; } }; }
const EMBUTIDOS = ${JSON.stringify(EMBUTIDOS)};
(() => {
  const d = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  Object.defineProperty(HTMLImageElement.prototype, 'src', {
    get() { return d.get.call(this); },
    set(v) { d.set.call(this, EMBUTIDOS[v] || v); },
  });
  const troca = (n) => {
    if (n.tagName === 'IMG') { const s = n.getAttribute('src'); if (EMBUTIDOS[s]) n.src = s; }
    if (n.querySelectorAll) n.querySelectorAll('img').forEach(i => {
      const s = i.getAttribute('src'); if (EMBUTIDOS[s]) i.src = s;
    });
  };
  new MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(troca)))
    .observe(document.documentElement, { childList: true, subtree: true });
})();
`;

// ---- 5. os módulos do jogo, na ordem do index, com o save usando ARMAZEM
const ordem = [...indexHtml.matchAll(/<script src="(js\/[^"]+)"/g)].map(m => m[1]);
const scripts = ordem.map(rel =>
  `<script>\n${ler(rel).toString().replace(/\blocalStorage\b/g, 'ARMAZEM')}\n</script>`);

// ---- 6. monta as duas saídas
const miolo = `<style>\n${css}\n</style>\n${corpo}\n<script>${shim}</script>\n${scripts.join('\n')}`;
const completo = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="theme-color" content="#2b1d12">
<title>Reino por Conquista</title>
</head>
<body>
${miolo}
</body>
</html>
`;
fs.writeFileSync(path.join(RAIZ, 'ReinoPorConquista.html'), completo);
// variante sem casca para publicação como página (o publicador põe a própria casca)
fs.writeFileSync(path.join(RAIZ, 'ReinoPorConquista.pagina.html'),
  `<title>Reino por Conquista</title>\n${miolo}\n`);
console.log(`ok: ReinoPorConquista.html (${(completo.length / 1048576).toFixed(2)} MB, ${Object.keys(EMBUTIDOS).length} imagens embutidas)`);
