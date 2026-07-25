// ============================================================
// DUELO ANIMADO — cena de batalha com os sprites do pacote
// (Knight Hero = você; Medieval Warrior = inimigo comum;
//  Medieval King = tropas reais/imperiais)
// Coreografia: aproximação → troca de golpes → o perdedor cai.
// ============================================================
'use strict';

const Duelo = (() => {
  // alvoH = altura do QUADRO desenhado (os personagens ocupam ~60% do quadro)
  const FICHAS = {
    heroi: { fh: 96, alvoH: 118, anims: {
      idle: { arq: 'heroi_idle', frames: 5, fw: 128 },
      run: { arq: 'heroi_run', frames: 8, fw: 128 },
      atk: { arq: 'heroi_atk', frames: 7, fw: 128 },
      hit: { arq: 'heroi_hit', frames: 3, fw: 128 },
      morte: { arq: 'heroi_morte', frames: 7, fw: 128 },
    } },
    guerreiro: { fh: 150, alvoH: 150, anims: {
      idle: { arq: 'guerreiro_idle', frames: 8, fw: 150 },
      run: { arq: 'guerreiro_idle', frames: 8, fw: 150 },
      atk: { arq: 'guerreiro_atk', frames: 4, fw: 150 },
      hit: { arq: 'guerreiro_hit', frames: 4, fw: 150 },
      morte: { arq: 'guerreiro_morte', frames: 6, fw: 150 },
    } },
    rei: { fh: 111, alvoH: 128, anims: {
      idle: { arq: 'rei_idle', frames: 8, fw: 160 },
      run: { arq: 'rei_idle', frames: 8, fw: 160 },
      atk: { arq: 'rei_atk', frames: 4, fw: 160 },
      hit: { arq: 'rei_hit', frames: 4, fw: 160 },
      morte: { arq: 'rei_morte', frames: 6, fw: 160 },
    } },
  };

  const cache = {};
  function img(arq) {
    if (!cache[arq]) {
      const im = new Image();
      im.src = 'img/duelo/' + arq + '.png';
      cache[arq] = im;
    }
    return cache[arq];
  }

  let rodando = null;

  // canvas 340×130; vitoria = o herói vence?; inimigo = 'guerreiro' | 'rei'
  function iniciar(canvas, vitoria, inimigo) {
    parar();
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    const W = canvas.width, H = canvas.height, CHAO = H - 14;
    // x é o CENTRO do lutador na tela
    const fx = { tipo: 'heroi', x: 46, flip: false, anim: 'run', f: 0 };
    const fy = { tipo: inimigo || 'guerreiro', x: W / 2 + 62, flip: true, anim: 'idle', f: 0 };
    // roteiro: [duração em ticks, animHeroi, animInimigo]
    const roteiro = [
      [26, 'run', 'idle'],                                     // herói se aproxima
      [16, 'atk', 'idle'], [10, 'idle', 'hit'],                // 1º golpe
      [14, 'idle', 'atk'], [8, 'hit', 'idle'],                 // resposta
      [16, 'atk', 'idle'], [10, 'idle', 'hit'],                // 2º golpe
      vitoria ? [30, 'idle', 'morte'] : [30, 'morte', 'idle'], // desfecho
    ];
    let etapa = 0, tick = 0, quadro = 0;

    function desenhar(l) {
      const ficha = FICHAS[l.tipo];
      const a = ficha.anims[l.anim];
      const im = img(a.arq);
      if (!im.complete || !im.naturalWidth) return;
      const esc = ficha.alvoH / ficha.fh;
      const w = a.fw * esc, h = ficha.fh * esc;
      const fi = (l.anim === 'morte' && l.f >= a.frames) ? a.frames - 1 : l.f % a.frames;
      ctx.save();
      ctx.translate(l.x - w / 2, CHAO - h + 4);
      if (l.flip) { ctx.translate(w, 0); ctx.scale(-1, 1); }
      ctx.drawImage(im, fi * a.fw, 0, a.fw, ficha.fh, 0, 0, w, h);
      ctx.restore();
    }

    function passo() {
      // fundo: fim de tarde de campo de batalha
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, '#3c2f3e'); g.addColorStop(0.7, '#6b4a3c'); g.addColorStop(1, '#2e2018');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = '#241a12'; ctx.fillRect(0, CHAO, W, H - CHAO);
      ctx.fillStyle = '#3a2a1c';
      for (let i = 0; i < 12; i++) ctx.fillRect((i * 47 + 13) % W, CHAO + 3 + (i % 3) * 3, 8, 2);

      const [dur, aH, aI] = roteiro[etapa];
      if (fx.anim !== aH) { fx.anim = aH; fx.f = 0; }
      if (fy.anim !== aI) { fy.anim = aI; fy.f = 0; }
      if (fx.anim === 'run' && fx.x < W / 2 - 44) fx.x += 3;

      // sombras
      ctx.fillStyle = 'rgba(0,0,0,.35)';
      for (const l of [fx, fy]) { ctx.beginPath(); ctx.ellipse(l.x, CHAO + 4, 24, 5, 0, 0, 7); ctx.fill(); }
      desenhar(fy); desenhar(fx);

      if (++quadro % 6 === 0) { fx.f++; fy.f++; }
      if (++tick >= dur) {
        tick = 0;
        if (etapa < roteiro.length - 1) { etapa++; }
        else if (fx.anim !== 'morte' && fy.anim !== 'morte') { etapa = 1; }  // vitória: herói segue de pé
      }
      rodando = requestAnimationFrame(passo);
    }
    rodando = requestAnimationFrame(passo);
  }

  function parar() { if (rodando) { cancelAnimationFrame(rodando); rodando = null; } }

  return { iniciar, parar };
})();
