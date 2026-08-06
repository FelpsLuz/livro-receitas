// ============================================================
// CLÃS MERCENÁRIOS INDEPENDENTES
// - 4 clãs com líder, especialidade e preço próprios.
// - Contratação via MENSAGEIRO: a carta leva 1 mês para voltar
//   (e pode ser interceptada em tempos de guerra).
// - A resposta chega como carta selada. Oferta baixa = recusa;
//   oferta boa = o clã marcha sob seu estandarte por 6 meses.
// - Soldo mensal: se o tesouro zerar, o clã vai embora — e pode
//   saquear seus celeiros na saída.
// ============================================================
'use strict';

const CLAS = [
  {
    id: 'cla_lobos', nome: 'Lobos de Ferro', lider: 'Ragnar Meio-Lobo',
    desc: 'Lanceiros pesados do norte. Caros, brutais, nunca recuam.',
    personalidade: 'orgulhoso',
    contingente: { lanceiro: 25 }, precoBase: 350, soldo: 45, renomeMin: 20,
    lema: '"Aço barato quebra. Nós não."',
  },
  {
    id: 'cla_corvos', nome: 'Corvos da Névoa', lider: 'Sira Olho-Vazio',
    desc: 'Arqueiros e batedores. Aparecem, matam, somem.',
    personalidade: 'calculista',
    contingente: { arqueiro: 20 }, precoBase: 300, soldo: 38, renomeMin: 15,
    lema: '"Você não nos verá chegar. Eles também não."',
  },
  {
    id: 'cla_estepe', nome: 'Filhos da Estepe', lider: 'Khal Tembu',
    desc: 'Cavaleiros nômades. A carga deles decide batalhas.',
    personalidade: 'cruel',
    contingente: { cavaleiro: 8 }, precoBase: 500, soldo: 60, renomeMin: 35,
    lema: '"Pague em ouro. Ou pague em sangue."',
  },
  {
    id: 'cla_machados', nome: 'Machados do Norte', lider: 'Ulf Barba-Gelo',
    desc: 'Infantaria de choque veterana. Honram contratos até o fim.',
    personalidade: 'honrado',
    contingente: { lanceiro: 15, arqueiro: 8 }, precoBase: 400, soldo: 50, renomeMin: 25,
    lema: '"Palavra dada é machado cravado."',
  },
];

