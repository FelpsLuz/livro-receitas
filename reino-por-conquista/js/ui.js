// ============================================================
// INTERFACE DIEGÉTICA
// - Livro-razão de pergaminho, cartas seladas na mesa de madeira,
//   mural de contratos na taverna, campo de fala livre.
// ============================================================
'use strict';

const UI = (() => {
  let abaAtual = 'terra';
  let npcAtual = null;
  let animTimer = null;

  const $ = (sel) => document.querySelector(sel);
  const el = (tag, cls, html) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html !== undefined) e.innerHTML = html;
    return e;
  };
  // escapa texto livre do jogador antes de ir para innerHTML (anti-XSS)
  const esc = (t) => String(t).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // ---------- inicialização ----------
  function iniciar() {
    $('#btn-novo').onclick = () => {
      const nome = $('#input-nome').value.trim();
      Jogo.novoJogo(nome || null);
      $('#tela-titulo').style.display = 'none';
      $('#tela-jogo').style.display = 'flex';
      abaAtual = 'terra';
      renderTudo();
      iniciarAnimacao();
    };
    $('#btn-continuar').onclick = () => {
      if (Jogo.carregar()) {
        $('#tela-titulo').style.display = 'none';
        $('#tela-jogo').style.display = 'flex';
        renderTudo();
        iniciarAnimacao();
      }
    };
    if (!Jogo.temSave()) $('#btn-continuar').style.display = 'none';

    if (typeof LLMNuvem !== 'undefined') {
      LLMNuvem.registrar();
      const bIA = $('#btn-ia');
      const rotuloIA = () => {
        bIA.textContent = LLMNuvem.estaConfigurado()
          ? '🧠 IA ligada (' + (LLMNuvem.PROVEDORES[LLMNuvem.provedor()] || {}).nome + ') — configurar'
          : '🧠 IA das conversas (Claude / GPT)';
      };
      rotuloIA();
      bIA.onclick = () => abrirConfigIA(rotuloIA);
    } else {
      const bIA = $('#btn-ia'); if (bIA) bIA.style.display = 'none';
    }

    document.querySelectorAll('.aba').forEach(b => {
      b.onclick = () => {
        Sfx.pagina(); abaAtual = b.dataset.aba; npcAtual = null; renderTudo();
        const c = $('#conteudo'); // fade curto ao trocar de aba (game feel)
        c.classList.remove('trocando'); void c.offsetWidth; c.classList.add('trocando');
      };
    });
    $('#btn-mes').onclick = () => {
      Sfx.tique();
      Jogo.passarMes();
      Jogo.salvar();
      renderTudo();
    };
    const bMudo = $('#btn-mudo');
    const rotuloMudo = () => { bMudo.textContent = Sfx.mudo ? '🔇' : '🔊'; };
    bMudo.onclick = () => { Sfx.alternarMudo(); rotuloMudo(); };
    rotuloMudo();

    // vitrine animada na tela de título
    const tc = $('#canvas-titulo');
    if (tc) {
      const loopTitulo = () => {
        if ($('#tela-titulo').style.display !== 'none') {
          Cidade.renderShowcase(tc);
          requestAnimationFrame(loopTitulo);
        }
      };
      loopTitulo();
      requestAnimationFrame(reajustarCanvases);
    }
  }

  function iniciarAnimacao() {
    if (animTimer) cancelAnimationFrame(animTimer);
    const loop = () => {
      // com um modal aberto, os canvases de trás não precisam ser redesenhados
      const modalAberto = $('#modal').style.display === 'flex';
      const canvas = $('#canvas-cidade');
      if (canvas && canvas.offsetParent !== null && Jogo.state && !modalAberto) Cidade.render(canvas, Jogo.state);
      const cvMapa = $('#canvas-mapa');
      if (cvMapa && cvMapa.offsetParent !== null && Jogo.state && !modalAberto) MapaMundi.render(cvMapa, Jogo.state, performance.now());
      Retratos.tick();
      animTimer = requestAnimationFrame(loop);
    };
    loop();
  }

  // ---------- escala inteira (pixel perfect) ----------
  // Se um múltiplo inteiro de pixels do aparelho ocupar ≥70% da largura,
  // trava nele (pixels uniformes, sem tremida); senão usa a largura toda.
  function ajustarPixelPerfeito(canvas) {
    const wrap = canvas && canvas.parentElement;
    if (!wrap || !wrap.clientWidth) return;
    const dpr = window.devicePixelRatio || 1;
    const disp = Math.floor(wrap.clientWidth * dpr);
    const esc = Math.floor(disp / canvas.width);
    if (esc >= 1 && canvas.width * esc >= disp * 0.7) {
      canvas.style.width = (canvas.width * esc / dpr) + 'px';
      canvas.style.height = (canvas.height * esc / dpr) + 'px';
      canvas.style.margin = '0 auto';
    } else {
      canvas.style.width = ''; canvas.style.height = ''; canvas.style.margin = '';
    }
  }
  function reajustarCanvases() {
    ['#canvas-cidade', '#canvas-titulo', '#canvas-mapa'].forEach((id) => {
      const cv = $(id);
      if (cv) ajustarPixelPerfeito(cv);
    });
  }
  window.addEventListener('resize', () => requestAnimationFrame(reajustarCanvases));

  // ---------- barra de status ----------
  function renderStatus() {
    const s = Jogo.state, j = s.jogador;
    $('#status-bar').innerHTML = `
      <span class="st"><b>${j.nome}</b> · ${Contratos.titulo(s)} · ${j.idade} anos</span>
      <span class="st">🪙 ${j.ouro}</span>
      <span class="st">⭐ Renome ${j.renome}</span>
      <span class="st">⚔️ ${Combate.totalHomens(j.tropas)} homens</span>
      <span class="st">🛡️ ${j.guardas} guardas</span>
      <span class="st">📅 ${MESES[s.mes - 1]}, Ano ${s.ano}</span>`;
  }

  // ---------- render principal ----------
  function renderTudo() {
    const s = Jogo.state;
    if (!s) return;
    renderStatus();
    document.querySelectorAll('.aba').forEach(b =>
      b.classList.toggle('ativa', b.dataset.aba === abaAtual));

    if (s.fim) { renderFim(); return; }
    if (s.eventoPendente) { renderEvento(); return; }
    $('#modal').style.display = 'none';

    const c = $('#conteudo');
    c.innerHTML = '';
    ({ terra: renderTerra, mapa: renderMapa, mercado: renderMercado, taverna: renderTaverna,
       corte: renderCorte, exercito: renderExercito, clas: renderClas, intrigas: renderIntrigas,
       familia: renderFamilia, cronica: renderCronica }[abaAtual] || renderTerra)(c);
    requestAnimationFrame(reajustarCanvases);
  }

  // ---------- SUA TERRA (pixel art + gestão) ----------
  function renderTerra(c) {
    const s = Jogo.state, t = s.terra;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, t ? `${t.nome} — ${NIVEIS_TERRA[t.nivel].nome}` : 'Acampamento Mercenário'));
    const wrap = el('div', 'canvas-wrap');
    const canvas = el('canvas');
    canvas.id = 'canvas-cidade'; canvas.width = 640; canvas.height = 360;
    wrap.appendChild(canvas);
    painel.appendChild(wrap);

    if (!t) {
      painel.appendChild(el('p', 'flavor', 'Sem terras, sem raízes. Sua "corte" é uma fogueira e três tendas na beira da estrada. Seja armado CAVALEIRO por um rei (60⭐ + relação 40, na corte) e compre seu primeiro pedaço de chão.'));
      const b = el('button', 'btn', '🏕️ Comprar terra (300 🪙, requer título de Cavaleiro)');
      b.onclick = () => aviso(Jogo.comprarTerra().msg) || renderTudo();
      painel.appendChild(b);
    } else {
      const col = t.ultimaColeta;
      painel.appendChild(el('div', 'grade', `
        <div class="celula">👥 População<br><b>${t.populacao}</b></div>
        <div class="celula">🌾 Alimento<br><b>${t.alimento}</b>${col ? ` <small>(+${col.producao}/−${col.consumo})</small>` : ''}</div>
        <div class="celula">🪵 Madeira<br><b>${t.madeira}</b></div>
        <div class="celula">😊 Felicidade<br><span class="barra-hud"><span class="barra-fill ${t.felicidade >= 60 ? 'ouro' : ''}" style="clip-path:inset(0 ${100 - clamp(t.felicidade, 0, 100)}% 0 0)"></span><b class="barra-valor">${t.felicidade}</b></span></div>`));
      if (t.felicidade <= 30) painel.appendChild(el('p', 'flavor ruim', '⚠️ O povo murmura nas tavernas. Felicidade baixa demais termina em foices e tochas na sua porta.'));
      if (t.nivel < 5) {
        const prox = NIVEIS_TERRA[t.nivel + 1];
        const b = el('button', 'btn', `🏗️ Evoluir para ${prox.nome} (${prox.custoOuro} 🪙 + ${prox.custoMadeira} 🪵)`);
        b.onclick = () => { aviso(Jogo.melhorarTerra().msg); renderTudo(); };
        painel.appendChild(b);
        painel.appendChild(el('p', 'flavor', prox.desc));
      } else {
        painel.appendChild(el('p', 'flavor bom', '🏰 Seu castelo domina o horizonte. Falta apenas uma coroa.'));
        if (Politica.podeProclamar(s)) {
          const bInd = el('button', 'btn destaque', `👑 FUNDAR REINO INDEPENDENTE (${CUSTO_FUNDAR_REINO.toLocaleString('pt-BR')} 🪙)`);
          bInd.onclick = () => modalFundarReino();
          painel.appendChild(bInd);
        } else if (!s.jogador.reiDe) {
          painel.appendChild(el('p', 'flavor', `👑 Independência exige 80 de renome (você tem ${s.jogador.renome}) e ${CUSTO_FUNDAR_REINO.toLocaleString('pt-BR')} 🪙 de tesouro.`));
        }
      }
      const bExp = el('button', 'btn sec', '📦 Exportar 30 de alimento da vila (ouro rápido, povo faminto reclama)');
      bExp.onclick = () => { aviso(Economia.exportarComidaDaTerra(Jogo.state, 30).msg); renderTudo(); };
      painel.appendChild(bExp);

      // ---- edifícios de produção (nível 1 a 30) ----
      Producao.garantir(s);
      painel.appendChild(el('h3', null, '🏗️ Produção (edifícios até nível 30)'));
      const up = t.ultimaProducao;
      if (up) painel.appendChild(el('p', 'flavor', `Último mês: +${up.alimento} 🌾, +${up.madeira} 🪵, +${up.ferro} ⛏️ ferro, +${up.armas} ⚔️ armas` + (up.eficiencia < 1 ? ` (eficiência ${Math.round(up.eficiencia * 100)}% — faltam braços)` : '')));
      for (const [idEd, ed] of Object.entries(Producao.EDIFICIOS)) {
        const nivelEd = t.edificios[idEd];
        const est = Producao.estagio(nivelEd);
        const card = el('div', 'card-npc com-retrato');
        const cv = el('canvas', 'retrato');
        cv.width = 48; cv.height = 48;
        desenharEdificio(cv, idEd, est);
        card.appendChild(cv);
        const info = el('div', 'npc-info');
        info.innerHTML = `<b>${ed.icone} ${ed.nome}</b> — nível <b>${nivelEd}</b>/${Producao.NIVEL_MAX} · <small>estágio ${est}/6 (sprite evolui a cada 5 níveis)</small><br><small><i>${ed.desc}</i>` +
          (nivelEd > 0 ? ` · produz ${Producao.producaoDe(s, idEd, nivelEd)}/mês` : '') + `</small>`;
        card.appendChild(info);
        const card_alvo = info;
        if (nivelEd < Producao.NIVEL_MAX) {
          const custoEd = Producao.custo(idEd, nivelEd);
          const b = el('button', 'btn mini', `Evoluir (${custoEd} 🪙 + ${Math.round(custoEd / 4)} 🪵)`);
          b.onclick = () => { const r = Producao.construir(s, idEd); if (r.ok) Sfx.moeda(); aviso(r.msg); Jogo.salvar(); renderTudo(); };
          card_alvo.appendChild(b);
        }
        painel.appendChild(card);
      }
      painel.appendChild(el('p', 'flavor', '💡 Produzir é renda constante; comerciar é lucro rápido. A mina enche sua carga de ferro; o ferreiro forja 2 ferro → 1 arma (⚔️ vale ouro em reinos em guerra) e barateia o equipamento do exército.'));
    }
    c.appendChild(painel);
  }

  // sprite procedural do edifício: cresce a cada estágio (0..6)
  function desenharEdificio(cv, id, est) {
    const x = cv.getContext('2d');
    x.imageSmoothingEnabled = false;
    // arte do designer, se entregue em img/edificios/<id>_<estagio>.png (48×48)
    if (typeof Assets !== 'undefined' && est > 0
        && Assets.desenharSeExistir(x, 'edificios/' + id + '_' + Math.min(est, 6), 0, 0, 48, 48)) return;
    const P = (a, b, w, h, c) => { x.fillStyle = c; x.fillRect(a, b, w, h); };
    P(0, 0, 48, 48, '#5cae31');
    P(0, 40, 48, 8, '#3f8a44');
    if (est === 0) { P(20, 30, 8, 8, '#8a6136'); P(18, 36, 12, 2, '#77522c'); return; } // terreno baldio
    const t = Math.min(est, 6);
    if (id === 'fazenda') {
      for (let i = 0; i < t; i++) P(4, 8 + i * 5, 18 + t * 2, 3, i % 2 ? '#8fd14a' : '#7a5433');
      P(28, 20 - t, 16, 16 + t, '#a3703c');
      x.fillStyle = '#c9403a';
      x.beginPath(); x.moveTo(26, 22 - t); x.lineTo(36, 12 - t); x.lineTo(46, 22 - t); x.fill();
      if (t >= 4) { P(24, 14, 5, 22, '#c2c3c9'); P(23, 12, 7, 4, '#9799a3'); } // silo
    } else if (id === 'serraria') {
      for (let i = 0; i < Math.min(t, 4); i++) { P(4 + i * 6, 30, 4, 12, '#6b4423'); x.fillStyle = '#389048'; x.beginPath(); x.moveTo(2 + i * 6, 32); x.lineTo(6 + i * 6, 18 - t); x.lineTo(10 + i * 6, 32); x.fill(); }
      P(28, 26 - t, 16, 16 + t, '#8a5a2e');
      for (let i = 0; i < t; i++) P(29, 40 - i * 3, 14, 2, '#c48c4e'); // pilha de toras
      if (t >= 3) { x.fillStyle = '#c2c3c9'; x.beginPath(); x.arc(36, 22 - t, 4 + t / 2, 0, 7); x.fill(); } // serra
    } else if (id === 'mina') {
      P(6, 18 - t, 36, 24 + t, '#7b7e8e');
      P(18, 30, 12, 12, '#26160e');
      P(16, 28, 16, 3, '#6b4423'); P(16, 28, 3, 14, '#6b4423'); P(29, 28, 3, 14, '#6b4423');
      for (let i = 0; i < t; i++) P(8 + i * 5, 22 - t + (i % 2) * 3, 3, 3, '#c2c3c9'); // veios de ferro
      if (t >= 3) { P(34, 36, 10, 6, '#8a5a2e'); P(35, 42, 3, 3, '#26160e'); P(40, 42, 3, 3, '#26160e'); } // vagonete
      if (t >= 5) P(4, 12 - t, 8, 30 + t, '#63667a'); // torre do poço
    } else {
      P(10, 22 - t, 28, 20 + t, '#8a5a2e');
      x.fillStyle = '#63667a';
      x.beginPath(); x.moveTo(6, 24 - t); x.lineTo(24, 12 - t); x.lineTo(42, 24 - t); x.fill();
      P(30, 14 - t, 6, 10, '#9799a3'); // chaminé
      P(31, 10 - t, 4, 4, '#e8742e');  // brasa
      P(14, 34, 8, 8, '#26160e');      // forja
      P(15, 35, 6, 4, '#f7a63c');
      if (t >= 3) { P(26, 36, 10, 3, '#c2c3c9'); P(28, 32, 3, 6, '#63667a'); } // bigorna
      if (t >= 5) for (let i = 0; i < 3; i++) P(38 + i * 3, 28, 2, 10, '#c2c3c9'); // arsenal
    }
  }

  // ---------- MAPA (reinos, guerras, relações) ----------
  function renderMapa(c) {
    const s = Jogo.state;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, 'O Continente'));
    // MAPA ILUSTRADO: pergaminho vivo — clique numa capital para ir ao reino
    const wrapMapa = el('div', 'canvas-wrap');
    const cvMapa = el('canvas');
    cvMapa.id = 'canvas-mapa'; cvMapa.width = 640; cvMapa.height = 420;
    cvMapa.title = 'Clique numa capital para ver o reino';
    cvMapa.onclick = (ev) => {
      const id = MapaMundi.reinoEm(cvMapa, ev, s);
      if (!id) return;
      Sfx.pagina();
      const card = document.getElementById('card-reino-' + id);
      if (card) {
        card.scrollIntoView({ behavior: 'smooth', block: 'center' });
        card.classList.remove('brilho'); void card.offsetWidth; card.classList.add('brilho');
      }
    };
    wrapMapa.appendChild(cvMapa);
    painel.appendChild(wrapMapa);
    painel.appendChild(el('p', 'flavor', '🗺️ Espadas cruzadas = guerra em curso · coroa = trono sob seu domínio · clique numa capital para saltar ao reino.'));
    // barra de progresso da UNIFICAÇÃO (nova condição de vitória)
    const dominados = s.reinos.filter(r => r.dominadoPor === 'jogador').length;
    const total = s.reinos.length;
    const pct = Math.round(dominados / total * 100);
    const objetivo = el('div', 'objetivo-vitoria');
    objetivo.innerHTML = `<b>👑 Objetivo: unificar o continente</b> — domine os <b>${total}</b> tronos e reine sobre todos por 12 meses.
      <div class="barra-unificacao"><span style="width:${pct}%"></span><i>${dominados}/${total} reinos</i></div>` +
      (dominados >= total
        ? `<div class="flavor bom">🏆 Todos os tronos são seus! Segure a coroa por mais ${Math.max(0, 12 - (s.jogador.mesesImperador || 0))} meses.</div>`
        : `<div class="flavor">Reivindique cada trono pela guerra (aba de cada reino). Alicie lordes e explore crises de sucessão para enfraquecer as defesas.</div>`);
    painel.appendChild(objetivo);
    if (s.jogador.reiDe) {
      const meus = Politica.meusNobres(s);
      const bandeiraMinha = s.jogador.reiDe === 'jogador' && s.jogador.bandeira
        ? `<img src="img/bandeiras/${s.jogador.bandeira}.png" class="bandeira" alt=""> ` : '👑 ';
      painel.appendChild(el('p', 'flavor bom', `${bandeiraMinha}${s.jogador.reiDe === 'jogador' ? (s.jogador.reinoNome || 'Seu Reino') : 'Seu trono'} — lordes sob sua bandeira: ${meus.length} (${meus.map(n => n.nome).join(', ') || 'nenhum ainda'}). Cada um rende 20 🪙/mês e mina o reino de origem.`));
    }
    if (s.guerras.length) {
      for (const g of s.guerras) {
        const ra = s.reinos.find(r => r.id === g.a), rb = s.reinos.find(r => r.id === g.b);
        painel.appendChild(el('p', 'flavor ruim', `⚔️ ${ra.nome} × ${rb.nome} — ${g.meses} ${g.meses === 1 ? 'mês' : 'meses'} de guerra. Campos em chamas, trigo pela hora da morte.`));
      }
    } else painel.appendChild(el('p', 'flavor', '🕊️ Os reinos estão em paz. Os mercadores agradecem; os mercenários, nem tanto.'));

    for (const r of s.reinos) {
      const tags = s.tags['rei_' + r.id] || { relacao: 0 };
      const rel = Dialogo.nomeRelacao(tags.relacao);
      const cb = s.casusBelli.includes(r.id);
      const card = el('div', 'card-reino com-retrato');
      card.id = 'card-reino-' + r.id;
      card.style.borderLeftColor = r.cor;
      card.appendChild(retratoDe(r.rei.id, null, r.rei.retratoId));
      const lordes = Politica.nobresDe(s, r.id);
      const listaLordes = lordes.map(n => `<span title="${(n.papel || '').replace(/"/g, '&quot;')} (${n.cidade})">${n.nome}</span>`).join(' · ');
      const infoReino = el('div', 'npc-info', `
        <img src="img/bandeiras/${r.id}.png" class="bandeira" alt=""> <b>${r.nome}</b> — capital ${r.capital}<br>
        <small>${r.rei.nome} · <i>${r.rei.desc}</i></small><br>
        <small>Relação: <b class="${tags.relacao <= -25 ? 'ruim' : tags.relacao >= 25 ? 'bom' : ''}">${rel} (${tags.relacao})</b>
        ${cb ? ' · <b class="bom">📜 Casus Belli</b>' : ''}
        ${Politica.temComercio(s, r.id) ? ' · <b class="bom">🪙 Comércio</b>' : ''}
        ${Politica.aliado(s, r.id) ? ' · <b class="bom">🤝 ALIADO</b>' : ''}
        ${Politica.lealdadeDe(s, r.id) > 0 ? ` · ✊ Povo ${Politica.lealdadeDe(s, r.id)}/100` : ''}
        ${(s.embargos && s.embargos[r.id]) ? ' · <b class="ruim">📦 EMBARGO contra você</b>' : ''}
        ${s.jogador.vassaloDe === r.id ? ' · <b class="bom">🛡️ SEU SENHOR</b>' : ''}
        ${r.dominadoPor === 'jogador' ? ' · <b class="bom">👑 SOB SEU DOMÍNIO</b>' : ''}
        ${r.emCrise ? ' · <b class="ruim">🏚️ CRISE DE SUCESSÃO</b>' : ''}<br>
        🏰 ${r.imperial ? 'Lordes Comandantes' : 'Lordes'} (${lordes.length}): <i class="lordes-lista">${listaLordes || '—'}</i><br>
        📜 <i>${Politica.DOUTRINAS[r.id] || ''}</i></small>`);
      card.appendChild(infoReino);
      const botoes = el('div', 'linha-botoes');
      const bIr = el('button', 'btn mini', s.local === r.id ? '📍 Você está aqui' : '🐴 Viajar');
      bIr.disabled = s.local === r.id;
      bIr.onclick = () => { s.local = r.id; Jogo.log(`🐴 Você viaja para ${r.nome}.`); renderTudo(); };
      botoes.appendChild(bIr);
      const oferta = (s.ofertas || []).find(o => o.reino === r.id);
      if (oferta) {
        const bAc = el('button', 'btn mini', `✅ Aceitar ${oferta.tipo === 'comercio' ? 'acordo comercial' : 'ALIANÇA'} proposto`);
        bAc.onclick = () => { aviso(Politica.aceitarOferta(s, r.id, Jogo.log).msg); Jogo.salvar(); renderTudo(); };
        botoes.appendChild(bAc);
      }
      if (!Politica.temComercio(s, r.id) && !oferta) {
        const bCom = el('button', 'btn mini', '📜 Propor comércio (100 🪙, rel. 20+)');
        bCom.onclick = () => { aviso(Politica.proporTratado(s, r.id, 'comercio', Jogo.log).msg); Jogo.salvar(); renderTudo(); };
        botoes.appendChild(bCom);
      }
      if (Politica.temComercio(s, r.id) && !Politica.aliado(s, r.id) && !oferta) {
        const custoAli = r.id === 'aguias' ? 600 : 300;
        const bAli = el('button', 'btn mini', `🤝 Propor aliança (${custoAli} 🪙, rel. 50+, ⭐60+)`);
        bAli.onclick = () => { aviso(Politica.proporTratado(s, r.id, 'alianca', Jogo.log).msg); Jogo.salvar(); renderTudo(); };
        botoes.appendChild(bAli);
      }
      if (r.imperial && s.tributo) {
        const bTri = el('button', 'btn mini', `🟢 Pagar tributo imperial (${s.tributo.valor} 🪙, ${s.tributo.meses}m restantes)`);
        bTri.onclick = () => { const rr = Politica.pagarTributo(s, Jogo.log); if (rr.ok) Sfx.moeda(); aviso(rr.msg); Jogo.salvar(); renderTudo(); };
        botoes.appendChild(bTri);
      }
      if (Politica.eNobre(s) && r.dominadoPor !== 'jogador' && Politica.nobresDe(s, r.id).length > 0) {
        const bNob = el('button', 'btn mini', '🏰 Aliciar lorde (200 🪙, enfraquece a defesa)');
        bNob.onclick = () => { aviso(Politica.persuadirNobre(s, r.id, Jogo.log).msg); Jogo.salvar(); renderTudo(); };
        botoes.appendChild(bNob);
      }
      // reivindicar o trono pela guerra — em qualquer reino ainda não dominado
      if (r.dominadoPor !== 'jogador' && !s.jogador.vassaloDe) {
        const podeNobre = Politica.eNobre(s);
        const bGuerra = el('button', 'btn mini ruim-btn', cb ? '⚔️ Reivindicar o trono (com CB)' : '⚔️ Conquistar SEM casus belli');
        if (!podeNobre) { bGuerra.disabled = true; bGuerra.title = 'Torne-se Conde (terra nível 4) para reivindicar tronos.'; }
        bGuerra.onclick = () => confirmar(
          cb ? `Marchar sobre ${r.capital} com sua reivindicação legal e tomar o trono?`
             : `Atacar ${r.nome} SEM justificativa legal? Os reinos livres se voltarão contra você!`,
          () => { const rel = Intriga.declararGuerra(s, r.id, Jogo.log); mostrarBatalha(rel); });
        botoes.appendChild(bGuerra);
      }
      infoReino.appendChild(botoes);
      painel.appendChild(card);
    }
    c.appendChild(painel);
  }

  // ---------- MERCADO (livro-razão) ----------
  function renderMercado(c) {
    const s = Jogo.state;
    const reino = s.reinos.find(r => r.id === s.local);
    const emGuerra = s.guerras.some(g => g.a === s.local || g.b === s.local);
    const painel = el('div', 'painel pergaminho');
    painel.appendChild(el('h2', null, `📖 Livro-Razão — Mercado de ${reino.nome}`));
    if (emGuerra) painel.appendChild(el('p', 'flavor ruim', '⚔️ Reino em guerra: trigo vale ouro aqui (ágio de contrabando +30%), mas patrulhas confiscam cargas de quem for pego.'));
    const rel = (s.tags['rei_' + s.local] || { relacao: 0 }).relacao;
    if (rel <= -25) painel.appendChild(el('p', 'flavor ruim', `Os mercadores sabem que ${reino.rei.nome} não gosta de você: preços inflacionados para a sua cara.`));
    if (rel >= 25) painel.appendChild(el('p', 'flavor bom', 'Amigo da coroa paga menos. Os mercadores te tratam bem.'));

    const tab = el('table', 'tabela');
    tab.innerHTML = '<tr><th>Mercadoria</th><th>Preço</th><th>Sua carga</th><th></th><th></th></tr>';
    for (const [gId, m] of Object.entries(MERCADORIAS)) {
      const preco = Economia.precoDe(s, s.local, gId);
      const carga = s.carga[gId] || 0;
      const tr = el('tr');
      const alerta = preco > m.precoBase * 1.5 ? ' 📈' : preco < m.precoBase * 0.8 ? ' 📉' : '';
      const icoM = gId === 'armas' ? '<img src="img/armas/claymore.png" class="ico-arma" alt="">' : m.icone;
      tr.innerHTML = `<td>${icoM} ${m.nome}</td><td><b>${preco}</b>🪙${alerta}</td><td>${carga}</td>`;
      const tdC = el('td'), tdV = el('td');
      const bC = el('button', 'btn mini', 'Comprar 5');
      bC.onclick = () => { const r = Economia.comprar(s, s.local, gId, 5); if (r.ok) Sfx.moeda(); aviso(r.msg); renderTudo(); };
      const bV = el('button', 'btn mini', 'Vender 5');
      bV.disabled = carga < 5;
      bV.onclick = () => { const r = Economia.vender(s, s.local, gId, 5); if (r.ok) Sfx.moeda(); else Sfx.alerta(); aviso(r.msg); renderTudo(); };
      tdC.appendChild(bC); tdV.appendChild(bV);
      tr.appendChild(tdC); tr.appendChild(tdV);
      tab.appendChild(tr);
    }
    painel.appendChild(tab);
    painel.appendChild(el('p', 'flavor', '💡 Compre barato onde há fartura (produção local 📉), venda caro onde há guerra e fome (📈). É assim que mercenários viram mercadores — e mercadores viram lordes.'));
    c.appendChild(painel);
  }

  // ---------- TAVERNA (contratos + NPCs locais) ----------
  function renderTaverna(c) {
    const s = Jogo.state;
    if (npcAtual) { renderConversa(c, npcAtual); return; }
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, '🍺 Taverna do Javali Manco'));
    const falat = Fofoca.falatorio(s); // o boato que corre as mesas este mês
    if (falat) painel.appendChild(el('p', 'flavor falatorio', esc(falat)));

    if (s.torneio) {
      const cardT = el('div', 'card-contrato');
      cardT.innerHTML = `<b><img src="img/armas/espada_dourada.png" class="ico-arma g" alt=""> TORNEIO DE ${s.torneio.reinoNome.toUpperCase()}</b><br><small>Lanças, glória e a chance de recrutar um CAMPEÃO DE GUERRA. Prazo: ${s.torneio.meses} ${s.torneio.meses === 1 ? 'mês' : 'meses'}. Inscrição: 100 🪙.</small>`;
      const bT = el('button', 'btn mini', '🐎 Entrar na justa!');
      bT.onclick = () => {
        const r = Politica.participarTorneio(s, Jogo.log);
        if (r.ok) { Sfx.tambor(); if (r.vitorias >= 3) Sfx.vitoria(); }
        aviso(r.msg); Jogo.salvar(); renderTudo();
      };
      cardT.appendChild(bT);
      painel.appendChild(cardT);
    }
    const reinoLocal = s.reinos.find(r => r.id === s.local);
    const cardM = el('div', 'card-contrato');
    cardM.innerHTML = `<b><img src="img/armas/escudo.png" class="ico-arma g" alt=""> Desafiar a milícia de ${reinoLocal.capital}</b><br><small>Duelo de companhias na praça. Vitória conquista a LEALDADE do povo (${Politica.lealdadeDe(s, s.local)}/100): preços melhores e, com 60+, a guarnição hesita em lutar contra você numa conquista.</small>`;
    const bM = el('button', 'btn mini', '⚔️ Desafiar!');
    bM.onclick = () => {
      const rel = Politica.desafiarMilicia(s, Jogo.log);
      Jogo.salvar();
      if (rel.rodadas) mostrarBatalha(rel); else { aviso(rel.msg); renderTudo(); }
    };
    cardM.appendChild(bM);
    painel.appendChild(cardM);

    if ((s.campeoes || []).length)
      painel.appendChild(el('p', 'flavor bom', '🏆 Campeões na sua companhia: ' + s.campeoes.map(c => `${c.nome} (+${c.bonus} atq)`).join(', ')));

    painel.appendChild(el('h3', null, 'Mural de Contratos'));
    for (const ct of s.contratos) {
      const contratante = s.reinos.find(r => r.id === ct.contratante);
      const alvo = ct.alvo ? s.reinos.find(r => r.id === ct.alvo) : null;
      const card = el('div', 'card-contrato');
      card.innerHTML = `<b>${ct.nome}</b> — para ${contratante.nome}${alvo ? ` (alvo: ${alvo.nome})` : ''}<br>
        <small>${ct.desc}</small><br>
        <small>💰 ${ct.pagamento} 🪙 · ⭐ +${ct.renome} renome · dificuldade ${'⚔️'.repeat(ct.forca)}</small>`;
      const b = el('button', 'btn mini', 'Aceitar e executar');
      b.onclick = () => {
        if (Combate.totalHomens(s.jogador.tropas) === 0) { aviso('Você não tem tropas! Recrute no quartel.'); return; }
        confirmar(`Partir em "${ct.nome}"? Suas tropas podem morrer.`, () => {
          const rel = Contratos.executar(s, ct, Jogo.log);
          s.contratos = s.contratos.filter(x => x.uid !== ct.uid);
          mostrarBatalha(rel);
        });
      };
      card.appendChild(b);
      painel.appendChild(card);
    }
    painel.appendChild(el('h3', null, 'Fregueses'));
    for (const npc of s.npcs) painel.appendChild(cardNpc(npc));
    c.appendChild(painel);
  }

  function retratoDe(id, tamanho, artId) {
    const wrap = el('div', 'moldura-retrato' + (tamanho === 'g' ? ' grande' : ''));
    const c = el('canvas', 'retrato' + (tamanho === 'g' ? ' retrato-grande' : ''));
    Retratos.montar(c, id, Retratos.humorDe(Jogo.state, id), artId);
    wrap.appendChild(c);
    return wrap;
  }

  function cardNpc(npc) {
    const s = Jogo.state;
    const tags = s.tags[npc.id] || { relacao: 0 };
    const card = el('div', 'card-npc com-retrato');
    card.appendChild(retratoDe(npc.id, null, npc.retratoId));
    const agora = Agenda.linha(s, npc); // a agenda do mês vaza no painel
    const info = el('div', 'npc-info',
      `<b>${npc.nome}</b> <small>(${Dialogo.nomeRelacao(tags.relacao)} ${tags.relacao})</small><br><small><i>${npc.desc}</i></small>` +
      (agora ? `<br><small class="agenda-npc">📍 Agora: ${agora}</small>` : ''));
    const b = el('button', 'btn mini', '💬 Conversar');
    b.onclick = () => { npcAtual = npc; renderTudo(); };
    info.appendChild(el('div')).appendChild(b);
    card.appendChild(info);
    return card;
  }

  // ---------- CORTE (falar com o rei local) ----------
  function renderCorte(c) {
    const s = Jogo.state;
    const reino = s.reinos.find(r => r.id === s.local);
    if (npcAtual) { renderConversa(c, npcAtual); return; }
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, `👑 Corte de ${reino.capital}`));
    painel.appendChild(el('p', 'flavor', `Tochas, tapeçarias e sussurros. No trono, ${reino.rei.nome}.`));
    painel.appendChild(cardNpc({ ...reino.rei }));
    if (Politica.podeSerArmado(s, s.local)) {
      const bCav = el('button', 'btn', `⚔️ Ajoelhar-se: pedir a ${reino.rei.nome} para ser armado CAVALEIRO`);
      bCav.onclick = () => { const r = Politica.armarCavaleiro(s, s.local, Jogo.log); if (r.ok) Sfx.vitoria(); aviso(r.msg); Jogo.salvar(); renderTudo(); };
      painel.appendChild(bCav);
    } else if (!Politica.eCavaleiro(s)) {
      painel.appendChild(el('p', 'flavor', `🎖️ Progressão: 60⭐ + relação 40 com um rei → CAVALEIRO (compra terra) → Senhor → Barão (terra 2) → CONDE (terra 4, nobre) → só nobres reivindicam tronos.`));
    }
    if (!s.jogador.reiDe && !s.jogador.vassaloDe) {
      const relRei = (s.tags['rei_' + s.local] || { relacao: 0 }).relacao;
      const bVas = el('button', 'btn sec', `🛡️ Jurar vassalagem a ${reino.rei.nome} (relação ${relRei}/30) — proteção e contratos +30%`);
      bVas.onclick = () => { const r = Politica.jurarVassalagem(s, s.local, Jogo.log); aviso(r.msg); Jogo.salvar(); renderTudo(); };
      painel.appendChild(bVas);
    } else if (s.jogador.vassaloDe === s.local) {
      const bQue = el('button', 'btn sec', '⚡ Quebrar o juramento de vassalagem (relação −50, fama de traidor)');
      bQue.onclick = () => { const r = Politica.quebrarVassalagem(s, Jogo.log); aviso(r.msg); Jogo.salvar(); renderTudo(); };
      painel.appendChild(bQue);
    }
    painel.appendChild(el('p', 'flavor', '💡 Na conversa, escreva o que quiser: elogie, insulte, ameace, peça contratos, proponha casamento, pergunte sobre guerras e preços, chantageie com segredos, ofereça suborno, negocie a paz... O NPC entende — e LEMBRA.'));
    c.appendChild(painel);
  }

  // ---------- CONVERSA LIVRE ----------
  function renderConversa(c, npc) {
    const s = Jogo.state;
    const tags = Dialogo.tagsDe(s, npc.id);
    const painel = el('div', 'painel conversa');
    const cab = el('div', 'conversa-cab');
    const lado = el('div', 'conversa-persona');
    const retratoConversa = retratoDe(npc.id, 'g', npc.retratoId);
    lado.appendChild(retratoConversa);
    const iaLigada = typeof LLMNuvem !== 'undefined' && LLMNuvem.estaConfigurado();
    lado.appendChild(el('div', null,
      `<b>${npc.nome}</b><br><small>relação: <b class="${tags.relacao <= -25 ? 'ruim' : tags.relacao >= 25 ? 'bom' : ''}">${Dialogo.nomeRelacao(tags.relacao)} (${tags.relacao})</b></small>` +
      (iaLigada ? '<br><small class="ia-ativa">🧠 IA ligada</small>' : '')));
    cab.appendChild(lado);
    const bSair = el('button', 'btn mini', '← Sair da conversa');
    bSair.onclick = () => { npcAtual = null; renderTudo(); };
    cab.appendChild(bSair);
    painel.appendChild(cab);

    const hist = el('div', 'conversa-hist');
    hist.id = 'conversa-hist';
    if (!s.historicoConversa || s.historicoConversa.npc !== npc.id)
      s.historicoConversa = { npc: npc.id, linhas: [{ de: 'npc', texto: '*aguarda você falar*' }] };
    for (const l of s.historicoConversa.linhas) {
      hist.appendChild(el('div', 'fala ' + l.de,
        (l.de === 'voce' ? '<b>Você:</b> ' : `<b>${esc(npc.nome)}:</b> `) + esc(l.texto) +
        (l.efeitos && l.efeitos.length ? `<div class="tags-efeito">${esc(l.efeitos.join(' '))}</div>` : '')));
    }
    painel.appendChild(hist);

    const form = el('div', 'conversa-form');
    const input = el('input');
    input.type = 'text'; input.placeholder = 'Diga o que quiser... (ex.: "Vossa sabedoria é lendária, majestade" ou "seu porco covarde")';
    input.maxLength = 200;
    const bFalar = el('button', 'btn', 'Falar');
    let enviando = false;
    const rolar = () => { hist.scrollTop = hist.scrollHeight; };
    const bolha = (de, html) => el('div', 'fala ' + de, html);

    // o NPC "pondera" antes de responder e a fala sai letra a letra
    const enviar = () => {
      const texto = input.value.trim();
      if (!texto || enviando) return;
      enviando = true;
      input.value = '';
      input.placeholder = `${npc.nome} está ouvindo...`;
      s.historicoConversa.linhas.push({ de: 'voce', texto });
      hist.appendChild(bolha('voce', '<b>Você:</b> ' + esc(texto)));
      const tb = bolha('npc digitando',
        `<b>${npc.nome}</b> <span class="pondera">pondera</span><span class="pontos"><i>.</i><i>.</i><i>.</i></span>`);
      hist.appendChild(tb);
      rolar();

      // Com IA na nuvem ligada, a fala vem da API (a mecânica continua no
      // motor); sem ela, o motor offline responde. falarAsync cobre os dois
      // e cai no motor sozinho em qualquer erro — a mecânica aplica UMA vez.
      const usaIA = typeof LLMNuvem !== 'undefined' && LLMNuvem.estaConfigurado();
      (async () => {
        const inicio = performance.now();
        let r;
        try { r = await Dialogo.falarAsync(s, npc, texto); }
        catch (e) { r = Dialogo.falar(s, npc, texto); }
        // garante um tempo mínimo de "pondera" mesmo quando a resposta é instantânea
        const minPondera = usaIA ? 150 : (420 + Math.random() * 500);
        const jaPassou = performance.now() - inicio;
        if (jaPassou < minPondera) await new Promise(res => setTimeout(res, minPondera - jaPassou));

        Sfx.pagina();
        tb.classList.remove('digitando');
        retratoConversa.classList.add('falando'); // retrato balança enquanto fala
        tb.innerHTML = `<b>${npc.nome}:</b> <span class="tw"></span>`;
        const alvo = tb.querySelector('.tw');
        let i = 0;
        const timer = setInterval(() => {
          i += 2;
          alvo.textContent = r.resposta.slice(0, i);
          rolar();
          if (i >= r.resposta.length) {
            clearInterval(timer);
            retratoConversa.classList.remove('falando');
            if (r.efeitos.length) tb.appendChild(el('div', 'tags-efeito', r.efeitos.join(' ')));
            s.historicoConversa.linhas.push({ de: 'npc', texto: r.resposta, efeitos: r.efeitos });
            enviando = false;
            input.placeholder = 'Diga o que quiser...';
            for (const a of r.acoes) {
              if (a.tipo === 'fim_conversa') { npcAtual = null; }
              if (a.tipo === 'casamento') Intriga.realizarCasamento(s, a.reino, false);
              if (a.tipo === 'oferecer_contratos') { abaAtual = 'taverna'; npcAtual = null; }
            }
            Jogo.salvar();
            renderTudo();
          }
        }, 26);
      })();
    };
    bFalar.onclick = enviar;
    input.onkeydown = (e) => { if (e.key === 'Enter') enviar(); };
    form.appendChild(input); form.appendChild(bFalar);
    painel.appendChild(form);
    c.appendChild(painel);
    setTimeout(() => { rolar(); if (window.innerWidth > 700) input.focus(); }, 0);
  }

  // ---------- EXÉRCITO ----------
  function renderExercito(c) {
    const s = Jogo.state, j = s.jogador;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, '⚔️ Quartel'));
    const p = Combate.poder(j.tropas, j.equip);
    painel.appendChild(el('p', 'flavor', `Força total: ataque ${Math.round(p.atq)}, defesa ${Math.round(p.def)}, ${p.homens} homens. Manutenção mensal: ${j.ultimaManut || '—'} 🪙. Equipamento nível ${j.equip}/3.`));

    const tab = el('table', 'tabela');
    tab.innerHTML = '<tr><th>Tropa</th><th>Você tem</th><th>Custo</th><th>Manut.</th><th></th></tr>';
    for (const [tipo, t] of Object.entries(TROPAS)) {
      const tr = el('tr');
      const armaDe = { campones: 'machado', lanceiro: 'lanca', arqueiro: 'arco', cavaleiro: 'espada' };
      tr.innerHTML = `<td><img src="img/armas/${armaDe[tipo] || 'espada'}.png" class="ico-arma" alt=""> ${t.nome}</td><td><b>${j.tropas[tipo] || 0}</b></td><td>${t.custo}🪙</td><td>${t.manut}🪙/mês</td>`;
      const td = el('td');
      const b = el('button', 'btn mini', 'Recrutar 5');
      b.onclick = () => { aviso(Jogo.recrutar(tipo, 5).msg); renderTudo(); };
      td.appendChild(b); tr.appendChild(td);
      tab.appendChild(tr);
    }
    painel.appendChild(tab);
    if (s.terra) painel.appendChild(el('p', 'flavor', `⚠️ Camponeses saem da SUA vila (${s.terra.populacao} hab.). Convocar demais = colheita perdida = fome = rebelião.`));

    painel.appendChild(el('h3', null, 'Formação de batalha'));
    const linhaForm = el('div', 'linha-botoes');
    for (const [fId, f] of Object.entries(FORMACOES)) {
      const b = el('button', 'btn mini' + (j.formacao === fId ? ' ativa' : ''), f.nome);
      b.title = f.desc;
      b.onclick = () => { j.formacao = fId; renderTudo(); };
      linhaForm.appendChild(b);
    }
    painel.appendChild(linhaForm);
    painel.appendChild(el('p', 'flavor', '💡 Linha de Escudos vence Cunha; Cunha rompe Envolvimento; Envolvimento flanqueia a Linha. Escolha pensando no inimigo.'));

    const custoEq = Math.round(200 * (j.equip + 1) * (1 - Producao.descontoEquip(s)));
    const descEq = Producao.descontoEquip(s);
    const bEq = el('button', 'btn', '');
    bEq.innerHTML = `<img src="img/armas/martelo.png" class="ico-arma" alt=""> Melhorar equipamento (${custoEq} 🪙${descEq > 0 ? ` · −${Math.round(descEq * 100)}% do ferreiro` : ''})`;
    bEq.disabled = j.equip >= 3;
    bEq.onclick = () => { aviso(Jogo.melhorarEquip().msg); renderTudo(); };
    painel.appendChild(bEq);
    const bG = el('button', 'btn sec', '');
    bG.innerHTML = '<img src="img/armas/escudo_celta.png" class="ico-arma" alt=""> Contratar 2 guardas de elite (120 🪙, 4🪙/mês cada)';
    bG.onclick = () => { aviso(Jogo.contratarGuardas(2).msg); renderTudo(); };
    painel.appendChild(bG);
    painel.appendChild(el('p', 'flavor ruim', '⚠️ Se o tesouro zerar, tropas desertam — e a guarda de elite pode ser comprada por rivais para abrir seus portões à noite.'));
    c.appendChild(painel);
  }

  // ---------- CLÃS MERCENÁRIOS (mensageiros e cartas) ----------
  function renderClas(c) {
    const s = Jogo.state;
    if (!s.cartas) s.cartas = [];
    const painel = el('div', 'painel mesa');
    painel.appendChild(el('h2', null, '🐺 Clãs Mercenários'));
    painel.appendChild(el('p', 'flavor', 'Companhias livres que não servem a rei nenhum — servem a quem paga. Envie um mensageiro com sua oferta de ouro; a resposta chega com a virada do mês. Oferta generosa convence; ninharia ofende.'));

    for (const cla of Clas.CLAS) {
      const contrato = Clas.ativo(s, cla.id);
      const naEstrada = Clas.mensageiroPendente(s, cla.id);
      const rel = (s.tags[cla.id] || { relacao: 0 }).relacao;
      const card = el('div', 'card-reino com-retrato');
      card.style.borderLeftColor = '#c9a227';
      card.appendChild(retratoDe(cla.id));
      const info = el('div', 'npc-info', `
        <b>${cla.nome}</b> — ${cla.lider} <small>(${Dialogo.nomeRelacao(rel)} ${rel})</small><br>
        <small><i>${cla.desc}</i> · ${cla.lema}</small><br>
        <small>⚔️ ${Clas.resumoContingente(cla.contingente)} · 💰 pede ~${cla.precoBase} + ${cla.soldo}/mês · ⭐ exige ${cla.renomeMin}</small>`);
      if (contrato) {
        info.appendChild(el('p', 'flavor bom', `🤝 Sob contrato: restam ${contrato.mesesRestantes} ${contrato.mesesRestantes === 1 ? 'mês' : 'meses'}. Mantenha o soldo em dia.`));
      } else if (naEstrada) {
        info.appendChild(el('p', 'flavor', `🐴 Mensageiro na estrada com oferta de ${naEstrada.oferta} de ouro...`));
      } else {
        const linha = el('div', 'linha-botoes oferta-linha');
        const input = el('input', 'input-oferta');
        input.type = 'number'; input.min = 50; input.step = 50; input.value = cla.precoBase;
        input.placeholder = 'oferta';
        const b = el('button', 'btn mini', '✉️ Enviar mensageiro (10 🪙)');
        b.onclick = () => {
          const oferta = Math.max(0, parseInt(input.value, 10) || 0);
          const r = Clas.enviarMensageiro(s, cla.id, oferta);
          if (r.ok) Sfx.pagina(); else Sfx.alerta();
          aviso(r.msg); Jogo.salvar(); renderTudo();
        };
        linha.appendChild(input); linha.appendChild(b);
        info.appendChild(linha);
      }
      card.appendChild(info);
      painel.appendChild(card);
    }

    painel.appendChild(el('h3', null, '✉️ Cartas recebidas'));
    if (!s.cartas.length) painel.appendChild(el('p', 'flavor', 'Nenhuma carta sobre a mesa. Os mensageiros trazem as respostas — e as más notícias.'));
    for (const carta of s.cartas.slice(0, 8)) {
      painel.appendChild(el('div', 'carta' + (carta.tipo === 'ruim' ? ' selada' : ''),
        `<b>De: ${carta.de}</b> <small>· ${MESES[carta.mes - 1].slice(0, 3)}/A${carta.ano}</small><br>${carta.texto}`));
    }
    painel.appendChild(el('p', 'flavor ruim', '⚠️ Clã sem soldo rasga o contrato, pode saquear seus celeiros e espalha sua fama de caloteiro para os outros clãs. Em guerra, mensageiros podem ser interceptados.'));
    c.appendChild(painel);
  }

  // ---------- INTRIGAS (mesa de madeira com cartas) ----------
  function renderIntrigas(c) {
    const s = Jogo.state;
    const painel = el('div', 'painel mesa');
    const h2Int = el('h2', null, '');
    h2Int.innerHTML = '<img src="img/armas/adaga.png" class="ico-arma g" alt=""> Mesa de Intrigas';
    painel.appendChild(h2Int);

    if (s.chantagemPendente) {
      const reino = s.reinos.find(r => r.id === s.chantagemPendente.reino);
      const carta = el('div', 'carta selada');
      carta.innerHTML = `<b>✉️ Chantagem em curso — ${reino.rei.nome} cedeu.</b><br><small>Escolha sua exigência:</small>`;
      const lb = el('div', 'linha-botoes');
      for (const [k, txt] of [['ouro', '💰 Ouro (300–500)'], ['casamento', '💍 Casamento forçado'], ['casusbelli', '📜 Casus Belli']]) {
        const b = el('button', 'btn mini', txt);
        b.onclick = () => { Intriga.resolverChantagem(s, k, Jogo.log); renderTudo(); };
        lb.appendChild(b);
      }
      carta.appendChild(lb);
      painel.appendChild(carta);
    }

    painel.appendChild(el('h3', null, 'Segredos que você guarda'));
    if (!s.segredos.length) painel.appendChild(el('p', 'flavor', 'Nenhum. Mande espiões às cortes — todo rei esconde algo que vale mais que ouro.'));
    for (const seg of s.segredos) {
      const reino = s.reinos.find(r => r.id === seg.reino);
      painel.appendChild(el('div', 'carta' + (seg.usado ? ' usada' : ''),
        `✉️ <b>${reino.nome}:</b> ${seg.texto} ${seg.usado ? '<small>(já usado)</small>' : '<small>(chantageie o rei em conversa: "sei o que você fez...")</small>'}`));
    }

    painel.appendChild(el('h3', null, 'Operações'));
    for (const r of s.reinos) {
      if (s.jogador.reiDe === r.id) continue;
      const linha = el('div', 'card-reino');
      linha.style.borderLeftColor = r.cor;
      const cb = s.casusBelli.includes(r.id);
      linha.innerHTML = `<b>${r.nome}</b> ${cb ? '<small class="bom">📜 casus belli obtido</small>' : ''}`;
      const lb = el('div', 'linha-botoes');
      const bEsp = el('button', 'btn mini', '🕵️ Espionar (80 🪙)');
      bEsp.onclick = () => { aviso(Intriga.espionar(s, r.id, Jogo.log).msg); renderTudo(); };
      lb.appendChild(bEsp);
      if (!cb) {
        const bDoc = el('button', 'btn mini', '📜 Forjar documento (150 🪙)');
        bDoc.onclick = () => { aviso(Intriga.forjarDocumento(s, r.id, Jogo.log).msg); renderTudo(); };
        const bInt = el('button', 'btn mini', '🎭 Fabricar intriga (250 🪙)');
        bInt.onclick = () => { aviso(Intriga.fabricarIntriga(s, r.id, Jogo.log).msg); renderTudo(); };
        lb.appendChild(bDoc); lb.appendChild(bInt);
      }
      linha.appendChild(lb);
      painel.appendChild(linha);
    }
    painel.appendChild(el('p', 'flavor', '💡 Guerra sem casus belli une os 6 reinos contra você. Forje, fabrique, case ou chantageie — a legalidade é só uma questão de criatividade.'));
    c.appendChild(painel);
  }

  // ---------- FAMÍLIA ----------
  function renderFamilia(c) {
    const s = Jogo.state, f = s.familia, j = s.jogador;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, '🏰 Sua Casa'));
    const attrs = (a) => `💪${a.forca} 🗣️${a.carisma} 📊${a.gestao} 🗡️${a.intriga}`;
    painel.appendChild(el('p', null, `<b>${j.nome}</b>, ${j.idade} anos — ${attrs(j.atributos)}${j.crueldade >= 3 ? ' · <span class="ruim">reputação de crueldade</span>' : ''}`));

    if (f.conjuge) {
      const reino = s.reinos.find(r => r.id === f.conjuge.reino);
      const cardConj = el('div', 'card-npc com-retrato');
      cardConj.appendChild(retratoDe('conjuge_' + f.conjuge.nome.replace(/\s+/g, '_')));
      cardConj.appendChild(el('div', 'npc-info', `💍 Casado com <b>${f.conjuge.nome}</b> (${reino.nome}${f.conjuge.forcado ? ', união... negociada sob pressão' : ''})<br><small>${attrs(f.conjuge.atributos)}</small>`));
      painel.appendChild(cardConj);
    } else {
      painel.appendChild(el('p', 'flavor', 'Solteiro. Casamento com casa real exige 40+ de renome e boa relação com o rei — ou um segredo sujo dele. Peça a mão em conversa na corte.'));
    }

    painel.appendChild(el('h3', null, 'Herdeiros'));
    if (!f.filhos.length) painel.appendChild(el('p', 'flavor', 'Nenhum filho. Sem herdeiro, sua morte é o fim da linhagem — e do jogo.'));
    f.filhos.forEach((filho, i) => {
      const card = el('div', 'card-npc');
      card.innerHTML = `<b>${filho.nome}</b>, ${filho.idade} anos — ${attrs(filho.atributos)}
        ${filho.mimado ? '<span class="ruim"> · mimado e cruel (vassalos conspirarão!)</span>' : ''}
        ${filho.educacao ? `<small> · educação ${filho.educacao}</small>` : ''}
        ${filho.idade >= 16 ? ' · <b class="bom">herdeiro apto</b>' : ''}`;
      if (!filho.educacao && filho.idade >= 6) {
        const lb = el('div', 'linha-botoes');
        for (const [ed, txt] of [['marcial', '⚔️ Marcial'], ['cortesa', '🗣️ Cortesã'], ['administrativa', '📊 Administrativa'], ['sombras', '🗡️ Sombras']]) {
          const b = el('button', 'btn mini', txt);
          b.onclick = () => { aviso(Intriga.educar(s, i, ed).msg); renderTudo(); };
          lb.appendChild(b);
        }
        card.appendChild(lb);
      }
      painel.appendChild(card);
    });
    painel.appendChild(el('p', 'flavor', '💡 Atributos passam por sangue (média dos pais ± sorte) e por educação. Um herdeiro mimado herda seus inimigos E cria os próprios.'));
    c.appendChild(painel);
  }

  // ---------- CRÔNICA ----------
  function renderCronica(c) {
    const s = Jogo.state;
    const painel = el('div', 'painel pergaminho');
    painel.appendChild(el('h2', null, '📜 Crônica da Casa'));
    for (const l of s.cronica)
      painel.appendChild(el('p', 'linha-cronica', `<small>${MESES[l.mes - 1].slice(0, 3)}/A${l.ano}</small> — ${l.msg}`));
    c.appendChild(painel);
  }

  // ---------- eventos modais ----------
  function renderEvento() {
    Sfx.alerta();
    const s = Jogo.state, ev = s.eventoPendente;
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    if (ev.tipo === 'rebeliao') {
      box.appendChild(el('h2', null, '🔥 REBELIÃO!'));
      box.appendChild(el('p', null, `O povo de ${s.terra.nome} marcha sobre sua residência com foices, tochas e uma lista de queixas escrita com fome.`));
      botaoEvento(box, '⚔️ Reprimir pela força (batalha; o povo lembrará)', 'reprimir');
      botaoEvento(box, '🕊️ Abrir os celeiros e ceder (−até 200 🪙, +alimento ao povo)', 'conceder');
    } else if (ev.tipo === 'traicao_guardas') {
      box.appendChild(el('h2', null, '🌙 Traição por Ouro'));
      box.appendChild(el('p', null, `Sua guarda de elite está sem soldo — e um reino rival ofereceu o dobro para abrirem seus portões esta noite.`));
      botaoEvento(box, `💰 Pagar em dobro agora (${s.jogador.guardas * 15} 🪙)`, 'pagar');
      botaoEvento(box, '🎲 Confiar na "lealdade" deles', 'recusar');
    } else if (ev.tipo === 'assassinato') {
      const reino = s.reinos.find(r => r.id === ev.reino);
      box.appendChild(el('h2', null, '🗡️ Assassino!'));
      box.appendChild(el('p', null, `Você acorda com uma sombra ao pé da cama — um assassino enviado por ${reino.rei.nome}, que nunca esqueceu suas palavras.`));
      botaoEvento(box, `⚔️ Lutar por sua vida (força ${s.jogador.atributos.forca})`, 'lutar');
    }
  }

  function botaoEvento(box, texto, escolha) {
    const b = el('button', 'btn', texto);
    b.onclick = () => {
      const rel = Jogo.resolverEvento(escolha);
      Jogo.salvar();
      if (rel) mostrarBatalha(rel); else renderTudo();
    };
    box.appendChild(b);
  }

  function renderFim() {
    const s = Jogo.state, j = s.jogador;
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    const vit = s.fim.tipo === 'vitoria';
    const banner = el('div', 'fim-banner');
    banner.innerHTML = `<img src="img/hud/logo.png" class="fim-logo" alt=""><br>
      <img src="img/hud/banner_${vit ? 'vitoria' : 'derrota'}.png" class="fim-titulo ${vit ? '' : 'derrota'}" alt="${vit ? 'VITÓRIA' : 'FIM DA SAGA'}">`;
    box.appendChild(banner);
    box.appendChild(el('p', null, s.fim.msg));
    // resumo da saga
    const anos = s.ano - 1, tit = Politica.titulo(s);
    const jornada = anos <= 0 ? 'menos de um ano' : `${anos} ${anos === 1 ? 'ano' : 'anos'}`;
    box.appendChild(el('p', 'flavor', `📜 A saga de <b>${j.nome}</b>: ${jornada} de jornada · título final: <b>${tit}</b> · ⭐ ${j.renome} de renome · 🪙 ${Math.max(0, j.ouro).toLocaleString('pt-BR')} no tesouro · 🏰 ${Politica.meusNobres(s).length} lordes sob sua bandeira.`));
    const b = el('button', 'btn destaque', '🗡️ Nova saga');
    b.onclick = () => { Jogo.apagarSave(); location.reload(); };
    box.appendChild(b);
  }

  // ---------- relatório de batalha ----------
  function mostrarBatalha(rel) {
    Sfx.tambor(); Sfx.espada();
    setTimeout(() => rel.vitoria ? Sfx.vitoria() : Sfx.derrota(), 500);
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    box.appendChild(el('h2', null, (rel.vitoria ? '🏆 VITÓRIA — ' : '☠️ DERROTA — ') + (rel.contexto || 'Batalha')));
    // cena animada do duelo (sprites do pacote de cavaleiros)
    const cvD = el('canvas', 'duelo-canvas');
    cvD.width = 340; cvD.height = 130;
    box.appendChild(cvD);
    const ctx = rel.contexto || '';
    const inimigo = /rebeli|mil[ií]cia|bandid|saque|touros|caravana|estrada/i.test(ctx) ? 'bandido'
      : /imp[eé]rio|felps|legi[aã]o|trono|rei /i.test(ctx) ? 'rei' : 'guerreiro';
    Duelo.iniciar(cvD, !!rel.vitoria, inimigo);
    for (const r of rel.rodadas) {
      const vant = r.ventJ > 1 ? ' (sua formação venceu a deles!)' : r.ventI > 1 ? ' (a formação DELES venceu a sua!)' : '';
      box.appendChild(el('p', 'linha-cronica',
        `Rodada ${r.rodada}: inimigo em <b>${FORMACOES[r.formacaoInimiga].nome}</b>${vant} — baixas: você −${r.baixasJ}, inimigo −${r.baixasI}.`));
    }
    if (rel.debandada) box.appendChild(el('p', null, rel.debandada === 'inimigo' ? '🏃 O inimigo debandou!' : '🏃 Suas tropas debandaram!'));
    const totalJ = Object.values(rel.baixasJogador).reduce((a, x) => a + x, 0);
    box.appendChild(el('p', null, `Cada soldado conta: você perdeu <b>${totalJ}</b> homens nesta ação.`));
    const b = el('button', 'btn', 'Continuar');
    b.onclick = () => { Duelo.parar(); Jogo.salvar(); renderTudo(); };
    box.appendChild(b);
  }

  // ---------- utilitários ----------
  function aviso(msg) {
    if (!msg) return;
    const a = el('div', 'toast', msg);
    document.body.appendChild(a);
    setTimeout(() => a.classList.add('show'), 10);
    setTimeout(() => { a.classList.remove('show'); setTimeout(() => a.remove(), 400); }, 3500);
  }

  // ---------- fundação do reino: nome + escolha de bandeira ----------
  function modalFundarReino() {
    const s = Jogo.state;
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    box.appendChild(el('h2', null, '👑 Fundar o seu Reino'));
    box.appendChild(el('p', null, `Coroa, corte, selo real e arautos custam <b>${CUSTO_FUNDAR_REINO.toLocaleString('pt-BR')} 🪙</b> (você tem ${s.jogador.ouro.toLocaleString('pt-BR')}). Escolha o nome e a bandeira que o continente vai aprender a temer.`));
    const inp = el('input');
    inp.type = 'text'; inp.maxLength = 30; inp.placeholder = 'Nome do reino (ex.: Reino de ' + (s.jogador.nome.split(' ')[0] || 'Aço') + ')';
    inp.className = 'input-reino';
    box.appendChild(inp);
    box.appendChild(el('p', 'flavor', '🏴 Escolha sua bandeira:'));
    let escolhida = BANDEIRAS_JOGADOR[0].id;
    const linha = el('div', 'linha-bandeiras');
    const cartoes = [];
    for (const b of BANDEIRAS_JOGADOR) {
      const cardB = el('div', 'card-bandeira' + (b.id === escolhida ? ' ativa' : ''));
      cardB.innerHTML = `<img src="img/bandeiras/${b.id}.png" alt="${b.nome}"><br><b>${b.nome}</b><br><small>${b.desc}</small>`;
      cardB.onclick = () => { escolhida = b.id; cartoes.forEach(cc => cc.classList.remove('ativa')); cardB.classList.add('ativa'); };
      cartoes.push(cardB);
      linha.appendChild(cardB);
    }
    box.appendChild(linha);
    const bOk = el('button', 'btn destaque', '👑 PROCLAMAR');
    bOk.onclick = () => {
      const r = Politica.proclamarIndependencia(s, Jogo.log, inp.value, escolhida);
      if (r.ok) Sfx.vitoria(); else Sfx.alerta();
      aviso(r.msg);
      modal.style.display = 'none';
      Jogo.salvar(); renderTudo();
    };
    const bNao = el('button', 'btn sec', 'Ainda não');
    bNao.onclick = () => { modal.style.display = 'none'; };
    box.appendChild(bOk); box.appendChild(bNao);
  }

  // ---------- configuração da IA na nuvem ----------
  function abrirConfigIA(aoFechar) {
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    box.appendChild(el('h2', null, '🧠 IA das conversas'));
    box.appendChild(el('p', 'flavor',
      'Ligue uma IA de verdade e converse LIVREMENTE com os reis — eles entendem e respondem qualquer coisa, no personagem. ' +
      'A mecânica do jogo (relação, ouro, memória) continua no motor; a IA só dá voz. ' +
      'Sua chave fica só neste aparelho, nunca é enviada a nós nem salva no jogo. Sem internet, o jogo usa o motor offline.'));

    const provAtual = LLMNuvem.provedor() || 'claude';
    const linhaProv = el('div', 'ia-campo');
    linhaProv.appendChild(el('label', null, 'Provedor'));
    const sel = el('select', 'input-reino');
    for (const [id, p] of Object.entries(LLMNuvem.PROVEDORES)) {
      const opt = el('option', null, p.nome); opt.value = id;
      if (id === provAtual) opt.selected = true;
      sel.appendChild(opt);
    }
    linhaProv.appendChild(sel);
    box.appendChild(linhaProv);

    const linhaKey = el('div', 'ia-campo');
    const lblKey = el('label', null, 'Chave de API');
    linhaKey.appendChild(lblKey);
    const inpKey = el('input', 'input-reino');
    inpKey.type = 'password'; inpKey.placeholder = 'cole aqui a sua chave';
    inpKey.value = LLMNuvem.chave || '';
    linhaKey.appendChild(inpKey);
    const dica = el('small', 'flavor', '');
    linhaKey.appendChild(dica);
    box.appendChild(linhaKey);

    const linhaModelo = el('div', 'ia-campo');
    linhaModelo.appendChild(el('label', null, 'Modelo (opcional)'));
    const inpModelo = el('input', 'input-reino');
    const provObj = () => LLMNuvem.PROVEDORES[sel.value];
    inpModelo.placeholder = 'padrão: ' + provObj().modeloPadrao;
    inpModelo.value = (LLMNuvem.provedor() === sel.value ? (LLMNuvem.modelo() === provObj().modeloPadrao ? '' : LLMNuvem.modelo()) : '');
    linhaModelo.appendChild(inpModelo);
    box.appendChild(linhaModelo);

    const atualizaDica = () => {
      dica.textContent = provObj().dica;
      inpModelo.placeholder = 'padrão: ' + provObj().modeloPadrao;
    };
    sel.onchange = atualizaDica; atualizaDica();

    const status = el('p', 'ia-status', '');
    box.appendChild(status);

    const linhaBtns = el('div', 'ia-botoes');
    const bTestar = el('button', 'btn sec', '🔌 Testar conexão');
    bTestar.onclick = async () => {
      const r = LLMNuvem.configurar(sel.value, inpKey.value, inpModelo.value);
      if (!r.ok) { status.className = 'ia-status ruim'; status.textContent = '⚠️ ' + r.msg; return; }
      status.className = 'ia-status'; status.textContent = '⏳ Testando...';
      bTestar.disabled = true;
      const t = await LLMNuvem.testar();
      bTestar.disabled = false;
      if (t.ok) { status.className = 'ia-status bom'; status.textContent = '✅ Funcionou! O taverneiro disse: "' + t.fala + '"'; }
      else { status.className = 'ia-status ruim'; status.textContent = '❌ Falhou: ' + t.erro; }
    };
    const bSalvar = el('button', 'btn destaque', '💾 Salvar e ligar');
    bSalvar.onclick = () => {
      const r = LLMNuvem.configurar(sel.value, inpKey.value, inpModelo.value);
      if (!r.ok) { status.className = 'ia-status ruim'; status.textContent = '⚠️ ' + r.msg; return; }
      Sfx.vitoria(); modal.style.display = 'none';
      if (aoFechar) aoFechar();
    };
    const bDesligar = el('button', 'btn sec', '🚫 Desligar IA');
    bDesligar.onclick = () => { LLMNuvem.desligar(); inpKey.value = ''; Sfx.tique();
      status.className = 'ia-status'; status.textContent = 'IA desligada — o jogo usa o motor offline.'; if (aoFechar) aoFechar(); };
    const bFechar = el('button', 'btn sec', 'Fechar');
    bFechar.onclick = () => { modal.style.display = 'none'; };
    linhaBtns.appendChild(bTestar); linhaBtns.appendChild(bSalvar);
    linhaBtns.appendChild(bDesligar); linhaBtns.appendChild(bFechar);
    box.appendChild(linhaBtns);
  }

  function confirmar(msg, fn) {
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    box.appendChild(el('h2', null, '⚖️ Decisão'));
    box.appendChild(el('p', null, msg));
    const bS = el('button', 'btn', 'Sim, adiante');
    bS.onclick = () => { modal.style.display = 'none'; fn(); };
    const bN = el('button', 'btn sec', 'Melhor não');
    bN.onclick = () => { modal.style.display = 'none'; renderTudo(); };
    box.appendChild(bS); box.appendChild(bN);
  }

  return { iniciar, renderTudo };
})();

window.addEventListener('DOMContentLoaded', UI.iniciar);
