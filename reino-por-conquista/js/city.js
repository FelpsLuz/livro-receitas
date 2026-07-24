// ============================================================
// PIXEL ART PROCEDURAL DO ASSENTAMENTO
// Nível 0: mato e tendas → 1: aldeia+paliçada → 2: vila+moinho
// → 3: burgo (muro de pedra, mercado) → 4: cidade (torres, NPCs)
// → 5: castelo. NPCs andam pelo mercado nos níveis altos.
// ============================================================
'use strict';

const Cidade = (() => {
  const W = 320, H = 180, PX = 1; // resolução lógica; canvas escala via CSS
  let anim = 0;
  let npcs = [];

  function seedNpcs(nivel) {
    npcs = [];
    const n = nivel >= 4 ? 14 : nivel >= 3 ? 8 : nivel >= 2 ? 4 : nivel >= 1 ? 2 : 0;
    for (let i = 0; i < n; i++) {
      npcs.push({
        x: 60 + Math.random() * 200, y: 118 + Math.random() * 40,
        vx: (Math.random() - 0.5) * 0.4,
        cor: rnd(['#c9a227', '#7a4a2b', '#5b6b8c', '#7d3b3b', '#4a6b4a', '#8c7a5b']),
      });
    }
  }

  function px(ctx, x, y, w, h, cor) { ctx.fillStyle = cor; ctx.fillRect(Math.round(x), Math.round(y), w, h); }

  function desenharCeu(ctx, nivel) {
    const g = ctx.createLinearGradient(0, 0, 0, 100);
    g.addColorStop(0, '#8db8d8'); g.addColorStop(1, '#d8c8a8');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, 100);
    // sol
    px(ctx, 264, 18, 14, 14, '#f5e6a8'); px(ctx, 267, 15, 8, 20, '#f5e6a8'); px(ctx, 261, 21, 20, 8, '#f5e6a8');
    // nuvens que se movem
    const cx = (anim * 0.15) % (W + 60) - 60;
    px(ctx, cx, 26, 34, 7, '#f0ece2'); px(ctx, cx + 8, 21, 20, 6, '#f0ece2');
    px(ctx, (cx + 150) % (W + 60), 40, 28, 6, '#e8e4da');
    // colinas de fundo
    ctx.fillStyle = '#7a9464';
    ctx.beginPath(); ctx.moveTo(0, 100);
    for (let x = 0; x <= W; x += 8) ctx.lineTo(x, 84 + Math.sin(x * 0.05) * 8);
    ctx.lineTo(W, 100); ctx.fill();
  }

  function desenharChao(ctx, nivel) {
    px(ctx, 0, 100, W, 80, nivel >= 2 ? '#8a9a5b' : '#7d8f55');
    // trilha / rua
    const corRua = nivel >= 3 ? '#9a8f7a' : '#a8905f';
    ctx.fillStyle = corRua;
    ctx.beginPath(); ctx.moveTo(140, 180); ctx.lineTo(150, 108); ctx.lineTo(170, 108); ctx.lineTo(190, 180); ctx.fill();
    // mato aleatório determinístico
    for (let i = 0; i < 70; i++) {
      const x = (i * 37) % W, y = 102 + ((i * 53) % 74);
      if (x > 130 && x < 195) continue;
      px(ctx, x, y, 1, 2 + (i % 2), nivel === 0 ? '#5f7442' : '#6b8248');
    }
  }

  function tenda(ctx, x, y) {
    ctx.fillStyle = '#b0925f';
    ctx.beginPath(); ctx.moveTo(x, y + 14); ctx.lineTo(x + 9, y); ctx.lineTo(x + 18, y + 14); ctx.fill();
    px(ctx, x + 7, y + 8, 4, 6, '#4a3826');
  }

  function casa(ctx, x, y, pedra) {
    px(ctx, x, y + 6, 18, 12, pedra ? '#a8a095' : '#8a6b45');   // parede
    ctx.fillStyle = pedra ? '#7d5a3a' : '#6b4a2d';               // telhado
    ctx.beginPath(); ctx.moveTo(x - 2, y + 7); ctx.lineTo(x + 9, y - 2); ctx.lineTo(x + 20, y + 7); ctx.fill();
    px(ctx, x + 7, y + 11, 4, 7, '#3a2d1d');                     // porta
    px(ctx, x + 2, y + 9, 3, 3, '#e8d8a0');                      // janela
    px(ctx, x + 13, y + 9, 3, 3, '#e8d8a0');
  }

  function moinho(ctx, x, y) {
    px(ctx, x, y, 14, 26, '#9a8365');
    ctx.fillStyle = '#6b4a2d';
    ctx.beginPath(); ctx.moveTo(x - 2, y + 1); ctx.lineTo(x + 7, y - 8); ctx.lineTo(x + 16, y + 1); ctx.fill();
    // pás girando
    ctx.save(); ctx.translate(x + 7, y + 4); ctx.rotate(anim * 0.02);
    ctx.fillStyle = '#e8dcc0';
    for (let i = 0; i < 4; i++) { ctx.rotate(Math.PI / 2); ctx.fillRect(-1, 0, 3, 16); }
    ctx.restore();
  }

  function paliçada(ctx, y) {
    for (let x = 4; x < W - 4; x += 6) {
      if (x > 132 && x < 190) continue; // portão
      px(ctx, x, y, 4, 14, '#7a5c38');
      ctx.fillStyle = '#8a6b45';
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 2, y - 4); ctx.lineTo(x + 4, y); ctx.fill();
    }
    px(ctx, 132, y - 2, 4, 16, '#5d4428'); px(ctx, 186, y - 2, 4, 16, '#5d4428');
  }

  function muroPedra(ctx, y, torres) {
    px(ctx, 0, y, W, 12, '#8f8b82');
    for (let x = 0; x < W; x += 8) px(ctx, x, y - 3, 5, 4, '#8f8b82');       // ameias
    for (let x = 0; x < W; x += 16) px(ctx, x + 3, y + 4, 6, 3, '#7d7970'); // pedras
    px(ctx, 138, y - 4, 46, 18, '#7d7970'); px(ctx, 146, y + 2, 30, 12, '#3a3128'); // portão
    if (torres) {
      for (const tx of [20, 290]) {
        px(ctx, tx, y - 22, 16, 34, '#8f8b82');
        for (let x = tx; x < tx + 16; x += 5) px(ctx, x, y - 25, 3, 4, '#8f8b82');
        px(ctx, tx + 6, y - 16, 4, 5, '#3a3128');
        // bandeira
        px(ctx, tx + 7, y - 32, 1, 8, '#4a3826');
        px(ctx, tx + 8, y - 32 + Math.sin(anim * 0.1) * 0.8, 7, 4, '#8b2635');
      }
    }
  }

  function castelo(ctx, x, y) {
    px(ctx, x, y, 60, 40, '#a8a49b');                       // corpo
    px(ctx, x - 12, y - 14, 16, 54, '#98948b');             // torre esq
    px(ctx, x + 56, y - 14, 16, 54, '#98948b');             // torre dir
    px(ctx, x + 22, y - 22, 16, 62, '#b0aca3');             // torre central
    for (const [tx, ty, tw] of [[x - 12, y - 14, 16], [x + 56, y - 14, 16], [x + 22, y - 22, 16]])
      for (let i = 0; i < tw; i += 5) px(ctx, tx + i, ty - 4, 3, 5, '#98948b');
    px(ctx, x + 26, y + 22, 9, 18, '#3a3128');              // portão
    for (const wx of [x + 6, x + 46]) px(ctx, wx, y + 8, 4, 6, '#e8d8a0');
    px(ctx, x + 28, y - 12, 4, 5, '#e8d8a0');
    // estandarte real
    px(ctx, x + 29, y - 34, 2, 12, '#4a3826');
    ctx.fillStyle = '#c9a227';
    ctx.beginPath(); ctx.moveTo(x + 31, y - 34); ctx.lineTo(x + 43 + Math.sin(anim * 0.08) * 2, y - 31); ctx.lineTo(x + 31, y - 27); ctx.fill();
  }

  function barraca(ctx, x, y, cor) {
    px(ctx, x, y + 4, 14, 8, '#8a6b45');
    ctx.fillStyle = cor;
    for (let i = 0; i < 14; i += 4) px(ctx, x + i, y, 4, 5, i % 8 === 0 ? cor : '#e8dcc0');
    px(ctx, x + 1, y + 6, 12, 2, '#c9b280'); // mercadorias
  }

  function campos(ctx) {
    for (const [cx, cy] of [[10, 150], [40, 158], [258, 148], [286, 158]]) {
      px(ctx, cx, cy, 26, 14, '#a3843c');
      for (let i = 2; i < 26; i += 4) px(ctx, cx + i, cy + 1, 1, 12, '#c9a94f');
    }
  }

  function desenharNpcs(ctx) {
    for (const n of npcs) {
      n.x += n.vx; if (n.x < 50 || n.x > 270) n.vx *= -1;
      const bob = Math.floor(anim / 12 + n.x) % 2;
      px(ctx, n.x, n.y - 5 - bob, 3, 3, '#d8b090');  // cabeça
      px(ctx, n.x, n.y - 2 - bob, 3, 4, n.cor);      // corpo
    }
  }

  function render(canvas, state) {
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    anim++;
    const nivel = state.terra ? state.terra.nivel : -1;
    desenharCeu(ctx, nivel);
    desenharChao(ctx, Math.max(0, nivel));

    if (nivel < 0) { // sem terra: acampamento mercenário na estrada
      tenda(ctx, 90, 128); tenda(ctx, 220, 140); tenda(ctx, 60, 150);
      px(ctx, 158, 138, 6, 6, '#d86a2d'); px(ctx, 160, 134, 2, 4, '#f5c04a'); // fogueira
      desenharNpcs(ctx);
      return;
    }
    if (nivel >= 1) campos(ctx);
    if (nivel === 0) {
      tenda(ctx, 80, 120); tenda(ctx, 210, 132); tenda(ctx, 120, 148); tenda(ctx, 250, 118);
      px(ctx, 160, 140, 6, 6, '#d86a2d'); px(ctx, 162, 136, 2, 4, '#f5c04a');
    }
    if (nivel >= 1) {
      casa(ctx, 70, 116, false); casa(ctx, 230, 120, false); casa(ctx, 100, 140, false);
      if (nivel === 1 || nivel === 2) paliçada(ctx, 104);
    }
    if (nivel >= 2) {
      moinho(ctx, 34, 108); casa(ctx, 260, 138, false); casa(ctx, 200, 148, false);
    }
    if (nivel >= 3) {
      muroPedra(ctx, 100, nivel >= 4);
      casa(ctx, 70, 116, true); casa(ctx, 230, 120, true);
      barraca(ctx, 116, 146, '#8b2635'); barraca(ctx, 196, 142, '#2d4a6b');
    }
    if (nivel >= 4) {
      barraca(ctx, 86, 156, '#b8862d'); barraca(ctx, 226, 158, '#3e5f3e');
      casa(ctx, 40, 130, true); casa(ctx, 280, 128, true);
    }
    if (nivel >= 5) castelo(ctx, 130, 44);
    desenharNpcs(ctx);
  }

  return { render, seedNpcs };
})();
