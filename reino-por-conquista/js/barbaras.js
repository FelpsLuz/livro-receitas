// ============================================================
// TERRAS BÁRBARAS — o caminho de quem não se ajoelha.
// Fora das seis coroas há quatro regiões sem rei. Tomando uma delas
// você funda sua casa DO ZERO: sem ser armado cavaleiro, sem jurar
// vassalagem, sem pedir licença a coroa nenhuma.
// Dois caminhos: a CAMPANHA (aço) ou o PACTO (conversa, respeito e ouro).
// O clã que vive na terra reage de acordo — e lembra para sempre.
// ============================================================
'use strict';

const Barbaras = (() => {
  const porId = (id) => TERRAS_BARBARAS.find(t => t.id === id);

  function garantir(state) {
    if (!state.barbaras) state.barbaras = {};   // { [regiao]: 'tomada'|'pacto' }
    return state.barbaras;
  }
  const dono = (state, id) => garantir(state)[id] || null;
  const livres = (state) => TERRAS_BARBARAS.filter(t => !dono(state, t.id));
  const minhaRegiao = (state) => (state.terra && state.terra.regiao) ? porId(state.terra.regiao) : null;

  // o chefe do clã que vive na terra — NPC conversável, com voz própria
  function chefeDe(regiaoId) {
    const t = porId(regiaoId);
    if (!t) return null;
    const c = Clas.claPorId(t.cla);
    if (!c) return null;
    return {
      id: c.id, nome: c.lider, retratoId: c.id, personalidade: c.personalidade,
      barbaro: true, regiao: t.id,
      desc: `Chefe dos ${c.nome}, senhor de guerra dos ${t.nome}. ${c.lema}`,
    };
  }

  // ---------- fundar a casa na terra tomada ----------
  function fundar(state, regiao, comoTomou, log) {
    const NOMES = { ermos: 'Forte Ferrolho', costa: 'Enseada Torta', estepe: 'Curral do Vento', brenha: 'Clareira Funda' };
    state.terra = {
      nome: NOMES[regiao.id] || regiao.nome,
      nivel: 0, populacao: comoTomou === 'pacto' ? 32 : 24,
      alimento: 90, madeira: 40, felicidade: comoTomou === 'pacto' ? 70 : 45,
      ultimaColeta: null, regiao: regiao.id, barbara: true,
      edificios: { fazenda: 0, serraria: 0, mina: 0, ferreiro: 0 },
    };
    for (const [ed, niv] of Object.entries(regiao.bonus || {}))
      state.terra.edificios[ed] = (state.terra.edificios[ed] || 0) + niv;
    garantir(state)[regiao.id] = comoTomou;
    state.jogador.senhorBarbaro = true;   // título fora do sistema feudal
    if (typeof Cidade !== 'undefined' && Cidade.seedNpcs) Cidade.seedNpcs(0);
    if (typeof Fofoca !== 'undefined')
      Fofoca.plantar(state, 'terra_barbara', { autor: 'jogador', origem: regiao.cla,
        regiaoNome: regiao.nome, pacto: comoTomou === 'pacto' });
    log(`🏔️ ${state.terra.nome} é sua — erguida em terra que nenhum rei governa. Você não deve nada a coroa alguma: esta casa é SUA, do primeiro tijolo ao último.`);
    log(`🎁 ${regiao.premio}`);
  }

  // ---------- CAMPANHA: tomar no aço ----------
  function podeCampanha(state, id) {
    const t = porId(id);
    if (!t) return { ok: false, msg: 'Região desconhecida.' };
    if (state.terra) return { ok: false, msg: 'Você já tem uma casa. Um senhor não abandona seu povo para caçar outro vale.' };
    if (dono(state, id)) return { ok: false, msg: 'Esta terra já tem dono.' };
    const homens = Combate.totalHomens(state.jogador.tropas);
    if (homens < t.homensMin)
      return { ok: false, msg: `Marchar sobre ${t.nome} exige pelo menos ${t.homensMin} homens (você tem ${homens}). Contrate na taverna.` };
    return { ok: true };
  }

  function campanha(state, id, log) {
    const check = podeCampanha(state, id);
    if (!check.ok) { log('⚠️ ' + check.msg); return { bloqueado: true, msg: check.msg }; }
    const t = porId(id);
    const cla = Clas.claPorId(t.cla);
    log(`🐺 Você marcha sobre ${t.nome}. Os ${cla.nome} não pedem trégua e não oferecem rendição.`);
    const inimigo = Combate.exercitoInimigo(t.defesa);
    // cada terreno luta do seu jeito
    if (t.terreno === 'montanha') { inimigo.formacao = 'cerco'; log('⛰️ Eles esperam nos desfiladeiros — pedras rolam antes do primeiro golpe.'); }
    if (t.terreno === 'floresta') { inimigo.formacao = 'cerco'; log('🌲 A mata engole sua formação: cada árvore esconde um machado.'); }
    if (t.terreno === 'planicie') { inimigo.formacao = 'cunha'; log('🐎 Sem um morro sequer para se apoiar, a cavalaria deles carrega em campo aberto.'); }
    if (t.terreno === 'litoral') { inimigo.formacao = 'linha'; log('🌊 Eles recuam para o cascalho e fazem muralha de escudos contra o mar.'); }
    // relação com o clã pesa: quem os respeita enfrenta menos ferocidade
    const rel = Dialogo.tagsDe(state, t.cla).relacao;
    if (rel >= 25) { inimigo.equip = Math.max(0, (inimigo.equip || 0) - 1);
      log(`🤝 Há guerreiros que já beberam com você: parte deles luta sem vontade.`); }
    if (rel <= -30) { inimigo.equip = (inimigo.equip || 0) + 1;
      log(`💢 Eles odeiam você o bastante para lutar com tudo que têm.`); }

    const relato = Combate.batalhar(state, inimigo, `Campanha dos ${t.nome}`);
    if (relato.vitoria) {
      state.jogador.renome += 25;
      Dialogo.mudarRelacao(state, t.cla, -35, 'tomou a terra natal deles');
      log(`🏆 Os ${cla.nome} recuam para as brenhas. ${t.nome} é sua por direito de conquista. Renome +25 — e o ódio deles de brinde.`);
      fundar(state, t, 'conquista', log);
    } else {
      state.jogador.renome = Math.max(0, state.jogador.renome - 10);
      Dialogo.mudarRelacao(state, t.cla, -10, 'tentou invadir a terra deles');
      log(`❌ ${cla.nome} despedaçam sua coluna e você recua. Renome −10. Volte com mais homens — ou com uma proposta melhor.`);
    }
    return relato;
  }

  // ---------- PACTO: tomar na conversa ----------
  function podePacto(state, id) {
    const t = porId(id);
    if (!t) return { ok: false, msg: 'Região desconhecida.' };
    if (state.terra) return { ok: false, msg: 'Você já tem uma casa.' };
    if (dono(state, id)) return { ok: false, msg: 'Esta terra já tem dono.' };
    const rel = Dialogo.tagsDe(state, t.cla).relacao;
    if (rel < t.relacaoPacto)
      return { ok: false, msg: `Os ${Clas.claPorId(t.cla).nome} só cedem terra a quem respeitam (relação ${rel}/${t.relacaoPacto}). Fale com o chefe deles — beba, negocie, prove seu valor.` };
    if (state.jogador.ouro < t.custoPacto)
      return { ok: false, msg: `O pacto custa ${t.custoPacto} 🪙 em presentes de sangue (você tem ${state.jogador.ouro}).` };
    return { ok: true };
  }

  function pacto(state, id, log) {
    const check = podePacto(state, id);
    if (!check.ok) return { ok: false, msg: check.msg };
    const t = porId(id);
    const cla = Clas.claPorId(t.cla);
    state.jogador.ouro -= t.custoPacto;
    state.jogador.renome += 12;
    Dialogo.mudarRelacao(state, t.cla, 10, 'pacto de terra');
    log(`🤝 PACTO SELADO. ${cla.lider} corta a própria palma e aperta a sua: ${t.nome} passa a ser sua sem uma gota de sangue derramada. Os ${cla.nome} continuam na terra — como seu povo, não como servos.`);
    fundar(state, t, 'pacto', log);
    return { ok: true, msg: `${t.nome} é sua — conquistada na palavra, não na espada.` };
  }

  // ---------- efeitos permanentes da região ----------
  function bonusVenda(state) {
    const r = minhaRegiao(state);
    return r && r.id === 'costa' ? 1.25 : 1;
  }
  function fatorManutencao(state) {
    const r = minhaRegiao(state);
    return r && r.id === 'estepe' ? 0.8 : 1;
  }
  function fatorMadeira(state) {
    const r = minhaRegiao(state);
    return r && r.id === 'brenha' ? 2 : 1;
  }

  return { TERRAS: TERRAS_BARBARAS, porId, livres, dono, minhaRegiao, chefeDe,
    podeCampanha, campanha, podePacto, pacto, bonusVenda, fatorManutencao, fatorMadeira };
})();
