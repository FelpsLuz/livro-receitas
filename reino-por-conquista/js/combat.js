// ============================================================
// COMBATE TÁTICO SIMPLIFICADO
// - Cada soldado conta: formação, equipamento e moral decidem.
// - 3 rodadas; formação vence formação (linha > cunha > cerco > linha).
// - Baixas são permanentes. Renome recompensa vitórias.
// ============================================================
'use strict';

const Combate = (() => {

  function poder(tropas, equip) {
    let atq = 0, def = 0, homens = 0;
    for (const [tipo, n] of Object.entries(tropas)) {
      if (!n) continue;
      const t = TROPAS[tipo];
      atq += t.atq * n;
      def += t.def * n;
      homens += n;
    }
    const mult = 1 + (equip || 0) * 0.15; // nível de equipamento 0..3
    return { atq: atq * mult, def: def * mult, homens };
  }

  // gera exército inimigo com força ~alvo
  function exercitoInimigo(forca) {
    const e = { tropas: {}, equip: forca > 2 ? 1 : 0, formacao: rnd(Object.keys(FORMACOES)) };
    if (forca <= 1) e.tropas = { campones: ri(8, 14), lanceiro: ri(2, 5) };
    else if (forca === 2) e.tropas = { lanceiro: ri(8, 14), arqueiro: ri(4, 8) };
    else if (forca === 3) e.tropas = { lanceiro: ri(12, 18), arqueiro: ri(8, 12), cavaleiro: ri(2, 4) };
    else e.tropas = { lanceiro: ri(20, 30), arqueiro: ri(12, 18), cavaleiro: ri(5, 9) };
    return e;
  }

  // resolve uma batalha completa; retorna relatório
  function batalhar(state, inimigo, contexto) {
    const j = state.jogador;
    const rel = { rodadas: [], vitoria: false, baixasJogador: {}, baixasInimigo: {}, contexto };
    const formJ = j.formacao || 'linha';
    let moralJ = 1.0 + (j.atributos.forca - 5) * 0.04;
    let moralI = 1.0;

    const bonusCampeoes = (state.campeoes || []).reduce((a, c) => a + c.bonus, 0);
    for (let rodada = 1; rodada <= 3; rodada++) {
      const pj = poder(j.tropas, j.equip);
      pj.atq += bonusCampeoes;
      const pi = poder(inimigo.tropas, inimigo.equip);
      if (pj.homens === 0 || pi.homens === 0) break;

      // vantagem tática de formação
      let ventJ = 1.0, ventI = 1.0;
      if (FORMACOES[formJ].venceDe === inimigo.formacao) ventJ = 1.35;
      else if (FORMACOES[inimigo.formacao].venceDe === formJ) ventI = 1.35;

      const danoAoInimigo = pj.atq * ventJ * moralJ * (0.8 + Math.random() * 0.4);
      const danoAoJogador = pi.atq * ventI * moralI * (0.8 + Math.random() * 0.4);

      const baixasI = aplicarBaixas(inimigo.tropas, danoAoInimigo / Math.max(1, pi.def) * 0.25);
      const baixasJ = aplicarBaixas(j.tropas, danoAoJogador / Math.max(1, pj.def) * 0.25);
      somar(rel.baixasInimigo, baixasI);
      somar(rel.baixasJogador, baixasJ);

      moralI -= contar(baixasI) / Math.max(1, pi.homens) * 0.8;
      moralJ -= contar(baixasJ) / Math.max(1, pj.homens) * 0.8;

      rel.rodadas.push({
        rodada, ventJ, ventI, baixasJ: contar(baixasJ), baixasI: contar(baixasI),
        formacaoInimiga: inimigo.formacao,
      });
      if (moralI <= 0.3) { rel.debandada = 'inimigo'; break; }
      if (moralJ <= 0.3) { rel.debandada = 'jogador'; break; }
    }

    const restoJ = poder(j.tropas, 0).homens;
    const restoI = poder(inimigo.tropas, 0).homens;
    rel.vitoria = rel.debandada === 'inimigo' || (rel.debandada !== 'jogador' && restoJ > restoI);
    return rel;
  }

  function aplicarBaixas(tropas, taxa) {
    const baixas = {};
    for (const tipo of Object.keys(tropas)) {
      const n = tropas[tipo] || 0;
      if (!n) continue;
      // cavaleiros (def alta) morrem menos
      const resist = TROPAS[tipo].def / 4;
      const mortos = Math.min(n, Math.round(n * clamp(taxa / resist, 0, 0.6) + (Math.random() < 0.5 ? 0 : 1) * (taxa > 0.05 ? 1 : 0)));
      tropas[tipo] = n - mortos;
      if (mortos) baixas[tipo] = mortos;
    }
    return baixas;
  }

  function somar(acc, b) { for (const k of Object.keys(b)) acc[k] = (acc[k] || 0) + b[k]; }
  function contar(b) { return Object.values(b).reduce((a, x) => a + x, 0); }
  function totalHomens(tropas) { return Object.values(tropas).reduce((a, x) => a + (x || 0), 0); }

  return { batalhar, exercitoInimigo, totalHomens, poder };
})();

