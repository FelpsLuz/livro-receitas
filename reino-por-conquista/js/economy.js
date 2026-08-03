// ============================================================
// ECONOMIA VIVA
// - Cada reino tem oferta por mercadoria; preço = base * demanda/oferta.
// - Guerra queima campos: oferta de trigo despenca, preços disparam.
// - Contrabando para reinos em guerra: lucro alto, risco alto.
// - Fadiga de guerra: convocar camponeses => colheita menor => fome => rebelião.
// - Exportar comida do próprio povo faminto => revolta.
// ============================================================
'use strict';

const Economia = (() => {

  function inicializarMercados(state) {
    state.mercados = {};
    for (const r of state.reinos) {
      state.mercados[r.id] = {};
      for (const gId of Object.keys(MERCADORIAS)) {
        // produz bem => oferta alta (1.6); senão normal (1.0)
        const oferta = r.producao.includes(gId) ? 1.6 : 1.0;
        state.mercados[r.id][gId] = { oferta, demanda: 1.0 };
      }
    }
  }

  function precoDe(state, reinoId, gId) {
    const m = state.mercados[reinoId][gId];
    let preco = MERCADORIAS[gId].precoBase * (m.demanda / m.oferta);
    // relação pessoal com o rei altera os preços PARA O JOGADOR
    const rel = (state.tags['rei_' + reinoId] || { relacao: 0 }).relacao;
    if (rel <= -60) preco *= 1.6;        // Odiado: mercadores te exploram
    else if (rel <= -25) preco *= 1.25;  // Hostil
    else if (rel >= 60) preco *= 0.85;   // Leal: tratamento de amigo da coroa
    else if (rel >= 25) preco *= 0.95;
    if (typeof Politica !== 'undefined') {
      if (Politica.temComercio(state, reinoId)) preco *= 0.90;   // acordo comercial
      if (Politica.lealdadeDe(state, reinoId) >= 50) preco *= 0.95; // povo te adora
      if (state.embargos && state.embargos[reinoId]) preco *= 1.35; // embargo do Alvorecer
    }
    return Math.max(1, Math.round(preco));
  }

  function precosPara(state, reinoId) {
    const out = {};
    for (const gId of Object.keys(MERCADORIAS)) out[gId] = precoDe(state, reinoId, gId);
    return out;
  }

  // ---------- guerras entre reinos ----------
  function talvezIniciarGuerra(state, log) {
    if ((state.guerras || []).length >= 2) return;
    if (Math.random() > 0.10) return; // ~10% ao mês
    const livres = state.reinos.filter(r =>
      !state.guerras.some(g => g.a === r.id || g.b === r.id));
    if (livres.length < 2) return;
    const a = rnd(livres);
    const b = rnd(livres.filter(r => r.id !== a.id));
    state.guerras.push({ a: a.id, b: b.id, meses: 0 });
    log(`⚔️ GUERRA! ${a.nome} declarou guerra a ${b.nome}. Campos serão queimados; o preço do trigo vai disparar.`);
  }

  function tickGuerras(state, log) {
    for (const g of state.guerras) {
      g.meses++;
      // campos queimados: oferta de trigo cai nos dois reinos
      for (const id of [g.a, g.b]) {
        const m = state.mercados[id];
        m.trigo.oferta = Math.max(0.25, m.trigo.oferta * 0.82);
        m.ferro.demanda = Math.min(3, m.ferro.demanda * 1.08); // guerra consome ferro
        m.armas.demanda = Math.min(3, m.armas.demanda * 1.12);  // e devora armas
        m.cavalos.demanda = Math.min(3, m.cavalos.demanda * 1.05);
      }
      // guerras longas terminam por exaustão
      if (g.meses >= 6 && Math.random() < 0.35) {
        g.terminou = true;
        const ra = state.reinos.find(r => r.id === g.a), rb = state.reinos.find(r => r.id === g.b);
        log(`🕊️ ${ra.nome} e ${rb.nome} assinaram a paz, exaustos após ${g.meses} meses de guerra.`);
      }
    }
    state.guerras = state.guerras.filter(g => !g.terminou);
  }

  // recuperação lenta dos mercados em paz
  function tickMercados(state) {
    for (const r of state.reinos) {
      const emGuerra = state.guerras.some(g => g.a === r.id || g.b === r.id);
      for (const gId of Object.keys(MERCADORIAS)) {
        const m = state.mercados[r.id][gId];
        const alvoOferta = r.producao.includes(gId) ? 1.6 : 1.0;
        if (!emGuerra) m.oferta += (alvoOferta - m.oferta) * 0.15;
        m.demanda += (1.0 - m.demanda) * 0.10;
        // ruído sazonal leve
        m.demanda = clamp(m.demanda * (1 + (Math.random() - 0.5) * 0.06), 0.5, 3);
      }
    }
  }

  // ---------- comércio do jogador ----------
  function comprar(state, reinoId, gId, qtd) {
    const preco = precoDe(state, reinoId, gId);
    const custo = preco * qtd;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Ouro insuficiente (custa ${custo}).` };
    state.jogador.ouro -= custo;
    state.carga[gId] = (state.carga[gId] || 0) + qtd;
    const m = state.mercados[reinoId][gId];
    m.oferta = Math.max(0.2, m.oferta - 0.02 * qtd); // comprar muito sobe o preço
    return { ok: true, msg: `Comprou ${qtd}× ${MERCADORIAS[gId].nome} por ${custo} de ouro.` };
  }

  function vender(state, reinoId, gId, qtd) {
    if ((state.carga[gId] || 0) < qtd) return { ok: false, msg: 'Você não tem essa carga.' };
    const emGuerra = state.guerras.some(g => g.a === reinoId || g.b === reinoId);
    // contrabando: vender comida em zona de guerra tem ágio, mas risco de patrulha
    let preco = precoDe(state, reinoId, gId);
    let msgExtra = '';
    if (emGuerra && gId === 'trigo') {
      preco = Math.round(preco * 1.3);
      if (Math.random() < 0.20) {
        const perda = Math.ceil(qtd / 2);
        state.carga[gId] -= perda;
        return { ok: false, msg: `🚨 Uma patrulha confiscou ${perda}× ${MERCADORIAS[gId].nome} do seu contrabando! Fuja enquanto pode.` };
      }
      msgExtra = ' (ágio de contrabando de guerra!)';
    }
    // Costa dos Ossos: as enseadas de contrabando pagam melhor por tudo
    const agioRegiao = (typeof Barbaras !== 'undefined') ? Barbaras.bonusVenda(state) : 1;
    if (agioRegiao > 1) msgExtra += ' (suas enseadas rendem +25%!)';
    const ganho = Math.round(preco * qtd * agioRegiao);
    state.carga[gId] -= qtd;
    state.jogador.ouro += ganho;
    const m = state.mercados[reinoId][gId];
    m.oferta = Math.min(3, m.oferta + 0.02 * qtd);
    return { ok: true, msg: `Vendeu ${qtd}× ${MERCADORIAS[gId].nome} por ${ganho} de ouro.${msgExtra}` };
  }

  // exportar comida da PRÓPRIA terra: ouro fácil, povo com fome se revolta
  function exportarComidaDaTerra(state, qtd) {
    const t = state.terra;
    if (!t) return { ok: false, msg: 'Você não tem terras.' };
    if (t.alimento < qtd) return { ok: false, msg: 'Não há tanto alimento nos celeiros.' };
    t.alimento -= qtd;
    const ganho = Math.round(precoDe(state, state.local, 'trigo') * qtd * 1.1);
    state.jogador.ouro += ganho;
    const reserva = t.populacao * 2;
    if (t.alimento < reserva) {
      t.felicidade = clamp(t.felicidade - 15, 0, 100);
      return { ok: true, msg: `Vendeu ${qtd} de alimento por ${ganho} de ouro... enquanto os celeiros do povo esvaziam. Murmúrios de revolta crescem (felicidade −15).` };
    }
    return { ok: true, msg: `Exportou ${qtd} de alimento por ${ganho} de ouro. Os celeiros continuam cheios; ninguém reclama.` };
  }

  // ---------- terra do jogador: colheita, fome, rebelião ----------
  function tickTerra(state, log) {
    const t = state.terra;
    if (!t) return;
    // camponeses convocados não plantam (fadiga de guerra)
    const convocados = state.jogador.tropas.campones || 0;
    const trabalhando = Math.max(0, t.populacao - convocados);
    const producao = Math.round(trabalhando * 1.5 * (1 + t.nivel * 0.15));
    const consumo = t.populacao;
    t.alimento = Math.max(0, t.alimento + producao - consumo);
    t.madeira += Math.round(2 + t.nivel * 2);

    if (convocados > t.populacao * 0.4)
      log(`⚠️ Quase metade da sua vila está no seu exército. Quem vai plantar a colheita? Produção de alimento despencou.`);

    if (t.alimento <= 0) {
      t.felicidade = clamp(t.felicidade - 20, 0, 100);
      const antes = t.populacao;
      t.populacao = Math.max(5, t.populacao - ri(1, 4));
      // os mortos saem também das fileiras convocadas (nunca há mais soldado que morador)
      const mortos = antes - t.populacao;
      if (mortos > 0 && state.jogador.tropas.campones > 0) {
        const desertam = Math.min(state.jogador.tropas.campones, Math.ceil(mortos / 2));
        state.jogador.tropas.campones -= desertam;
      }
      if (state.jogador.tropas.campones > t.populacao)
        state.jogador.tropas.campones = t.populacao;
      log(`💀 FOME em ${t.nome}! O povo passa fome e alguns morrem${mortos > 0 ? ' (−' + mortos + ' hab.)' : ''}. Felicidade −20.`);
    } else if (t.felicidade < 70) {
      t.felicidade = clamp(t.felicidade + 5, 0, 100);
    }

    // fartura atrai gente: população cresce até o teto do assentamento
    const teto = 40 + t.nivel * 40;
    if (t.alimento > t.populacao * 2 && t.felicidade >= 60 && t.populacao < teto) {
      const cresc = Math.max(1, Math.round(t.populacao * 0.02));
      t.populacao = Math.min(teto, t.populacao + cresc);
      if (Math.random() < 0.2)
        log(`👨‍👩‍👧 Celeiros cheios atraem famílias: ${t.nome} cresce (+${cresc}, ${t.populacao}/${teto}).`);
    }

    // impostos
    const impostos = Math.round(trabalhando * 0.8 * (1 + t.nivel * 0.2));
    state.jogador.ouro += impostos;
    t.ultimaColeta = { producao, consumo, impostos };

    // REBELIÃO
    if (t.felicidade <= 20 && Math.random() < 0.5) {
      log(`🔥 REBELIÃO! O povo de ${t.nome} pegou em foices e tochas para cortar a SUA cabeça!`);
      state.eventoPendente = { tipo: 'rebeliao' };
    }
  }

  // ---------- manutenção do exército e traição por ouro ----------
  function tickExercito(state, log) {
    let manut = 0;
    for (const [tipo, n] of Object.entries(state.jogador.tropas))
      manut += (TROPAS[tipo].manut || 0) * n;
    manut += state.jogador.guardas * 4; // guarda de elite é cara
    // campeões de guerra cobram soldo (nada é de graça)
    for (const c of (state.campeoes || [])) manut += (c.soldo || 0);
    // Estepe Cinzenta: pastagem infinita barateia manter homens e cavalos
    if (typeof Barbaras !== 'undefined') manut = Math.round(manut * Barbaras.fatorManutencao(state));
    state.jogador.ultimaManut = manut;

    if (state.jogador.ouro >= manut) {
      state.jogador.ouro -= manut;
      state.jogador.mesesSemPagar = 0;
    } else {
      state.jogador.ouro = 0;
      state.jogador.mesesSemPagar = (state.jogador.mesesSemPagar || 0) + 1;
      log(`💸 O tesouro zerou! Suas tropas não receberam o soldo (${manut} de ouro). Elas não vão esperar para sempre.`);
      if (state.jogador.mesesSemPagar >= 2) {
        // deserção
        for (const tipo of Object.keys(state.jogador.tropas)) {
          const perda = Math.ceil((state.jogador.tropas[tipo] || 0) * 0.3);
          state.jogador.tropas[tipo] = Math.max(0, (state.jogador.tropas[tipo] || 0) - perda);
        }
        log(`🏃 Tropas desertaram em massa. Soldado sem soldo é só um homem armado procurando novo patrão.`);
        // traição da guarda de elite
        if (state.jogador.guardas > 0 && state.terra && Math.random() < 0.5) {
          state.eventoPendente = { tipo: 'traicao_guardas' };
          log(`🗡️ Rumores: um reino rival ofereceu ouro à sua guarda de elite para abrir os portões à noite...`);
        }
      }
    }
  }

  return { inicializarMercados, precoDe, precosPara, comprar, vender, exportarComidaDaTerra,
           talvezIniciarGuerra, tickGuerras, tickMercados, tickTerra, tickExercito };
})();
