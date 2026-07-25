// ============================================================
// PIXEL ART DO ASSENTAMENTO — v3 "Stardew"
// Regras desta versão (crítica do design):
//  1. GRADE ÚNICA: 640×360, tudo em pixels inteiros, sem mixels.
//  2. LUZ DIRECIONAL: sol na direita-superior → faces direitas
//     iluminadas, faces esquerdas em sombra, sombras projetadas
//     no chão para a esquerda-inferior.
//  3. HUE-SHIFTING: sombras puxam para azul-esverdeado, luzes
//     para amarelo — nunca "preto sujo".
//  4. TEXTURA: tufos de grama, pedrinhas, trilhas de terra,
//     tijolos, musgo, palha riscada, água com reflexo.
//  5. RIO ORGÂNICO com margens escuras.
//  6. ESCALA: aldeões 8×14 compatíveis com portas de 10×14.
// Desempenho: cenário estático vai para um canvas-cache; só o
// que se move (água, fumaça, bandeiras, moinho, NPCs) redesenha.
// ============================================================
'use strict';

const Cidade = (() => {
  const W = 640, H = 360;
  let anim = 0;
  let npcs = [], galinhas = [];
  let bg = null, bgKey = '';
  let luzes = [];          // posições das janelas (brilham à noite)
  let cicloForcado = null; // para testes: Cidade.forcarCiclo(v)

  // ---------- estruturas do tileset (img/estruturas/*.png) ----------
  // Quando carregadas, substituem casas/poço/props procedurais.
  const EST = {};
  const EST_LISTA = ['casa_1', 'casa_2', 'casa_3', 'casa_4', 'poco', 'arco', 'poste', 'feno', 'caixa', 'barril', 'placa', 'mural', 'banco',
    'arvore_1', 'arvore_2', 'arvore_3', 'arvore_4', 'arbusto_1', 'arbusto_2', 'arbusto_3',
    'grama_a', 'grama_b', 'grama_c', 'estrada_a', 'estrada_b', 'estrada_c', 'fogueira', 'pedra_1', 'pedra_2', 'pedra_3'];
  function estImg(nome) {
    if (!EST[nome]) { const im = new Image(); im.src = 'img/estruturas/' + nome + '.png'; EST[nome] = im; }
    return EST[nome];
  }
  function estPronta(nome) { const im = estImg(nome); return (im.complete && im.naturalWidth) ? im : null; }
  function estOk() { return EST_LISTA.every(n => estPronta(n)); }
  // desenha bottom-anchored com largura alvo, preservando proporção
  function estDesenha(x, nome, cx, baseY, larg) {
    const im = estPronta(nome);
    if (!im) return false;
    const alt = Math.round(larg * im.naturalHeight / im.naturalWidth);
    x.imageSmoothingEnabled = false;
    x.drawImage(im, Math.round(cx - larg / 2), Math.round(baseY - alt), Math.round(larg), alt);
    return true;
  }

  // ---------- paletas com hue-shifting ----------
  const RAMPAS = {
    primavera: {
      ceu: ['#79b7e6', '#a8d2ea', '#d8ecdf'], sol: ['#fff8d8', '#ffe98f'],
      grama: ['#3c6b52', '#579050', '#74a94c', '#9cc45e'],
      arvore: ['#2e5b45', '#3f7a4a', '#5b9a50', '#8bbf62'],
      campo: ['#5d4a30', '#77603c', '#8fba55'],
      montanha: ['#5e6b85', '#7c88a0', '#a3adc0'], neve: false, tiles: true,
    },
    verao: {
      ceu: ['#6fb0e0', '#a5cfe0', '#ead9a8'], sol: ['#fff6c8', '#ffdf78'],
      grama: ['#41684a', '#5f8c48', '#7fa746', '#a8c258'],
      arvore: ['#31593f', '#457546', '#63954a', '#93b85c'],
      campo: ['#5d4a30', '#77603c', '#d0af52'],
      montanha: ['#606d86', '#7e8aa2', '#a5afc2'], neve: false, tiles: true,
    },
    outono: {
      ceu: ['#8998b5', '#b3b3c0', '#e3cfa5'], sol: ['#fdf2c8', '#f5cf78'],
      grama: ['#575a3a', '#6f7440', '#8d8a48', '#aca258'],
      arvore: ['#6b3a26', '#95542c', '#bd7a35', '#d9a44a'],
      campo: ['#4f3e28', '#655034', '#8a7440'],
      montanha: ['#5c6880', '#7a869e', '#a1abbe'], neve: false,
    },
    inverno: {
      ceu: ['#9fb2c4', '#c3d0da', '#eef3f6'], sol: ['#fdfbe8', '#f2ead0'],
      grama: ['#a8b8c2', '#c4d1d9', '#dde7ec', '#f4f8fa'],
      arvore: ['#4a4a45', '#5d5a50', '#6f6b5e', '#e8eff3'],
      campo: ['#8a94a0', '#aab4be', '#ccd6dd'],
      montanha: ['#6b7890', '#8b97ac', '#c8d2de'], neve: true,
    },
  };
  const SOMBRA = 'rgba(38,54,74,.30)';   // sombra projetada (azulada, nunca preta)
  const SOMBRA_FORTE = 'rgba(38,54,74,.42)';

  function estacao(mes) {
    if (mes >= 3 && mes <= 5) return 'primavera';
    if (mes >= 6 && mes <= 8) return 'verao';
    if (mes >= 9 && mes <= 11) return 'outono';
    return 'inverno';
  }
  function sr(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }

  function seedNpcs(nivel) {
    npcs = []; galinhas = [];
    const n = nivel >= 5 ? 14 : nivel >= 3 ? 10 : nivel >= 1 ? 5 : nivel >= 0 ? 3 : 4;
    const cores = ['#a04038', '#3c5a8a', '#c9a227', '#4a7a4a', '#7d4a8c', '#8a5a3a', '#557a8a', '#a06a30'];
    for (let i = 0; i < n; i++) {
      npcs.push({
        x: 90 + sr(i * 3 + 1) * 440, y: 250 + sr(i * 7 + 2) * 70,
        vx: (sr(i * 11 + 3) - 0.5) * 0.5, pausa: 0,
        roupa: cores[i % cores.length], capuz: sr(i * 13 + 5) < 0.3,
        cabelo: ['#3a2a1a', '#6b4a2d', '#c9a227', '#8a8078'][i % 4],
      });
    }
    if (nivel >= 1) for (let i = 0; i < 4; i++) {
      galinhas.push({ x: 60 + sr(i * 17) * 120, y: 268 + sr(i * 19) * 30, t: sr(i * 23) * 100 });
    }
  }

  // ============================================================
  // CENÁRIO ESTÁTICO (desenhado uma vez por nível+estação)
  // ============================================================
  function desenharEstatico(nivel, pal) {
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const x = cv.getContext('2d');
    luzes = [];  // recoleta as janelas desta cena (para o brilho noturno)
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };

    // ---------- céu em degradê suave (interpolação entre as 3 cores) ----------
    const lerpCor = (a, b, t) => {
      const ca = parseInt(a.slice(1), 16), cb = parseInt(b.slice(1), 16);
      const r = Math.round(((ca >> 16) & 255) + (((cb >> 16) & 255) - ((ca >> 16) & 255)) * t);
      const g = Math.round(((ca >> 8) & 255) + (((cb >> 8) & 255) - ((ca >> 8) & 255)) * t);
      const bl = Math.round((ca & 255) + ((cb & 255) - (ca & 255)) * t);
      return `rgb(${r},${g},${bl})`;
    };
    for (let y = 0; y < 200; y += 4) {
      const t = y / 200;
      const cor = t < 0.5 ? lerpCor(pal.ceu[0], pal.ceu[1], t * 2) : lerpCor(pal.ceu[1], pal.ceu[2], (t - 0.5) * 2);
      P(0, y, W, 4, cor);
    }
    // (o sol agora é DINÂMICO: cruza o céu no ciclo dia/noite — ver astro())

    // ---------- montanhas: silhuetas limpas, encosta direita iluminada ----------
    const serra = (base, amp, freq, fase, cor, corLuz) => {
      for (let mx = 0; mx < W; mx += 2) {
        const ym = base + Math.sin(mx * freq + fase) * amp + Math.sin(mx * freq * 2.7) * amp * 0.3;
        P(mx, ym, 2, 205 - ym, cor);
      }
      // luz contínua na encosta voltada para o sol (derivada descendo à direita)
      for (let mx = 0; mx < W; mx += 2) {
        const ym = base + Math.sin(mx * freq + fase) * amp + Math.sin(mx * freq * 2.7) * amp * 0.3;
        const ym2 = base + Math.sin((mx + 2) * freq + fase) * amp + Math.sin((mx + 2) * freq * 2.7) * amp * 0.3;
        if (ym2 > ym) P(mx, ym, 2, 3, corLuz);
      }
    };
    serra(150, 26, 0.012, 1.2, pal.montanha[0], pal.montanha[1]);
    // textura de rocha: salpicos e linhas de cume na cadeia distante
    for (let i = 0; i < 120; i++) {
      const mx = sr(i * 13) * W;
      const topo = 150 + Math.sin(mx * 0.012 + 1.2) * 26 + Math.sin(mx * 0.0324) * 7.8;
      const my = topo + 4 + sr(i * 17) * (200 - topo) * 0.5;
      P(mx, my, 2, 1 + (i % 2), i % 3 ? 'rgba(30,40,60,.18)' : 'rgba(230,238,248,.14)');
    }
    // picos nevados
    x.fillStyle = '#eef3f8';
    for (const px of [90, 250, 420, 590]) {
      const py = 150 + Math.sin(px * 0.012 + 1.2) * 26 + Math.sin(px * 0.0324) * 7.8;
      x.beginPath(); x.moveTo(px - 9, py + 7); x.lineTo(px, py - 2); x.lineTo(px + 9, py + 7); x.fill();
      x.fillStyle = 'rgba(200,212,228,.6)';
      x.fillRect(px - 2, py + 5, 6, 2); x.fillRect(px + 3, py + 8, 5, 2);
      x.fillStyle = '#eef3f8';
    }
    // perspectiva atmosférica: névoa da cor do céu "empurra" a serra para longe
    const neblina = x.createLinearGradient(0, 145, 0, 205);
    neblina.addColorStop(0, 'rgba(190,215,232,.42)');
    neblina.addColorStop(1, 'rgba(190,215,232,.10)');
    x.fillStyle = neblina;
    x.fillRect(0, 145, W, 60);
    serra(176, 14, 0.017, 4.1, pal.montanha[1], pal.montanha[2]);
    for (let i = 0; i < 60; i++) {
      const mx = sr(i * 23) * W;
      const topo = 176 + Math.sin(mx * 0.017 + 4.1) * 14 + Math.sin(mx * 0.0459) * 4.2;
      P(mx, topo + 3 + sr(i * 29) * 14, 2, 1, 'rgba(30,40,60,.14)');
    }
    x.fillStyle = 'rgba(190,215,232,.16)';
    x.fillRect(0, 168, W, 37);

    // ---------- linha de floresta ----------
    for (let i = 0; i < 54; i++) {
      const fx = i * 12 + sr(i) * 8, fy = 188 + sr(i * 3) * 10;
      const c = i % 2 ? pal.arvore[1] : pal.arvore[0];
      x.fillStyle = c;
      x.beginPath(); x.moveTo(fx - 5, fy + 4); x.lineTo(fx, fy - 12 - sr(i * 7) * 5); x.lineTo(fx + 5, fy + 4); x.fill();
      x.fillStyle = pal.neve ? '#e8eff3' : pal.arvore[2];
      x.beginPath(); x.moveTo(fx + 1, fy - 9); x.lineTo(fx + 4, fy + 2); x.lineTo(fx, fy + 2); x.fill();
    }

    // ---------- gramado com rampa de profundidade ----------
    P(0, 200, W, 160, pal.grama[2]);
    P(0, 200, W, 26, pal.grama[3]);                      // horizonte amarelado (luz)
    P(0, 300, W, 60, pal.grama[1]);                      // primeiro plano mais frio
    // dithering entre as faixas
    for (let dx = 0; dx < W; dx += 6) {
      P(dx + (dx % 12 ? 0 : 3), 224, 3, 3, pal.grama[3]);
      P(dx + (dx % 12 ? 3 : 0), 298, 3, 3, pal.grama[2]);
    }
    // manchas orgânicas do tileset (decalques suaves, só nas estações verdes)
    if (pal.tiles) {
      const decalques = ['grama_a', 'grama_b', 'grama_c'].map(estPronta);
      if (decalques.every(Boolean)) {
        x.imageSmoothingEnabled = false;
        for (let i = 0; i < 16; i++) {
          const gx = sr(i * 71) * (W - 24), gy = 214 + sr(i * 73) * 130;
          const im = decalques[i % 3];
          x.globalAlpha = 0.22 + sr(i * 79) * 0.12;
          const tam = 18 + sr(i * 83) * 16;
          x.drawImage(im, Math.round(gx), Math.round(gy), Math.round(tam), Math.round(tam));
          x.globalAlpha = 1;
        }
      }
    }
    // tufos de grama (3 tons), pedrinhas e flores
    for (let i = 0; i < 240; i++) {
      const gx = sr(i * 5) * W, gy = 206 + sr(i * 5 + 1) * 148;
      const tom = pal.grama[gy > 300 ? 0 : (i % 2 ? 1 : 3)];
      P(gx, gy, 2, 2, tom);
      if (i % 3 === 0) { P(gx, gy - 2, 1, 2, tom); P(gx + 2, gy - 1, 1, 2, tom); }
    }
    for (let i = 0; i < 26; i++) {
      const gx = sr(i * 31) * W, gy = 220 + sr(i * 37) * 130;
      P(gx, gy, 4, 3, pal.montanha[1]); P(gx, gy, 4, 1, pal.montanha[2]);
    }
    if (!pal.neve) for (let i = 0; i < 22; i++) {
      const gx = sr(i * 41) * W, gy = 214 + sr(i * 43) * 130;
      P(gx, gy, 2, 2, ['#e8e0f0', '#f5d060', '#e88fa8'][i % 3]);
    }

    // ---------- rio ORGÂNICO com margens escuras ----------
    const margemRio = (rx) => 306 + Math.sin(rx * 0.017) * 6 + Math.sin(rx * 0.007 + 3) * 4;
    for (let rx = 0; rx < W; rx += 2) {
      const topo = margemRio(rx);
      const fundo = topo + 24 + Math.sin(rx * 0.013 + 1) * 3;
      P(rx, topo - 2, 2, 2, pal.grama[0]);               // margem sombreada
      P(rx, topo, 2, fundo - topo, pal.neve ? '#a9c0d2' : '#2e5a78');
      P(rx, topo, 2, 3, pal.neve ? '#cdddea' : '#6fa3c0'); // reflexo do céu na borda
      P(rx, fundo, 2, 2, pal.neve ? '#8fa8ba' : '#244a63'); // fundo escuro
      P(rx, fundo + 2, 2, 2, pal.grama[0]);
    }
    // reflexos verticais dos objetos próximos na água (borrados)
    if (!pal.neve) {
      x.fillStyle = 'rgba(20,38,54,.25)';
      for (const [rx, rw] of [[300, 44], [150, 30], [508, 34]]) {
        for (let i = 0; i < rw; i += 4) {
          const alt = 8 + sr(rx + i) * 8;
          x.fillRect(rx + i, margemRio(rx + i) + 3, 3, alt);
        }
      }
      // espuma clara junto às margens
      x.fillStyle = 'rgba(220,238,248,.35)';
      for (let rx = 0; rx < W; rx += 9) x.fillRect(rx + (rx % 18 ? 3 : 0), margemRio(rx) + 1, 4, 1);
    }

    // ---------- estrada de terra com cascalho (textura do tileset quando carregada) ----------
    const rua = (x0, y0, x1, y1, larg) => {
      const passos = Math.max(1, Math.floor((y1 - y0) / 2));
      for (let i = 0; i <= passos; i++) {
        const t = i / passos;
        const cx = x0 + (x1 - x0) * t + Math.sin(t * 5) * 3;
        const cy = y0 + (y1 - y0) * t;
        const l = larg * (0.72 + t * 0.28);
        P(cx - l / 2, cy, l, 2.2, '#8a6a42');
        P(cx - l / 2, cy, 2, 2.2, '#6b5334');             // borda esquerda sombreada
        P(cx + l / 2 - 2, cy, 2, 2.2, '#a58a5c');         // borda direita na luz
      }
      // carimbos de cascalho do tileset por cima do leito
      const pedras = ['estrada_a', 'estrada_b', 'estrada_c'].map(estPronta);
      if (pedras.every(Boolean) && larg >= 20) {
        x.imageSmoothingEnabled = false;
        x.globalAlpha = 0.8;
        for (let i = 0; i <= passos; i += 6) {
          const t = i / passos;
          const cx = x0 + (x1 - x0) * t + Math.sin(t * 5) * 3;
          const cy = y0 + (y1 - y0) * t;
          const l = larg * (0.72 + t * 0.28) - 4;
          for (let sx = -l / 2; sx < l / 2 - 6; sx += 12) {
            const im = pedras[Math.floor(sr(i * 11 + sx) * 3)];
            x.drawImage(im, Math.round(cx + sx), Math.round(cy), 12, 12);
          }
        }
        x.globalAlpha = 1;
      }
      for (let i = 0; i < passos; i += 2) {
        const t = i / passos;
        P(x0 + (x1 - x0) * t + (sr(i * 7) - 0.5) * larg * 0.5, y0 + (y1 - y0) * t, 2, 1, '#a58a5c');
      }
    };
    const yMuralha = 236;
    rua(320, nivel >= 1 ? yMuralha + 18 : 212, 316, 302, 30);
    rua(316, 318, 320, 360, 40);
    // trilhas de terra ligando as casas à estrada
    if (nivel >= 1) { rua(200, 262, 300, 286, 8); rua(440, 268, 340, 290, 8); }

    // ---------- ponte de madeira ----------
    const yPonte = margemRio(320) - 4;
    P(288, yPonte, 62, 8, '#8a6b45');
    P(288, yPonte, 62, 2, '#a58a5c');
    for (let i = 0; i < 8; i++) P(290 + i * 8, yPonte + 2, 2, 6, '#5d4428');
    P(288, yPonte + 8, 62, 3, '#4a3a26');
    for (const px of [290, 344]) { P(px, yPonte - 8, 3, 9, '#6b4f30'); P(px, yPonte - 8, 3, 2, '#8a6b45'); }
    P(290, yPonte - 7, 57, 2, '#6b4f30');

    // ---------- campos de cultivo ----------
    if (nivel >= 1) {
      // a cidade cresce sobre a lavoura: no nível 4+ o campo da direita vira casa
      const campos = nivel >= 4 ? [[28, 244, 66, 26]] : [[28, 244, 66, 26], [548, 240, 66, 26]];
      for (const [cx, cy, cw, ch] of campos) {
        P(cx + 3, cy + ch, cw, 4, SOMBRA);
        P(cx, cy, cw, ch, pal.campo[0]);
        for (let ry = 2; ry < ch - 1; ry += 4) {
          P(cx + 1, cy + ry, cw - 2, 2, pal.campo[1]);
          if (!pal.neve) for (let rx = 3 + (ry % 8 ? 2 : 0); rx < cw - 3; rx += 6)
            P(cx + rx, cy + ry - 1, 2, 2, pal.campo[2]);
        }
        for (let i = 0; i <= cw; i += 10) { P(cx + i - 1, cy - 5, 2, 6, '#5d4428'); P(cx + i - 1, cy - 5, 2, 1, '#8a6b45'); }
        P(cx - 1, cy - 3, cw + 2, 1, '#6b4f30');
      }
    }

    // ---------- castelo (ao fundo, ANTES do muro para não cobrir as torres) ----------
    if (nivel >= 5) castelo(x, 160, pal);

    // ---------- muralhas ----------
    if (nivel === 1 || nivel === 2) paliçada(x, yMuralha, pal);
    if (nivel >= 3) muroPedra(x, yMuralha, nivel >= 4, pal);

    // ---------- construções ----------
    if (nivel < 0) { acampamento(x, pal); return cv; }
    if (nivel === 0) {
      tenda(x, 150, 236, '#b0925f'); tenda(x, 420, 250, '#a08a5c'); tenda(x, 210, 274, '#93765a');
    }
    if (nivel >= 1) {
      casa(x, 130, 250, 52, 30, false, true, pal);
      casa(x, 430, 258, 48, 28, false, false, pal);
      casa(x, 196, 284, 46, 26, false, false, pal);
    }
    if (nivel >= 1) {
      // entrada da vila: arco de pedra sobre a estrada + placa
      if (nivel < 3) estDesenha(x, 'arco', 320, 300, 58);
      estDesenha(x, 'placa', 282, 300, 14);
    }
    if (nivel >= 2) {
      moinhoCorpo(x, 52, 208, pal);
      casa(x, 500, 276, 48, 27, false, true, pal);
      poco(x, 352, 268);
      barril(x, 118, 272); barril(x, 128, 274);
      estDesenha(x, 'banco', 372, 284, 20);
      estDesenha(x, 'feno', 96, 300, 22);
      estDesenha(x, 'poste', 288, 268, 18); estDesenha(x, 'poste', 352, 246, 18);
    }
    if (nivel >= 3) {
      casa(x, 130, 250, 52, 30, true, true, pal);
      casa(x, 430, 258, 48, 28, true, false, pal);
      barraca(x, 246, 262, '#a04038', 'frutas'); barraca(x, 380, 258, '#3c5a8a', 'tecidos');
      caixa(x, 278, 270); caixa(x, 372, 270); barril(x, 486, 268);
      estDesenha(x, 'mural', 262, 300, 22);
    }
    if (nivel >= 4) {
      casa(x, 66, 286, 46, 26, true, false, pal);
      // solar rural à direita (tileset) — sem a imagem, fica a estrebaria procedural
      if (!estDesenha(x, 'casa_3', 560, 300, 92)) estabulo(x, 524, 244, pal);
      barraca(x, 210, 284, '#b8862d', 'paes'); barraca(x, 412, 282, '#3e5f3e', 'liso');
      caixa(x, 244, 292); barril(x, 444, 288); caixa(x, 500, 284);
    }

    // ---------- vegetação: árvores variadas + arbustos ----------
    arvore(x, 38, 224, pal, 'copa'); arvore(x, 606, 228, pal, 'pinheiro');
    if (nivel < 4) arvore(x, 588, 296, pal, 'copa');
    if (nivel < 2) { arvore(x, 170, 218, pal, 'pinheiro'); arvore(x, 480, 222, pal, 'copa'); }
    for (let i = 0; i < 8; i++) {
      const bx2 = 20 + sr(i * 61) * 600, by2 = 212 + sr(i * 67) * 84;
      if (bx2 > 270 && bx2 < 380) continue;   // não obstruir a estrada
      arbusto(x, bx2, by2, pal);
    }
    // pedras do tileset espalhadas (neutras em todas as estações)
    for (let i = 0; i < 5; i++) {
      const px2 = 30 + sr(i * 97) * 580, py2 = 216 + sr(i * 101) * 120;
      if (px2 > 270 && px2 < 380) continue;
      estDesenha(x, 'pedra_' + (1 + (i % 3)), px2, py2 + 6, 14 + (i % 3) * 5);
    }

    // ---------- atmosfera global: luz quente da direita, sombra fria à esquerda ----------
    const luzAtm = x.createLinearGradient(W, 0, 0, H);
    luzAtm.addColorStop(0, 'rgba(255,232,160,.10)');
    luzAtm.addColorStop(0.5, 'rgba(255,232,160,0)');
    luzAtm.addColorStop(1, 'rgba(45,65,95,.10)');
    x.fillStyle = luzAtm;
    x.fillRect(0, 0, W, H);

    return cv;
  }

  function arbusto(x, bx, by, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 5, by + 4, 12, 2, SOMBRA);
    if (pal.tiles && estDesenha(x, 'arbusto_' + (1 + (bx % 3)), bx, by + 6, 16 + (bx % 3) * 4)) return;
    P(bx - 6, by - 2, 12, 6, pal.arvore[1]);
    P(bx - 4, by - 5, 9, 5, pal.arvore[1]);
    P(bx - 6, by + 1, 5, 3, pal.arvore[0]);
    P(bx + 1, by - 5, 4, 3, pal.arvore[3]);
    P(bx + 3, by - 2, 3, 2, pal.arvore[2]);
  }

  // ---------- peças estáticas ----------
  function arvore(x, tx, ty, pal, tipo) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    // sombra projetada (esq-inferior)
    P(tx - 18, ty + 12, 28, 5, SOMBRA);
    // árvores Emerald do tileset nas estações verdes (variante estável por posição)
    if (pal.tiles) {
      const v = tipo === 'pinheiro' ? (3 + (tx % 2)) : (1 + (tx % 2));
      if (estDesenha(x, 'arvore_' + v, tx, ty + 15, v >= 3 ? 38 : 46)) return;
    }
    P(tx - 3, ty - 6, 6, 20, '#4a3421');
    P(tx + 1, ty - 6, 2, 20, '#6b4f30');                  // lado direito do tronco na luz
    P(tx - 3, ty - 6, 1, 20, '#332417');                  // veio escuro do tronco
    if (pal.neve) {
      P(tx - 1, ty - 26, 3, 22, '#4a3421');
      P(tx - 12, ty - 16, 10, 2, '#4a3421'); P(tx + 3, ty - 22, 11, 2, '#4a3421');
      P(tx - 12, ty - 18, 10, 2, '#e8eff3'); P(tx + 3, ty - 24, 11, 2, '#e8eff3');
      return;
    }
    const blob = (bx, by, bw, bh, c) => { P(bx - bw / 2, by - bh / 2, bw, bh, c); };
    if (tipo === 'pinheiro') {
      // pinheiro em camadas triangulares, face direita clara
      for (let i = 0; i < 4; i++) {
        const w = 30 - i * 6, y2 = ty - 6 - i * 9;
        x.fillStyle = pal.arvore[1];
        x.beginPath(); x.moveTo(tx - w / 2, y2); x.lineTo(tx, y2 - 12); x.lineTo(tx + w / 2, y2); x.fill();
        x.fillStyle = pal.arvore[2];
        x.beginPath(); x.moveTo(tx, y2 - 12); x.lineTo(tx + w / 2, y2); x.lineTo(tx + w / 6, y2); x.fill();
        x.fillStyle = pal.arvore[0];
        x.beginPath(); x.moveTo(tx - w / 2, y2); x.lineTo(tx - w / 6, y2); x.lineTo(tx, y2 - 10); x.fill();
      }
      return;
    }
    // copa redonda: base escura → média → luz na direita-superior + frestas
    blob(tx, ty - 16, 34, 20, pal.arvore[1]);
    blob(tx - 6, ty - 24, 24, 14, pal.arvore[1]);
    blob(tx + 8, ty - 26, 20, 14, pal.arvore[2]);
    blob(tx - 12, ty - 10, 16, 10, pal.arvore[0]);
    blob(tx + 10, ty - 30, 12, 8, pal.arvore[3]);
    blob(tx + 12, ty - 18, 10, 8, pal.arvore[3]);
    // textura interna: pontos de folha
    for (let i = 0; i < 14; i++) {
      const fx = tx - 14 + sr(i * 7 + tx) * 28, fy = ty - 30 + sr(i * 9 + ty) * 20;
      P(fx, fy, 2, 2, i % 3 ? pal.arvore[0] : pal.arvore[3]);
    }
  }

  function casa(x, hx, hy, w, h, pedra, chamine, pal) {
    const P = (a, b, ww, hh, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(ww), Math.round(hh)); };
    // sombra projetada para a esquerda-inferior
    P(hx - 6, hy + h, w + 6, 5, SOMBRA);
    // estrutura do tileset, se carregada (variante estável por posição)
    const variante = pedra ? 'casa_2' : (['casa_1', 'casa_4', 'casa_1'][hx % 3]);
    if (estDesenha(x, variante, hx + w / 2, hy + h + 2, w + 14)) {
      luzes.push({ x: hx + w / 2 - 6, y: hy + h - 10 }, { x: hx + w / 2 + 8, y: hy + h - 10 });
      return;
    }
    const parede = pedra ? '#8a8d92' : '#dcc9a0';
    const paredeEsq = pedra ? '#5c6470' : '#b09a6e';      // face esquerda em sombra (hue-shift frio)
    const paredeDir = pedra ? '#b5b2a6' : '#f0e2be';      // face direita na luz
    P(hx, hy, w, h, parede);
    P(hx, hy, 4, h, paredeEsq);
    P(hx + w - 4, hy, 4, h, paredeDir);
    if (pedra) {
      // tijolos sugeridos + musgo na base
      x.fillStyle = '#6e737c';
      for (let ry = 4; ry < h - 2; ry += 6)
        for (let rx = (ry % 12 === 4 ? 4 : 10); rx < w - 4; rx += 12) x.fillRect(hx + rx, hy + ry, 6, 1);
      x.fillStyle = '#4f6b46';
      for (let rx = 2; rx < w - 2; rx += 7) x.fillRect(hx + rx, hy + h - 2, 4, 2);
    } else {
      // vigas de enxaimel
      const viga = '#5a4228';
      P(hx, hy, w, 3, viga); P(hx, hy + h - 3, w, 3, viga);
      P(hx, hy, 3, h, viga); P(hx + w - 3, hy, 3, h, viga);
      P(hx + w / 2 - 1, hy, 3, h, viga);
      P(hx + w / 4, hy, 2, h, viga); P(hx + (3 * w) / 4, hy, 2, h, viga);
    }
    // telhado de palha com risco de textura; direita mais clara
    const beira = 5, alt = h * 0.75;
    x.fillStyle = '#8a6b2d';
    x.beginPath(); x.moveTo(hx - beira, hy + 2); x.lineTo(hx + w / 2, hy - alt); x.lineTo(hx + w + beira, hy + 2); x.fill();
    x.fillStyle = '#b08d3a';
    x.beginPath(); x.moveTo(hx + w / 2, hy - alt); x.lineTo(hx + w + beira, hy + 2); x.lineTo(hx + w / 2 + 4, hy + 2); x.fill();
    // riscos da palha
    x.strokeStyle = '#6e5424'; x.lineWidth = 1;
    for (let i = 1; i <= 4; i++) {
      const t = i / 5;
      x.beginPath();
      x.moveTo(hx - beira + (w / 2 + beira) * t, hy + 2 - alt * t);
      x.lineTo(hx + w + beira - (w / 2 + beira) * t, hy + 2 - alt * t);
      x.stroke();
    }
    x.fillStyle = '#d0af52';                               // cume iluminado
    x.fillRect(hx + w / 2 - 3, hy - alt, 7, 2);
    if (pal.neve) {
      x.fillStyle = '#eef3f8';
      x.beginPath(); x.moveTo(hx - beira, hy); x.lineTo(hx + w / 2, hy - alt - 1); x.lineTo(hx + w + beira, hy);
      x.lineTo(hx + w + beira - 4, hy + 1); x.lineTo(hx + w / 2, hy - alt + 3); x.lineTo(hx - beira + 4, hy + 1); x.fill();
    }
    // porta em arco 10×14 (escala do aldeão) com batente
    const px = hx + w / 2 - 5, py = hy + h - 14;
    P(px - 1, py - 1, 12, 15, '#4a3a26');
    P(px, py, 10, 14, '#2e2418');
    P(px + 1, py + 1, 8, 12, '#3d3020');
    P(px + 7, py + 7, 2, 2, '#c9a227');
    // janelas 6×7 com luz quente e peitoril
    for (const wx of [hx + 7, hx + w - 13]) {
      P(wx - 1, hy + 7, 8, 9, pedra ? '#5c6470' : '#5a4228');
      P(wx, hy + 8, 6, 7, '#2e2418');
      P(wx + 1, hy + 9, 4, 5, '#f5d060');
      P(wx + 1, hy + 9, 4, 2, '#fdf0a0');
      P(wx - 1, hy + 16, 8, 1, pedra ? '#b5b2a6' : '#f0e2be');
      luzes.push({ x: wx + 3, y: hy + 11 });
    }
    if (chamine) {
      P(hx + w - 12, hy - alt * 0.7, 6, alt * 0.55, '#8a8d92');
      P(hx + w - 12, hy - alt * 0.7, 2, alt * 0.55, '#5c6470');
      P(hx + w - 13, hy - alt * 0.7 - 2, 8, 3, '#6e737c');
    }
  }

  function tenda(x, tx, ty, cor) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(tx - 4, ty + 20, 36, 4, SOMBRA);
    x.fillStyle = cor;
    x.beginPath(); x.moveTo(tx, ty + 20); x.lineTo(tx + 14, ty); x.lineTo(tx + 28, ty + 20); x.fill();
    x.fillStyle = 'rgba(38,54,74,.25)';
    x.beginPath(); x.moveTo(tx, ty + 20); x.lineTo(tx + 14, ty); x.lineTo(tx + 14, ty + 20); x.fill();
    P(tx + 13, ty - 4, 2, 5, '#5d4428');
    P(tx + 10, ty + 9, 8, 11, '#3d3020');
  }

  // barracas de mercado — cada uma é ÚNICA (toldo, mercadoria e adereço próprios)
  function barraca(x, bx, by, cor, tipo) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 3, by + 16, 30, 4, SOMBRA);
    P(bx, by, 3, 16, '#5d4428'); P(bx + 23, by, 3, 16, '#6b4f30');
    if (tipo === 'liso') {
      P(bx - 2, by - 6, 30, 7, cor);
      P(bx - 2, by - 6, 30, 2, 'rgba(255,240,200,.35)');
      for (let i = 0; i < 30; i += 5) P(bx - 2 + i, by + 1, 3, 2, 'rgba(38,54,74,.3)'); // barra recortada
    } else {
      for (let i = 0; i < 26; i += 4) {
        P(bx - 2 + i, by - 6, 4, 7, (i / 4) % 2 ? '#efe6cf' : cor);
        P(bx - 2 + i, by + 1, 4, 2, (i / 4) % 2 ? '#cfc4a8' : 'rgba(38,54,74,.25)');
      }
    }
    P(bx + 1, by + 8, 24, 7, '#8a6b45');
    P(bx + 1, by + 8, 24, 2, '#a58a5c');
    if (tipo === 'frutas') {
      P(bx + 3, by + 5, 3, 3, '#c94f4f'); P(bx + 7, by + 5, 3, 3, '#c94f4f'); P(bx + 5, by + 3, 3, 3, '#d86a2d');
      P(bx + 13, by + 5, 3, 3, '#d8a028'); P(bx + 17, by + 5, 3, 3, '#7aa03a'); P(bx + 15, by + 3, 3, 3, '#d8a028');
    } else if (tipo === 'tecidos') {
      P(bx + 3, by + 2, 5, 6, '#8b2635'); P(bx + 9, by + 2, 5, 6, '#3c5a8a'); P(bx + 15, by + 2, 5, 6, '#c9a227');
      P(bx + 3, by + 2, 5, 1, '#b05060'); P(bx + 9, by + 2, 5, 1, '#5a7ab0'); P(bx + 15, by + 2, 5, 1, '#e0c050');
    } else if (tipo === 'paes') {
      P(bx + 4, by + 4, 6, 3, '#b08d3a'); P(bx + 12, by + 4, 6, 3, '#b08d3a'); P(bx + 8, by + 2, 6, 3, '#d0af52');
      P(bx + 5, by + 4, 4, 1, '#d0af52');
    } else {
      P(bx + 4, by + 5, 4, 3, '#c94f4f'); P(bx + 10, by + 5, 4, 3, '#d8a028'); P(bx + 16, by + 5, 4, 3, '#5a8a4a');
    }
  }

  function barril(x, bx, by) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 1, by + 9, 10, 2, SOMBRA);
    P(bx, by, 8, 10, '#8a6b45');
    P(bx + 6, by, 2, 10, '#a58a5c');
    P(bx, by, 2, 10, '#5d4428');
    P(bx, by + 2, 8, 1, '#4a3a26'); P(bx, by + 7, 8, 1, '#4a3a26'); // arcos de ferro
  }

  function caixa(x, bx, by) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(bx - 1, by + 8, 11, 2, SOMBRA);
    P(bx, by, 9, 8, '#a58a5c');
    P(bx, by, 9, 1, '#c4a877'); P(bx, by, 1, 8, '#8a6b45');
    P(bx, by + 3, 9, 1, '#8a6b45'); P(bx + 4, by, 1, 8, '#8a6b45');
  }

  function poco(x, px2, py) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(px2 - 3, py + 12, 22, 3, SOMBRA);
    if (estDesenha(x, 'poco', px2 + 8, py + 14, 26)) return;
    P(px2, py + 4, 16, 9, '#8a8d92');
    P(px2, py + 4, 16, 2, '#b5b2a6');
    x.fillStyle = '#6e737c';
    for (let i = 1; i < 15; i += 5) x.fillRect(px2 + i, py + 7, 3, 1);
    P(px2 + 3, py + 6, 10, 4, '#26333d');                 // boca escura
    P(px2 + 1, py - 8, 2, 12, '#5d4428'); P(px2 + 13, py - 8, 2, 12, '#5d4428');
    x.fillStyle = '#7d3b3b';
    x.beginPath(); x.moveTo(px2 - 2, py - 7); x.lineTo(px2 + 8, py - 13); x.lineTo(px2 + 18, py - 7); x.fill();
    x.fillStyle = '#a05050';
    x.beginPath(); x.moveTo(px2 + 8, py - 13); x.lineTo(px2 + 18, py - 7); x.lineTo(px2 + 10, py - 7); x.fill();
    P(px2 + 7, py - 4, 2, 5, '#4a3a26');                  // corda
    P(px2 + 6, py + 1, 4, 3, '#8a6b45');                  // balde
  }

  function estabulo(x, ex, ey, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(ex - 5, ey + 24, 56, 4, SOMBRA);
    // galpão aberto de madeira com veios
    P(ex, ey, 48, 24, '#7a5c38');
    for (let i = 3; i < 48; i += 6) P(ex + i, ey, 1, 24, '#5d4428');
    P(ex + 44, ey, 4, 24, '#8f6d44');
    x.fillStyle = '#8a6b2d';
    x.beginPath(); x.moveTo(ex - 5, ey + 2); x.lineTo(ex + 24, ey - 14); x.lineTo(ex + 53, ey + 2); x.fill();
    x.fillStyle = '#b08d3a';
    x.beginPath(); x.moveTo(ex + 24, ey - 14); x.lineTo(ex + 53, ey + 2); x.lineTo(ex + 28, ey + 2); x.fill();
    if (pal.neve) { x.fillStyle = '#eef3f8'; x.beginPath(); x.moveTo(ex - 5, ey); x.lineTo(ex + 24, ey - 15); x.lineTo(ex + 53, ey); x.lineTo(ex + 48, ey + 1); x.lineTo(ex + 24, ey - 11); x.lineTo(ex, ey + 1); x.fill(); }
    // vão aberto escuro com feno
    P(ex + 5, ey + 6, 38, 18, '#3a2d1d');
    P(ex + 7, ey + 18, 12, 6, '#c9a94f'); P(ex + 8, ey + 16, 8, 3, '#d8bc60');
    // cavalo dentro (cabeça baixa comendo)
    cavalo(x, ex + 22, ey + 10, '#6b4a2d');
    // cerquinha do paddock com segundo cavalo
    for (let i = 0; i <= 40; i += 8) { P(ex + 48 + i, ey + 14, 2, 9, '#6b4f30'); }
    P(ex + 48, ey + 15, 42, 2, '#8a6b45'); P(ex + 48, ey + 20, 42, 2, '#8a6b45');
    cavalo(x, ex + 62, ey + 12, '#4a3421');
  }

  function cavalo(x, cx, cy, cor) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(cx - 1, cy + 12, 18, 2, SOMBRA);
    P(cx, cy, 14, 8, cor);                                 // corpo
    P(cx + 12, cy - 2, 4, 5, cor);                         // pescoço
    P(cx + 14, cy + 1, 5, 4, cor);                         // cabeça baixa
    P(cx + 17, cy + 4, 2, 2, sombraCor(cor));              // focinho
    P(cx + 11, cy - 3, 4, 2, '#2d2018');                   // crina
    P(cx, cy, 14, 2, corClara(cor));                       // lombo na luz
    P(cx + 1, cy + 8, 2, 5, cor); P(cx + 5, cy + 8, 2, 5, sombraCor(cor));
    P(cx + 9, cy + 8, 2, 5, cor); P(cx + 12, cy + 8, 2, 5, sombraCor(cor));
    P(cx - 2, cy + 1, 2, 6, '#2d2018');                    // cauda
  }
  function sombraCor(hex) { const n = parseInt(hex.slice(1), 16); return `rgb(${((n >> 16) & 255) * 0.7 | 0},${((n >> 8) & 255) * 0.72 | 0},${(n & 255) * 0.82 | 0})`; }
  function corClara(hex) { const n = parseInt(hex.slice(1), 16); const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255; return `rgb(${r + (255 - r) * 0.18 | 0},${g + (255 - g) * 0.16 | 0},${b + (255 - b) * 0.1 | 0})`; }

  function paliçada(x, y, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(0, y + 16, W, 4, SOMBRA);
    for (let px = 2; px < W - 2; px += 8) {
      if (px > 296 && px < 348) continue;
      const hh = 22 + (px % 5);
      P(px, y - hh + 18, 6, hh, '#6b4f30');
      P(px + 4, y - hh + 18, 2, hh, '#8a6b45');           // lado direito na luz
      P(px, y - hh + 18, 2, hh, '#4a3a26');               // lado esquerdo na sombra
      x.fillStyle = '#8a6b45';
      x.beginPath(); x.moveTo(px, y - hh + 18); x.lineTo(px + 3, y - hh + 12); x.lineTo(px + 6, y - hh + 18); x.fill();
      if (pal.neve) P(px, y - hh + 17, 6, 2, '#eef3f8');
    }
    P(296, y - 12, 6, 32, '#4a3a26'); P(346, y - 12, 6, 32, '#4a3a26');
    P(296, y - 14, 56, 4, '#5d4428');
    P(302, y - 8, 44, 26, '#6b4f30');
    P(302, y - 2, 44, 3, '#4a3a26'); P(302, y + 8, 44, 3, '#4a3a26');
  }

  function muroPedra(x, y, torres, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(0, y + 20, W, 5, SOMBRA);
    P(0, y, W, 22, '#8a8d92');
    // pedra desgastada: blocos individuais com tons variados
    for (let ry = 0; ry < 22; ry += 5) {
      for (let rx = (ry % 10 === 0 ? 0 : 8); rx < W; rx += 16) {
        const tom = sr(rx * 7 + ry * 13);
        if (tom < 0.22) P(rx, y + ry, 14, 4, '#979a9e');
        else if (tom < 0.4) P(rx, y + ry, 14, 4, '#7f838c');
        else if (tom > 0.9) P(rx, y + ry, 14, 4, '#94908a'); // bloco amarelado (idade)
      }
    }
    P(0, y, W, 3, '#b5b2a6');                              // topo pega luz
    P(0, y + 19, W, 3, '#5c6470');                         // base em sombra fria
    // juntas dos tijolos
    x.fillStyle = '#6e737c';
    for (let ry = 5; ry < 19; ry += 6)
      for (let rx = (ry % 12 === 5 ? 4 : 12); rx < W; rx += 16) x.fillRect(rx, y + ry, 8, 1);
    // rachaduras e lascas
    for (let i = 0; i < 26; i++) {
      const rx = sr(i * 31) * W, ry = y + 3 + sr(i * 37) * 15;
      P(rx, ry, 1, 2 + (i % 3), 'rgba(60,70,85,.5)');
      if (i % 4 === 0) P(rx + 1, ry + 2, 2, 1, 'rgba(60,70,85,.4)');
    }
    // musgo na base e trepadeiras
    x.fillStyle = '#4f6b46';
    for (let rx = 3; rx < W; rx += 11) x.fillRect(rx, y + 20, 5, 2);
    for (let i = 0; i < 12; i++) {
      const rx = sr(i * 41) * W;
      if (rx > 280 && rx < 364) continue;
      P(rx, y + 14, 2, 6, '#5d7a4e'); P(rx + 1, y + 10, 2, 5, '#5d7a4e'); P(rx - 1, y + 17, 2, 4, '#466a42');
    }
    // ameias com face direita clara
    for (let px = 0; px < W; px += 14) {
      if (px > 288 && px < 356) continue;
      P(px, y - 7, 8, 7, '#8a8d92');
      P(px + 6, y - 7, 2, 7, '#b5b2a6');
      P(px, y - 7, 2, 7, '#6e737c');
      if (pal.neve) P(px, y - 8, 8, 2, '#eef3f8');
    }
    // portão em arco com levadiça
    P(288, y - 18, 68, 42, '#7c8087');
    P(288, y - 18, 68, 3, '#a5a89e');
    x.fillStyle = '#242e28';
    x.beginPath(); x.moveTo(302, y + 22); x.lineTo(302, y - 4);
    x.quadraticCurveTo(322, y - 16, 342, y - 4); x.lineTo(342, y + 22); x.fill();
    x.fillStyle = '#5a4a35';
    for (let gx = 306; gx < 342; gx += 7) x.fillRect(gx, y - 9, 3, 31);
    x.fillRect(302, y - 2, 40, 2); x.fillRect(302, y + 9, 40, 2);
    if (torres) {
      for (const tx of [266, 356]) {
        P(tx - 4, y + 18, 30, 4, SOMBRA);
        P(tx, y - 34, 22, 56, '#9a9d9d');
        P(tx + 18, y - 34, 4, 56, '#b5b2a6');
        P(tx, y - 34, 4, 56, '#6e737c');
        x.fillStyle = '#6e737c';
        for (let ry = 4; ry < 52; ry += 6) x.fillRect(tx + (ry % 12 === 4 ? 3 : 9), y - 34 + ry, 7, 1);
        x.fillStyle = '#7d3b3b';
        x.beginPath(); x.moveTo(tx - 4, y - 33); x.lineTo(tx + 11, y - 52); x.lineTo(tx + 26, y - 33); x.fill();
        x.fillStyle = '#a05050';
        x.beginPath(); x.moveTo(tx + 11, y - 52); x.lineTo(tx + 26, y - 33); x.lineTo(tx + 15, y - 33); x.fill();
        if (pal.neve) { x.fillStyle = '#eef3f8'; x.beginPath(); x.moveTo(tx - 4, y - 33); x.lineTo(tx + 11, y - 52); x.lineTo(tx + 26, y - 33); x.lineTo(tx + 21, y - 33); x.lineTo(tx + 11, y - 48); x.lineTo(tx + 1, y - 33); x.fill(); }
        P(tx + 8, y - 20, 6, 8, '#2e2418'); P(tx + 9, y - 19, 4, 5, '#f5d060'); P(tx + 9, y - 19, 4, 2, '#fdf0a0');
        luzes.push({ x: tx + 11, y: y - 17 });
      }
    }
  }

  function castelo(x, cy, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    const corpoW = 130;
    const bx = 322 - corpoW / 2;                            // centrado no portão da muralha
    const baseY = cy + 78;                                  // desce até encostar no muro
    // sombra projetada sobre o gramado atrás do muro
    P(bx - 24, baseY + 2, corpoW + 30, 6, SOMBRA_FORTE);
    // corpo
    P(bx, cy + 18, corpoW, 60, '#9a9d9d');
    P(bx, cy + 18, 6, 60, '#6e737c');
    P(bx + corpoW - 6, cy + 18, 6, 60, '#b5b2a6');
    x.fillStyle = '#7c8087';
    for (let ry = 4; ry < 58; ry += 6)
      for (let rx = (ry % 12 === 4 ? 5 : 13); rx < corpoW - 5; rx += 16) x.fillRect(bx + rx, cy + 18 + ry, 8, 1);
    for (let i = 0; i < corpoW; i += 13) { P(bx + i, cy + 12, 8, 6, '#9a9d9d'); P(bx + i + 6, cy + 12, 2, 6, '#b5b2a6'); }
    // torres laterais com telhado cônico (face direita clara)
    for (const [tx, alt] of [[bx - 24, 86], [bx + corpoW - 4, 86]]) {
      P(tx, baseY - alt, 28, alt, '#a5a8a2');
      P(tx + 24, baseY - alt, 4, alt, '#c0bdb0');
      P(tx, baseY - alt, 4, alt, '#767c88');
      x.fillStyle = '#7c8087';
      for (let ry = 5; ry < alt - 4; ry += 6) x.fillRect(tx + (ry % 12 === 5 ? 4 : 12), baseY - alt + ry, 8, 1);
      x.fillStyle = '#46526b';
      x.beginPath(); x.moveTo(tx - 5, baseY - alt + 1); x.lineTo(tx + 14, baseY - alt - 24); x.lineTo(tx + 33, baseY - alt + 1); x.fill();
      x.fillStyle = '#5d6b8c';
      x.beginPath(); x.moveTo(tx + 14, baseY - alt - 24); x.lineTo(tx + 33, baseY - alt + 1); x.lineTo(tx + 19, baseY - alt + 1); x.fill();
      if (pal.neve) { x.fillStyle = '#eef3f8'; x.beginPath(); x.moveTo(tx - 5, baseY - alt + 1); x.lineTo(tx + 14, baseY - alt - 24); x.lineTo(tx + 33, baseY - alt + 1); x.lineTo(tx + 28, baseY - alt + 1); x.lineTo(tx + 14, baseY - alt - 20); x.lineTo(tx, baseY - alt + 1); x.fill(); }
      P(tx + 10, baseY - alt + 14, 6, 8, '#2e2418'); P(tx + 11, baseY - alt + 15, 4, 5, '#f5d060'); P(tx + 11, baseY - alt + 15, 4, 2, '#fdf0a0');
      P(tx + 10, baseY - alt + 34, 6, 8, '#2e2418'); P(tx + 11, baseY - alt + 35, 4, 5, '#f5d060');
      luzes.push({ x: tx + 13, y: baseY - alt + 17 }, { x: tx + 13, y: baseY - alt + 37 });
    }
    // torre de menagem central
    P(bx + corpoW / 2 - 20, cy - 22, 40, 44, '#b0b3ab');
    P(bx + corpoW / 2 + 14, cy - 22, 6, 44, '#c8c5b8');
    P(bx + corpoW / 2 - 20, cy - 22, 5, 44, '#7c828e');
    x.fillStyle = '#8b8e8c';
    for (let ry = 4; ry < 40; ry += 6) x.fillRect(bx + corpoW / 2 - 16 + (ry % 12 === 4 ? 2 : 9), cy - 22 + ry, 8, 1);
    for (let i = 0; i < 40; i += 9) { P(bx + corpoW / 2 - 20 + i, cy - 28, 6, 6, '#b0b3ab'); P(bx + corpoW / 2 - 16 + i, cy - 28, 2, 6, '#c8c5b8'); }
    P(bx + corpoW / 2 - 4, cy - 14, 8, 10, '#2e2418'); P(bx + corpoW / 2 - 3, cy - 13, 6, 7, '#f5d060'); P(bx + corpoW / 2 - 3, cy - 13, 6, 3, '#fdf0a0');
    luzes.push({ x: bx + corpoW / 2, y: cy - 10 });
    // janelas do corpo
    for (const wx of [bx + 16, bx + 38, bx + corpoW - 46, bx + corpoW - 24]) {
      P(wx - 1, cy + 32, 9, 12, '#767c88');
      P(wx, cy + 33, 7, 10, '#2e2418');
      P(wx + 1, cy + 34, 5, 8, '#f5d060');
      P(wx + 1, cy + 34, 5, 3, '#fdf0a0');
      luzes.push({ x: wx + 3, y: cy + 38 });
    }
    // musgo na base
    x.fillStyle = '#4f6b46';
    for (let rx = 4; rx < corpoW - 4; rx += 9) x.fillRect(bx + rx, cy + 74, 5, 3);
    if (pal.neve) { P(bx, cy + 16, corpoW, 3, '#eef3f8'); }
  }

  function moinhoCorpo(x, mx, my, pal) {
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    P(mx - 8, my + 48, 44, 5, SOMBRA);
    x.fillStyle = '#9a9d9d';
    x.beginPath(); x.moveTo(mx, my + 48); x.lineTo(mx + 6, my); x.lineTo(mx + 24, my); x.lineTo(mx + 30, my + 48); x.fill();
    x.fillStyle = '#b5b2a6';
    x.beginPath(); x.moveTo(mx + 18, my); x.lineTo(mx + 24, my); x.lineTo(mx + 30, my + 48); x.lineTo(mx + 22, my + 48); x.fill();
    x.fillStyle = '#6e737c';
    x.beginPath(); x.moveTo(mx, my + 48); x.lineTo(mx + 6, my); x.lineTo(mx + 10, my); x.lineTo(mx + 6, my + 48); x.fill();
    for (let ry = 6; ry < 44; ry += 7) { x.fillStyle = '#7c8087'; x.fillRect(mx + 5 + (ry % 14 === 6 ? 2 : 6), my + ry, 7, 1); }
    x.fillStyle = '#7d3b3b';
    x.beginPath(); x.moveTo(mx - 2, my + 1); x.lineTo(mx + 15, my - 13); x.lineTo(mx + 32, my + 1); x.fill();
    x.fillStyle = '#a05050';
    x.beginPath(); x.moveTo(mx + 15, my - 13); x.lineTo(mx + 32, my + 1); x.lineTo(mx + 20, my + 1); x.fill();
    P(mx + 11, my + 36, 9, 12, '#2e2418'); P(mx + 12, my + 37, 7, 10, '#3d3020');
    P(mx + 12, my + 10, 6, 7, '#2e2418'); P(mx + 13, my + 11, 4, 5, '#f5d060');
    luzes.push({ x: mx + 15, y: my + 13 });
    x.fillStyle = '#4f6b46';
    for (let rx = 2; rx < 28; rx += 6) x.fillRect(mx + rx, my + 46, 4, 2);
  }

  function acampamento(x, pal) {
    tenda(x, 170, 240, '#8a6b45'); tenda(x, 400, 254, '#7a6248'); tenda(x, 120, 276, '#93765a'); tenda(x, 470, 280, '#8a6b45');
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };
    // carroça
    P(432, 292, 6, 4, SOMBRA);
    P(430, 282, 28, 12, '#6b4f30'); P(431, 280, 26, 4, '#8a6b45'); P(454, 282, 4, 12, '#8a6b45');
    for (const rx of [433, 449]) { P(rx, 292, 8, 8, '#3d3020'); P(rx + 3, 292, 2, 8, '#5a4a35'); P(rx, 295, 8, 2, '#5a4a35'); }
    // estandarte
    P(210, 226, 3, 40, '#4a3826');
    // rack de lanças
    P(350, 250, 20, 3, '#6b4f30');
    for (const lx of [352, 358, 364]) { P(lx, 232, 2, 20, '#8a6b45'); P(lx - 1, 229, 4, 4, '#c0bdb0'); }
    // boneco de treino
    P(160, 288, 3, 16, '#6b4f30'); P(152, 291, 19, 3, '#6b4f30'); P(157, 282, 9, 7, '#b09a6e');
  }

  // ============================================================
  // CAMADA DINÂMICA (por quadro)
  // ============================================================
  function desenharDinamico(ctx, state, pal, nivel) {
    const P = (a, b, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(a), Math.round(b), Math.round(w), Math.round(h)); };

    // nuvens variadas em camadas, com borda macia e base sombreada
    const nuvem = (nx, ny, s, forma) => {
      ctx.fillStyle = 'rgba(255,255,252,.55)';                        // halo macio
      P(nx - 4 * s, ny - 2 * s, 60 * s, 14 * s);
      ctx.fillStyle = 'rgba(252,252,248,.96)';
      if (forma === 0) {
        P(nx, ny, 52 * s, 10 * s); P(nx + 10 * s, ny - 7 * s, 30 * s, 8 * s); P(nx + 24 * s, ny - 12 * s, 16 * s, 7 * s);
      } else if (forma === 1) {
        P(nx, ny, 40 * s, 9 * s); P(nx + 26 * s, ny - 5 * s, 26 * s, 9 * s); P(nx + 12 * s, ny - 10 * s, 22 * s, 8 * s);
        P(nx + 44 * s, ny + 2 * s, 14 * s, 6 * s);
      } else {
        P(nx, ny, 30 * s, 8 * s); P(nx + 8 * s, ny - 6 * s, 18 * s, 7 * s);
      }
      ctx.fillStyle = 'rgba(255,255,255,.9)';                          // topo iluminado
      P(nx + 12 * s, ny - (forma === 2 ? 8 : 13) * s, 14 * s, 3 * s);
      ctx.fillStyle = 'rgba(150,165,190,.35)';                         // base sombreada
      P(nx + 3 * s, ny + 8 * s, (forma === 2 ? 26 : 46) * s, 2 * s);
    };
    nuvem((anim * 0.10) % (W + 160) - 130, 40, 1.2, 0);
    nuvem((anim * 0.16 + 260) % (W + 160) - 130, 74, 0.9, 1);
    nuvem((anim * 0.07 + 460) % (W + 160) - 130, 24, 0.7, 2);
    nuvem((anim * 0.12 + 90) % (W + 160) - 130, 96, 0.6, 1);

    // água: linhas de reflexo horizontais em movimento
    for (let i = 0; i < 16; i++) {
      const wx = ((i * 47 + anim * (0.5 + (i % 3) * 0.25)) % (W + 40)) - 20;
      const wy = 310 + Math.sin(wx * 0.017) * 6 + (i % 4) * 4;
      P(wx, wy, 10 + (i % 3) * 5, 1, pal.neve ? '#dde9f2' : '#6fa3c0');
    }
    for (let i = 0; i < 6; i++) {
      const wx = ((i * 101 + anim * 0.9) % (W + 30)) - 15;
      P(wx, 314 + (i % 3) * 5, 3, 1, '#cfe6f2');
    }

    // pás do moinho
    if (nivel >= 2) {
      ctx.save(); ctx.translate(67, 208); ctx.rotate(anim * 0.015);
      for (let i = 0; i < 4; i++) {
        ctx.rotate(Math.PI / 2);
        ctx.fillStyle = '#e8dcc0'; ctx.fillRect(-2, 4, 5, 30);
        ctx.fillStyle = '#b8a880';
        for (let j = 7; j < 32; j += 5) ctx.fillRect(-2, j, 5, 1);
        ctx.fillRect(-2, 4, 1, 30);
      }
      ctx.restore();
      ctx.fillStyle = '#5a4228'; ctx.fillRect(64, 205, 6, 6);
    }

    // bandeiras (torres nível 4+, castelo nível 5)
    const bandeira = (bx, by, cor) => {
      P(bx, by, 2, 14, '#4a3826');
      const ond = Math.sin(anim * 0.09 + bx) * 3;
      ctx.fillStyle = cor;
      ctx.beginPath(); ctx.moveTo(bx + 2, by); ctx.lineTo(bx + 16 + ond, by + 3); ctx.lineTo(bx + 2, by + 7); ctx.fill();
    };
    if (nivel >= 4) { bandeira(276, 170, '#8b2635'); bandeira(366, 170, '#8b2635'); }
    if (nivel >= 5) bandeira(318, 118, '#c9a227');
    if (nivel < 0) bandeira(210, 222, '#7d3b3b');

    // fumaça das chaminés / fogueira
    const fumaca = (fx, fy, seed) => {
      for (let i = 0; i < 5; i++) {
        const t = ((anim * 0.5 + i * 20 + seed * 13) % 90) / 90;
        const dx = Math.sin((t * 6 + seed) * 1.8) * (2 + t * 6);
        const s = 2 + t * 4;
        ctx.fillStyle = `rgba(235,233,228,${0.5 * (1 - t)})`;
        ctx.fillRect(Math.round(fx + dx - s / 2), Math.round(fy - t * 34 - s / 2), Math.round(s), Math.round(s));
      }
    };
    if (nivel >= 1) fumaca(173, 232, 1);
    if (nivel >= 2) fumaca(539, 253, 2);
    if (nivel >= 4) fumaca(563, 246, 3);
    if (nivel === 0 || nivel < 0) {
      const fx = nivel < 0 ? 300 : 260, fy = nivel < 0 ? 270 : 262;
      const sheetFogo = estPronta('fogueira');
      if (sheetFogo) {
        // fogueira animada do tileset (8 quadros de 32×32)
        const q = Math.floor(anim / 7) % 8;
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(sheetFogo, q * 32, 0, 32, 32, fx - 9, fy - 17, 26, 26);
      } else {
        P(fx - 5, fy + 4, 7, 3, '#5d4428'); P(fx + 3, fy + 4, 7, 3, '#6b4f30');
        const fl = Math.sin(anim * 0.3) * 2;
        P(fx, fy - 3 + fl * 0.3, 5, 6, '#d86a2d');
        P(fx + 1, fy - 6 + fl * 0.5, 3, 5, '#f5a03c');
        P(fx + 2, fy - 8 + fl * 0.6, 1, 3, '#fbd060');
      }
      fumaca(fx + 2, fy - 8, 5);
    }

    // galinhas bicando
    for (const g of galinhas) {
      g.t += 1;
      const bica = Math.floor(g.t / 40) % 3 === 0;
      P(g.x, g.y + 5, 6, 1, SOMBRA);
      P(g.x, g.y, 5, 4, '#f0ece2');
      P(g.x + 4, g.y - 2 + (bica ? 2 : 0), 2, 3, '#f0ece2');
      P(g.x + 5, g.y - 1 + (bica ? 2 : 0), 2, 1, '#d8a028');
      P(g.x + 4, g.y - 3 + (bica ? 2 : 0), 1, 1, '#c94f4f');
      P(g.x + 1, g.y + 4, 1, 2, '#d8a028'); P(g.x + 3, g.y + 4, 1, 2, '#d8a028');
    }

    // aldeões 8×14 — escala compatível com as portas
    npcs.sort((a, b) => a.y - b.y);
    for (const n of npcs) {
      if (n.pausa > 0) n.pausa--;
      else {
        n.x += n.vx;
        if (Math.random() < 0.004) n.pausa = 60 + Math.random() * 90;
        if (Math.random() < 0.005) n.vx = (Math.random() - 0.5) * 0.5;
        if (n.x < 70) n.vx = Math.abs(n.vx);
        if (n.x > 560) n.vx = -Math.abs(n.vx);
        const yTopoRio = 306 + Math.sin(n.x * 0.017) * 6;
        if (n.y > yTopoRio - 16 && n.y < yTopoRio + 34 && (n.x < 288 || n.x > 350)) n.y = yTopoRio - 18;
      }
      const passo = n.pausa > 0 ? 0 : Math.floor(anim / 8 + n.x) % 2;
      P(n.x, n.y + 13, 8, 2, SOMBRA);                     // sombra no chão
      P(n.x + 2, n.y, 4, 4, '#d8b090');                   // cabeça
      P(n.x + 2, n.y - 1, 4, 2, n.capuz ? n.roupa : n.cabelo);
      if (n.capuz) { P(n.x + 1, n.y - 1, 1, 3, n.roupa); P(n.x + 6, n.y - 1, 1, 3, n.roupa); }
      P(n.x + 1, n.y + 4, 6, 6, n.roupa);                 // túnica
      P(n.x + 1, n.y + 4, 2, 6, 'rgba(38,54,74,.30)');    // lado esquerdo sombreado
      P(n.x + 6, n.y + 4, 1, 6, 'rgba(255,240,180,.35)'); // lado direito na luz
      P(n.x + 1, n.y + 10, 6, 1, 'rgba(38,54,74,.3)');    // cinto
      P(n.x + 1 + passo, n.y + 11, 2, 3, '#3d3020');      // pernas
      P(n.x + 5 - passo, n.y + 11, 2, 3, '#3d3020');
    }

    // tochas acesas nas laterais do portão
    if (nivel >= 3) {
      for (const tx of [296, 344]) {
        P(tx, 218, 2, 8, '#5d4428');
        const fl = Math.sin(anim * 0.35 + tx) * 1.2;
        P(tx - 1, 213 + fl * 0.4, 4, 5, '#d86a2d');
        P(tx, 211 + fl * 0.6, 2, 4, '#f5a03c');
        P(tx, 210 + fl * 0.7, 1, 2, '#fbd060');
        ctx.fillStyle = 'rgba(255,190,90,.12)';
        ctx.fillRect(tx - 6, 206, 14, 18);
      }
    }

    // guardas no portão (estáticos, com lança)
    if (nivel >= 3) {
      for (const gx of [292, 348]) {
        P(gx, 249, 8, 2, SOMBRA);
        P(gx + 2, 226, 4, 4, '#c8c4bc');
        P(gx + 3, 227, 2, 2, '#d8b090');
        P(gx + 1, 230, 6, 8, '#8a8478');
        P(gx + 1, 230, 2, 8, 'rgba(38,54,74,.3)');
        P(gx + 1 + (gx > 300 ? 6 : -2), 220, 2, 18, '#6b4f30');
        P(gx + (gx > 300 ? 6 : -3), 217, 4, 4, '#c8c4bc');
      }
    }
  }

  // ============================================================
  // CICLO DIA/NOITE, ASTROS E CLIMA (o "budget i3" bem gasto)
  // ============================================================

  // 0 = meia-noite · 0.5 = amanhecer/entardecer · 1 = meio-dia
  function cicloAtual() {
    if (cicloForcado !== null) return cicloForcado;
    return (Math.sin(anim * 0.0009) + 1) / 2;   // dia completo ≈ 2 minutos
  }

  // sol e lua cruzam o céu conforme o ciclo (antes das nuvens)
  function astros(ctx, pal, ciclo) {
    const arco = (t) => ({ x: 80 + t * 480, y: 130 - Math.sin(t * Math.PI) * 100 });
    if (ciclo > 0.32) { // sol visível
      const t = Math.min(1, Math.max(0, (ciclo - 0.35) / 0.65));
      const p = arco(t);
      const r = 16;
      const forca = Math.min(1, (ciclo - 0.32) / 0.2);
      const quente = ciclo < 0.55; // sol baixo = alaranjado
      const g = ctx.createRadialGradient(p.x, p.y, r * 0.5, p.x, p.y, r * 4.2);
      g.addColorStop(0, `rgba(255,${quente ? 190 : 244},${quente ? 120 : 190},${0.55 * forca})`);
      g.addColorStop(1, 'rgba(255,240,180,0)');
      ctx.fillStyle = g;
      ctx.fillRect(p.x - r * 4.2, p.y - r * 4.2, r * 8.4, r * 8.4);
      for (let dy = -r; dy <= r; dy += 2) for (let dx = -r; dx <= r; dx += 2) {
        const d = Math.sqrt(dx * dx + dy * dy);
        let c = null;
        if (d <= r - 6) c = quente ? '#ffe8c0' : '#fffce8';
        else if (d <= r - 3) c = quente ? '#ffc878' : pal.sol[1];
        else if (d <= r) c = quente ? '#f5a860' : pal.sol[0];
        else if (d <= r + 5 && (dx + dy) % 4 === 0) c = quente ? '#f5a860' : pal.sol[0];
        if (c) { ctx.fillStyle = c; ctx.globalAlpha = forca; ctx.fillRect(Math.round(p.x + dx), Math.round(p.y + dy), 2, 2); ctx.globalAlpha = 1; }
      }
    }
    if (ciclo < 0.45) { // lua visível
      const t = 1 - Math.min(1, ciclo / 0.45);
      const p = arco(t);
      const forca = Math.min(1, (0.45 - ciclo) / 0.15);
      ctx.globalAlpha = forca;
      const g = ctx.createRadialGradient(p.x, p.y, 6, p.x, p.y, 40);
      g.addColorStop(0, 'rgba(210,225,255,.35)');
      g.addColorStop(1, 'rgba(210,225,255,0)');
      ctx.fillStyle = g;
      ctx.fillRect(p.x - 40, p.y - 40, 80, 80);
      for (let dy = -10; dy <= 10; dy += 2) for (let dx = -10; dx <= 10; dx += 2) {
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d <= 10) { ctx.fillStyle = d <= 7 ? '#e8eef8' : '#c8d4e8'; ctx.fillRect(Math.round(p.x + dx), Math.round(p.y + dy), 2, 2); }
      }
      ctx.fillStyle = '#aab8d0'; // crateras
      ctx.fillRect(p.x - 4, p.y - 2, 3, 3); ctx.fillRect(p.x + 2, p.y + 3, 2, 2); ctx.fillRect(p.x + 1, p.y - 5, 2, 2);
      ctx.globalAlpha = 1;
    }
  }

  // partículas de clima por estação
  function clima(ctx, est, ciclo) {
    const chovendo = (est === 'primavera' || est === 'outono') && Math.sin(anim * 0.0004 + 2) > 0.55;
    if (chovendo) {
      ctx.fillStyle = 'rgba(180,200,225,.55)';
      for (let i = 0; i < 90; i++) {
        const px = (sr(i * 3) * (W + 60) + anim * 1.2) % (W + 60) - 30;
        const py = (sr(i * 7) * H + anim * 6.5) % H;
        ctx.fillRect(Math.round(px), Math.round(py), 1, 6);
      }
      ctx.fillStyle = 'rgba(200,220,240,.4)'; // respingos no chão
      for (let i = 0; i < 14; i++) {
        const px = sr(i * 11 + Math.floor(anim / 8)) * W;
        const py = 210 + sr(i * 13 + Math.floor(anim / 8)) * 140;
        ctx.fillRect(Math.round(px), Math.round(py), 2, 1);
      }
      ctx.fillStyle = 'rgba(40,55,80,.14)';   // céu fechado
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
    if (est === 'outono' && !chovendo) { // folhas ao vento
      for (let i = 0; i < 10; i++) {
        const px = (sr(i * 17) * W + anim * (0.8 + sr(i) * 0.6)) % W;
        const py = (sr(i * 19) * 200 + anim * (0.5 + sr(i * 3) * 0.4) + Math.sin(anim * 0.03 + i) * 10) % 300;
        ctx.fillStyle = ['#bd7a35', '#95542c', '#d9a44a'][i % 3];
        ctx.fillRect(Math.round(px), Math.round(py + 40), 3, 2);
      }
    }
    if (est === 'verao' && ciclo < 0.4) { // vagalumes nas noites de verão
      for (let i = 0; i < 12; i++) {
        const px = 60 + sr(i * 23) * 520 + Math.sin(anim * 0.008 + i * 2.1) * 24;
        const py = 220 + sr(i * 29) * 110 + Math.cos(anim * 0.011 + i * 1.7) * 14;
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
    // sombras de nuvens deslizando pelo campo (profundidade barata e elegante)
    if (!chovendo) {
      ctx.fillStyle = 'rgba(30,50,42,.07)';
      for (const [vel, faixaY, wN, hN] of [[0.22, 210, 170, 46], [0.15, 268, 130, 36]]) {
        const px = (anim * vel) % (W + 300) - 300;
        ctx.beginPath();
        ctx.ellipse(px + wN / 2, faixaY + hN / 2, wN / 2, hN / 2, 0, 0, 7);
        ctx.fill();
      }
    }
  }

  // tonalização ambiente + luzes noturnas + vinheta
  function ambiente(ctx, ciclo, nivel) {
    const noite = Math.max(0, (0.42 - ciclo) / 0.42);       // 0..1
    const tarde = Math.max(0, 1 - Math.abs(ciclo - 0.48) / 0.14);
    if (tarde > 0) {                                        // hora dourada
      ctx.fillStyle = `rgba(255,120,45,${0.16 * tarde})`;
      ctx.fillRect(0, 0, W, H);
    }
    if (noite > 0) {                                        // manto azul da noite
      ctx.fillStyle = `rgba(16,24,58,${0.42 * noite})`;
      ctx.fillRect(0, 0, W, H);
      // estrelas
      ctx.fillStyle = `rgba(240,245,255,${0.85 * noite})`;
      for (let i = 0; i < 60; i++) {
        const px = sr(i * 37) * W, py = sr(i * 41) * 150;
        const cintila = Math.sin(anim * 0.05 + i * 3.3) > -0.4;
        if (cintila) ctx.fillRect(Math.round(px), Math.round(py), i % 7 === 0 ? 2 : 1, i % 7 === 0 ? 2 : 1);
      }
      // janelas acesas com halo quente
      for (const l of luzes) {
        const g = ctx.createRadialGradient(l.x, l.y, 1, l.x, l.y, 14);
        g.addColorStop(0, `rgba(255,190,90,${0.5 * noite})`);
        g.addColorStop(1, 'rgba(255,190,90,0)');
        ctx.fillStyle = g;
        ctx.fillRect(l.x - 14, l.y - 14, 28, 28);
        ctx.fillStyle = `rgba(255,220,130,${0.85 * noite})`;
        ctx.fillRect(l.x - 2, l.y - 2, 4, 4);
      }
      // tochas do portão ganham força na escuridão
      if (nivel >= 3) {
        for (const tx of [297, 345]) {
          const g = ctx.createRadialGradient(tx, 214, 2, tx, 214, 26);
          g.addColorStop(0, `rgba(255,170,70,${0.4 * noite})`);
          g.addColorStop(1, 'rgba(255,170,70,0)');
          ctx.fillStyle = g;
          ctx.fillRect(tx - 26, 188, 52, 52);
        }
      }
    }
    // vinheta sutil
    const v = ctx.createRadialGradient(W / 2, H / 2, H * 0.55, W / 2, H / 2, H * 0.95);
    v.addColorStop(0, 'rgba(20,15,10,0)');
    v.addColorStop(1, 'rgba(20,15,10,.22)');
    ctx.fillStyle = v;
    ctx.fillRect(0, 0, W, H);
  }

  function render(canvas, state) {
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    anim++;
    const nivel = state.terra ? state.terra.nivel : -1;
    const est = estacao(state.mes || 6);
    const pal = RAMPAS[est];
    const chave = nivel + '|' + est + '|' + (estOk() ? 'tiles' : 'proc');
    if (bgKey !== chave || !bg) { bg = desenharEstatico(nivel, pal); bgKey = chave; }
    const ciclo = cicloAtual();
    ctx.drawImage(bg, 0, 0);
    astros(ctx, pal, ciclo);
    desenharDinamico(ctx, state, pal, nivel);
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
