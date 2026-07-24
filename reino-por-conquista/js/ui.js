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

    document.querySelectorAll('.aba').forEach(b => {
      b.onclick = () => { Sfx.pagina(); abaAtual = b.dataset.aba; npcAtual = null; renderTudo(); };
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
    }
  }

  function iniciarAnimacao() {
    if (animTimer) cancelAnimationFrame(animTimer);
    const loop = () => {
      const canvas = $('#canvas-cidade');
      if (canvas && canvas.offsetParent !== null && Jogo.state) Cidade.render(canvas, Jogo.state);
      Retratos.tick();
      animTimer = requestAnimationFrame(loop);
    };
    loop();
  }

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
  }

  // ---------- SUA TERRA (pixel art + gestão) ----------
  function renderTerra(c) {
    const s = Jogo.state, t = s.terra;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, t ? `${t.nome} — ${NIVEIS_TERRA[t.nivel].nome}` : 'Acampamento Mercenário'));
    const wrap = el('div', 'canvas-wrap');
    const canvas = el('canvas');
    canvas.id = 'canvas-cidade'; canvas.width = 480; canvas.height = 270;
    wrap.appendChild(canvas);
    painel.appendChild(wrap);

    if (!t) {
      painel.appendChild(el('p', 'flavor', 'Sem terras, sem raízes. Sua "corte" é uma fogueira e três tendas na beira da estrada. Junte 25 de renome e 300 de ouro para comprar seu primeiro pedaço de chão.'));
      const b = el('button', 'btn', '🏕️ Comprar terra (300 🪙, requer 25 ⭐)');
      b.onclick = () => aviso(Jogo.comprarTerra().msg) || renderTudo();
      painel.appendChild(b);
    } else {
      const col = t.ultimaColeta;
      painel.appendChild(el('div', 'grade', `
        <div class="celula">👥 População<br><b>${t.populacao}</b></div>
        <div class="celula">🌾 Alimento<br><b>${t.alimento}</b>${col ? ` <small>(+${col.producao}/−${col.consumo})</small>` : ''}</div>
        <div class="celula">🪵 Madeira<br><b>${t.madeira}</b></div>
        <div class="celula">😊 Felicidade<br><b class="${t.felicidade <= 30 ? 'ruim' : t.felicidade >= 60 ? 'bom' : ''}">${t.felicidade}</b></div>`));
      if (t.felicidade <= 30) painel.appendChild(el('p', 'flavor ruim', '⚠️ O povo murmura nas tavernas. Felicidade baixa demais termina em foices e tochas na sua porta.'));
      if (t.nivel < 5) {
        const prox = NIVEIS_TERRA[t.nivel + 1];
        const b = el('button', 'btn', `🏗️ Evoluir para ${prox.nome} (${prox.custoOuro} 🪙 + ${prox.custoMadeira} 🪵)`);
        b.onclick = () => { aviso(Jogo.melhorarTerra().msg); renderTudo(); };
        painel.appendChild(b);
        painel.appendChild(el('p', 'flavor', prox.desc));
      } else {
        painel.appendChild(el('p', 'flavor bom', '🏰 Seu castelo domina o horizonte. Falta apenas uma coroa.'));
      }
      const bExp = el('button', 'btn sec', '📦 Exportar 30 de alimento da vila (ouro rápido, povo faminto reclama)');
      bExp.onclick = () => { aviso(Economia.exportarComidaDaTerra(Jogo.state, 30).msg); renderTudo(); };
      painel.appendChild(bExp);
    }
    c.appendChild(painel);
  }

  // ---------- MAPA (reinos, guerras, relações) ----------
  function renderMapa(c) {
    const s = Jogo.state;
    const painel = el('div', 'painel');
    painel.appendChild(el('h2', null, 'Os Seis Reinos'));
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
      card.style.borderLeftColor = r.cor;
      card.appendChild(retratoDe(r.rei.id));
      const infoReino = el('div', 'npc-info', `
        <b>${r.nome}</b> — capital ${r.capital}<br>
        <small>${r.rei.nome} · <i>${r.rei.desc}</i></small><br>
        <small>Relação: <b class="${tags.relacao <= -25 ? 'ruim' : tags.relacao >= 25 ? 'bom' : ''}">${rel} (${tags.relacao})</b>
        ${cb ? ' · <b class="bom">📜 Casus Belli</b>' : ''}
        ${s.jogador.reiDe === r.id ? ' · <b class="bom">👑 SEU TRONO</b>' : ''}</small>`);
      card.appendChild(infoReino);
      const botoes = el('div', 'linha-botoes');
      const bIr = el('button', 'btn mini', s.local === r.id ? '📍 Você está aqui' : '🐴 Viajar');
      bIr.disabled = s.local === r.id;
      bIr.onclick = () => { s.local = r.id; Jogo.log(`🐴 Você viaja para ${r.nome}.`); renderTudo(); };
      botoes.appendChild(bIr);
      if (!s.jogador.reiDe) {
        const bGuerra = el('button', 'btn mini ruim-btn', cb ? '⚔️ Guerra de conquista (com CB)' : '⚔️ Atacar SEM casus belli');
        bGuerra.onclick = () => confirmar(
          cb ? `Marchar sobre ${r.capital} com sua reivindicação legal?`
             : `Atacar ${r.nome} SEM justificativa legal? Os 6 reinos se voltarão contra você!`,
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
      tr.innerHTML = `<td>${m.icone} ${m.nome}</td><td><b>${preco}</b>🪙${alerta}</td><td>${carga}</td>`;
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

  function retratoDe(id, tamanho) {
    const c = el('canvas', 'retrato' + (tamanho === 'g' ? ' retrato-grande' : ''));
    Retratos.montar(c, id, Retratos.humorDe(Jogo.state, id));
    return c;
  }

  function cardNpc(npc) {
    const s = Jogo.state;
    const tags = s.tags[npc.id] || { relacao: 0 };
    const card = el('div', 'card-npc com-retrato');
    card.appendChild(retratoDe(npc.id));
    const info = el('div', 'npc-info',
      `<b>${npc.nome}</b> <small>(${Dialogo.nomeRelacao(tags.relacao)} ${tags.relacao})</small><br><small><i>${npc.desc}</i></small>`);
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
    lado.appendChild(retratoDe(npc.id, 'g'));
    lado.appendChild(el('div', null,
      `<b>${npc.nome}</b><br><small>relação: <b class="${tags.relacao <= -25 ? 'ruim' : tags.relacao >= 25 ? 'bom' : ''}">${Dialogo.nomeRelacao(tags.relacao)} (${tags.relacao})</b></small>`));
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
        (l.de === 'voce' ? '<b>Você:</b> ' : `<b>${npc.nome}:</b> `) + l.texto +
        (l.efeitos && l.efeitos.length ? `<div class="tags-efeito">${l.efeitos.join(' ')}</div>` : '')));
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
      hist.appendChild(bolha('voce', '<b>Você:</b> ' + texto));
      const tb = bolha('npc digitando',
        `<b>${npc.nome}</b> <span class="pondera">pondera</span><span class="pontos"><i>.</i><i>.</i><i>.</i></span>`);
      hist.appendChild(tb);
      rolar();

      const r = Dialogo.falar(s, npc, texto);
      // quanto mais longa e pesada a resposta, mais tempo ele "pensa"
      const atraso = Math.min(2600, 550 + r.resposta.length * 9) * (0.75 + Math.random() * 0.5);
      setTimeout(() => {
        Sfx.pagina();
        tb.classList.remove('digitando');
        tb.innerHTML = `<b>${npc.nome}:</b> <span class="tw"></span>`;
        const alvo = tb.querySelector('.tw');
        let i = 0;
        const timer = setInterval(() => {
          i += 2;
          alvo.textContent = r.resposta.slice(0, i);
          rolar();
          if (i >= r.resposta.length) {
            clearInterval(timer);
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
      }, atraso);
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
      tr.innerHTML = `<td>${t.icone} ${t.nome}</td><td><b>${j.tropas[tipo] || 0}</b></td><td>${t.custo}🪙</td><td>${t.manut}🪙/mês</td>`;
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

    const bEq = el('button', 'btn', `🛠️ Melhorar equipamento (${200 * (j.equip + 1)} 🪙)`);
    bEq.onclick = () => { aviso(Jogo.melhorarEquip().msg); renderTudo(); };
    painel.appendChild(bEq);
    const bG = el('button', 'btn sec', '🛡️ Contratar 2 guardas de elite (120 🪙, 4🪙/mês cada)');
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
    painel.appendChild(el('h2', null, '🕯️ Mesa de Intrigas'));

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
      painel.appendChild(el('p', null, `💍 Casado com <b>${f.conjuge.nome}</b> (${reino.nome}${f.conjuge.forcado ? ', união... negociada sob pressão' : ''}) — ${attrs(f.conjuge.atributos)}`));
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
    const s = Jogo.state;
    const modal = $('#modal');
    modal.style.display = 'flex';
    const box = $('#modal-box');
    box.innerHTML = '';
    box.appendChild(el('h2', null, s.fim.tipo === 'vitoria' ? '👑 REINO POR CONQUISTA' : '💀 FIM DA SAGA'));
    box.appendChild(el('p', null, s.fim.msg));
    const b = el('button', 'btn', 'Nova saga');
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
    for (const r of rel.rodadas) {
      const vant = r.ventJ > 1 ? ' (sua formação venceu a deles!)' : r.ventI > 1 ? ' (a formação DELES venceu a sua!)' : '';
      box.appendChild(el('p', 'linha-cronica',
        `Rodada ${r.rodada}: inimigo em <b>${FORMACOES[r.formacaoInimiga].nome}</b>${vant} — baixas: você −${r.baixasJ}, inimigo −${r.baixasI}.`));
    }
    if (rel.debandada) box.appendChild(el('p', null, rel.debandada === 'inimigo' ? '🏃 O inimigo debandou!' : '🏃 Suas tropas debandaram!'));
    const totalJ = Object.values(rel.baixasJogador).reduce((a, x) => a + x, 0);
    box.appendChild(el('p', null, `Cada soldado conta: você perdeu <b>${totalJ}</b> homens nesta ação.`));
    const b = el('button', 'btn', 'Continuar');
    b.onclick = () => { Jogo.salvar(); renderTudo(); };
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
