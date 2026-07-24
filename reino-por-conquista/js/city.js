// ============================================================
// VILA EM PIXEL ART — v5 "anatomia Stardew"
// As 5 regras (à risca):
//  1. MALHA 16×16: todo o mundo em tiles de 16px; aldeões 16×32.
//  2. CONTORNO SELETIVO: personagens/animais/itens têm contorno
//     escuro; grama, água e construções NÃO (fundo coeso).
//  3. PERSPECTIVA 3/4 TOP-DOWN: o chão preenche a tela (sem céu
//     nem horizonte) e a profundidade é a REGRA DO Y — pé mais
//     baixo desenha na frente (ordenação por Y a cada quadro).
//  4. PALETA SATURADA com sombras hue-shifted (verde→azulado,
//     nunca preto) e 4 estações completas.
//  5. CONTROLE DE RUÍDO: tiles de cor sólida + tufos estratégicos
//     de 3-4 pixels; leitura limpa por horas.
// Desempenho: terreno em canvas-cache; construções + entidades
// ordenadas por Y a cada quadro (barato num i3).
// ============================================================
'use strict';

const Cidade = (() => {
  const W = 640, H = 360, T = 16;          // T = tile 16×16
  let anim = 0;
  let npcs = [], galinhas = [];
  let bg = null, bgKey = '';
  let sprites = [];                        // construções fixas {y, fn}
  let luzes = [];                          // janelas (brilham à noite)
  let chamines = [];                       // fumaça
  let cicloForcado = null;

  // ---------- paletas saturadas (hue-shift: sombra fria, luz quente) ----------
  const PAL = {
    primavera: {
      gramaA: '#63b737', gramaB: '#5cae31', gramaEscuro: '#3f8a44', tufo: '#7fd14a',
      flor: ['#f5f0fa', '#f7d94c', '#f2a0c0'],
      arvore: ['#2e7a45', '#3f9a4e', '#54b558', '#7fd166'],
      agua: ['#2b55b0', '#3a6fd8', '#6fa9f0', '#cfe8ff'],
      terra: '#b98a4e', terraEscura: '#8a6136', pedrisco: '#d3a968',
      campo: '#7a5433', broto: '#8fd14a',
    },
    verao: {
      gramaA: '#55a52e', gramaB: '#4e9c29', gramaEscuro: '#357c3e', tufo: '#78c342',
      flor: ['#f7d94c', '#f09048', '#f5f0fa'],
      arvore: ['#28703f', '#389048', '#4daa50', '#74c65e'],
      agua: ['#2b55b0', '#3a6fd8', '#6fa9f0', '#cfe8ff'],
      terra: '#b3824a', terraEscura: '#855c34', pedrisco: '#cfa261',
      campo: '#74502f', broto: '#e3c04a',
    },
    outono: {
      gramaA: '#b0872f', gramaB: '#a67f2b', gramaEscuro: '#7d5c33', tufo: '#cf9f3d',
      flor: ['#c25a2e', '#a8442e', '#d98e35'],
      arvore: ['#8a3b26', '#b0562e', '#ce7a35', '#e8a844'],
      agua: ['#2b4d9e', '#3763c4', '#6698e0', '#c4dcf5'],
      terra: '#a3743f', terraEscura: '#77522c', pedrisco: '#c49355',
      campo: '#6b4a2c', broto: '#b0722e',
    },
    inverno: {
      gramaA: '#e8f0f4', gramaB: '#dde8ee', gramaEscuro: '#b6c9d6', tufo: '#f6fafc',
      flor: ['#c8d8e4', '#dde8ee', '#b6c9d6'],
      arvore: ['#4a4a45', '#5d5a50', '#6f6b5e', '#eef4f8'],
      agua: ['#5a7ba8', '#7295bd', '#a9c4dd', '#e8f2fa'],
      terra: '#a99a88', terraEscura: '#83766a', pedrisco: '#c6bab0',
      campo: '#8f96a3', broto: '#dde8ee',
    },
  };
  const SOMBRA = 'rgba(32,52,78,.28)';     // sombra projetada (azulada)
  const CONTORNO = '#26160e';              // contorno dos elementos interativos

  function estacao(mes) {
    if (mes >= 3 && mes <= 5) return 'primavera';
    if (mes >= 6 && mes <= 8) return 'verao';
    if (mes >= 9 && mes <= 11) return 'outono';
    return 'inverno';
  }
  function sr(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }

  // rio: banda horizontal que serpenteia (2 tiles de altura)
  function rioTopo(px) { return 292 + Math.round(Math.sin(px * 0.015) * 8 + Math.sin(px * 0.006 + 2) * 5); }
  const RIO_ALT = 34;
  const RUA_X0 = 304, RUA_X1 = 336;        // estrada vertical (2 tiles) alinhada ao portão

  function dentroDoRio(px, py) { const t = rioTopo(px); return py > t - 4 && py < t + RIO_ALT + 2; }
  function naPonte(px) { return px >= RUA_X0 - 4 && px <= RUA_X1 + 4; }

  // ---------- entidades ----------
  function seedNpcs(nivel) {
    npcs = []; galinhas = [];
    const n = nivel >= 5 ? 12 : nivel >= 3 ? 9 : nivel >= 1 ? 5 : 4;
    const roupas = ['#c9403a', '#3c6ac4', '#e0a63c', '#4a9a4a', '#9a55c4', '#c4703c', '#4aa9a0', '#b04a7a'];
    const calcas = ['#3a4a8a', '#5d4228', '#4a5a66', '#6b3a55'];
    const cabelos = ['#3a2416', '#7a4a24', '#e0b43c', '#8a8078', '#b0542e'];
    for (let i = 0; i < n; i++) {
      npcs.push({
        x: 80 + sr(i * 3 + 1) * 480, y: 110 + sr(i * 7 + 2) * 200,
        vx: (sr(i * 11 + 3) - 0.5) * 0.4, vy: (sr(i * 5 + 8) - 0.5) * 0.3,
        pausa: 0, roupa: roupas[i % roupas.length], calca: calcas[i % calcas.length],
        cabelo: cabelos[i % cabelos.length], fem: sr(i * 13) < 0.45,
      });
    }
    if (nivel >= 1) for (let i = 0; i < 4; i++) {
      galinhas.push({ x: 70 + sr(i * 17) * 90, y: 250 + sr(i * 19) * 30, t: sr(i * 23) * 100, vx: 0.1 });
    }
  }

  // ============================================================
  // TERRENO (cache): grama, trilhas, campos, rio, ponte
  // ============================================================
  function desenharTerreno(nivel, pal) {
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const x = cv.getContext('2d');
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };

    // --- grama em tiles 16×16 (duas variações de base, sem ruído) ---
    for (let ty = 0; ty < H; ty += T) {
      for (let tx = 0; tx < W; tx += T) {
        P(tx, ty, T, T, sr(tx * 7 + ty * 13) < 0.5 ? pal.gramaA : pal.gramaB);
      }
    }
    // tufos estratégicos (clusters de 3-4 px) e flores — ~1 a cada 6 tiles
    for (let ty = 0; ty < H; ty += T) {
      for (let tx = 0; tx < W; tx += T) {
        const r = sr(tx * 31 + ty * 17);
        if (r < 0.16) {
          const ox = tx + 3 + Math.floor(sr(tx + ty) * 8), oy = ty + 3 + Math.floor(sr(tx * 3 + ty) * 8);
          P(ox, oy, 2, 2, pal.gramaEscuro); P(ox + 2, oy - 1, 1, 2, pal.gramaEscuro);
          P(ox - 1, oy + 1, 1, 1, pal.tufo);
        } else if (r > 0.94 && !dentroDoRio(tx, ty)) {
          const ox = tx + 4 + Math.floor(sr(tx * 9 + ty) * 7), oy = ty + 4 + Math.floor(sr(tx + ty * 9) * 7);
          P(ox, oy, 2, 2, pal.flor[Math.floor(sr(tx * ty + 1) * 3)]);
          P(ox, oy + 2, 1, 1, pal.gramaEscuro);
        }
      }
    }

    // --- trilhas de terra (tiles com borda escura onde encontra grama) ---
    const trilha = (x0, y0, x1, y1) => {   // retângulo em tiles
      for (let ty = y0; ty < y1; ty += T) for (let tx = x0; tx < x1; tx += T) {
        P(tx, ty, T, T, pal.terra);
        if (sr(tx * 3 + ty * 7) < 0.3) P(tx + 4 + sr(tx + ty) * 6, ty + 4 + sr(tx * 2 + ty) * 6, 2, 2, pal.pedrisco);
        if (sr(tx * 5 + ty * 3) < 0.2) P(tx + 3 + sr(tx - ty) * 8, ty + 6 + sr(tx * 4) * 6, 2, 1, pal.terraEscura);
      }
      P(x0, y0, 1, y1 - y0, pal.terraEscura); P(x1 - 1, y0, 1, y1 - y0, pal.terraEscura);
      P(x0, y0, x1 - x0, 1, pal.terraEscura); P(x0, y1 - 1, x1 - x0, 1, pal.terraEscura);
    };
    // estrada principal: do portão ao sul da tela
    trilha(RUA_X0, nivel >= 1 ? 88 : 64, RUA_X1, H);
    // ruas horizontais da vila
    if (nivel >= 1) trilha(128, 208, 512, 208 + T);
    if (nivel >= 3) trilha(208, 144, 432, 144 + T);

    // --- campos de cultivo (sulcos + brotos por estação) ---
    if (nivel >= 1) {
      const plots = nivel >= 4 ? [[48, 256]] : [[48, 256], [528, 256]];
      for (const [cx, cy] of plots) {
        for (let ty = 0; ty < 3; ty++) for (let tx = 0; tx < 5; tx++) {
          const px = cx + tx * T, py = cy + ty * T;
          P(px, py, T, T, pal.campo);
          P(px, py + 4, T, 2, pal.terraEscura); P(px, py + 10, T, 2, pal.terraEscura);
          P(px + 4, py + 3, 2, 3, pal.broto); P(px + 10, py + 9, 2, 3, pal.broto);
        }
        P(cx - 2, cy - 2, 5 * T + 4, 2, pal.terraEscura);
        P(cx - 2, cy + 3 * T, 5 * T + 4, 2, pal.terraEscura);
      }
    }

    // --- rio (2 tiles, serpenteia; margens escuras, SEM contorno preto) ---
    for (let px = 0; px < W; px += 2) {
      const topo = rioTopo(px);
      P(px, topo - 2, 2, 2, pal.gramaEscuro);
      P(px, topo, 2, 3, pal.agua[2]);
      P(px, topo + 3, 2, RIO_ALT - 8, pal.agua[1]);
      P(px, topo + RIO_ALT - 5, 2, 3, pal.agua[0]);
      P(px, topo + RIO_ALT - 2, 2, 2, pal.gramaEscuro);
    }

    // --- ponte de madeira sobre o rio ---
    const yP = rioTopo(320) - 2;
    P(RUA_X0 - 4, yP, RUA_X1 - RUA_X0 + 8, RIO_ALT + 4, '#a3703c');
    for (let py = yP + 2; py < yP + RIO_ALT + 2; py += 5) P(RUA_X0 - 4, py, RUA_X1 - RUA_X0 + 8, 2, '#8a5a2e');
    P(RUA_X0 - 6, yP, 3, RIO_ALT + 4, '#6b4423'); P(RUA_X1 + 3, yP, 3, RIO_ALT + 4, '#6b4423');
    P(RUA_X0 - 6, yP - 2, 3, 3, '#8a5a2e'); P(RUA_X1 + 3, yP - 2, 3, 3, '#8a5a2e');
    P(RUA_X0 - 6, yP + RIO_ALT + 1, 3, 3, '#8a5a2e'); P(RUA_X1 + 3, yP + RIO_ALT + 1, 3, 3, '#8a5a2e');

    return cv;
  }

  // ============================================================
  // CONSTRUÇÕES (sprites com Y para ordenação)
  // ============================================================
  function montarCena(nivel, pal) {
    sprites = []; luzes = []; chamines = [];
    const add = (y, fn) => sprites.push({ y, fn });

    // ---------- casa 3/4: telhado + parede frontal ----------
    const casa = (cx, cy, wT, telhado, pedra, chamine) => {
      const w = wT * T, alturaParede = 26, alturaTelhado = 30;
      const px = cx, py = cy;               // py = base (pés da casa)
      add(py, (x) => {
        const P = (a, b, ww, hh, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(ww), Math.round(hh)); };
        // sombra no chão (direção fixa: sudoeste)
        P(px - 5, py - 3, w + 8, 6, SOMBRA);
        const yParede = py - alturaParede, yTelhado = yParede - alturaTelhado;
        // parede frontal
        const parede = pedra ? '#a9abb3' : '#e8d4a8';
        const paredeSombra = pedra ? '#7b7e8e' : '#c4a878';
        P(px, yParede, w, alturaParede, parede);
        P(px, yParede, 3, alturaParede, paredeSombra);
        P(px, py - 4, w, 4, paredeSombra);
        if (pedra) {
          x.fillStyle = '#8e9099';
          for (let ry = 5; ry < alturaParede - 3; ry += 7)
            for (let rx = (ry % 14 === 5 ? 4 : 11); rx < w - 4; rx += 14) x.fillRect(px + rx, yParede + ry, 7, 2);
        } else {
          const viga = '#7a4a26';
          P(px, yParede, w, 2, viga); P(px, py - 2, w, 2, viga);
          P(px, yParede, 2, alturaParede, viga); P(px + w - 2, yParede, 2, alturaParede, viga);
          P(px + w / 2 - 1, yParede, 2, alturaParede, viga);
        }
        // porta (1 tile de largura, arco)
        const dx = px + w / 2 - 8;
        P(dx - 2, py - 22, 20, 22, pedra ? '#7b7e8e' : '#7a4a26');
        P(dx, py - 20, 16, 20, '#4a3018');
        P(dx + 2, py - 18, 12, 18, '#66421f');
        P(dx + 11, py - 11, 3, 3, '#e8c84a');
        // janelas (luz quente + moldura)
        for (const wx of [px + 8, px + w - 20]) {
          P(wx - 2, yParede + 6, 16, 14, pedra ? '#7b7e8e' : '#7a4a26');
          P(wx, yParede + 8, 12, 10, '#3a2c16');
          P(wx + 2, yParede + 10, 8, 6, '#5a749e');
          P(wx + 2, yParede + 10, 8, 2, '#7e95bd');
          P(wx + 5, yParede + 10, 2, 6, '#3a2c16');
          luzes.push({ x: wx + 6, y: yParede + 13 });
        }
        // telhado (plano vertical com beiral; palha ou ardósia)
        const beira = 6;
        const tons = telhado === 'palha' ? ['#d29b38', '#c08a2f', '#a8742c'] : ['#6b7bb4', '#5d6b9e', '#4d5a88'];
        P(px - beira, yTelhado, w + beira * 2, alturaTelhado, tons[1]);
        P(px - beira, yTelhado, w + beira * 2, 10, tons[0]);
        P(px - beira, yTelhado + alturaTelhado - 8, w + beira * 2, 8, tons[2]);
        P(px - beira, yTelhado, w + beira * 2, 3, telhado === 'palha' ? '#eec25c' : '#8a97c9');
        for (let rx = 6; rx < w + beira * 2 - 4; rx += 11)
          P(px - beira + rx, yTelhado + 6, 2, alturaTelhado - 10, tons[2]);
        P(px - beira, yTelhado + alturaTelhado - 2, w + beira * 2, 2, pedra ? '#4d5878' : '#8a6428');
        if (chamine) {
          P(px + w - 14, yTelhado - 8, 8, 12, '#9b9da8');
          P(px + w - 14, yTelhado - 8, 8, 3, '#c2c3c9');
          P(px + w - 15, yTelhado - 10, 10, 3, '#7b7e8e');
          chamines.push({ x: px + w - 10, y: yTelhado - 11 });
        }
      });
    };

    // ---------- árvores (copa cheia + sombra elíptica) ----------
    const arvore = (tx, ty, tipo) => add(ty, (x) => {
      const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
      x.fillStyle = SOMBRA;
      x.beginPath(); x.ellipse(tx, ty - 1, 17, 6, 0, 0, 7); x.fill();
      P(tx - 4, ty - 16, 8, 16, '#6b4423');
      P(tx - 4, ty - 16, 2, 16, '#4d2f16');
      P(tx + 1, ty - 16, 2, 16, '#8a5a2e');
      if (tipo === 'pinheiro') {
        for (let i = 0; i < 3; i++) {
          const w2 = 34 - i * 9, y2 = ty - 18 - i * 13;
          x.fillStyle = PALATUAL.arvore[1];
          x.beginPath(); x.moveTo(tx - w2 / 2, y2); x.lineTo(tx, y2 - 16); x.lineTo(tx + w2 / 2, y2); x.fill();
          x.fillStyle = PALATUAL.arvore[2];
          x.beginPath(); x.moveTo(tx, y2 - 16); x.lineTo(tx + w2 / 2, y2); x.lineTo(tx + w2 / 8, y2); x.fill();
        }
      } else {
        const A = PALATUAL.arvore;
        const blob = (bx, by, bw, bh, c) => P(bx - bw / 2, by - bh / 2, bw, bh, c);
        blob(tx, ty - 30, 40, 24, A[1]);
        blob(tx - 8, ty - 40, 26, 16, A[1]);
        blob(tx + 10, ty - 42, 22, 16, A[2]);
        blob(tx - 14, ty - 24, 18, 12, A[0]);
        blob(tx + 12, ty - 47, 14, 9, A[3]);
        blob(tx + 14, ty - 32, 12, 9, A[3]);
        for (let i = 0; i < 10; i++)
          P(tx - 16 + sr(i * 7 + tx) * 32, ty - 48 + sr(i * 9 + ty) * 24, 2, 2, i % 2 ? A[0] : A[3]);
      }
    });

    const arbusto = (bx, by) => add(by, (x) => {
      const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
      P(bx - 7, by - 2, 15, 3, SOMBRA);
      P(bx - 7, by - 9, 14, 8, PALATUAL.arvore[1]);
      P(bx - 5, by - 12, 10, 5, PALATUAL.arvore[2]);
      P(bx - 7, by - 5, 5, 4, PALATUAL.arvore[0]);
      P(bx + 1, by - 12, 4, 3, PALATUAL.arvore[3]);
    });

    // ---------- muralha / paliçada (corre horizontal no topo) ----------
    if (nivel >= 3) {
      add(88, (x) => {
        const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
        P(0, 84, W, 5, SOMBRA);
        P(0, 40, W, 46, '#9799a3');                      // frente da muralha
        P(0, 40, W, 6, '#c2c3c9');                        // topo (passarela)
        P(0, 80, W, 6, '#63667a');                        // base fria
        x.fillStyle = '#84868f';
        for (let ry = 10; ry < 76; ry += 9)
          for (let rx = (ry % 18 === 10 ? 4 : 13); rx < W; rx += 18) x.fillRect(rx, 40 + ry - 2, 9, 2);
        for (let rx = 0; rx < W; rx += 14) {              // ameias
          if (rx > RUA_X0 - 24 && rx < RUA_X1 + 10) continue;
          P(rx, 32, 9, 9, '#9799a3'); P(rx, 32, 9, 2, '#c2c3c9');
        }
        x.fillStyle = '#55704a';                          // musgo
        for (let rx = 5; rx < W; rx += 23) x.fillRect(rx, 82, 6, 3);
        // portão em arco com levadiça
        P(RUA_X0 - 14, 34, RUA_X1 - RUA_X0 + 28, 52, '#84868f');
        P(RUA_X0 - 14, 34, RUA_X1 - RUA_X0 + 28, 4, '#c2c3c9');
        x.fillStyle = '#241c14';
        x.beginPath(); x.moveTo(RUA_X0 - 2, 86); x.lineTo(RUA_X0 - 2, 54);
        x.quadraticCurveTo(320, 40, RUA_X1 + 2, 54); x.lineTo(RUA_X1 + 2, 86); x.fill();
        x.fillStyle = '#5d4a30';
        for (let gx = RUA_X0 + 2; gx < RUA_X1; gx += 7) x.fillRect(gx, 50, 3, 36);
        x.fillRect(RUA_X0 - 2, 60, 36, 2); x.fillRect(RUA_X0 - 2, 72, 36, 2);
        // tochas
        for (const txx of [RUA_X0 - 20, RUA_X1 + 14]) {
          P(txx, 58, 3, 12, '#6b4423');
          const fl = Math.sin(anim * 0.3 + txx) * 1.5;
          P(txx - 1, 52 + fl * 0.5, 5, 6, '#e8742e');
          P(txx, 50 + fl * 0.7, 3, 4, '#f7a63c');
          P(txx + 1, 49 + fl, 1, 2, '#fbe37a');
        }
      });
    } else if (nivel >= 1) {
      add(80, (x) => {
        const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
        P(0, 76, W, 4, SOMBRA);
        for (let px = 0; px < W; px += 9) {
          if (px > RUA_X0 - 12 && px < RUA_X1 + 4) continue;
          const hh = 30 + (px % 7);
          P(px, 78 - hh, 7, hh, '#8a5a2e');
          P(px + 5, 78 - hh, 2, hh, '#a3703c');
          P(px, 78 - hh, 2, hh, '#5f3d22');
          x.fillStyle = '#a3703c';
          x.beginPath(); x.moveTo(px, 78 - hh); x.lineTo(px + 3.5, 70 - hh); x.lineTo(px + 7, 78 - hh); x.fill();
        }
        P(RUA_X0 - 12, 42, 4, 38, '#5f3d22'); P(RUA_X1 + 2, 42, 4, 38, '#5f3d22');
        P(RUA_X0 - 12, 40, RUA_X1 - RUA_X0 + 18, 5, '#6b4423');
      });
    }

    // ---------- castelo (nível 5): torreão atrás da muralha ----------
    if (nivel >= 5) {
      add(40, (x) => {
        const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
        const cx = 320, cyt = 10;   // desce para os cones caberem na tela
        // torreão central
        P(cx - 56, cyt, 112, 42, '#aaacb6');
        x.fillStyle = '#8e9099';
        for (let ry = 6; ry < 40; ry += 9)
          for (let rx = (ry % 18 === 6 ? 6 : 16); rx < 104; rx += 20) x.fillRect(cx - 56 + rx, cyt + ry, 10, 2);
        P(cx - 56, cyt, 112, 4, '#c9cad1');
        for (const wx of [cx - 40, cx - 8, cx + 26]) {
          P(wx - 2, cyt + 12, 16, 16, '#7b7e8e');
          P(wx, cyt + 14, 12, 12, '#3a2c16');
          P(wx + 2, cyt + 16, 8, 8, '#5a749e'); P(wx + 2, cyt + 16, 8, 3, '#7e95bd');
          P(wx + 5, cyt + 16, 2, 8, '#3a2c16');
          luzes.push({ x: wx + 6, y: cyt + 20 });
        }
        // torres de canto com telhado cônico
        for (const txx of [cx - 84, cx + 52]) {
          P(txx, 22, 32, 42, '#b8bac2');
          P(txx, 22, 5, 42, '#84868f');
          P(txx + 27, 22, 5, 42, '#d0d1d7');
          x.fillStyle = '#8e9099';
          for (let ry = 8; ry < 40; ry += 8) x.fillRect(txx + (ry % 16 === 8 ? 5 : 13), 22 + ry, 9, 2);
          x.fillStyle = '#4d5a88';
          x.beginPath(); x.moveTo(txx - 6, 24); x.lineTo(txx + 16, 2); x.lineTo(txx + 38, 24); x.fill();
          x.fillStyle = '#6b7bb4';
          x.beginPath(); x.moveTo(txx + 16, 2); x.lineTo(txx + 38, 24); x.lineTo(txx + 22, 24); x.fill();
          P(txx + 10, 36, 12, 12, '#3a2c16');
          P(txx + 12, 38, 8, 8, '#5a749e'); P(txx + 12, 38, 8, 3, '#7e95bd');
          luzes.push({ x: txx + 16, y: 42 });
        }
        // estandarte real tremulando
        P(cx - 2, cyt - 16, 3, 18, '#5d4a30');
        const ond = Math.sin(anim * 0.09) * 4;
        x.fillStyle = '#e8c84a';
        x.beginPath(); x.moveTo(cx + 1, cyt - 16); x.lineTo(cx + 22 + ond, cyt - 11); x.lineTo(cx + 1, cyt - 5); x.fill();
        x.fillStyle = '#c9403a'; x.fillRect(cx + 4, cyt - 13, 5, 5);
      });
    }

    // ---------- moinho, poço, estábulo, barracas, props ----------
    if (nivel >= 2) {
      add(150, (x) => {  // moinho
        const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
        P(30, 146, 52, 5, SOMBRA);
        P(38, 92, 36, 56, '#b8bac2');
        P(38, 92, 6, 56, '#84868f'); P(68, 92, 6, 56, '#d0d1d7');
        x.fillStyle = '#8e9099';
        for (let ry = 8; ry < 52; ry += 8) x.fillRect(44 + (ry % 16 === 8 ? 0 : 8), 92 + ry, 9, 2);
        x.fillStyle = '#8a5a2e';
        x.beginPath(); x.moveTo(34, 94); x.lineTo(56, 78); x.lineTo(78, 94); x.fill();
        P(50, 128, 14, 20, '#4a3018'); P(52, 130, 10, 18, '#66421f');
        P(52, 104, 10, 10, '#3a2c16'); P(54, 106, 6, 6, '#5a749e');
        luzes.push({ x: 57, y: 109 });
        x.save(); x.translate(56, 88); x.rotate(anim * 0.015);
        for (let i = 0; i < 4; i++) {
          x.rotate(Math.PI / 2);
          x.fillStyle = '#ead9b0'; x.fillRect(-3, 5, 6, 34);
          x.fillStyle = '#c4a878';
          for (let j = 8; j < 36; j += 6) x.fillRect(-3, j, 6, 2);
        }
        x.restore();
        P(52, 84, 8, 8, '#5f3d22');
      });
      add(232, (x) => poco(x, 352, 232));
      add(230, (x) => { barril(x, 250, 226); barril(x, 261, 229); });
    }
    if (nivel >= 3) {
      barracaSprite(add, 232, 176, '#c9403a', 'frutas');
      barracaSprite(add, 408, 176, '#3c6ac4', 'tecidos');
      add(180, (x) => caixa(x, 384, 172));
    }
    if (nivel >= 4) {
      barracaSprite(add, 232, 248, '#e0a63c', 'paes');
      barracaSprite(add, 408, 248, '#4a9a4a', 'liso');
      add(276, (x) => estabulo(x, 500, 276));
      add(252, (x) => caixa(x, 456, 246));
    }

    // ---------- casas por nível ----------
    if (nivel === 0) {
      add(190, (x) => tenda(x, 240, 190)); add(214, (x) => tenda(x, 380, 214)); add(258, (x) => tenda(x, 300, 258));
      add(228, (x) => fogueira(x, 320, 224));
    }
    if (nivel < 0) {
      add(180, (x) => tenda(x, 250, 180)); add(210, (x) => tenda(x, 390, 210)); add(250, (x) => tenda(x, 290, 250));
      add(222, (x) => fogueira(x, 330, 218));
      add(244, (x) => carroca(x, 430, 240));
      add(200, (x) => estandarte(x, 218, 200));
    }
    if (nivel >= 1) {
      casa(112, 200, 4, 'palha', false, true);
      casa(464, 200, 4, 'palha', false, false);
      casa(176, 288, 4, 'palha', false, false);
    }
    if (nivel >= 2) casa(432, 288, 4, 'palha', false, true);
    if (nivel >= 3) {
      casa(112, 200, 4, 'ardosia', true, true);
      casa(464, 200, 4, 'ardosia', true, false);
    }
    if (nivel >= 4) casa(96, 140, 4, 'ardosia', true, false);

    // ---------- vegetação ----------
    const arvores = [[28, 130, 'copa'], [612, 140, 'pinheiro'], [50, 350, 'copa'], [600, 344, 'copa'],
                     [180, 122, 'pinheiro'], [560, 116, 'copa']];
    for (const [ax, ay, tipo] of arvores) {
      if (nivel >= 4 && ax === 560) continue;
      if (dentroDoRio(ax, ay)) continue;
      arvore(ax, ay, tipo);
    }
    for (let i = 0; i < 7; i++) {
      const bx = 30 + sr(i * 61) * 580, by = 110 + sr(i * 67) * 230;
      if (dentroDoRio(bx, by) || (bx > RUA_X0 - 20 && bx < RUA_X1 + 20)) continue;
      arbusto(bx, by);
    }

    // guardas do portão (elementos interativos → contorno)
    if (nivel >= 3) {
      add(100, (x) => guarda(x, 284, 100));
      add(100, (x) => guarda(x, 348, 100));
    }
  }

  let PALATUAL = PAL.verao;

  // ---------- props ----------
  function barracaSprite(add, bx, by, cor, tipo) {
    add(by, (x) => {
      const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
      P(bx - 18, by - 3, 40, 5, SOMBRA);
      P(bx - 16, by - 20, 3, 20, '#6b4423'); P(bx + 13, by - 20, 3, 20, '#6b4423');
      P(bx - 14, by - 12, 28, 9, '#a3703c');
      P(bx - 14, by - 12, 28, 2, '#c48c4e');
      if (tipo === 'frutas') {
        P(bx - 11, by - 16, 4, 4, '#e04a3a'); P(bx - 5, by - 16, 4, 4, '#e8742e'); P(bx + 1, by - 16, 4, 4, '#e04a3a'); P(bx + 7, by - 16, 4, 4, '#f7d94c');
      } else if (tipo === 'tecidos') {
        P(bx - 11, by - 18, 6, 7, '#c9403a'); P(bx - 3, by - 18, 6, 7, '#3c6ac4'); P(bx + 5, by - 18, 6, 7, '#e8c84a');
      } else if (tipo === 'paes') {
        P(bx - 10, by - 16, 7, 4, '#c48c4e'); P(bx - 1, by - 16, 7, 4, '#c48c4e'); P(bx - 6, by - 19, 7, 4, '#e0aa62');
      }
      // toldo listrado com barra recortada
      for (let i = 0; i < 36; i += 6) {
        P(bx - 18 + i, by - 30, 6, 9, (i / 6) % 2 ? '#f2ead2' : cor);
        P(bx - 18 + i, by - 21, 6, 2, (i / 6) % 2 ? '#d0c4a4' : 'rgba(32,52,78,.3)');
      }
      P(bx - 18, by - 32, 36, 3, cor);
    });
  }

  function poco(x, px, py) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(px - 12, py - 3, 26, 5, SOMBRA);
    P(px - 10, py - 14, 22, 13, '#9799a3');
    P(px - 10, py - 14, 22, 3, '#c2c3c9');
    x.fillStyle = '#84868f';
    for (let i = -8; i < 10; i += 7) x.fillRect(px + i, py - 8, 4, 2);
    P(px - 6, py - 11, 14, 6, '#1c2733');
    P(px - 9, py - 34, 3, 22, '#6b4423'); P(px + 8, py - 34, 3, 22, '#6b4423');
    x.fillStyle = '#8a3b26';
    x.beginPath(); x.moveTo(px - 13, py - 32); x.lineTo(px + 1, py - 42); x.lineTo(px + 15, py - 32); x.fill();
    x.fillStyle = '#b0562e';
    x.beginPath(); x.moveTo(px + 1, py - 42); x.lineTo(px + 15, py - 32); x.lineTo(px + 4, py - 32); x.fill();
    P(px, py - 28, 2, 8, '#5d4a30');
    P(px - 2, py - 20, 6, 5, '#a3703c');
  }

  function barril(x, bx, by) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 1, by - 2, 12, 3, SOMBRA);
    P(bx, by - 14, 10, 13, '#a3703c');
    P(bx + 7, by - 14, 3, 13, '#c48c4e');
    P(bx, by - 14, 2, 13, '#6b4423');
    P(bx, by - 12, 10, 2, '#4d3a26'); P(bx, by - 5, 10, 2, '#4d3a26');
  }

  function caixa(x, bx, by) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 1, by - 2, 13, 3, SOMBRA);
    P(bx, by - 12, 11, 11, '#c48c4e');
    P(bx, by - 12, 11, 2, '#e0aa62'); P(bx, by - 12, 2, 11, '#a3703c');
    P(bx, by - 7, 11, 2, '#a3703c'); P(bx + 5, by - 12, 2, 11, '#a3703c');
  }

  function tenda(x, tx, ty) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(tx - 20, ty - 3, 42, 5, SOMBRA);
    x.fillStyle = '#b08d5c';
    x.beginPath(); x.moveTo(tx - 18, ty); x.lineTo(tx, ty - 28); x.lineTo(tx + 18, ty); x.fill();
    x.fillStyle = '#8a6b42';
    x.beginPath(); x.moveTo(tx - 18, ty); x.lineTo(tx, ty - 28); x.lineTo(tx, ty); x.fill();
    P(tx - 1, ty - 32, 2, 6, '#5f3d22');
    P(tx - 5, ty - 12, 10, 12, '#4a3018');
  }

  function fogueira(x, fx, fy) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(fx - 8, fy - 2, 18, 4, SOMBRA);
    P(fx - 7, fy - 4, 6, 3, '#6b4423'); P(fx + 2, fy - 4, 6, 3, '#8a5a2e');
    const fl = Math.sin(anim * 0.3) * 2;
    P(fx - 3, fy - 10 + fl * 0.3, 7, 7, '#e8742e');
    P(fx - 1, fy - 13 + fl * 0.5, 4, 6, '#f7a63c');
    P(fx, fy - 15 + fl * 0.7, 2, 3, '#fbe37a');
  }

  function carroca(x, cx, cy) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(cx - 2, cy - 2, 36, 4, SOMBRA);
    P(cx, cy - 14, 32, 12, '#8a5a2e');
    P(cx + 1, cy - 16, 30, 4, '#a3703c');
    P(cx + 28, cy - 14, 4, 12, '#a3703c');
    for (const rx of [cx + 4, cx + 22]) {
      P(rx, cy - 4, 9, 9, CONTORNO);
      P(rx + 1, cy - 3, 7, 7, '#4d3a26');
      P(rx + 4, cy - 3, 1, 7, '#8a6b42'); P(rx + 1, cy, 7, 1, '#8a6b42');
    }
  }

  function estandarte(x, ex, ey) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(ex, ey - 40, 3, 40, '#5d4a30');
    const ond = Math.sin(anim * 0.1) * 3;
    x.fillStyle = '#8a3b26';
    x.beginPath(); x.moveTo(ex + 3, ey - 40); x.lineTo(ex + 20 + ond, ey - 35); x.lineTo(ex + 3, ey - 28); x.fill();
  }

  function estabulo(x, ex, ey) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(ex - 34, ey - 3, 72, 6, SOMBRA);
    P(ex - 32, ey - 26, 64, 26, '#8a5a2e');
    for (let i = 4; i < 64; i += 8) P(ex - 32 + i, ey - 26, 2, 26, '#6b4423');
    P(ex - 32, ey - 4, 64, 4, '#5f3d22');
    x.fillStyle = '#a3703c';
    x.beginPath(); x.moveTo(ex - 38, ey - 24); x.lineTo(ex, ey - 40); x.lineTo(ex + 38, ey - 24); x.fill();
    x.fillStyle = '#c48c4e';
    x.beginPath(); x.moveTo(ex, ey - 40); x.lineTo(ex + 38, ey - 24); x.lineTo(ex + 8, ey - 24); x.fill();
    P(ex - 26, ey - 22, 24, 22, '#3a2c16');
    P(ex - 24, ey - 6, 14, 6, '#e0c05c');
    cavaloSprite(x, ex - 18, ey - 8);
    cavaloSprite(x, ex + 12, ey - 4);
  }

  // cavalo: ELEMENTO INTERATIVO → contorno escuro
  function cavaloSprite(x, cx, cy) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(cx - 1, cy - 9, 20, 12, CONTORNO);
    P(cx + 15, cy - 13, 8, 8, CONTORNO);
    P(cx, cy - 8, 18, 8, '#8a5a3a');
    P(cx + 16, cy - 12, 6, 6, '#8a5a3a');
    P(cx + 20, cy - 8, 3, 3, '#6b4028');
    P(cx + 14, cy - 14, 5, 3, '#3a2416');
    P(cx, cy - 8, 18, 2, '#a3703c');
    P(cx + 1, cy, 3, 4, '#6b4028'); P(cx + 13, cy, 3, 4, '#6b4028');
    P(cx + 1, cy + 3, 3, 1, CONTORNO); P(cx + 13, cy + 3, 3, 1, CONTORNO);
    P(cx - 3, cy - 8, 3, 7, '#3a2416');
  }

  // guarda: mesmas proporções do aldeão (16×32), armadura + lança
  function guarda(x, gx, gy) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    x.fillStyle = SOMBRA;
    x.beginPath(); x.ellipse(gx + 6, gy + 1, 7, 3, 0, 0, 7); x.fill();
    P(gx - 1, gy - 29, 14, 30, CONTORNO);
    // elmo + rosto
    P(gx, gy - 28, 12, 5, '#c2c3c9');
    P(gx, gy - 24, 2, 3, '#c2c3c9'); P(gx + 10, gy - 24, 2, 3, '#c2c3c9');
    P(gx + 2, gy - 24, 8, 5, '#e8c090');
    P(gx + 3, gy - 23, 2, 2, CONTORNO); P(gx + 7, gy - 23, 2, 2, CONTORNO);
    // couraça
    P(gx, gy - 19, 12, 11, '#9799a3');
    P(gx, gy - 19, 3, 11, '#63667a');
    P(gx + 10, gy - 19, 2, 11, '#c2c3c9');
    P(gx + 2, gy - 15, 8, 2, '#c9403a');    // tabardo
    // pernas
    P(gx + 1, gy - 8, 4, 8, '#4a5566'); P(gx + 7, gy - 8, 4, 8, '#63667a');
    P(gx + 1, gy - 1, 4, 2, '#3a2416'); P(gx + 7, gy - 1, 4, 2, '#3a2416');
    // lança
    P(gx + 13, gy - 38, 2, 38, '#6b4423');
    P(gx + 12, gy - 43, 4, 6, '#c2c3c9');
  }

  // aldeão 16×32 com CONTORNO (elemento interativo)
  function aldeao(ctx, n) {
    const P = (a, b, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    const px = n.x, py = n.y;
    const passo = n.pausa > 0 ? 0 : Math.floor(anim / 9 + px) % 2;
    ctx.fillStyle = SOMBRA;
    ctx.beginPath(); ctx.ellipse(px + 6, py + 1, 7, 3, 0, 0, 7); ctx.fill();
    // silhueta de contorno
    P(px - 1, py - 29, 14, 30, CONTORNO);
    // cabeça + cabelo
    P(px + 1, py - 28, 10, 9, '#e8c090');
    P(px, py - 29, 12, 4, n.cabelo);
    P(px, py - 26, 2, 4, n.cabelo); P(px + 10, py - 26, 2, 4, n.cabelo);
    if (n.fem) { P(px, py - 22, 2, 6, n.cabelo); P(px + 10, py - 22, 2, 6, n.cabelo); }
    P(px + 3, py - 24, 2, 2, CONTORNO); P(px + 7, py - 24, 2, 2, CONTORNO);
    // túnica
    P(px, py - 19, 12, 11, n.roupa);
    P(px, py - 19, 3, 11, sombraDe(n.roupa));
    P(px + 10, py - 19, 2, 11, claraDe(n.roupa));
    P(px, py - 10, 12, 2, sombraDe(n.roupa));
    // pernas (2 quadros de caminhada)
    P(px + 1 + passo * 2, py - 8, 4, 8, n.calca);
    P(px + 7 - passo * 2, py - 8, 4, 8, sombraDe(n.calca));
    P(px + 1 + passo * 2, py - 1, 4, 2, '#3a2416');
    P(px + 7 - passo * 2, py - 1, 4, 2, '#3a2416');
  }
  function sombraDe(hex) { const n = parseInt(hex.slice(1), 16); return `rgb(${((n >> 16) & 255) * 0.62 | 0},${((n >> 8) & 255) * 0.66 | 0},${Math.min(255, (n & 255) * 0.85 + 30) | 0})`; }
  function claraDe(hex) { const n = parseInt(hex.slice(1), 16); const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255; return `rgb(${r + (255 - r) * 0.25 | 0},${g + (255 - g) * 0.22 | 0},${b + (255 - b) * 0.12 | 0})`; }

  // galinha com contorno
  function galinha(ctx, g) {
    const P = (a, b, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    const bica = Math.floor(g.t / 40) % 3 === 0;
    P(g.x - 1, g.y + 4, 10, 2, SOMBRA);
    P(g.x - 1, g.y - 7, 10, 12, CONTORNO);
    P(g.x, g.y - 6, 8, 7, '#f6f2e8');
    P(g.x + 6, g.y - 9 + (bica ? 3 : 0), 4, 5, CONTORNO);
    P(g.x + 6, g.y - 8 + (bica ? 3 : 0), 3, 3, '#f6f2e8');
    P(g.x + 9, g.y - 7 + (bica ? 3 : 0), 2, 2, '#e0a63c');
    P(g.x + 7, g.y - 10 + (bica ? 3 : 0), 2, 2, '#e04a3a');
    P(g.x + 1, g.y - 4, 4, 3, '#e8e0d0');
    P(g.x + 1, g.y + 1, 2, 3, '#e0a63c'); P(g.x + 5, g.y + 1, 2, 3, '#e0a63c');
  }

  // ============================================================
  // CAMADAS DINÂMICAS
  // ============================================================
  function aguaViva(ctx, pal) {
    for (let i = 0; i < 22; i++) {
      const px = ((i * 37 + anim * (0.4 + (i % 3) * 0.2)) % (W + 40)) - 20;
      const py = rioTopo(px) + 5 + (i % 5) * 5;
      ctx.fillStyle = pal.agua[2];
      ctx.fillRect(Math.round(px), Math.round(py), 8 + (i % 3) * 5, 2);
    }
    for (let i = 0; i < 7; i++) {
      const px = ((i * 91 + anim * 0.9) % (W + 20)) - 10;
      ctx.fillStyle = pal.agua[3];
      ctx.fillRect(Math.round(px), Math.round(rioTopo(px) + 8 + (i % 3) * 7), 3, 1);
    }
  }

  function fumacas(ctx) {
    for (const ch of chamines) {
      for (let i = 0; i < 5; i++) {
        const t = ((anim * 0.5 + i * 20 + ch.x * 0.7) % 90) / 90;
        const dx = Math.sin((t * 6 + ch.x) * 1.8) * (2 + t * 6);
        const s = 2 + t * 4;
        ctx.fillStyle = `rgba(240,238,232,${0.5 * (1 - t)})`;
        ctx.fillRect(Math.round(ch.x + dx - s / 2), Math.round(ch.y - t * 30 - s / 2), Math.round(s), Math.round(s));
      }
    }
  }

  function cicloAtual() {
    if (cicloForcado !== null) return cicloForcado;
    return (Math.sin(anim * 0.0009) + 1) / 2;
  }

  function clima(ctx, est, ciclo) {
    const chovendo = (est === 'primavera' || est === 'outono') && Math.sin(anim * 0.0004 + 2) > 0.55;
    if (chovendo) {
      ctx.fillStyle = 'rgba(190,210,235,.5)';
      for (let i = 0; i < 90; i++) {
        const px = (sr(i * 3) * (W + 60) + anim * 1.2) % (W + 60) - 30;
        const py = (sr(i * 7) * H + anim * 6.5) % H;
        ctx.fillRect(Math.round(px), Math.round(py), 1, 6);
      }
      ctx.fillStyle = 'rgba(40,55,80,.15)';
      ctx.fillRect(0, 0, W, H);
    }
    if (est === 'inverno') {
      ctx.fillStyle = 'rgba(250,252,255,.85)';
      for (let i = 0; i < 60; i++) {
        const px = (sr(i * 5) * W + Math.sin(anim * 0.01 + i) * 18 + anim * 0.3) % W;
        const py = (sr(i * 9) * H + anim * (0.6 + sr(i) * 0.5)) % H;
        ctx.fillRect(Math.round(px), Math.round(py), 2, 2);
      }
    }
    if (est === 'outono' && !chovendo) {
      for (let i = 0; i < 10; i++) {
        const px = (sr(i * 17) * W + anim * (0.8 + sr(i) * 0.6)) % W;
        const py = (sr(i * 19) * H + anim * (0.5 + sr(i * 3) * 0.4) + Math.sin(anim * 0.03 + i) * 10) % H;
        ctx.fillStyle = ['#ce7a35', '#b0562e', '#e8a844'][i % 3];
        ctx.fillRect(Math.round(px), Math.round(py), 3, 2);
      }
    }
    if (est === 'verao' && ciclo < 0.4) {
      for (let i = 0; i < 12; i++) {
        const px = 60 + sr(i * 23) * 520 + Math.sin(anim * 0.008 + i * 2.1) * 24;
        const py = 110 + sr(i * 29) * 220 + Math.cos(anim * 0.011 + i * 1.7) * 14;
        const pulso = (Math.sin(anim * 0.06 + i * 2.9) + 1) / 2;
        if (pulso > 0.35) {
          const g = ctx.createRadialGradient(px, py, 0, px, py, 7);
          g.addColorStop(0, `rgba(210,255,130,${0.5 * pulso})`);
          g.addColorStop(1, 'rgba(210,255,130,0)');
          ctx.fillStyle = g;
          ctx.fillRect(px - 7, py - 7, 14, 14);
          ctx.fillStyle = `rgba(235,255,170,${0.9 * pulso})`;
          ctx.fillRect(Math.round(px), Math.round(py), 2, 2);
        }
      }
    }
    if (!chovendo) {  // sombras de nuvens passeando pelo chão
      ctx.fillStyle = 'rgba(28,48,40,.08)';
      for (const [vel, faixaY, wN, hN] of [[0.22, 120, 180, 60], [0.15, 260, 140, 48]]) {
        const px = (anim * vel) % (W + 320) - 320;
        ctx.beginPath();
        ctx.ellipse(px + wN / 2, faixaY + hN / 2, wN / 2, hN / 2, 0, 0, 7);
        ctx.fill();
      }
    }
  }

  function ambiente(ctx, ciclo, nivel) {
    const noite = Math.max(0, (0.42 - ciclo) / 0.42);
    const tarde = Math.max(0, 1 - Math.abs(ciclo - 0.48) / 0.14);
    if (tarde > 0) {
      ctx.fillStyle = `rgba(255,120,45,${0.15 * tarde})`;
      ctx.fillRect(0, 0, W, H);
    }
    if (noite > 0) {
      ctx.fillStyle = `rgba(16,24,58,${0.45 * noite})`;
      ctx.fillRect(0, 0, W, H);
      for (const l of luzes) {
        const g = ctx.createRadialGradient(l.x, l.y, 1, l.x, l.y, 8);
        g.addColorStop(0, `rgba(255,190,90,${0.26 * noite})`);
        g.addColorStop(1, 'rgba(255,190,90,0)');
        ctx.fillStyle = g;
        ctx.fillRect(l.x - 8, l.y - 8, 16, 16);
        ctx.fillStyle = `rgba(255,214,110,${0.65 * noite})`;
        ctx.fillRect(l.x - 3, l.y - 2, 7, 5);
      }
      if (nivel >= 3) {
        for (const tx of [RUA_X0 - 19, RUA_X1 + 15]) {
          const g = ctx.createRadialGradient(tx, 56, 2, tx, 56, 30);
          g.addColorStop(0, `rgba(255,170,70,${0.45 * noite})`);
          g.addColorStop(1, 'rgba(255,170,70,0)');
          ctx.fillStyle = g;
          ctx.fillRect(tx - 30, 26, 60, 60);
        }
      }
    }
    const v = ctx.createRadialGradient(W / 2, H / 2, H * 0.55, W / 2, H / 2, H * 0.98);
    v.addColorStop(0, 'rgba(15,12,8,0)');
    v.addColorStop(1, 'rgba(15,12,8,.20)');
    ctx.fillStyle = v;
    ctx.fillRect(0, 0, W, H);
  }

  // ============================================================
  function render(canvas, state) {
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    anim++;
    const nivel = state.terra ? state.terra.nivel : -1;
    const est = estacao(state.mes || 6);
    const pal = PAL[est];
    PALATUAL = pal;
    const chave = nivel + '|' + est;
    if (bgKey !== chave || !bg) {
      bg = desenharTerreno(nivel, pal);
      montarCena(nivel, pal);
      bgKey = chave;
    }
    ctx.drawImage(bg, 0, 0);
    aguaViva(ctx, pal);

    // entidades móveis atualizam
    for (const n of npcs) {
      if (n.pausa > 0) n.pausa--;
      else {
        n.x += n.vx; n.y += n.vy;
        if (Math.random() < 0.005) n.pausa = 50 + Math.random() * 90;
        if (Math.random() < 0.008) { n.vx = (Math.random() - 0.5) * 0.4; n.vy = (Math.random() - 0.5) * 0.3; }
        if (n.x < 30) n.vx = Math.abs(n.vx);
        if (n.x > 596) n.vx = -Math.abs(n.vx);
        if (n.y < 104) n.vy = Math.abs(n.vy);
        if (n.y > 352) n.vy = -Math.abs(n.vy);
        if (dentroDoRio(n.x + 6, n.y) && !naPonte(n.x + 6)) n.vy = n.y > rioTopo(n.x) + RIO_ALT / 2 ? Math.abs(n.vy) + 0.1 : -Math.abs(n.vy) - 0.1;
      }
    }
    for (const g of galinhas) {
      g.t += 1;
      g.x += Math.sin(g.t * 0.02) * 0.15;
    }

    // REGRA DO Y: construções + aldeões + bichos numa única ordenação
    const fila = sprites.slice();
    for (const n of npcs) fila.push({ y: n.y, fn: (c) => aldeao(c, n) });
    for (const g of galinhas) fila.push({ y: g.y + 4, fn: (c) => galinha(c, g) });
    fila.sort((a, b) => a.y - b.y);
    for (const s of fila) s.fn(ctx);

    fumacas(ctx);
    const ciclo = cicloAtual();
    clima(ctx, est, ciclo);
    ambiente(ctx, ciclo, nivel);
  }

  function renderShowcase(canvas) {
    if (!npcs.length) seedNpcs(5);
    render(canvas, { terra: { nivel: 5 }, mes: 6 });
  }

  function forcarCiclo(v) { cicloForcado = v; }

  return { render, renderShowcase, seedNpcs, forcarCiclo };
})();