const Clas = (() => {

  function garantir(state) {
    if (!state.mensageiros) state.mensageiros = [];
    if (!state.clasAtivos) state.clasAtivos = [];
    if (!state.cartas) state.cartas = [];
  }

  function claPorId(id) { return CLAS.find(c => c.id === id); }
  function ativo(state, claId) { garantir(state); return state.clasAtivos.find(a => a.id === claId); }
  function mensageiroPendente(state, claId) { garantir(state); return state.mensageiros.find(m => m.cla === claId); }

  // ---------- enviar mensageiro com oferta ----------
  function enviarMensageiro(state, claId, oferta) {
    garantir(state);
    const cla = claPorId(claId);
    if (!cla) return { ok: false, msg: 'Clã desconhecido.' };
    if (ativo(state, claId)) return { ok: false, msg: `${cla.nome} já cavalga sob seu estandarte.` };
    if (mensageiroPendente(state, claId)) return { ok: false, msg: 'Seu mensageiro ainda está na estrada. Espere a resposta.' };
    if (state.jogador.renome < cla.renomeMin)
      return { ok: false, msg: `${cla.lider} não lê cartas de desconhecidos. (Renome ${state.jogador.renome}/${cla.renomeMin})` };
    const custoMensageiro = 10;
    if (state.jogador.ouro < oferta + custoMensageiro)
      return { ok: false, msg: `Você precisa de ${oferta + custoMensageiro} de ouro (oferta + ${custoMensageiro} do mensageiro).` };
    state.jogador.ouro -= custoMensageiro; // a oferta só é paga se aceitarem
    state.mensageiros.push({ cla: claId, oferta, mesesRestantes: 1 });
    Jogo.log(`✉️ Mensageiro despachado ao acampamento dos ${cla.nome} com oferta de ${oferta} de ouro. Resposta no próximo mês.`);
    return { ok: true, msg: `Mensageiro a caminho dos ${cla.nome}. As respostas chegam com a virada do mês.` };
  }

  // ---------- virada do mês: mensageiros e contratos ----------
  function tick(state, log) {
    garantir(state);

    // mensageiros na estrada
    for (const m of state.mensageiros) {
      m.mesesRestantes--;
      if (m.mesesRestantes > 0) continue;
      m.resolvido = true;
      const cla = claPorId(m.cla);
      // interceptação em tempos de guerra
      if (state.guerras.length > 0 && Math.random() < 0.15) {
        state.cartas.unshift({ de: 'Estrada do Norte', tipo: 'ruim', ano: state.ano, mes: state.mes,
          texto: `Encontraram o cavalo do seu mensageiro sem cavaleiro. A carta para os ${cla.nome} — e a oferta — se perderam na guerra.` });
        log(`🏴 Seu mensageiro para os ${cla.nome} foi interceptado na estrada. Tempos de guerra...`);
        continue;
      }
      // decisão do clã
      const relacao = (state.tags[cla.id] || { relacao: 0 }).relacao;
      const generosidade = m.oferta / cla.precoBase; // 1.0 = preço justo
      let chance = Math.min(0.95, generosidade * 0.55 + state.jogador.renome / 200 + relacao / 150);
      if (state.jogador.traiuClas) chance -= 0.3;
      if (generosidade >= 1.5) chance = Math.max(chance, 0.9);
      if (Math.random() < chance) {
        if (state.jogador.ouro < m.oferta) {
          state.cartas.unshift({ de: cla.lider, tipo: 'ruim', ano: state.ano, mes: state.mes,
            texto: `"Aceitamos sua oferta. Mas seu cofre não tinha o ouro prometido. ${cla.nome} não marcham por promessas." (relação abalada)` });
          Dialogo.mudarRelacao(state, cla.id, -20, 'oferta sem fundos');
          continue;
        }
        state.jogador.ouro -= m.oferta;
        state.clasAtivos.push({ id: cla.id, mesesRestantes: 6, contingente: { ...cla.contingente } });
        for (const [tipo, n] of Object.entries(cla.contingente))
          state.jogador.tropas[tipo] = (state.jogador.tropas[tipo] || 0) + n;
        Dialogo.mudarRelacao(state, cla.id, 10, 'contrato firmado');
        state.cartas.unshift({ de: cla.lider, tipo: 'bom', ano: state.ano, mes: state.mes,
          texto: `"Oferta digna. Os ${cla.nome} marcham sob seu estandarte por 6 meses. Soldo: ${cla.soldo} de ouro ao mês, pago em dia. ${cla.lema}"` });
        log(`⚔️ Os ${cla.nome} aceitaram seu contrato! ${resumoContingente(cla.contingente)} juntam-se ao seu exército.`);
      } else {
        const motivos = {
          orgulhoso: `"Essa ninharia? Os ${cla.nome} não empunham lança por esmola. Dobre a oferta ou não escreva de novo."`,
          calculista: `"Analisamos sua proposta. O risco excede o retorno. Melhore os números."`,
          cruel: `"Khal Tembu riu da sua carta. Depois a queimou. Mais ouro, ou nada."`,
          honrado: `"Agradecemos a consideração, mas o valor não sustenta nossos veteranos. Com mais ouro, conversamos."`,
        };
        state.cartas.unshift({ de: cla.lider, tipo: 'ruim', ano: state.ano, mes: state.mes,
          texto: motivos[cla.personalidade] || motivos.honrado });
        log(`✉️ Os ${cla.nome} recusaram sua oferta de ${m.oferta} de ouro.`);
      }
    }
    state.mensageiros = state.mensageiros.filter(m => !m.resolvido);

    // contratos ativos: soldo e duração
    for (const a of state.clasAtivos) {
      const cla = claPorId(a.id);
      if (state.jogador.ouro >= cla.soldo) {
        state.jogador.ouro -= cla.soldo;
        a.mesesRestantes--;
        if (a.mesesRestantes <= 0) {
          removerContingente(state, a);
          a.encerrado = true;
          Dialogo.mudarRelacao(state, cla.id, 10, 'contrato honrado até o fim');
          state.cartas.unshift({ de: cla.lider, tipo: 'bom', ano: state.ano, mes: state.mes,
            texto: `"Contrato cumprido, ouro em dia. Foi uma honra sangrar ao seu lado. Se precisar dos ${cla.nome} de novo, sabe onde nos achar." (relação +10)` });
          log(`🤝 O contrato com os ${cla.nome} chegou ao fim. Eles partem como amigos — e voltariam por um preço justo.`);
        }
      } else {
        // sem soldo: o clã vai embora — e pode saquear
        removerContingente(state, a);
        a.encerrado = true;
        state.jogador.traiuClas = true;
        Dialogo.mudarRelacao(state, a.id, -50, 'soldo não pago');
        if (Math.random() < 0.4 && state.terra) {
          const saque = Math.min(state.terra.alimento, 40);
          state.terra.alimento -= saque;
          state.terra.felicidade = clamp(state.terra.felicidade - 10, 0, 100);
          state.cartas.unshift({ de: cla.lider, tipo: 'ruim', ano: state.ano, mes: state.mes,
            texto: `"Mercenário que não paga mercenário aprende na pele." Os ${cla.nome} saquearam ${saque} de alimento dos seus celeiros ao partir.` });
          log(`🔥 Os ${cla.nome} partiram SEM soldo — e levaram ${saque} de alimento dos seus celeiros como "pagamento". A notícia corre entre os clãs.`);
        } else {
          state.cartas.unshift({ de: cla.lider, tipo: 'ruim', ano: state.ano, mes: state.mes,
            texto: `"Cofre vazio, contrato morto. Os ${cla.nome} não morrem de graça." Eles partiram — e todos os clãs souberam que você não paga.` });
          log(`💸 Sem soldo, os ${cla.nome} rasgaram o contrato e partiram. Sua fama de caloteiro chegou aos outros clãs.`);
        }
      }
    }
    state.clasAtivos = state.clasAtivos.filter(a => !a.encerrado);
    if (state.cartas.length > 20) state.cartas.length = 20;
  }

  // clã leva embora o que restou do contingente (limitado às tropas vivas)
  function removerContingente(state, a) {
    for (const [tipo, n] of Object.entries(a.contingente)) {
      state.jogador.tropas[tipo] = Math.max(0, (state.jogador.tropas[tipo] || 0) - n);
    }
  }

  function resumoContingente(c) {
    return Object.entries(c).map(([t, n]) => `${n} ${TROPAS[t].nome.toLowerCase()}`).join(' + ');
  }

  return { CLAS, enviarMensageiro, tick, ativo, mensageiroPendente, claPorId, resumoContingente };
})();
