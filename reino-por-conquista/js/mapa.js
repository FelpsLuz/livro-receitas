// ============================================================
// MAPA-MÚNDI ILUSTRADO — o continente em pergaminho vivo:
// litoral a nanquim, serras, bosques, estradas pontilhadas,
// capitais com bandeira, guerras pulsando e o marcador do jogador.
// ============================================================
'use strict';

const MapaMundi = (() => {
  // posições das capitais no pergaminho (canvas 640×420)
  const POS = {
    aguias: { x: 250, y: 108 },
    imperio: { x: 330, y: 212 },
    alvorecer: { x: 492, y: 152 },
    touros: { x: 138, y: 252 },
    leoes: { x: 402, y: 312 },
    rosa: { x: 528, y: 276 },
    jogador: { x: 182, y: 344 },
  };
  // estradas: quem se liga a quem (o Império toca todos)
  const ESTRADAS = [
    ['imperio', 'aguias'], ['imperio', 'alvorecer'], ['imperio', 'touros'],
    ['imperio', 'leoes'], ['imperio', 'rosa'], ['aguias', 'alvorecer'],
    ['touros', 'leoes'], ['leoes', 'rosa'],
  ];

  // PRNG semeado: o mapa é sempre o MESMO pergaminho
  function prng(seed) {
    let a = seed | 0;
    return () => { a = (a * 1103515245 + 12345) & 0x7fffffff; return a / 0x7fffffff; };
  }

  const bandeiras = {};
  function bandeira(id) {
    if (!bandeiras[id]) { const im = new Image(); im.src = 'img/bandeiras/' + id + '.png'; bandeiras[id] = im; }
    return bandeiras[id];
  }

  // litoral do continente (polígono fechado com baías)
  const COSTA = [
    [66, 96], [128, 62], [214, 44], [300, 52], [368, 38], [452, 50], [532, 78],
    [586, 128], [604, 196], [588, 252], [598, 308], [556, 356], [478, 384],
    [396, 372], [330, 392], [252, 384], [186, 392], [116, 360], [66, 312],
    [42, 244], [58, 176], [40, 132],
  ];

  function tracarCosta(ctx, folga) {
    ctx.beginPath();
    COSTA.forEach(([x, y], i) => {
      const fx = x + (x < 320 ? -folga : folga), fy = y + (y < 210 ? -folga : folga);
      i === 0 ? ctx.moveTo(fx, fy) : ctx.lineTo(fx, fy);
    });
    ctx.closePath();
  }

  function serra(ctx, x, y, n, esc) {
    // cordilheira: triângulos de nanquim com neve
    for (let i = 0; i < n; i++) {
      const mx = x + i * 16 * esc, my = y + ((i % 3) - 1) * 4, h = (13 + (i * 7) % 8) * esc;
      ctx.fillStyle = '#8d7f63';
      ctx.beginPath(); ctx.moveTo(mx - 9 * esc, my); ctx.lineTo(mx, my - h); ctx.lineTo(mx + 9 * esc, my); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#4a3a26'; ctx.lineWidth = 1; ctx.stroke();
      ctx.fillStyle = '#efe8d6';
      ctx.beginPath(); ctx.moveTo(mx - 3 * esc, my - h + 4 * esc); ctx.lineTo(mx, my - h); ctx.lineTo(mx + 3 * esc, my - h + 4 * esc); ctx.closePath(); ctx.fill();
    }
  }

  function bosque(ctx, x, y, n, seed) {
    const r = prng(seed);
    for (let i = 0; i < n; i++) {
      const tx = x + r() * 54 - 27, ty = y + r() * 30 - 15;
      ctx.fillStyle = i % 3 ? '#5b7247' : '#4a6039';
      ctx.beginPath(); ctx.moveTo(tx - 4, ty); ctx.lineTo(tx, ty - 9); ctx.lineTo(tx + 4, ty); ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#4a3a26'; ctx.fillRect(tx - 0.5, ty, 1, 2.5);
    }
  }

  function pantano(ctx, x, y, seed) {
    const r = prng(seed);
    ctx.strokeStyle = '#6b7a52'; ctx.lineWidth = 1;
    for (let i = 0; i < 10; i++) {
      const tx = x + r() * 60 - 30, ty = y + r() * 26 - 13;
      ctx.beginPath(); ctx.moveTo(tx - 4, ty); ctx.lineTo(tx + 4, ty); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(tx - 1, ty); ctx.lineTo(tx - 3, ty - 4); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(tx + 1, ty); ctx.lineTo(tx + 3, ty - 4); ctx.stroke();
    }
  }

  function castelo(ctx, x, y, cor, dominado) {
    // fortim de três torres, estilo iluminura
    ctx.fillStyle = '#d9c99a'; ctx.fillRect(x - 11, y - 8, 22, 10);
    ctx.strokeStyle = '#3a2c1a'; ctx.lineWidth = 1; ctx.strokeRect(x - 11, y - 8, 22, 10);
    for (const dx of [-9, 0, 9]) {
      const alto = dx === 0 ? 8 : 5;
      ctx.fillStyle = '#cbb88a'; ctx.fillRect(x + dx - 3, y - 8 - alto, 6, alto);
      ctx.strokeRect(x + dx - 3, y - 8 - alto, 6, alto);
      ctx.fillStyle = '#3a2c1a';
      ctx.fillRect(x + dx - 3, y - 9 - alto, 2, 2); ctx.fillRect(x + dx + 1, y - 9 - alto, 2, 2);
    }
    ctx.fillStyle = cor; ctx.fillRect(x - 2, y - 4, 4, 6); // portão na cor do reino
    if (dominado) { // coroa dourada sobre a torre central
      ctx.fillStyle = '#e8c85a';
      ctx.fillRect(x - 4, y - 22, 8, 3);
      ctx.fillRect(x - 4, y - 25, 2, 3); ctx.fillRect(x - 1, y - 26, 2, 4); ctx.fillRect(x + 2, y - 25, 2, 3);
    }
  }

  function rotulo(ctx, x, y, texto, cor) {
    ctx.font = '13px VT323, monospace'; ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(232,216,176,.75)';
    const w = ctx.measureText(texto).width;
    ctx.fillRect(x - w / 2 - 3, y - 10, w + 6, 12);
    ctx.fillStyle = cor || '#26160e';
    ctx.fillText(texto, x, y);
  }

  function espadasCruzadas(ctx, x, y, pulso) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(1 + pulso * 0.25, 1 + pulso * 0.25);
    ctx.strokeStyle = '#8b2635'; ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.moveTo(-6, -6); ctx.lineTo(6, 6); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(6, -6); ctx.lineTo(-6, 6); ctx.stroke();
    ctx.fillStyle = '#c9a227';
    ctx.fillRect(-7.5, -7.5, 3, 3); ctx.fillRect(4.5, -7.5, 3, 3);
    ctx.restore();
  }

  function rosaDosVentos(ctx, x, y) {
    ctx.strokeStyle = '#4a3a26'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(x, y, 15, 0, 7); ctx.stroke();
    ctx.beginPath(); ctx.arc(x, y, 11, 0, 7); ctx.stroke();
    ctx.fillStyle = '#8b2635';
    ctx.beginPath(); ctx.moveTo(x, y - 14); ctx.lineTo(x + 3, y); ctx.lineTo(x - 3, y); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#4a3a26';
    ctx.beginPath(); ctx.moveTo(x, y + 14); ctx.lineTo(x + 3, y); ctx.lineTo(x - 3, y); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(x - 14, y); ctx.lineTo(x, y - 3); ctx.lineTo(x, y + 3); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(x + 14, y); ctx.lineTo(x, y - 3); ctx.lineTo(x, y + 3); ctx.closePath(); ctx.fill();
    ctx.font = '11px VT323, monospace'; ctx.textAlign = 'center'; ctx.fillStyle = '#26160e';
    ctx.fillText('N', x, y - 18);
  }

  function serpenteDoMar(ctx, x, y) {
    ctx.strokeStyle = '#3f5a55'; ctx.lineWidth = 2;
    for (const dx of [0, 14, 28]) {
      ctx.beginPath(); ctx.arc(x + dx, y, 6, Math.PI, 0); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(x + 34, y); ctx.lineTo(x + 40, y - 8); ctx.stroke(); // pescoço
    ctx.fillStyle = '#3f5a55';
    ctx.beginPath(); ctx.arc(x + 41, y - 9, 2.5, 0, 7); ctx.fill();
  }

  // O pergaminho é pesado (~300 traçados): rasteriza UMA vez num canvas oculto
  // e só redesenha quando o mundo muda; por cima, a cada frame, apenas o que
  // pulsa (espadas de guerra e o marcador VOCÊ).
  let cacheCv = null, cacheKey = '';
  function chaveEstatica(state) {
    if (!state) return 'sem-estado';
    const carregadas = state.reinos.map(r => {
      const b = bandeira(r.id); return b.complete && b.naturalWidth ? 1 : 0;
    });
    return JSON.stringify([
      state.reinos.map(r => [r.id, r.dominadoPor === 'jogador', !!r.emCrise, r.capital, r.nome]),
      state.jogador.reiDe, state.jogador.bandeira, state.jogador.reinoNome, state.local,
      carregadas,
    ]);
  }

  function render(canvas, state, t) {
    const ctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    ctx.imageSmoothingEnabled = false;
    t = t || 0;
    const chave = chaveEstatica(state);
    if (!cacheCv || cacheCv.width !== W || cacheCv.height !== H || cacheKey !== chave) {
      if (!cacheCv) cacheCv = document.createElement('canvas');
      cacheCv.width = W; cacheCv.height = H;
      desenharEstatico(cacheCv.getContext('2d'), W, H, state);
      cacheKey = chave;
    }
    ctx.drawImage(cacheCv, 0, 0);

    // ---- camada viva: guerras pulsando e o marcador do jogador
    const pulso = (Math.sin(t / 300) + 1) / 2;
    for (const g of (state ? state.guerras : [])) {
      const pa = POS[g.a], pb = POS[g.b];
      if (pa && pb) espadasCruzadas(ctx, (pa.x + pb.x) / 2, (pa.y + pb.y) / 2 - 10, pulso);
    }
    if (state) {
      const temJogador = state.jogador.reiDe === 'jogador';
      const onde = temJogador && state.local === 'jogador' ? POS.jogador : POS[state.local];
      if (onde) {
        const bob = Math.sin(t / 260) * 2;
        ctx.fillStyle = '#8b2635';
        ctx.beginPath();
        ctx.moveTo(onde.x - 22, onde.y - 34 + bob);
        ctx.lineTo(onde.x - 6, onde.y - 28 + bob);
        ctx.lineTo(onde.x - 22, onde.y - 22 + bob);
        ctx.closePath(); ctx.fill();
        ctx.fillStyle = '#4a3a26'; ctx.fillRect(onde.x - 23, onde.y - 34 + bob, 1.5, 22 - bob);
        ctx.font = '11px VT323, monospace'; ctx.textAlign = 'center'; ctx.fillStyle = '#8b2635';
        ctx.fillText('VOCÊ', onde.x - 14, onde.y - 38 + bob);
      }
    }
  }

  function desenharEstatico(ctx, W, H, state) {
    ctx.imageSmoothingEnabled = false;

    // ---- mar: pergaminho escurecido com ondinhas
    ctx.fillStyle = '#c8b489'; ctx.fillRect(0, 0, W, H);
    const rOndas = prng(77);
    ctx.strokeStyle = 'rgba(74,90,85,.5)'; ctx.lineWidth = 1;
    for (let i = 0; i < 46; i++) {
      const ox = rOndas() * W, oy = rOndas() * H;
      ctx.beginPath(); ctx.moveTo(ox, oy);
      ctx.quadraticCurveTo(ox + 5, oy - 3, ox + 10, oy);
      ctx.quadraticCurveTo(ox + 15, oy + 3, ox + 20, oy);
      ctx.stroke();
    }

    // ---- continente: sombra da costa, terra e traço a nanquim
    ctx.fillStyle = 'rgba(58,44,26,.30)'; tracarCosta(ctx, 4); ctx.fill();
    ctx.fillStyle = '#e8d8b0'; tracarCosta(ctx, 0); ctx.fill();
    // manchas de idade do pergaminho (recortadas na terra)
    ctx.save(); tracarCosta(ctx, 0); ctx.clip();
    const rMancha = prng(13);
    for (let i = 0; i < 26; i++) {
      ctx.fillStyle = i % 2 ? 'rgba(190,164,110,.20)' : 'rgba(214,196,150,.35)';
      ctx.beginPath(); ctx.arc(rMancha() * W, rMancha() * H, 12 + rMancha() * 30, 0, 7); ctx.fill();
    }

    // ---- relevo e vegetação (ainda recortado na terra)
    serra(ctx, 190, 88, 9, 1);          // montanhas das Águias
    serra(ctx, 520, 110, 5, 0.8);       // serra do leste
    serra(ctx, 78, 180, 4, 0.7);        // penhascos do oeste
    bosque(ctx, 268, 168, 16, 5);       // floresta central
    bosque(ctx, 452, 220, 12, 9);       // bosque do leste
    bosque(ctx, 230, 300, 10, 21);      // matas do sul
    pantano(ctx, 132, 286, 31);         // pântanos dos Touros
    pantano(ctx, 96, 240, 45);
    // rio: das montanhas ao mar do sul, passando pelo Jardim Azul
    ctx.strokeStyle = '#7a9a94'; ctx.lineWidth = 3; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(300, 120);
    ctx.quadraticCurveTo(360, 180, 430, 240);
    ctx.quadraticCurveTo(490, 290, 520, 340);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(232,216,176,.55)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(300, 120);
    ctx.quadraticCurveTo(360, 180, 430, 240);
    ctx.quadraticCurveTo(490, 290, 520, 340);
    ctx.stroke();
    ctx.restore();

    ctx.strokeStyle = '#3a2c1a'; ctx.lineWidth = 2.5; tracarCosta(ctx, 0); ctx.stroke();
    ctx.strokeStyle = 'rgba(74,90,85,.6)'; ctx.lineWidth = 1; tracarCosta(ctx, 6); ctx.stroke();

    // ---- estradas pontilhadas entre capitais
    const temJogador = state && state.jogador.reiDe === 'jogador';
    ctx.strokeStyle = 'rgba(90,64,38,.75)'; ctx.lineWidth = 2; ctx.setLineDash([3, 5]);
    const liga = (a, b) => {
      const pa = POS[a], pb = POS[b];
      const mx = (pa.x + pb.x) / 2 + (a < b ? 12 : -12), my = (pa.y + pb.y) / 2 - 10;
      ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.quadraticCurveTo(mx, my, pb.x, pb.y); ctx.stroke();
    };
    for (const [a, b] of ESTRADAS) liga(a, b);
    if (temJogador) { liga('jogador', 'touros'); liga('jogador', 'leoes'); }
    ctx.setLineDash([]);

    // ---- capitais: castelo + bandeira + nome
    if (state) {
      for (const r of state.reinos) {
        const p = POS[r.id]; if (!p) continue;
        castelo(ctx, p.x, p.y, r.cor, r.dominadoPor === 'jogador');
        const bd = bandeira(r.id);
        if (bd.complete && bd.naturalWidth) {
          ctx.fillStyle = '#4a3a26'; ctx.fillRect(p.x + 13, p.y - 26, 1.5, 20);
          ctx.drawImage(bd, p.x + 14, p.y - 26, 15, 10);
        }
        rotulo(ctx, p.x, p.y + 16, r.capital, '#26160e');
        rotulo(ctx, p.x, p.y + 28, r.nome, r.emCrise ? '#8b2635' : '#5a4026');
        // com o jogador presente, o rótulo de crise sobe para não cobrir o "VOCÊ"
        if (r.emCrise) rotulo(ctx, p.x, p.y - (state.local === r.id ? 54 : 30), '† SEM REI †', '#8b2635');
      }
      // reino do jogador, quando fundado
      if (temJogador) {
        const p = POS.jogador;
        castelo(ctx, p.x, p.y, '#c9a227', true);
        const bd = bandeira(state.jogador.bandeira || 'jogador_1');
        if (bd.complete && bd.naturalWidth) {
          ctx.fillStyle = '#4a3a26'; ctx.fillRect(p.x + 13, p.y - 26, 1.5, 20);
          ctx.drawImage(bd, p.x + 14, p.y - 26, 15, 10);
        }
        rotulo(ctx, p.x, p.y + 16, state.jogador.reinoNome || 'Seu Reino', '#26160e');
      }
    }

    // ---- adornos de cartógrafo
    rosaDosVentos(ctx, 52, H - 52);
    serpenteDoMar(ctx, W - 92, H - 34);
    // cartucho do título
    ctx.font = '17px VT323, monospace'; ctx.textAlign = 'center';
    const tw = ctx.measureText('~ O CONTINENTE ~').width;
    ctx.fillStyle = '#e8d8b0'; ctx.fillRect(W / 2 - tw / 2 - 10, 8, tw + 20, 20);
    ctx.strokeStyle = '#4a3a26'; ctx.lineWidth = 1.5; ctx.strokeRect(W / 2 - tw / 2 - 10, 8, tw + 20, 20);
    ctx.fillStyle = '#26160e'; ctx.fillText('~ O CONTINENTE ~', W / 2, 23);
    // moldura dupla
    ctx.strokeStyle = '#4a3a26'; ctx.lineWidth = 2; ctx.strokeRect(3, 3, W - 6, H - 6);
    ctx.strokeStyle = 'rgba(74,58,38,.5)'; ctx.lineWidth = 1; ctx.strokeRect(7, 7, W - 14, H - 14);
  }

  // clique → reino mais próximo (raio de 44px no espaço do canvas)
  function reinoEm(canvas, evento, state) {
    const rect = canvas.getBoundingClientRect();
    const x = (evento.clientX - rect.left) * canvas.width / rect.width;
    const y = (evento.clientY - rect.top) * canvas.height / rect.height;
    let melhor = null, dMin = 44;
    const alvos = state.reinos.map(r => r.id);
    if (state.jogador.reiDe === 'jogador') alvos.push('jogador');
    for (const id of alvos) {
      const p = POS[id]; if (!p) continue;
      const d = Math.hypot(p.x - x, p.y - y);
      if (d < dMin) { dMin = d; melhor = id; }
    }
    return melhor;
  }

  return { render, reinoEm, POS };
})();
