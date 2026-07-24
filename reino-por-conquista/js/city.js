// ============================================================
// PIXEL ART PROCEDURAL DO ASSENTAMENTO — v2
// 480×270, casas de enxaimel, estações do ano, rio com ponte,
// fumaça nas chaminés, pássaros, estandartes, NPCs com sombra.
// Nível -1: acampamento mercenário → 0: tendas → 1: aldeia+paliçada
// → 2: vila+moinho → 3: burgo murado → 4: cidade com torres
// → 5: castelo.
// ============================================================
'use strict';

const Cidade = (() => {
  const W = 480, H = 270;
  let anim = 0;
  let npcs = [];

  // ---------- utilidades ----------
  function P(ctx, x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
  // pseudo-aleatório determinístico (mesma cena a cada frame)
  function sr(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
  function sombra(hex, f) { // escurece cor hex por fator 0..1
    const n = parseInt(hex.slice(1), 16);
    const r = Math.round(((n >> 16) & 255) * f), g = Math.round(((n >> 8) & 255) * f), b = Math.round((n & 255) * f);
    return `rgb(${r},${g},${b})`;
  }

  // ---------- estações ----------
  function estacao(mes) {
    if (mes >= 3 && mes <= 5) return 'primavera';
    if (mes >= 6 && mes <= 8) return 'verao';
    if (mes >= 9 && mes <= 11) return 'outono';
    return 'inverno';
  }
  const PALETAS = {
    primavera: { ceuA: '#8fc3e8', ceuB: '#dcecc8', grama: '#79a655', grama2: '#6d9a4b', arvore: '#4d7c3a', arvore2: '#5f9147', campo: '#7fa050', colina: '#6b9455', neve: false },
    verao:     { ceuA: '#7ab5e0', ceuB: '#f0e2b0', grama: '#8aa64f', grama2: '#7d9a45', arvore: '#48753a', arvore2: '#578a45', campo: '#c9a94f', colina: '#7a9a50', neve: false },
    outono:    { ceuA: '#a8b4c8', ceuB: '#e8cfa0', grama: '#9a9050', grama2: '#8d8348', arvore: '#a5622d', arvore2: '#b8823a', campo: '#8a7440', colina: '#8a8a55', neve: false },
    inverno:   { ceuA: '#b8c4d0', ceuB: '#e8ecf0', grama: '#dfe4e8', grama2: '#d0d8de', arvore: '#5a5248', arvore2: '#6b6258', campo: '#d8dde2', colina: '#c8d0d8', neve: true },
  };

  function seedNpcs(nivel) {
    npcs = [];
    const n = nivel >= 5 ? 18 : nivel >= 4 ? 14 : nivel >= 3 ? 9 : nivel >= 2 ? 5 : nivel >= 1 ? 3 : nivel >= 0 ? 2 : 3;
    for (let i = 0; i < n; i++) {
      npcs.push({
        x: 70 + sr(i * 3 + 1) * 330, y: 196 + sr(i * 7 + 2) * 60,
        vx: (sr(i * 11 + 3) - 0.5) * 0.5,
        pausa: 0,
        roupa: ['#b03a3a', '#3a5a8c', '#c9a227', '#4a7a4a', '#7d4a8c', '#8a5a3a', '#5a7a8a', '#a06a30'][i % 8],
        capuz: sr(i * 13 + 5) < 0.3,
      });
    }
  }

  // ---------- céu e fundo ----------
  function ceu(ctx, pal) {
    const g = ctx.createLinearGradient(0, 0, 0, 150);
    g.addColorStop(0, pal.ceuA); g.addColorStop(1, pal.ceuB);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, 150);
    // sol com halo
    ctx.fillStyle = 'rgba(255,244,200,.35)'; ctx.beginPath(); ctx.arc(400, 38, 26, 0, 7); ctx.fill();
    P(ctx, 391, 29, 18, 18, '#fdf3c0'); P(ctx, 394, 26, 12, 24, '#fdf3c0'); P(ctx, 388, 32, 24, 12, '#fdf3c0');
    P(ctx, 395, 30, 10, 10, '#fffbe0');
    // nuvens em 2 camadas de paralaxe
    nuvem(ctx, (anim * 0.10) % (W + 120) - 100, 30, 1.2);
    nuvem(ctx, (anim * 0.16 + 200) % (W + 120) - 100, 58, 0.9);
    nuvem(ctx, (anim * 0.07 + 340) % (W + 120) - 100, 16, 0.7);
    // pássaros (bando em "v" que cruza de tempos em tempos)
    const bx = (anim * 0.45) % (W + 300) - 150;
    if (bx > -60 && bx < W + 20) {
      ctx.fillStyle = '#3a3a42';
      for (let i = 0; i < 5; i++) {
        const px = bx + i * 12, py = 44 + Math.abs(i - 2) * 5 + Math.sin((anim + i * 9) * 0.25) * 1.5;
        P(ctx, px, py, 2, 1); P(ctx, px - 2, py - 1, 2, 1); P(ctx, px + 2, py - 1, 2, 1);
      }
    }
  }
  function nuvem(ctx, x, y, s) {
    ctx.fillStyle = 'rgba(250,248,240,.92)';
    P(ctx, x, y, 46 * s, 9 * s); P(ctx, x + 8 * s, y - 6 * s, 26 * s, 8 * s); P(ctx, x + 20 * s, y - 10 * s, 14 * s, 6 * s);
    ctx.fillStyle = 'rgba(200,205,215,.5)';
    P(ctx, x + 4 * s, y + 7 * s, 38 * s, 2 * s);
  }

  function montanhas(ctx, pal) {
    // cadeia distante
    ctx.fillStyle = '#8a94a8';
    ctx.beginPath(); ctx.moveTo(0, 132);
    for (let x = 0; x <= W; x += 4) ctx.lineTo(x, 104 + Math.sin(x * 0.021 + 2) * 14 + Math.sin(x * 0.055) * 6);
    ctx.lineTo(W, 132); ctx.fill();
    // picos nevados
    ctx.fillStyle = '#e8ecf2';
    for (const px of [58, 172, 305, 428]) {
      const py = 104 + Math.sin(px * 0.021 + 2) * 14 + Math.sin(px * 0.055) * 6;
      ctx.beginPath(); ctx.moveTo(px - 7, py + 5); ctx.lineTo(px, py - 2); ctx.lineTo(px + 7, py + 5); ctx.fill();
    }
    // colinas próximas
    ctx.fillStyle = pal.colina;
    ctx.beginPath(); ctx.moveTo(0, 152);
    for (let x = 0; x <= W; x += 4) ctx.lineTo(x, 128 + Math.sin(x * 0.014 + 5) * 9);
    ctx.lineTo(W, 152); ctx.fill();
    // linha de floresta
    for (let i = 0; i < 40; i++) {
      const x = i * 12 + sr(i) * 8, y = 128 + Math.sin(x * 0.014 + 5) * 9;
      ctx.fillStyle = i % 2 ? pal.arvore : sombra('#4d7c3a', pal.neve ? 1 : 0.85);
      if (pal.neve) ctx.fillStyle = i % 2 ? '#6b7268' : '#5a6058';
      ctx.beginPath(); ctx.moveTo(x - 4, y + 2); ctx.lineTo(x, y - 7 - sr(i * 3) * 4); ctx.lineTo(x + 4, y + 2); ctx.fill();
    }
  }

  // ---------- chão, rio, estrada ----------
  function chao(ctx, pal) {
    P(ctx, 0, 144, W, H - 144, pal.grama);
    // profundidade: o primeiro plano é mais saturado/escuro que o fundo
    ctx.fillStyle = 'rgba(255,255,255,.08)';
    ctx.fillRect(0, 144, W, 18);
    ctx.fillStyle = 'rgba(20,30,10,.10)';
    ctx.fillRect(0, 246, W, 24);
    ctx.fillStyle = 'rgba(20,30,10,.05)';
    ctx.fillRect(0, 220, W, 26);
    // manchas de grama
    for (let i = 0; i < 90; i++) {
      const x = sr(i * 5) * W, y = 146 + sr(i * 5 + 1) * (H - 150);
      P(ctx, x, y, 3 + sr(i) * 5, 2, pal.grama2);
    }
    // tufos
    if (!pal.neve) for (let i = 0; i < 50; i++) {
      const x = sr(i * 9 + 4) * W, y = 150 + sr(i * 9 + 5) * (H - 156);
      P(ctx, x, y, 1, 3, sombra(pal.grama, 0.8)); P(ctx, x + 2, y + 1, 1, 2, sombra(pal.grama, 0.8));
    }
  }

  function rio(ctx, pal) {
    const yR = 228;
    P(ctx, 0, yR, W, 16, pal.neve ? '#9fb8cc' : '#3f6e94');
    P(ctx, 0, yR, W, 2, pal.neve ? '#c8d8e4' : '#5a8ab0');
    P(ctx, 0, yR + 14, W, 2, sombra('#3f6e94', 0.7));
    // reflexo do céu na superfície
    ctx.fillStyle = pal.neve ? 'rgba(240,246,250,.35)' : 'rgba(140,190,225,.30)';
    ctx.fillRect(0, yR + 1, W, 4);
    // brilho da água animado
    ctx.fillStyle = pal.neve ? '#e0ecf4' : '#7fb0d0';
    for (let i = 0; i < 14; i++) {
      const x = ((i * 41 + anim * (0.4 + (i % 3) * 0.2)) % (W + 30)) - 15;
      P(ctx, x, yR + 3 + (i % 4) * 3, 8 + (i % 3) * 4, 1);
    }
    // cintilância especular
    ctx.fillStyle = 'rgba(255,255,255,.5)';
    for (let i = 0; i < 5; i++) {
      const x = ((i * 97 + anim * 0.8) % (W + 20)) - 10;
      P(ctx, x, yR + 5 + (i % 3) * 4, 2, 1);
    }
    // margens
    P(ctx, 0, yR - 2, W, 2, sombra(pal.grama, 0.75));
  }

  function ponte(ctx) {
    const x = 218, yR = 226;
    P(ctx, x - 4, yR - 2, 52, 5, '#8a7a62');           // tabuleiro
    P(ctx, x - 4, yR - 2, 52, 1, '#a89878');
    for (let i = 0; i < 6; i++) P(ctx, x + i * 9, yR + 3, 3, 13, '#6b5d48'); // pilares
    P(ctx, x - 4, yR - 6, 52, 2, '#6b5d48');           // corrimão
    for (let i = 0; i < 7; i++) P(ctx, x - 3 + i * 8, yR - 5, 2, 4, '#6b5d48');
  }

  function estrada(ctx, pal, nivel) {
    const cor = nivel >= 3 ? '#a09788' : '#b09468';
    // afunila em direção ao horizonte (ou ao portão)
    const topoY = nivel >= 1 ? 150 : 158;
    const topoMeiaLarg = nivel >= 1 ? 14 : 5;
    ctx.fillStyle = cor;
    ctx.beginPath();
    ctx.moveTo(240 - topoMeiaLarg, topoY); ctx.lineTo(240 + topoMeiaLarg, topoY);
    ctx.lineTo(262, 226); ctx.lineTo(218, 226); ctx.closePath(); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(214, 244); ctx.lineTo(266, 244);
    ctx.lineTo(282, 270); ctx.lineTo(198, 270); ctx.closePath(); ctx.fill();
    // bordas desgastadas
    ctx.fillStyle = sombra(cor, 0.82);
    ctx.beginPath();
    ctx.moveTo(240 - topoMeiaLarg, topoY); ctx.lineTo(240 - topoMeiaLarg + 2, topoY);
    ctx.lineTo(221, 226); ctx.lineTo(218, 226); ctx.closePath(); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(240 + topoMeiaLarg, topoY); ctx.lineTo(240 + topoMeiaLarg - 2, topoY);
    ctx.lineTo(259, 226); ctx.lineTo(262, 226); ctx.closePath(); ctx.fill();
    // pedras do calçamento
    if (nivel >= 3) {
      ctx.fillStyle = '#8f8678';
      for (let i = 0; i < 26; i++) {
        const t = sr(i * 7); const y = 152 + t * 116;
        if (y > 224 && y < 246) continue;
        P(ctx, 226 + sr(i * 5) * 26, y, 4, 2);
      }
    } else {
      // sulcos de carroça na terra batida
      ctx.fillStyle = sombra(cor, 0.85);
      P(ctx, 231, topoY + 8, 2, 218 - topoY); P(ctx, 247, topoY + 8, 2, 218 - topoY);
    }
  }

  // ---------- vegetação e detalhes ----------
  function arvore(ctx, x, y, pal, i) {
    P(ctx, x - 2, y - 8, 4, 10, '#5d4428');
    P(ctx, x - 1, y - 8, 1, 10, '#6f5433');
    if (pal.neve && estAtual === 'inverno') { // galhos nus com neve
      P(ctx, x - 1, y - 20, 2, 12, '#5d4428');
      P(ctx, x - 7, y - 13, 6, 1, '#5d4428'); P(ctx, x - 7, y - 15, 2, 3, '#5d4428');
      P(ctx, x + 1, y - 16, 7, 1, '#5d4428'); P(ctx, x + 6, y - 19, 2, 4, '#5d4428');
      P(ctx, x - 4, y - 18, 4, 1, '#5d4428'); P(ctx, x - 4, y - 20, 1, 3, '#5d4428');
      P(ctx, x + 1, y - 21, 3, 1, '#5d4428');
      P(ctx, x - 7, y - 14, 3, 1, '#eef2f6'); P(ctx, x + 3, y - 17, 4, 1, '#eef2f6');
      P(ctx, x - 1, y - 21, 2, 1, '#eef2f6');
      return;
    }
    const c1 = i % 2 ? pal.arvore : pal.arvore2;
    P(ctx, x - 8, y - 16, 16, 8, c1);
    P(ctx, x - 6, y - 21, 12, 7, c1);
    P(ctx, x - 3, y - 24, 7, 5, sombra(c1, 1.15 > 1 ? 1 : 1));
    P(ctx, x - 6, y - 21, 4, 3, '#ffffff22' ? sombra(c1, 1.2) : c1);
    P(ctx, x - 8, y - 10, 16, 2, sombra(c1, 0.75));
    if (pal.neve) { P(ctx, x - 6, y - 22, 12, 2, '#eef2f6'); P(ctx, x - 8, y - 16, 16, 2, '#eef2f6'); }
  }

  function campo(ctx, x, y, w, h, pal) {
    // terra arada com sulcos horizontais (leitura de chão em perspectiva)
    P(ctx, x, y, w, h, '#6b5638');
    if (!pal.neve) {
      for (let ry = 2; ry < h - 1; ry += 3) {
        P(ctx, x + 1, y + ry, w - 2, 1, sombra(pal.campo, 0.9));
        // pés da plantação espetando dos sulcos
        for (let rx = 2 + (ry % 2) * 2; rx < w - 2; rx += 4)
          P(ctx, x + rx, y + ry - 1, 1, 2, pal.campo);
      }
    } else {
      P(ctx, x, y, w, h, '#cfd6dc');
      for (let ry = 2; ry < h - 1; ry += 3) P(ctx, x + 1, y + ry, w - 2, 1, '#b0bac2');
    }
    // cerca baixa
    P(ctx, x - 1, y - 2, w + 2, 1, '#7a5c38');
    for (let i = 0; i <= w; i += 7) P(ctx, x + i - 1, y - 4, 1, 4, '#6b4f30');
  }

  function fumaca(ctx, x, y, seed) {
    for (let i = 0; i < 4; i++) {
      const t = ((anim * 0.5 + i * 22 + seed * 13) % 88) / 88;
      const fx = x + Math.sin((t * 6 + seed) * 1.8) * (2 + t * 5);
      const fy = y - t * 26;
      const s = 1 + t * 3.2;
      ctx.fillStyle = `rgba(232,230,224,${0.55 * (1 - t)})`;
      ctx.fillRect(Math.round(fx - s / 2), Math.round(fy - s / 2), Math.round(s), Math.round(s));
    }
  }

  // ---------- construções ----------
  // casa de enxaimel (paredes creme + vigas escuras) ou pedra
  function casa(ctx, x, y, w, h, opts) {
    const o = opts || {};
    const parede = o.pedra ? '#a8a095' : '#e2d4b0';
    const viga = '#5a4228';
    // sombra projetada
    P(ctx, x + 2, y + h, w, 3, 'rgba(40,30,20,.25)');
    // parede
    P(ctx, x, y, w, h, parede);
    P(ctx, x + w - 2, y, 2, h, sombra(parede, 0.8));
    P(ctx, x, y, w, 1, sombra(parede, 1.1 > 1 ? 1 : 1));
    if (o.pedra) { // juntas de pedra
      ctx.fillStyle = sombra(parede, 0.85);
      for (let ry = 3; ry < h; ry += 5)
        for (let rx = (ry % 10 === 3 ? 2 : 6); rx < w - 2; rx += 9) P(ctx, x + rx, y + ry, 4, 1);
    } else { // vigas de enxaimel
      P(ctx, x, y, w, 2, viga); P(ctx, x, y + h - 2, w, 2, viga);
      P(ctx, x, y, 2, h, viga); P(ctx, x + w - 2, y, 2, h, viga);
      P(ctx, x + Math.round(w / 2) - 1, y, 2, h, viga);
      // diagonais
      for (let i = 0; i < Math.round(w / 2) - 3; i++) {
        P(ctx, x + 2 + i, y + 2 + Math.round(i * (h - 4) / (w / 2 - 3)), 1, 1, viga);
        P(ctx, x + w - 3 - i, y + 2 + Math.round(i * (h - 4) / (w / 2 - 3)), 1, 1, viga);
      }
    }
    // telhado (palha ou telha)
    const beira = 3;
    const telha = o.pedra ? '#7d4a3a' : '#a9862d';
    ctx.fillStyle = telha;
    ctx.beginPath();
    ctx.moveTo(x - beira, y + 1); ctx.lineTo(x + w / 2, y - h * 0.6); ctx.lineTo(x + w + beira, y + 1);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = sombra(telha, 0.8);
    ctx.beginPath();
    ctx.moveTo(x + w / 2, y - h * 0.6); ctx.lineTo(x + w + beira, y + 1); ctx.lineTo(x + w / 2 + 2, y + 1);
    ctx.closePath(); ctx.fill();
    // linhas do telhado
    ctx.fillStyle = sombra(telha, 0.85);
    for (let i = 1; i <= 3; i++) {
      const ty = y + 1 - (h * 0.6) * i / 4;
      const half = (beira + w / 2) * i / 4;
      P(ctx, x + w / 2 - half, ty, half * 2, 1);
    }
    if (o.neve) {
      ctx.fillStyle = '#eef2f6';
      ctx.beginPath();
      ctx.moveTo(x - beira, y); ctx.lineTo(x + w / 2, y - h * 0.6 - 1); ctx.lineTo(x + w + beira, y);
      ctx.lineTo(x + w + beira - 2, y + 2 - 2); ctx.lineTo(x + w / 2, y - h * 0.6 + 2); ctx.lineTo(x - beira + 2, y);
      ctx.closePath(); ctx.fill();
    }
    // porta
    P(ctx, x + w / 2 - 3, y + h - 8, 6, 8, '#3a2d1d');
    P(ctx, x + w / 2 - 3, y + h - 8, 6, 1, '#241a10');
    P(ctx, x + w / 2 + 1, y + h - 5, 1, 1, '#c9a227'); // maçaneta
    // janelas iluminadas (uma só nas casas estreitas, com moldura e caixilho)
    const janelas = w >= 30 ? [x + 5, x + w - 9] : [x + 4];
    for (const wx of janelas) {
      P(ctx, wx - 1, y + 5, 5, 6, sombra(parede, 0.7));
      P(ctx, wx, y + 6, 3, 4, '#f5d060');
      P(ctx, wx + 1, y + 6, 1, 4, sombra('#f5d060', 0.75));
    }
    // chaminé + fumaça
    if (o.chamine) {
      P(ctx, x + w - 7, y - h * 0.45, 4, h * 0.35, '#8a8078');
      P(ctx, x + w - 8, y - h * 0.45 - 2, 6, 2, '#6d655e');
      fumaca(ctx, x + w - 5, y - h * 0.45 - 3, x);
    }
  }

  function tenda(ctx, x, y, cor) {
    P(ctx, x + 2, y + 15, 20, 2, 'rgba(40,30,20,.2)');
    ctx.fillStyle = cor || '#b0925f';
    ctx.beginPath(); ctx.moveTo(x, y + 15); ctx.lineTo(x + 11, y); ctx.lineTo(x + 22, y + 15); ctx.closePath(); ctx.fill();
    ctx.fillStyle = sombra(cor || '#b0925f', 0.78);
    ctx.beginPath(); ctx.moveTo(x + 11, y); ctx.lineTo(x + 22, y + 15); ctx.lineTo(x + 11, y + 15); ctx.closePath(); ctx.fill();
    P(ctx, x + 10, y - 3, 1, 4, '#5d4428');
    P(ctx, x + 8, y + 7, 5, 8, '#4a3826');
    P(ctx, x + 9, y + 8, 3, 7, '#2d2418');
  }

  function moinho(ctx, x, y) {
    P(ctx, x + 2, y + 34, 22, 3, 'rgba(40,30,20,.25)');
    // base de pedra afunilada
    ctx.fillStyle = '#9a9288';
    ctx.beginPath(); ctx.moveTo(x, y + 34); ctx.lineTo(x + 4, y); ctx.lineTo(x + 18, y); ctx.lineTo(x + 22, y + 34); ctx.closePath(); ctx.fill();
    ctx.fillStyle = sombra('#9a9288', 0.82);
    ctx.beginPath(); ctx.moveTo(x + 11, y); ctx.lineTo(x + 18, y); ctx.lineTo(x + 22, y + 34); ctx.lineTo(x + 11, y + 34); ctx.closePath(); ctx.fill();
    ctx.fillStyle = sombra('#9a9288', 0.88);
    for (let ry = 4; ry < 32; ry += 5) P(ctx, x + 3 + (ry % 10 === 4 ? 2 : 5), y + ry, 5, 1);
    // topo
    ctx.fillStyle = '#7d4a3a';
    ctx.beginPath(); ctx.moveTo(x - 1, y + 1); ctx.lineTo(x + 11, y - 9); ctx.lineTo(x + 23, y + 1); ctx.closePath(); ctx.fill();
    // porta e janela
    P(ctx, x + 8, y + 26, 6, 8, '#3a2d1d');
    P(ctx, x + 9, y + 8, 4, 5, '#2d2418'); P(ctx, x + 10, y + 9, 2, 3, '#f5d060');
    // pás com treliça, girando
    ctx.save(); ctx.translate(x + 11, y + 2); ctx.rotate(anim * 0.018);
    for (let i = 0; i < 4; i++) {
      ctx.rotate(Math.PI / 2);
      ctx.fillStyle = '#e8dcc0'; ctx.fillRect(-2, 2, 4, 24);
      ctx.fillStyle = '#b8a880';
      for (let j = 4; j < 24; j += 4) ctx.fillRect(-2, j, 4, 1);
      ctx.fillRect(-2, 2, 1, 24);
    }
    ctx.restore();
    P(ctx, x + 10, y + 1, 3, 3, '#5a4228');
  }

  function barraca(ctx, x, y, cor) {
    P(ctx, x + 1, y + 12, 18, 2, 'rgba(40,30,20,.2)');
    // postes
    P(ctx, x, y, 2, 12, '#6b4f30'); P(ctx, x + 16, y, 2, 12, '#6b4f30');
    // toldo listrado
    for (let i = 0; i < 18; i += 3) {
      ctx.fillStyle = (i / 3) % 2 ? '#efe6cf' : cor;
      ctx.beginPath();
      ctx.moveTo(x - 1 + i, y - 4); ctx.lineTo(x + 2 + i, y - 4); ctx.lineTo(x + 2 + i, y + 1); ctx.lineTo(x - 1 + i, y + 1);
      ctx.fill();
      P(ctx, x - 1 + i, y + 1, 3, 2, (i / 3) % 2 ? sombra('#efe6cf', 0.85) : sombra(cor, 0.8));
    }
    // bancada com mercadorias
    P(ctx, x + 1, y + 6, 16, 5, '#8a6b45');
    P(ctx, x + 1, y + 6, 16, 1, '#a08052');
    P(ctx, x + 3, y + 4, 3, 2, '#c94f4f'); P(ctx, x + 7, y + 4, 3, 2, '#d8a028');
    P(ctx, x + 11, y + 4, 3, 2, '#5a8a4a'); P(ctx, x + 14, y + 4, 2, 2, '#b8b0a0');
  }

  function palicada(ctx, y, neve) {
    for (let x = 2; x < W - 2; x += 7) {
      if (x > 216 && x < 262) continue; // vão do portão
      const hh = 16 + (x % 3);
      P(ctx, x, y - hh + 14, 5, hh, '#7a5c38');
      P(ctx, x, y - hh + 14, 1, hh, '#8f6d44');
      ctx.fillStyle = '#8a6b45';
      ctx.beginPath(); ctx.moveTo(x, y - hh + 14); ctx.lineTo(x + 2.5, y - hh + 9); ctx.lineTo(x + 5, y - hh + 14); ctx.fill();
      if (neve) P(ctx, x, y - hh + 13, 5, 1, '#eef2f6');
    }
    // portão de madeira com travessas
    P(ctx, 216, y - 6, 5, 22, '#5d4428'); P(ctx, 258, y - 6, 5, 22, '#5d4428');
    P(ctx, 216, y - 8, 47, 3, '#6b4f30');
    P(ctx, 222, y - 4, 35, 18, '#7a5c38');
    P(ctx, 222, y + 2, 35, 2, '#5d4428'); P(ctx, 222, y + 8, 35, 2, '#5d4428');
  }

  function muroPedra(ctx, y, opts) {
    const o = opts || {};
    const base = '#96918a';
    // corpo do muro
    P(ctx, 0, y, W, 18, base);
    P(ctx, 0, y, W, 2, sombra(base, 1.1 > 1 ? 1 : 1));
    P(ctx, 0, y + 16, W, 2, sombra(base, 0.75));
    // padrão de blocos
    ctx.fillStyle = sombra(base, 0.85);
    for (let ry = 3; ry < 16; ry += 5)
      for (let rx = (ry % 10 === 3 ? 3 : 9); rx < W; rx += 12) P(ctx, rx, y + ry, 6, 1);
    // ameias
    for (let x = 0; x < W; x += 10) {
      if (x > 210 && x < 268) continue;
      P(ctx, x, y - 5, 6, 5, base);
      P(ctx, x, y - 5, 6, 1, sombra(base, 1.08 > 1 ? 1 : 1));
      if (o.neve) P(ctx, x, y - 6, 6, 1, '#eef2f6');
    }
    // portão em arco com gradeamento
    P(ctx, 212, y - 14, 56, 32, sombra(base, 0.9));
    ctx.fillStyle = '#2d261e';
    ctx.beginPath();
    ctx.moveTo(224, y + 18); ctx.lineTo(224, y - 2);
    ctx.quadraticCurveTo(240, y - 12, 256, y - 2);
    ctx.lineTo(256, y + 18); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#5a4a35'; // grade levadiça
    for (let gx = 227; gx < 256; gx += 6) P(ctx, gx, y - 6, 2, 24);
    P(ctx, 224, y - 1, 32, 2, '#5a4a35'); P(ctx, 224, y + 7, 32, 2, '#5a4a35');
    // torres do portão
    if (o.torres) {
      for (const tx of [196, 268]) {
        P(ctx, tx + 2, y + 16, 18, 3, 'rgba(40,30,20,.25)');
        P(ctx, tx, y - 26, 16, 44, '#9a958d');
        P(ctx, tx + 13, y - 26, 3, 44, sombra('#9a958d', 0.8));
        ctx.fillStyle = sombra('#9a958d', 0.87);
        for (let ry = 3; ry < 42; ry += 5) P(ctx, tx + (ry % 10 === 3 ? 2 : 6), y - 26 + ry, 5, 1);
        // telhado cônico
        ctx.fillStyle = '#7d3b3b';
        ctx.beginPath(); ctx.moveTo(tx - 3, y - 25); ctx.lineTo(tx + 8, y - 40); ctx.lineTo(tx + 19, y - 25); ctx.closePath(); ctx.fill();
        if (o.neve) { ctx.fillStyle = '#eef2f6'; ctx.beginPath(); ctx.moveTo(tx - 3, y - 25); ctx.lineTo(tx + 8, y - 40); ctx.lineTo(tx + 19, y - 25); ctx.lineTo(tx + 16, y - 25); ctx.lineTo(tx + 8, y - 37); ctx.lineTo(tx, y - 25); ctx.closePath(); ctx.fill(); }
        P(ctx, tx + 6, y - 14, 4, 6, '#2d2418'); P(ctx, tx + 7, y - 13, 2, 4, '#f5d060');
        // estandarte tremulando
        P(ctx, tx + 7, y - 52, 1, 12, '#4a3826');
        ctx.fillStyle = o.corBandeira || '#8b2635';
        const ondC = Math.sin(anim * 0.09 + tx) * 2;
        ctx.beginPath();
        ctx.moveTo(tx + 8, y - 52); ctx.lineTo(tx + 20 + ondC, y - 50); ctx.lineTo(tx + 8, y - 46);
        ctx.closePath(); ctx.fill();
      }
    }
  }

  function castelo(ctx, x, y, neve) {
    // x,y = canto sup. esquerdo do corpo central (~90 de largura)
    const pedra = '#b0aca3', pedraE = sombra('#b0aca3', 0.82);
    P(ctx, x + 4, y + 58, 86, 4, 'rgba(40,30,20,.28)');
    // corpo
    P(ctx, x, y + 14, 90, 44, pedra);
    P(ctx, x + 84, y + 14, 6, 44, pedraE);
    ctx.fillStyle = sombra(pedra, 0.88);
    for (let ry = 3; ry < 42; ry += 5)
      for (let rx = (ry % 10 === 3 ? 3 : 8); rx < 86; rx += 11) P(ctx, x + rx, y + 14 + ry, 5, 1);
    // ameias do corpo
    for (let i = 0; i < 90; i += 9) P(ctx, x + i, y + 10, 5, 5, pedra);
    // torres laterais
    for (const t of [{ tx: x - 16, alt: 66 }, { tx: x + 84, alt: 66 }]) {
      P(ctx, t.tx, y + 58 - t.alt + 14, 22, t.alt, '#a5a198');
      P(ctx, t.tx + 18, y + 58 - t.alt + 14, 4, t.alt, sombra('#a5a198', 0.8));
      ctx.fillStyle = sombra('#a5a198', 0.87);
      for (let ry = 4; ry < t.alt - 2; ry += 5) P(ctx, t.tx + (ry % 10 === 4 ? 3 : 8), y + 72 - t.alt + ry, 6, 1);
      // telhado cônico azul-ardósia
      ctx.fillStyle = '#4a5568';
      ctx.beginPath(); ctx.moveTo(t.tx - 4, y + 73 - t.alt); ctx.lineTo(t.tx + 11, y + 52 - t.alt); ctx.lineTo(t.tx + 26, y + 73 - t.alt); ctx.closePath(); ctx.fill();
      if (neve) { ctx.fillStyle = '#eef2f6'; ctx.beginPath(); ctx.moveTo(t.tx - 4, y + 73 - t.alt); ctx.lineTo(t.tx + 11, y + 52 - t.alt); ctx.lineTo(t.tx + 26, y + 73 - t.alt); ctx.lineTo(t.tx + 22, y + 73 - t.alt); ctx.lineTo(t.tx + 11, y + 56 - t.alt); ctx.lineTo(t.tx, y + 73 - t.alt); ctx.closePath(); ctx.fill(); }
      P(ctx, t.tx + 8, y + 80 - t.alt, 5, 7, '#2d2418'); P(ctx, t.tx + 9, y + 81 - t.alt, 3, 5, '#f5d060');
      P(ctx, t.tx + 8, y + 94 - t.alt, 5, 7, '#2d2418');
    }
    // torre de menagem central
    P(ctx, x + 30, y - 18, 30, 34, '#bab6ad');
    P(ctx, x + 55, y - 18, 5, 34, sombra('#bab6ad', 0.8));
    ctx.fillStyle = sombra('#bab6ad', 0.88);
    for (let ry = 3; ry < 32; ry += 5) P(ctx, x + 32 + (ry % 10 === 3 ? 2 : 8), y - 18 + ry, 6, 1);
    for (let i = 0; i < 30; i += 7) P(ctx, x + 30 + i, y - 23, 4, 5, '#bab6ad');
    P(ctx, x + 41, y - 12, 6, 8, '#2d2418'); P(ctx, x + 42, y - 11, 4, 6, '#f5d060');
    // estandarte real dourado
    P(ctx, x + 44, y - 40, 2, 17, '#4a3826');
    ctx.fillStyle = '#c9a227';
    const ond = Math.sin(anim * 0.08) * 3;
    ctx.beginPath(); ctx.moveTo(x + 46, y - 40); ctx.lineTo(x + 62 + ond, y - 36); ctx.lineTo(x + 46, y - 31); ctx.closePath(); ctx.fill();
    P(ctx, x + 48, y - 38, 3, 3, '#8b2635');
    // portão do castelo
    ctx.fillStyle = '#2d261e';
    ctx.beginPath(); ctx.moveTo(x + 36, y + 58); ctx.lineTo(x + 36, y + 42);
    ctx.quadraticCurveTo(x + 45, y + 34, x + 54, y + 42);
    ctx.lineTo(x + 54, y + 58); ctx.closePath(); ctx.fill();
    P(ctx, x + 38, y + 44, 2, 14, '#5a4a35'); P(ctx, x + 44, y + 40, 2, 18, '#5a4a35'); P(ctx, x + 50, y + 44, 2, 14, '#5a4a35');
    // janelas do corpo
    for (const wx of [x + 10, x + 24, x + 66, x + 78]) {
      P(ctx, wx, y + 24, 5, 8, '#2d2418'); P(ctx, wx + 1, y + 25, 3, 6, '#f5d060');
    }
    if (neve) { P(ctx, x, y + 13, 90, 2, '#eef2f6'); for (let i = 0; i < 90; i += 9) P(ctx, x + i, y + 9, 5, 1, '#eef2f6'); }
  }

  function guarda(ctx, x, y) {
    P(ctx, x + 1, y + 10, 4, 1, 'rgba(40,30,20,.3)');
    P(ctx, x, y, 4, 4, '#c8c4bc');     // elmo
    P(ctx, x + 1, y + 1, 2, 2, '#d8b090');
    P(ctx, x, y + 4, 4, 5, '#8a8478'); // cota
    P(ctx, x + 4, y - 2, 1, 12, '#6b4f30'); // lança
    P(ctx, x + 3.5, y - 4, 2, 3, '#c8c4bc');
  }

  function fogueira(ctx, x, y) {
    P(ctx, x - 4, y + 3, 12, 2, sombra('#7a5c38', 0.7));
    P(ctx, x - 3, y + 2, 4, 2, '#6b4f30'); P(ctx, x + 2, y + 2, 4, 2, '#6b4f30');
    const fl = Math.sin(anim * 0.3) * 1.5;
    P(ctx, x, y - 2 + fl * 0.3, 4, 4, '#d86a2d');
    P(ctx, x + 1, y - 4 + fl * 0.5, 2, 4, '#f5a03c');
    P(ctx, x + 1.5, y - 5 + fl * 0.6, 1, 2, '#fbd060');
    fumaca(ctx, x + 2, y - 6, x * 0.7);
  }

  function npcsDesenhar(ctx) {
    npcs.sort((a, b) => a.y - b.y);
    for (const n of npcs) {
      if (n.pausa > 0) { n.pausa--; }
      else {
        n.x += n.vx;
        if (Math.random() < 0.004) n.pausa = 60 + Math.random() * 90;
        if (Math.random() < 0.006) n.vx = (Math.random() - 0.5) * 0.5;
        if (n.x < 55) n.vx = Math.abs(n.vx); if (n.x > 420) n.vx = -Math.abs(n.vx);
        // não andar dentro do rio
        if (n.y > 222 && n.y < 250) n.y = 218;
      }
      const passo = n.pausa > 0 ? 0 : Math.floor(anim / 9 + n.x) % 2;
      P(ctx, n.x, n.y + 8, 5, 1, 'rgba(40,30,20,.3)');            // sombra
      P(ctx, n.x + 1, n.y, 3, 3, '#d8b090');                       // cabeça
      if (n.capuz) { P(ctx, n.x, n.y - 1, 5, 2, sombra(n.roupa, 0.7)); P(ctx, n.x, n.y, 1, 2, sombra(n.roupa, 0.7)); }
      P(ctx, n.x, n.y + 3, 5, 4, n.roupa);                         // túnica
      P(ctx, n.x, n.y + 3, 1, 4, sombra(n.roupa, 0.8));
      P(ctx, n.x + passo, n.y + 7, 2, 2, '#3a2d1d');               // pernas
      P(ctx, n.x + 3 - passo, n.y + 7, 2, 2, '#3a2d1d');
    }
  }

  // ---------- cena por nível ----------
  let estAtual = 'verao';

  function render(canvas, state) {
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    anim++;
    const nivel = state.terra ? state.terra.nivel : -1;
    estAtual = estacao(state.mes || 6);
    const pal = PALETAS[estAtual];

    ceu(ctx, pal);
    montanhas(ctx, pal);
    chao(ctx, pal);

    // castelo fica ATRÁS do muro (fundo, centro)
    if (nivel >= 5) castelo(ctx, 195, 78, pal.neve);

    rio(ctx, pal);
    ponte(ctx);
    estrada(ctx, pal, Math.max(0, nivel));

    // árvores de fundo
    arvore(ctx, 30, 168, pal, 1); arvore(ctx, 452, 172, pal, 2);
    if (nivel < 3) { arvore(ctx, 120, 160, pal, 3); arvore(ctx, 372, 162, pal, 4); }

    if (nivel < 0) { // acampamento mercenário
      tenda(ctx, 130, 178, '#8a6b45'); tenda(ctx, 300, 192, '#7a6248');
      tenda(ctx, 92, 204, '#93765a'); tenda(ctx, 350, 206, '#8a6b45');
      fogueira(ctx, 200, 200);
      // toras para sentar em volta do fogo
      P(ctx, 186, 208, 10, 3, '#6b4f30'); P(ctx, 210, 206, 10, 3, '#6b4f30');
      // carroça com rodas raiadas
      P(ctx, 328, 216, 20, 9, '#6b4f30'); P(ctx, 329, 214, 18, 3, '#7d5c3a');
      P(ctx, 330, 218, 16, 2, sombra('#6b4f30', 0.8));
      for (const rx of [330, 342]) {
        P(ctx, rx, 223, 6, 6, '#3a2d1d'); P(ctx, rx + 2, 223, 2, 6, '#5a4a35'); P(ctx, rx, 225, 6, 2, '#5a4a35');
      }
      P(ctx, 348, 217, 8, 2, '#5a4a35'); // varal da carroça
      // estandarte da companhia
      P(ctx, 158, 172, 2, 30, '#4a3826');
      ctx.fillStyle = '#7d3b3b';
      const om = Math.sin(anim * 0.1) * 2;
      ctx.beginPath(); ctx.moveTo(160, 172); ctx.lineTo(174 + om, 176); ctx.lineTo(160, 181); ctx.closePath(); ctx.fill();
      // rack de lanças e escudo
      P(ctx, 270, 190, 14, 2, '#6b4f30');
      for (const lx of [272, 276, 280]) { P(ctx, lx, 178, 1, 14, '#8a6b45'); P(ctx, lx - 0.5, 176, 2, 3, '#b8b4ac'); }
      P(ctx, 258, 196, 7, 8, '#7d3b3b'); P(ctx, 260, 198, 3, 4, '#c9a227'); // escudo encostado
      // boneco de treino
      P(ctx, 118, 214, 2, 12, '#6b4f30'); P(ctx, 112, 216, 14, 2, '#6b4f30');
      P(ctx, 116, 210, 6, 5, '#a08a5c'); P(ctx, 117, 211, 4, 3, '#8a7448');
      npcsDesenhar(ctx);
      return;
    }

    // campos de cultivo
    if (nivel >= 1) {
      campo(ctx, 16, 196, 44, 18, pal); campo(ctx, 66, 206, 40, 16, pal);
      campo(ctx, 380, 194, 44, 18, pal); campo(ctx, 424, 210, 40, 16, pal);
    }

    if (nivel === 0) {
      tenda(ctx, 120, 176, '#b0925f'); tenda(ctx, 310, 188, '#a08a5c');
      tenda(ctx, 160, 206, '#93765a'); tenda(ctx, 350, 214, '#b0925f');
      fogueira(ctx, 250, 196);
    }

    // muralhas
    if (nivel === 1 || nivel === 2) palicada(ctx, 152, pal.neve);
    if (nivel >= 3) muroPedra(ctx, 148, { torres: nivel >= 4, neve: pal.neve, corBandeira: '#8b2635' });

    // construções
    if (nivel >= 1) {
      casa(ctx, 96, 178, 38, 22, { chamine: true, neve: pal.neve });
      casa(ctx, 326, 186, 34, 20, { neve: pal.neve });
      casa(ctx, 144, 204, 32, 19, { neve: pal.neve });
    }
    if (nivel >= 2) {
      moinho(ctx, 44, 152);
      casa(ctx, 292, 212, 34, 20, { chamine: true, neve: pal.neve });
      casa(ctx, 382, 172, 32, 19, { neve: pal.neve });
    }
    if (nivel >= 3) {
      casa(ctx, 96, 178, 38, 22, { pedra: true, chamine: true, neve: pal.neve });
      casa(ctx, 326, 186, 34, 20, { pedra: true, neve: pal.neve });
      barraca(ctx, 178, 196, '#a03a3a'); barraca(ctx, 284, 190, '#2d4a6b');
      guarda(ctx, 216, 158); guarda(ctx, 260, 158);
    }
    if (nivel >= 4) {
      barraca(ctx, 148, 216, '#b8862d'); barraca(ctx, 318, 220, '#3e5f3e');
      casa(ctx, 56, 210, 32, 19, { pedra: true, neve: pal.neve });
      casa(ctx, 390, 212, 32, 19, { pedra: true, chamine: true, neve: pal.neve });
    }

    npcsDesenhar(ctx);
  }

  // cena-vitrine para a tela de título (castelo no verão)
  function renderShowcase(canvas) {
    if (!npcs.length) seedNpcs(5);
    render(canvas, { terra: { nivel: 5 }, mes: 6 });
  }

  return { render, renderShowcase, seedNpcs };
})();