// ============================================================
// CONTRATOS E RENOME — a jornada de mercenário a rei
// ============================================================
const Contratos = (() => {

  const TIPOS = [
    { id: 'escolta', nome: 'Escoltar caravana', forca: 1,
      desc: 'Mercadores pagam por proteção contra bandidos na estrada.',
      ouro: [60, 120], renome: 5, moral: 0 },
    { id: 'bandidos', nome: 'Caçar bandidos', forca: 2,
      desc: 'Um vilarejo sofre com saqueadores. Limpe a região.',
      ouro: [100, 180], renome: 10, moral: 0 },
    { id: 'incursao', nome: 'Queimar vila inimiga', forca: 2,
      desc: 'Um rei paga para você incendiar uma vila do reino rival. Trabalho sujo.',
      ouro: [200, 350], renome: 12, moral: -1 },
    { id: 'patrulha', nome: 'Guarnecer fronteira', forca: 3,
      desc: 'Guerra na fronteira. Reforce a linha por um mês.',
      ouro: [250, 400], renome: 18, moral: 0 },
  ];

  function gerar(state) {
    const contratos = [];
    const n = ri(2, 3);
    for (let i = 0; i < n; i++) {
      const t = rnd(TIPOS);
      const contratante = rnd(state.reinos);
      let alvo = null;
      if (t.id === 'incursao' || t.id === 'patrulha') {
        const g = state.guerras.find(w => w.a === contratante.id || w.b === contratante.id);
        alvo = g ? state.reinos.find(r => r.id === (g.a === contratante.id ? g.b : g.a))
                 : rnd(state.reinos.filter(r => r.id !== contratante.id));
      }
      contratos.push({
        ...t, uid: 'c' + Math.random().toString(36).slice(2, 8),
        contratante: contratante.id, alvo: alvo ? alvo.id : null,
        pagamento: ri(t.ouro[0], t.ouro[1]),
      });
    }
    return contratos;
  }

  function executar(state, contrato, log) {
    const inimigo = Combate.exercitoInimigo(contrato.forca);
    const rel = Combate.batalhar(state, inimigo, contrato.nome);
    const contratante = state.reinos.find(r => r.id === contrato.contratante);
    if (rel.vitoria) {
      state.jogador.ouro += contrato.pagamento;
      state.jogador.renome += contrato.renome;
      Dialogo.mudarRelacao(state, 'rei_' + contrato.contratante, 8, 'contrato cumprido');
      log(`✅ Contrato cumprido para ${contratante.nome}: +${contrato.pagamento} ouro, +${contrato.renome} renome.`);
      if (contrato.id === 'incursao' && contrato.alvo) {
        Dialogo.mudarRelacao(state, 'rei_' + contrato.alvo, -25, 'queimou vila');
        const alvo = state.reinos.find(r => r.id === contrato.alvo);
        state.mercados[contrato.alvo].trigo.oferta = Math.max(0.25, state.mercados[contrato.alvo].trigo.oferta * 0.8);
        log(`🔥 Você queimou uma vila de ${alvo.nome}. O rei de lá saberá seu nome — e não para o bem. O preço do trigo lá subiu.`);
        state.jogador.crueldade = (state.jogador.crueldade || 0) + 1;
      }
    } else {
      state.jogador.renome = Math.max(0, state.jogador.renome - 5);
      log(`❌ Contrato fracassou. Suas tropas foram rechaçadas. Renome −5.`);
    }
    return rel;
  }

  // título: a escada de nobreza vive em Politica
  function titulo(state) { return Politica.titulo(state); }

  return { gerar, executar, titulo };
})();
