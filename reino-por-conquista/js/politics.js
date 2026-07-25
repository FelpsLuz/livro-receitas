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
    if (!state.nobres || !state.nobres.length) gerarNobres(state);
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
    // o Império pressiona todos; Touros e Alvorecer são rivais de longa data
    for (const r of state.reinos) {
      if (r.id === 'imperio') continue;
      state.relReinos.imperio[r.id] = ri(-55, -25);
      state.relReinos[r.id].imperio = ri(-55, -25);
    }
    state.relReinos.touros.alvorecer = -35; state.relReinos.alvorecer.touros = -35;
    state.relReinos.leoes.aguias = -25; state.relReinos.aguias.leoes = -25;
  }

  // ---------- NOBRES: cada um com sua cidade, sorteada a cada jogo ----------
  function gerarNobres(state) {
    state.nobres = [];
    const cidades = NOMES_CIDADES.slice();
    for (const r of state.reinos) {
      const qtd = r.nobres || 4;
      for (let i = 0; i < qtd; i++) {
        const ci = Math.floor(Math.random() * cidades.length);
        const cidade = cidades.splice(ci, 1)[0] || ('Aldeia ' + (i + 1));
        const fem = Math.random() < 0.4;
        state.nobres.push({
          id: 'nobre_' + r.id + '_' + i,
          nome: (fem ? rnd(NOMES_F) : rnd(NOMES_M)) + ' de ' + cidade,
          cidade, reino: r.id, reinoOriginal: r.id,
        });
      }
    }
  }

  function nobresDe(state, reinoId) {
    return (state.nobres || []).filter(n => n.reino === reinoId);
  }

  // aliciar um nobre de outro reino para o SEU (exige ser rei)
  function persuadirNobre(state, reinoId, log) {
    if (!state.jogador.reiDe)
      return { ok: false, msg: 'Só um REI convence nobres a trocar de bandeira. Conquiste um trono ou proclame seu reino.' };
    const alvo = nobresDe(state, reinoId)[0];
    if (!alvo) return { ok: false, msg: 'Não restam nobres nesse reino.' };
    const custo = 200;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Cortejar um nobre custa ${custo} de ouro em presentes.` };
    state.jogador.ouro -= custo;
    const chance = 0.25 + state.jogador.renome / 300 + lealdadeDe(state, reinoId) / 250
      + state.jogador.atributos.carisma * 0.02;
    if (Math.random() < chance) {
      alvo.reino = 'jogador';
      log(`🏰 ${alvo.nome} ajoelhou-se diante de você! A cidade de ${alvo.cidade} agora hasteia SUA bandeira (+20 🪙/mês; o reino de origem enfraquece).`);
      Dialogo.mudarRelacao(state, 'rei_' + reinoId, -15, 'aliciou nobre');
      return { ok: true, msg: `${alvo.nome} integrou o seu reino!` };
    }
    Dialogo.mudarRelacao(state, 'rei_' + reinoId, -10, 'flagrado aliciando');
    return { ok: true, msg: `${alvo.nome} recusou — e a corte de origem soube da sua investida (relação −10).` };
  }

  function meusNobres(state) { return nobresDe(state, 'jogador'); }

  // ---------- REINO INDEPENDENTE ----------
  function podeProclamar(state) {
    return !state.jogador.reiDe && state.terra && state.terra.nivel >= 5
      && eNobre(state) && state.jogador.renome >= 80;
  }
  function proclamarIndependencia(state, log) {
    if (!podeProclamar(state))
      return { ok: false, msg: 'Proclamar um reino exige: ser CONDE, castelo (terra nível 5) e 80 de renome.' };
    state.jogador.reiDe = 'jogador';
    state.jogador.reinoNome = 'Reino do ' + state.terra.nome;
    state.jogador.mesesReinando = 0;
    for (const r of state.reinos)
      Dialogo.mudarRelacao(state, 'rei_' + r.id, r.id === 'imperio' ? -40 : -20, 'proclamou independência');
    log(`👑 INDEPENDÊNCIA! Você cinge a própria coroa: nasce o ${state.jogador.reinoNome}. As seis cortes tremem — e Felps, o Destruidor, esmaga a taça na mão ao saber. Sobreviva 12 meses no trono.`);
    return { ok: true, msg: `O ${state.jogador.reinoNome} foi proclamado! Segure o trono por 12 meses.` };
  }

  // ---------- VASSALAGEM: crescer dentro de um reino ----------
  function jurarVassalagem(state, reinoId, log) {
    if (state.jogador.reiDe) return { ok: false, msg: 'Um rei não se ajoelha.' };
    if (state.jogador.vassaloDe) return { ok: false, msg: 'Você já jurou a um senhor. Quebre o juramento primeiro (na corte dele).' };
    const rel = (state.tags['rei_' + reinoId] || { relacao: 0 }).relacao;
    if (rel < 30) return { ok: false, msg: `Jurar vassalagem exige a confiança do rei (relação ${rel}/30).` };
    state.jogador.vassaloDe = reinoId;
    const reino = state.reinos.find(r => r.id === reinoId);
    Dialogo.mudarRelacao(state, 'rei_' + reinoId, 15, 'juramento de vassalagem');
    log(`🛡️ Você jurou fidelidade a ${reino.rei.nome}. Contratos do ${reino.nome} pagam +30%, e a coroa o protege — mas vassalo não reivindica tronos.`);
    return { ok: true, msg: `Agora você é vassalo de ${reino.nome}.` };
  }
  function quebrarVassalagem(state, log) {
    if (!state.jogador.vassaloDe) return { ok: false, msg: 'Você não serve a ninguém.' };
    const reino = state.reinos.find(r => r.id === state.jogador.vassaloDe);
    Dialogo.mudarRelacao(state, 'rei_' + state.jogador.vassaloDe, -50, 'quebrou juramento');
    log(`⚡ Você QUEBROU o juramento a ${reino.rei.nome}. A palavra "traidor" corre as seis cortes (relação −50).`);
    state.jogador.vassaloDe = null;
    state.jogador.traidorDeJuramento = true;   // os Leões Carmesins não esquecem
    return { ok: true, msg: 'Juramento quebrado. Você está livre — e marcado.' };
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
    const rancorArmar = Dialogo.memoriasDe(state, 'rei_' + reinoId, ['insulto', 'ameaca']);
    if (rancorArmar.length) {
      const m = rancorArmar[rancorArmar.length - 1];
      return { ok: false, msg: `Ele baixa a espada sem tocar seus ombros: "Armar cavaleiro quem me disse '${m.frase}'? Peça desculpas primeiro — e que sejam sinceras."` };
    }
    state.jogador.cavaleiro = true;
    const reino = state.reinos.find(r => r.id === reinoId);
    state.jogador.renome += 10;
    log(`⚔️ ${reino.rei.nome} toca seus ombros com a espada: "Levante-se, CAVALEIRO." Agora você pode possuir terras — o primeiro degrau da nobreza.`);
    return { ok: true, msg: 'Você foi armado cavaleiro! (+10 renome). Agora pode comprar terras.' };
  }

  // ---------- DOUTRINAS: cada facção age conforme sua mente ----------
  const DOUTRINAS = {
    imperio:   'Status quo e tributos: 10 Lordes Comandantes, nenhum com recursos completos. Exige submissão.',
    touros:    'Guerrilha e saque: proscritos leais só à sobrevivência. Imprevisíveis; acordos são temporários.',
    alvorecer: 'Guerra econômica: embargos, sabotagem e assassinos pagos. Raramente declara guerra aberta.',
    leoes:     'Lei marcial e mérito: falange disciplinada. Punem quem quebra tratados ou mostra fraqueza.',
    aguias:    'Fortaleza isolacionista: quase impossíveis de invadir. Aliança só com tributo pesado.',
    rosa:      'Equilíbrio de poder: ajuda o mais fraco para frear o mais forte. A diplomacia mais ativa.',
  };

  function tickDoutrinas(state, log) {
    if (!state.embargos) state.embargos = {};
    // embargos expiram
    for (const k of Object.keys(state.embargos)) {
      state.embargos[k]--;
      if (state.embargos[k] <= 0) { delete state.embargos[k]; log(`📦 O embargo de ${k} contra você expirou.`); }
    }
    const relJog = (id) => (state.tags['rei_' + id] || { relacao: 0 }).relacao;

    // IMPÉRIO: exige tributo de quem cresce demais
    if (!state.tributo && state.jogador.renome >= 60 && state.jogador.vassaloDe !== 'imperio'
        && state.jogador.reiDe !== 'imperio' && Math.random() < 0.08) {
      const valor = 150 + Math.floor(state.jogador.renome * 2);
      state.tributo = { valor, meses: 3 };
      state.cartas.unshift({ de: 'Felps, o Destruidor', tipo: 'ruim', ano: state.ano, mes: state.mes,
        texto: `"Seu nome cresce, verme. O Império tolera formigas que pagam. ${valor} de ouro em 3 meses — ou aprenderá por que me chamam de Destruidor." (pague no Mapa)` });
      log(`🟢 O IMPÉRIO exige tributo: ${valor} de ouro em 3 meses. Pague no Mapa — ou desafie o Destruidor.`);
    }
    if (state.tributo) {
      state.tributo.meses--;
      if (state.tributo.meses <= 0) {
        Dialogo.mudarRelacao(state, 'rei_imperio', -30, 'tributo ignorado');
        const tags = Dialogo.tagsDe(state, 'rei_imperio');
        tags.flags.marcadoParaMorte = true;
        log(`🟢 Você IGNOROU o tributo imperial. Felps não esquece (relação −30; adagas virão).`);
        state.tributo = null;
      }
    }

    // ALVORECER DOURADO: embargo e sabotagem em vez de guerra
    if (relJog('alvorecer') <= -25 && !state.embargos.alvorecer && Math.random() < 0.15) {
      state.embargos.alvorecer = 4;
      state.cartas.unshift({ de: 'William Vangeance', tipo: 'ruim', ano: state.ano, mes: state.mes,
        texto: '"Nada pessoal. Apenas... aritmética. Nossos mercados estão fechados para você." (preços +35% no Alvorecer por 4 meses)' });
      log(`🪙 O Alvorecer Dourado decretou EMBARGO contra você: preços +35% lá por 4 meses.`);
    }
    for (const g of state.guerras) {
      if ((g.a === 'alvorecer' || g.b === 'alvorecer') && Math.random() < 0.3) {
        const rival = g.a === 'alvorecer' ? g.b : g.a;
        state.mercados[rival].trigo.oferta = Math.max(0.25, state.mercados[rival].trigo.oferta * 0.85);
        log(`🔥 Mercenários pagos pelo Alvorecer queimaram colheitas de ${rival} — o trigo dispara lá.`);
      }
    }

    // TOUROS NEGROS: saque de comboios de quem não é amigo
    if (relJog('touros') < 0 && Math.random() < 0.08) {
      const itens = Object.keys(state.carga).filter(k => state.carga[k] > 0);
      if (itens.length) {
        const item = rnd(itens);
        const perda = Math.max(1, Math.ceil(state.carga[item] * 0.3));
        state.carga[item] -= perda;
        log(`🐂 Emboscada dos Touros Negros na estrada! Perdeu ${perda}× ${MERCADORIAS[item].nome}. Yami manda lembranças.`);
      }
    }

    // LEÕES CARMESINS: punem traidores de juramento
    if (state.jogador.traidorDeJuramento && relJog('leoes') > -60 && Math.random() < 0.2) {
      Dialogo.mudarRelacao(state, 'rei_leoes', -15, 'desprezo por traidores');
      log(`🦁 Fuegoleon soube da sua quebra de juramento: "Covardia se paga." (Leões −15)`);
    }

    // ROSA AZUL: freia quem está vencendo (inclusive você)
    if (state.jogador.reiDe && Math.random() < 0.25) {
      Dialogo.mudarRelacao(state, 'rei_rosa', -4, 'equilíbrio de poder');
      if (Math.random() < 0.3)
        log(`🌹 Charlotte Roselei costura pactos contra o novo poder do continente — você. (Rosa Azul esfria)`);
    }
  }

  function pagarTributo(state, log) {
    if (!state.tributo) return { ok: false, msg: 'Nenhum tributo pendente.' };
    if (state.jogador.ouro < state.tributo.valor)
      return { ok: false, msg: `Faltam ${state.tributo.valor - state.jogador.ouro} de ouro.` };
    state.jogador.ouro -= state.tributo.valor;
    Dialogo.mudarRelacao(state, 'rei_imperio', 10, 'tributo pago');
    log(`🟢 Tributo de ${state.tributo.valor} pago ao Império. Felps aceita — por ora — sua existência.`);
    state.tributo = null;
    return { ok: true, msg: 'Tributo pago. O Destruidor está... satisfeito.' };
  }

  // ---------- IA dos reinos: relações, guerras e propostas ----------
  function tickReinos(state, log) {
    garantir(state);
    tickDoutrinas(state, log);
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
      const chanceOferta = r.id === 'rosa' ? 0.20 : 0.10;   // Rosa Azul: a diplomacia mais ativa
      if (!temComercio && rel >= 25 && Math.random() < chanceOferta) {
        state.ofertas.push({ reino: r.id, tipo: 'comercio', meses: 6 });
        state.cartas.unshift({ de: r.rei.nome, tipo: 'bom', ano: state.ano, mes: state.mes,
          texto: `"Nossos mercadores falam bem de você. ${r.nome} propõe um ACORDO COMERCIAL: rotas abertas, taxas reduzidas. Aceite no mapa, se tiver juízo."` });
        log(`✉️ ${r.rei.nome} propôs um acordo comercial! Aceite na aba Mapa.`);
      } else if (temComercio && !temAlianca && rel >= 55 && state.jogador.renome >= 60 && Math.random() < 0.08) {
        state.ofertas.push({ reino: r.id, tipo: 'alianca', meses: 6 });
        state.cartas.unshift({ de: r.rei.nome, tipo: 'bom', ano: state.ano, mes: state.mes,
          texto: `"Tempos sombrios pedem espadas amigas. ${r.nome} oferece ALIANÇA: nossos soldados nas suas guerras, nossos muros contra seus inimigos. Aceite no mapa."` });
        log(`🤝 ${r.rei.nome} ofereceu uma ALIANÇA! Aceite na aba Mapa.`);
      }
    }
    for (const o of state.ofertas) o.meses = (o.meses === undefined ? 6 : o.meses) - 1;
    state.ofertas = state.ofertas.filter(o => o.meses > 0);
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
    renda += meusNobres(state).length * 20;   // cada cidade nobre rende 20/mês
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
      const rancorAli = Dialogo.memoriasDe(state, 'rei_' + reinoId, ['ameaca']);
      if (rancorAli.length) {
        const m = rancorAli[rancorAli.length - 1];
        return { ok: false, msg: `${reino.rei.nome} recua: "Aliança? Você me disse '${m.frase}'. Quem ameaça um trono não dorme sob o mesmo estandarte. Retrate-se primeiro."` };
      }
      if (state.jogador.renome < 60) return { ok: false, msg: `Aliança exige renome 60+ (você tem ${state.jogador.renome}).` };
      const custoAli = reinoId === 'aguias' ? 600 : 300;   // Nozel cobra tributo absurdo
      if (state.jogador.ouro < custoAli) return { ok: false, msg: `Selar aliança custa ${custoAli} de ouro em garantias${reinoId === 'aguias' ? ' (as Águias cobram caro pela pureza)' : ''}.` };
      state.jogador.ouro -= custoAli;
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
           lealdadeDe, titulo, eNobre, eCavaleiro, podeSerArmado, armarCavaleiro,
           gerarNobres, nobresDe, persuadirNobre, meusNobres,
           podeProclamar, proclamarIndependencia, jurarVassalagem, quebrarVassalagem,
           DOUTRINAS, pagarTributo };
})();
