// ============================================================
// RETRATOS PROCEDURAIS 64×64
// Cada NPC tem um rosto único em pixel art: pele, cabelo, barba,
// coroa/capuz/elmo, roupa com a cor do reino. O humor do retrato
// muda com a relação (raiva, neutro, simpatia) e os olhos piscam.
// ============================================================
'use strict';

const Retratos = (() => {
  const S = 64;

  // paleta de tons
  const PELES = ['#e8c39a', '#d9a97c', '#c68e5e', '#a86f47', '#8a5632'];
  const CABELOS = ['#2d2018', '#4a3421', '#6b4a2d', '#8a6b45', '#b0925f', '#c9c2b8', '#e8e2d4', '#7d3b2d', '#d8b040'];

  // parâmetros curados por personagem
  const FICHAS = {
    rei_valdria:  { pele: 0, cabelo: 5, estilo: 'curto', barba: 'cheia', chapeu: 'coroa', roupa: '#8b2635', olhos: '#4a6b8a', cicatriz: false, idade: 'velho' },
    rei_morvane:  { pele: 0, cabelo: 0, estilo: 'longo', barba: null,    chapeu: 'tiara', roupa: '#2d4a6b', olhos: '#3a3a42', fem: true, idade: 'adulto' },
    rei_soleara:  { pele: 1, cabelo: 2, estilo: 'curto', barba: 'cavanhaque', chapeu: 'coroa', roupa: '#b8862d', olhos: '#5a4228', gordo: true, idade: 'adulto' },
    rei_thornmar: { pele: 0, cabelo: 2, estilo: 'medio', barba: 'cheia', chapeu: 'coroa', roupa: '#3e5f3e', olhos: '#4a6b4a', idade: 'adulto' },
    rei_ashkar:   { pele: 2, cabelo: 0, estilo: 'raspado', barba: 'cheia', chapeu: 'coroa_espinho', roupa: '#6b3a2d', olhos: '#2d2018', cicatriz: true, idade: 'adulto' },
    rei_lysande:  { pele: 0, cabelo: 8, estilo: 'longo', barba: null,    chapeu: 'tiara', roupa: '#5a3a6b', olhos: '#4a6b8a', fem: true, idade: 'jovem' },
    taverneiro:   { pele: 1, cabelo: 3, estilo: 'careca', barba: 'bigode', chapeu: null, roupa: '#6b4a2d', olhos: '#4a3421', gordo: true, avental: true, idade: 'adulto' },
    capitao:      { pele: 1, cabelo: 0, estilo: 'coque', barba: null,    chapeu: 'elmo', roupa: '#5a5f66', olhos: '#3a3a42', fem: true, cicatriz: true, idade: 'adulto' },
    espiao:       { pele: 3, cabelo: 0, estilo: 'curto', barba: 'rala',  chapeu: 'capuz', roupa: '#2d2a33', olhos: '#6b6255', sombra: true, idade: 'adulto' },
    // líderes de clãs mercenários
    cla_lobos:    { pele: 0, cabelo: 4, estilo: 'longo', barba: 'trancada', chapeu: 'pelo', roupa: '#5a4a3a', olhos: '#8a6b30', cicatriz: true, idade: 'adulto' },
    cla_corvos:   { pele: 2, cabelo: 0, estilo: 'longo', barba: null,    chapeu: 'capuz', roupa: '#33383f', olhos: '#4a5a2d', fem: true, pintura: '#2d3a45', idade: 'adulto' },
    cla_estepe:   { pele: 3, cabelo: 0, estilo: 'rabo',  barba: 'bigode_longo', chapeu: null, roupa: '#7a5a30', olhos: '#2d2018', pintura: '#8b2635', idade: 'adulto' },
    cla_machados: { pele: 0, cabelo: 6, estilo: 'longo', barba: 'gelo',  chapeu: 'elmo_chifre', roupa: '#4a5560', olhos: '#5a7a8a', idade: 'velho' },
  };

  function hash(str) { let h = 0; for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) | 0; return Math.abs(h); }

  function fichaDe(id) {
    if (FICHAS[id]) return FICHAS[id];
    const h = hash(id); // NPC desconhecido: gera determinístico
    return { pele: h % PELES.length, cabelo: (h >> 2) % CABELOS.length,
             estilo: ['curto', 'medio', 'longo'][(h >> 4) % 3],
             barba: (h >> 6) % 3 === 0 ? 'cheia' : null, chapeu: null,
             roupa: '#' + ((h & 0x7f7f7f) | 0x303030).toString(16).padStart(6, '0'),
             olhos: '#3a3a42', idade: 'adulto' };
  }

  function P(ctx, x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(x, y, w, h); }
  function esc(hex, f) {
    const n = parseInt(hex.slice(1), 16);
    return `rgb(${Math.round(((n >> 16) & 255) * f)},${Math.round(((n >> 8) & 255) * f)},${Math.round((n & 255) * f)})`;
  }

  // humor: 'raiva' | 'neutro' | 'feliz'
  function desenhar(canvas, id, humor, piscar) {
    const f = fichaDe(id);
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    const pele = PELES[f.pele], cab = CABELOS[f.cabelo];
    const sombraPele = esc(pele, 0.8);

    // fundo: cortina com a cor da roupa
    P(ctx, 0, 0, S, S, esc(f.roupa, 0.45));
    for (let i = 0; i < 8; i++) P(ctx, i * 8 + 2, 0, 3, S, esc(f.roupa, 0.38));
    P(ctx, 0, 0, S, 2, esc(f.roupa, 0.3)); P(ctx, 0, 62, S, 2, esc(f.roupa, 0.3));

    // ombros / tronco
    const larguraOmbro = f.gordo ? 56 : 48;
    P(ctx, (S - larguraOmbro) / 2, 50, larguraOmbro, 14, f.roupa);
    P(ctx, (S - larguraOmbro) / 2, 50, larguraOmbro, 2, esc(f.roupa, 1.25 > 1 ? 1.2 : 1));
    P(ctx, (S - larguraOmbro) / 2 + 2, 52, 3, 12, esc(f.roupa, 0.75));
    P(ctx, (S + larguraOmbro) / 2 - 5, 52, 3, 12, esc(f.roupa, 0.75));
    if (f.avental) { P(ctx, 24, 54, 16, 10, '#c9bda3'); P(ctx, 24, 54, 16, 2, '#b0a488'); }
    // broche/corrente
    if (f.chapeu === 'coroa') { P(ctx, 28, 55, 8, 3, '#c9a227'); P(ctx, 30, 58, 4, 3, '#c9a227'); }

    // pescoço
    P(ctx, 27, 44, 10, 8, sombraPele);

    // cabeça (formato)
    const gx = f.gordo ? 2 : 0;
    const cabecaAlt = f.idade === 'jovem' ? 28 : 30;
    P(ctx, 20 - gx, 14, 24 + gx * 2, cabecaAlt, pele);                    // rosto
    P(ctx, 18 - gx, 18, 2, 18, pele); P(ctx, 44 + gx, 18, 2, 18, sombraPele); // laterais/orelhas
    P(ctx, 20 - gx, 40, 24 + gx * 2, 4, sombraPele);                       // queixo sombreado
    if (f.gordo) { P(ctx, 19, 34, 4, 8, pele); P(ctx, 41, 34, 4, 8, sombraPele); } // bochechas

    // rugas de idade
    if (f.idade === 'velho') { P(ctx, 23, 22, 6, 1, sombraPele); P(ctx, 35, 22, 6, 1, sombraPele); P(ctx, 26, 36, 4, 1, sombraPele); }

    // pintura de guerra / marca
    if (f.pintura) { P(ctx, 22, 26, 5, 2, f.pintura); P(ctx, 37, 26, 5, 2, f.pintura); P(ctx, 31, 20, 2, 6, f.pintura); }

    // cicatriz
    if (f.cicatriz) { P(ctx, 38, 20, 2, 10, '#b06050'); P(ctx, 37, 24, 1, 2, '#b06050'); }

    // olhos + sobrancelhas (humor)
    const oy = 26;
    if (piscar) {
      P(ctx, 24, oy + 2, 5, 1, sombraPele); P(ctx, 35, oy + 2, 5, 1, sombraPele);
    } else {
      P(ctx, 24, oy, 5, 4, '#f5f0e0'); P(ctx, 35, oy, 5, 4, '#f5f0e0');
      P(ctx, 26, oy + 1, 2, 3, f.olhos); P(ctx, 37, oy + 1, 2, 3, f.olhos);
      if (f.sombra) { P(ctx, 24, oy, 5, 2, '#1d1a15'); P(ctx, 35, oy, 5, 2, '#1d1a15'); }
    }
    if (humor === 'raiva') {
      P(ctx, 23, oy - 4, 7, 2, cab); P(ctx, 34, oy - 4, 7, 2, cab);
      P(ctx, 28, oy - 3, 2, 2, cab); P(ctx, 34, oy - 3, 2, 2, cab);
    } else if (humor === 'feliz') {
      P(ctx, 24, oy - 3, 6, 1, cab); P(ctx, 35, oy - 3, 6, 1, cab);
    } else {
      P(ctx, 24, oy - 3, 6, 2, cab); P(ctx, 35, oy - 3, 6, 2, cab);
    }

    // nariz
    P(ctx, 30, 30, 3, 4, sombraPele); P(ctx, 30, 33, 4, 1, esc(pele, 0.7));

    // boca (humor)
    if (humor === 'raiva') { P(ctx, 27, 38, 9, 2, '#7a3a30'); P(ctx, 27, 37, 2, 1, '#7a3a30'); P(ctx, 34, 37, 2, 1, '#7a3a30'); }
    else if (humor === 'feliz') { P(ctx, 27, 37, 9, 2, '#8a4a3d'); P(ctx, 26, 36, 2, 1, '#8a4a3d'); P(ctx, 35, 36, 2, 1, '#8a4a3d'); }
    else P(ctx, 28, 38, 8, 2, '#8a4a3d');

    // barba
    if (f.barba === 'cheia') {
      P(ctx, 21 - gx, 33, 22 + gx * 2, 3, cab);
      P(ctx, 20 - gx, 35, 24 + gx * 2, 9, cab);
      P(ctx, 22, 44, 20, 4, cab); P(ctx, 25, 48, 14, 3, esc(cab === '#e8e2d4' ? '#c9c2b8' : cab, 0.85));
      if (humor !== 'raiva') P(ctx, 28, 38, 8, 2, '#8a4a3d'); // boca sobre a barba
    } else if (f.barba === 'cavanhaque') {
      P(ctx, 27, 40, 10, 6, cab);
    } else if (f.barba === 'bigode') {
      P(ctx, 25, 35, 14, 3, cab);
    } else if (f.barba === 'bigode_longo') {
      P(ctx, 25, 35, 14, 2, cab); P(ctx, 24, 36, 3, 8, cab); P(ctx, 37, 36, 3, 8, cab);
    } else if (f.barba === 'rala') {
      for (let i = 0; i < 14; i += 3) P(ctx, 24 + i, 41 + (i % 2), 2, 1, esc(cab, 0.9));
    } else if (f.barba === 'trancada') {
      P(ctx, 21, 34, 22, 10, cab);
      P(ctx, 26, 44, 4, 7, cab); P(ctx, 34, 44, 4, 7, cab);
      P(ctx, 26, 47, 4, 1, '#8a6b30'); P(ctx, 34, 47, 4, 1, '#8a6b30'); // anéis nas tranças
    } else if (f.barba === 'gelo') {
      P(ctx, 21, 34, 22, 10, '#e8e2d4'); P(ctx, 24, 44, 16, 8, '#e8e2d4'); P(ctx, 27, 52, 10, 4, '#d4d0c8');
    }

    // cabelo
    if (f.estilo === 'curto') { P(ctx, 19 - gx, 10, 26 + gx * 2, 8, cab); P(ctx, 19 - gx, 16, 3, 6, cab); P(ctx, 42 + gx, 16, 3, 6, cab); }
    else if (f.estilo === 'medio') { P(ctx, 18 - gx, 10, 28 + gx * 2, 8, cab); P(ctx, 18 - gx, 14, 4, 14, cab); P(ctx, 42 + gx, 14, 4, 14, cab); }
    else if (f.estilo === 'longo') { P(ctx, 17 - gx, 10, 30 + gx * 2, 8, cab); P(ctx, 16 - gx, 14, 5, 30, cab); P(ctx, 43 + gx, 14, 5, 30, cab); P(ctx, 17 - gx, 42, 4, 8, esc(cab, 0.85)); P(ctx, 43 + gx, 42, 4, 8, esc(cab, 0.85)); }
    else if (f.estilo === 'rabo') { P(ctx, 20, 10, 24, 6, cab); P(ctx, 40, 6, 6, 6, cab); P(ctx, 43, 10, 4, 16, cab); }
    else if (f.estilo === 'coque') { P(ctx, 20, 11, 24, 6, cab); P(ctx, 27, 6, 10, 6, cab); }
    else if (f.estilo === 'careca') { P(ctx, 20, 13, 24, 3, sombraPele); P(ctx, 19, 15, 3, 8, cab); P(ctx, 42, 15, 3, 8, cab); }
    else if (f.estilo === 'raspado') { P(ctx, 20, 12, 24, 5, esc(pele, 0.72)); }

    // chapéus e adereços (desenhados por último, cobrem o cabelo)
    if (f.chapeu === 'coroa') {
      P(ctx, 19, 6, 26, 6, '#c9a227');
      for (let i = 0; i < 5; i++) P(ctx, 20 + i * 6, 2, 3, 5, '#c9a227');
      P(ctx, 21 + 6, 4, 1, 1, '#8b2635'); P(ctx, 33, 4, 1, 1, '#2d6b4a'); P(ctx, 21, 4, 1, 1, '#2d4a8a');
      P(ctx, 19, 10, 26, 2, esc('#c9a227', 0.75));
    } else if (f.chapeu === 'coroa_espinho') {
      P(ctx, 19, 7, 26, 5, '#4a4540');
      for (let i = 0; i < 6; i++) { const sx = 20 + i * 5; P(ctx, sx, 1, 2, 7, '#4a4540'); P(ctx, sx, 0, 1, 2, '#6b6560'); }
      P(ctx, 30, 8, 4, 3, '#8b2635');
    } else if (f.chapeu === 'tiara') {
      P(ctx, 20, 9, 24, 3, '#d4d0c8'); P(ctx, 30, 6, 4, 4, '#d4d0c8'); P(ctx, 31, 7, 2, 2, '#5a8ab0');
    } else if (f.chapeu === 'capuz') {
      P(ctx, 16, 4, 32, 12, f.roupa); P(ctx, 14, 10, 6, 30, f.roupa); P(ctx, 44, 10, 6, 30, f.roupa);
      P(ctx, 16, 14, 4, 4, esc(f.roupa, 0.7)); P(ctx, 44, 14, 4, 4, esc(f.roupa, 0.7));
      P(ctx, 20, 14, 24, 3, esc(f.roupa, 0.6)); // sombra do capuz na testa
    } else if (f.chapeu === 'elmo') {
      P(ctx, 18, 6, 28, 12, '#b0b4ba'); P(ctx, 18, 16, 4, 12, '#b0b4ba'); P(ctx, 42, 16, 4, 12, '#b0b4ba');
      P(ctx, 18, 6, 28, 2, '#d0d4da'); P(ctx, 30, 2, 4, 6, '#8b2635'); // crista
    } else if (f.chapeu === 'elmo_chifre') {
      P(ctx, 18, 6, 28, 10, '#7a7e85'); P(ctx, 18, 6, 28, 2, '#9a9ea5');
      P(ctx, 12, 2, 6, 10, '#d8d0c0'); P(ctx, 10, 0, 4, 6, '#d8d0c0');
      P(ctx, 46, 2, 6, 10, '#d8d0c0'); P(ctx, 50, 0, 4, 6, '#d8d0c0');
    } else if (f.chapeu === 'pelo') {
      P(ctx, 16, 4, 32, 10, '#6b5a45');
      for (let i = 0; i < 30; i += 3) P(ctx, 17 + i, 2 + (i % 3), 2, 4, i % 2 ? '#7d6b52' : '#5a4a38');
    }

    // moldura
    P(ctx, 0, 0, S, 1, '#1d1309'); P(ctx, 0, 63, S, 1, '#1d1309');
    P(ctx, 0, 0, 1, S, '#1d1309'); P(ctx, 63, 0, 1, S, '#1d1309');
  }

  // ---------- registro de retratos vivos (piscar de olhos) ----------
  const vivos = new Map(); // canvas -> {id, humor}
  let ticker = 0;

  function humorDe(state, id) {
    const rel = (state.tags[id] || { relacao: 0 }).relacao;
    return rel <= -25 ? 'raiva' : rel >= 25 ? 'feliz' : 'neutro';
  }

  function montar(canvas, id, humor) {
    canvas.width = S; canvas.height = S;
    vivos.set(canvas, { id, humor });
    desenhar(canvas, id, humor, false);
  }

  // chamado pelo rAF global da UI
  function tick() {
    ticker++;
    for (const [canvas, info] of vivos) {
      if (!canvas.isConnected) { vivos.delete(canvas); continue; }
      // cada retrato pisca em momento próprio
      const fase = (ticker + hash(info.id) % 97) % 160;
      const piscar = fase < 5;
      if (fase < 7) desenhar(canvas, info.id, info.humor, piscar);
    }
  }

  return { montar, tick, humorDe, desenhar };
})();
