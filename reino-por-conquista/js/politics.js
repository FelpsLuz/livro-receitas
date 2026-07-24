// ============================================================
// POLÍTICA VIVA — IA dos reinos, tratados, torneios, milícia
// e a escada de nobreza.
// - Os 6 reinos têm relações ENTRE SI: rivalidades viram guerras,
//   e a situação deles gera propostas PARA VOCÊ (cartas).
// - Acordos: comercial (desconto + renda) e aliança (tropas na
//   guerra, bloqueia assassinos). Casamento e clãs completam o rol.
// - Torneios revelam CAMPEÕES DE GUERRA recrutáveis.
// - Milícia: derrote-a e ganhe a LEALDADE do povo da cidade.
// - Progressão: Mercenário → Capitão → Cavaleiro → Senhor →
//   Barão → CONDE (nobre) → Rei. Só um NOBRE reivindica tronos.
// ============================================================
'use strict';

const Politica = (() => {

  function garantir(state) {
    if (!state.relReinos) inicializarRelacoes(state);
    if (!state.tratados) state.tratados = [];
    if (!state.lealdade) state.lealdade = {};
    if (!state.campeoes) state.campeoes = [];
    if (!state.ofertas) state.ofertas = [];
    if (state.torneio === undefined) state.torneio = null;
    if (!state.cartas) state.cartas = [];
  }

  function inicializarRelacoes(state) {
    state.relReinos = {};
    for (const a of state.reinos) {
      state.relReinos[a.id] = {};
      for (const b of state.reinos) {
        if (a.id !== b.id)
          state.relReinos[a.id][b.id] = ri(-30, 30);
      }
    }
    // rivalidades históricas para dar tempero
    state.relReinos.valdria.ashkar = -45; state.relReinos.ashkar.valdria = -45;
    state.relReinos.lysande.thornmar = 35; state.relReinos.thornmar.lysande = 35;
  }

  // ---------- títulos: a escada até a coroa ----------
  // Mercenário → Capitão (50⭐) → Cavaleiro (armado por um rei) →
  // Senhor (terra) → Barão (terra 2+) → Conde/NOBRE (terra 4+) → Rei
  function titulo(state) {
    const j = state.jogador;
    if (j.reiDe) return 'Rei';
    if (state.terra) {
      if (state.terra.nivel >= 4) return 'Conde';
      if (state.terra.nivel >= 2) return 'Barão';
      return 'Senhor';
    }
    if (j.cavaleiro) return 'Cavaleiro';
    if (j.renome >= 50) return 'Capitão Mercenário';
    return 'Mercenário';
  }
  function eNobre(state) { return ['Conde', 'Rei'].includes(titulo(state)); }
  function eCavaleiro(state) { return state.jogador.cavaleiro || state.terra != null || state.jogador.reiDe; }

  function podeSerArmado(state, reinoId) {
    const rel = (state.tags['rei_' + reinoId] || { relacao: 0 }).relacao;
    return !state.jogador.cavaleiro && !state.terra && state.jogador.renome >= 60 && rel >= 40;
  }

  function armarCavaleiro(state, reinoId, log) {
    if (!podeSerArmado(state, reinoId))
      return { ok: false, msg: 'Um rei só arma cavaleiro quem tem 60+ de renome e a confiança dele (relação 40+).' };
    state.jogador.cavaleiro = true;
    const reino = state.reinos.find(r => r.id === reinoId);
    state.jogador.renome += 10;
    log(`⚔️ ${reino.rei.nome} toca seus ombros com a espada: "Levante-se, CAVALEIRO." Agora você pode possuir terras — o primeiro degrau da nobreza.`);
    return { ok: true, msg: 'Você foi armado cavaleiro! (+10 renome). Agora pode comprar terras.' };
  }

  // ---------- IA dos reinos: relações, guerras e propostas ----------
  function tickReinos(state, log) {
    garantir(state);
    const R = state.relReinos;
    // deriva das relações entre reinos
    for (const a of state.reinos) for (const b of state.reinos) {
      if (a.id === b.id) continue;
      R[a.id][b.id] = clamp(R[a.id][b.id] + ri(-3, 3), -100, 100);
    }
    // rivalidades profundas explodem em guerra
    if (state.guerras.length < 2) {
      for (const a of state.reinos) {
        for (const b of state.reinos) {
          if (a.id === b.id) continue;
          const emGuerra = state.guerras.some(g =>
            (g.a === a.id || g.b === a.id || g.a === b.id || g.b === b.id));
          if (!emGuerra && R[a.id][b.id] <= -60 && Math.random() < 0.35) {
            state.guerras.push({ a: a.id, b: b.id, meses: 0 });
            log(`⚔️ GUERRA! O rancor entre ${a.nome} e ${b.nome} transbordou: exércitos marcham. O trigo vai disparar.`);
            break;
          }
        }
      }
    }
    // guerra desgasta a relação; paz recupera devagar
    for (const g of state.guerras) {
      R[g.a][g.b] = clamp(R[g.a][g.b] - 5, -100, 100);
      R[g.b][g.a] = clamp(R[g.b][g.a] - 5, -100, 100);
    }

    // propostas dos reinos PARA o jogador
    for (const r of state.reinos) {
      const rel = (state.tags['rei_' + r.id] || { relacao: 0 }).relacao;
      const temComercio = state.tratados.some(t => t.reino === r.id && t.tipo === 'comercio');
      const temAlianca = state.tratados.some(t => t.reino === r.id && t.tipo === 'alianca');
      const jaOfertou = state.ofertas.some(o => o.reino === r.id);
      if (jaOfertou) continue;
      if (!temComercio && rel >= 25 && Math.random() < 0.10) {
        state.ofertas.push({ reino: r.id, tipo: 'comercio' });
        state.cartas.unshift({ de: r.rei.nome, tipo: 'bom', ano: state.ano, mes: state.mes,
          texto: `"Nossos mercadores falam bem de você. ${r.nome} propõe um ACORDO COMERCIAL: rotas abertas, taxas reduzidas. Aceite no mapa, se tiver juízo."` });
        log(`✉️ ${r.rei.nome} propôs um acordo comercial! Aceite na aba Mapa.`);
      } else if (temComercio && !temAlianca && rel >= 55 && state.jogador.renome >= 60 && Math.random() < 0.08) {
        state.ofertas.push({ reino: r.id, tipo: 'alianca' });
        state.cartas.unshift({ de: r.rei.nome, tipo: 'bom', ano: state.ano, mes: state.mes,
          texto: `"Tempos sombrios pedem espadas amigas. ${r.nome} oferece ALIANÇA: nossos soldados nas suas guerras, nossos muros contra seus inimigos. Aceite no mapa."` });
        log(`🤝 ${r.rei.nome} ofereceu uma ALIANÇA! Aceite na aba Mapa.`);
      }
    }
    if (state.ofertas.length > 3) state.ofertas.length = 3;

    // renda e quebra de tratados
    let renda = 0;
    const vivos = [];
    for (const t of state.tratados) {
      const rel = (state.tags['rei_' + t.reino] || { relacao: 0 }).relacao;
      if (rel < 0) {
        const reino = state.reinos.find(r => r.id === t.reino);
        log(`💔 O ${t.tipo === 'comercio' ? 'acordo comercial' : 'pacto de aliança'} com ${reino.nome} foi ROMPIDO — sua relação azedou.`);
        continue;
      }
      if (t.tipo === 'comercio') renda += 15;
      vivos.push(t);
    }
    state.tratados = vivos;
    if (renda > 0) {
      state.jogador.ouro += renda;
      state.jogador.ultimaRendaTratados = renda;
    }
  }

  // ---------- tratados iniciados pelo jogador ----------
  function proporTratado(state, reinoId, tipo, log) {
    garantir(state);
    const reino = state.reinos.find(r => r.id === reinoId);
    const rel = (state.tags['rei_' + reinoId] || { relacao: 0 }).relacao;
    if (state.tratados.some(t => t.reino === reinoId && t.tipo === tipo))
      return { ok: false, msg: 'Esse tratado já existe.' };
    if (tipo === 'comercio') {
      if (rel < 20) return { ok: false, msg: `${reino.rei.nome} não negocia com estranhos (relação ${rel}/20).` };
      if (state.jogador.ouro < 100) return { ok: false, msg: 'O presente de praxe custa 100 de ouro.' };
      state.jogador.ouro -= 100;
      state.tratados.push({ reino: reinoId, tipo: 'comercio' });
      Dialogo.mudarRelacao(state, 'rei_' + reinoId, 5, 'acordo comercial');
      log(`📜 Acordo comercial selado com ${reino.nome}: preços 10% menores lá e +15 de ouro por mês em rotas.`);
      return { ok: true, msg: `Acordo comercial com ${reino.nome} firmado!` };
    }
    if (tipo === 'alianca') {
      if (rel < 50) return { ok: false, msg: `Aliança exige confiança profunda (relação ${rel}/50).` };
      if (state.jogador.renome < 60) return { ok: false, msg: `Aliança exige renome 60+ (você tem ${state.jogador.renome}).` };
      if (state.jogador.ouro < 300) return { ok: false, msg: 'Selar aliança custa 300 de ouro em garantias.' };
      state.jogador.ouro -= 300;
      state.tratados.push({ reino: reinoId, tipo: 'alianca' });
      Dialogo.mudarRelacao(state, 'rei_' + reinoId, 10, 'aliança');
      log(`🤝 ALIANÇA com ${reino.nome}! Tropas aliadas lutarão ao seu lado e os assassinos deles jamais virão atrás de você.`);
      return { ok: true, msg: `Aliança com ${reino.nome} selada!` };
    }
    return { ok: false, msg: 'Tratado desconhecido.' };
  }

  function aceitarOferta(state, reinoId, log) {
    garantir(state);
    const i = state.ofertas.findIndex(o => o.reino === reinoId);
    if (i < 0) return { ok: false, msg: 'Não há oferta desse reino.' };
    const oferta = state.ofertas[i];
    state.ofertas.splice(i, 1);
    state.tratados.push({ reino: reinoId, tipo: oferta.tipo });
    Dialogo.mudarRelacao(state, 'rei_' + reinoId, 8, 'aceitou proposta');
    const reino = state.reinos.find(r => r.id === reinoId);
    log(`✅ Você aceitou a proposta de ${oferta.tipo === 'comercio' ? 'acordo comercial' : 'aliança'} de ${reino.nome}.`);
    return { ok: true, msg: 'Proposta aceita!' };
  }

  function aliado(state, reinoId) {
    garantir(state);
    return state.tratados.some(t => t.reino === reinoId && t.tipo === 'alianca');
  }
  function temComercio(state, reinoId) {
    garantir(state);
    return state.tratados.some(t => t.reino === reinoId && t.tipo === 'comercio');
  }

  // ---------- torneios: descubra seu campeão de guerra ----------
  function tickTorneio(state, log) {
    garantir(state);
    if (state.torneio) {
      state.torneio.meses--;
      if (state.torneio.meses <= 0) {
        log(`🏟️ O torneio de ${state.torneio.reinoNome} encerrou sem a sua lança.`);
        state.torneio = null;
      }
    } else if (Math.random() < 0.12) {
      const reino = rnd(state.reinos);
      state.torneio = { reino: reino.id, reinoNome: reino.nome, meses: 2 };
      state.cartas.unshift({ de: 'Arauto Real', tipo: 'bom', ano: state.ano, mes: state.mes,
        texto: `"Ouçam! ${reino.rei.nome} convoca TORNEIO em ${reino.capital}! Lanças, glória e ouro aos bravos. Inscrições na taverna por 50 moedas."` });
      log(`🏟️ TORNEIO anunciado em ${reino.nome}! Inscreva-se na taverna (2 meses de prazo).`);
    }
  }

  const NOMES_CAMPEOES = ['Grom Punho-de-Pedra', 'Sir Aldous, o Imbatível', 'Ravena das Duas Lâminas',
    'Bjorn Quebra-Escudos', 'Lady Morgana Ferro-Frio', 'Cassius, o Relâmpago'];

  function participarTorneio(state, log) {
    garantir(state);
    if (!state.torneio) return { ok: false, msg: 'Não há torneio aberto.' };
    if (state.jogador.ouro < 50) return { ok: false, msg: 'A inscrição custa 50 de ouro.' };
    state.jogador.ouro -= 50;
    const forca = state.jogador.atributos.forca + state.jogador.equip * 2;
    const rodadas = [];
    let vitorias = 0;
    for (const dificuldade of [10, 13, 16]) {
      const rolagem = ri(1, 20) + forca;
      const venceu = rolagem >= dificuldade;
      rodadas.push({ dificuldade, rolagem, venceu });
      if (!venceu) break;
      vitorias++;
    }
    const reinoNome = state.torneio.reinoNome;
    let msg;
    if (vitorias >= 3) {
      const premio = 300;
      state.jogador.ouro += premio;
      state.jogador.renome += 25;
      const nome = rnd(NOMES_CAMPEOES.filter(n => !state.campeoes.some(c => c.nome === n)));
      if (nome) {
        state.campeoes.push({ nome, bonus: 15 });
        msg = `🏆 CAMPEÃO DO TORNEIO DE ${reinoNome.toUpperCase()}! +${premio} ouro, +25 renome. E o vice, ${nome}, ajoelhou-se: "Minha lâmina é sua." (+15 de ataque permanente no exército!)`;
      } else {
        msg = `🏆 Campeão de novo! +${premio} ouro, +25 renome. Os bardos já compõem.`;
      }
      log(msg);
    } else if (vitorias === 2) {
      state.jogador.ouro += 100;
      state.jogador.renome += 10;
      msg = `🥈 Finalista do torneio de ${reinoNome}! Caiu na justa final. +100 ouro, +10 renome.`;
      log(msg);
    } else if (vitorias === 1) {
      state.jogador.renome += 4;
      msg = `Você venceu a primeira lança em ${reinoNome}, mas caiu na segunda. +4 renome.`;
      log(msg);
    } else {
      msg = `💥 Derrubado na primeira investida em ${reinoNome}. A plateia riu. O barro não.`;
      log(msg);
    }
    state.torneio = null;
    return { ok: true, msg, rodadas, vitorias };
  }

  // ---------- milícia local: lealdade do povo ----------
  function desafiarMilicia(state, log) {
    garantir(state);
    const reino = state.reinos.find(r => r.id === state.local);
    const lealdadeAtual = state.lealdade[state.local] || 0;
    if (lealdadeAtual >= 100) return { ok: false, msg: `O povo de ${reino.nome} já o venera como herói.` };
    if (Combate.totalHomens(state.jogador.tropas) === 0)
      return { ok: false, msg: 'Você precisa de tropas para desafiar a milícia.' };
    const milicia = Combate.exercitoInimigo(2);
    const rel = Combate.batalhar(state, milicia, `Milícia de ${reino.capital}`);
    if (rel.vitoria) {
      state.lealdade[state.local] = clamp(lealdadeAtual + 20, 0, 100);
      state.jogador.renome += 8;
      log(`🥊 Sua companhia venceu a milícia de ${reino.capital} em treino aberto! O povo aclama: lealdade popular ${state.lealdade[state.local]}/100 (+8 renome).`);
    } else {
      state.jogador.renome = Math.max(0, state.jogador.renome - 4);
      log(`A milícia de ${reino.capital} pôs sua companhia no chão. A praça vaiou (−4 renome).`);
    }
    return rel;
  }

  function lealdadeDe(state, reinoId) {
    garantir(state);
    return state.lealdade[reinoId] || 0;
  }

  return { garantir, inicializarRelacoes, tickReinos, proporTratado, aceitarOferta,
           aliado, temComercio, tickTorneio, participarTorneio, desafiarMilicia,
           lealdadeDe, titulo, eNobre, eCavaleiro, podeSerArmado, armarCavaleiro };
})();
