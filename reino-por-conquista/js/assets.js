// ============================================================
// ASSETS EXTERNOS (arte do designer)
// Se existir um PNG em img/<caminho>.png, ele SUBSTITUI a arte
// procedural automaticamente — sem mexer em código.
// Convenções (ver ARTE-DESIGNER.md na raiz do jogo):
//   img/retratos/rei_touros.png        64×64
//   img/edificios/fazenda_3.png        48×48  (estágios 1..6)
// Carregamento é assíncrono: o primeiro frame usa a arte
// procedural e os seguintes usam o PNG assim que carregar.
// ============================================================
'use strict';

const Assets = (() => {
  const cache = {};

  function img(caminho) {
    let e = cache[caminho];
    if (!e) {
      const im = new Image();
      e = cache[caminho] = { img: im, ok: false, erro: false };
      im.onload = () => { e.ok = true; };
      im.onerror = () => { e.erro = true; };
      im.src = 'img/' + caminho + '.png';
    }
    return e.ok ? e.img : null;
  }

  // desenha o PNG do designer se existir; senão retorna false (usa procedural)
  function desenharSeExistir(ctx, caminho, x, y, w, h) {
    const im = img(caminho);
    if (!im) return false;
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(im, x, y, w, h);
    return true;
  }

  return { img, desenharSeExistir };
})();
