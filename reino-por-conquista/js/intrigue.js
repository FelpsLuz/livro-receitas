// ============================================================
// INTRIGAS, CASUS BELLI, FAMÍLIA E TRAIÇÕES
// - Espionar revela segredos; segredos viram chantagem.
// - Casus belli: forjar documentos, fabricar intriga, casamento.
// - Atacar SEM casus belli une os 6 reinos contra você.
// - Dinastia: filhos herdam atributos (genética + educação).
// - Assassinos são enviados por reis que te odeiam.
// ============================================================
'use strict';

const Intriga = (() => {

  const SEGREDOS_MODELO = [
    { id: 'desvio', texto: (r) => `${r.rei.nome} desvia ouro dos impostos devidos aos templos.` },
    { id: 'bastardo', texto: (r) => `${r.rei.nome} tem um filho bastardo escondido numa aldeia de pescadores.` },
    { id: 'veneno', texto: (r) => `${r.rei.nome} envenenou o próprio conselheiro no ano passado.` },
    { id: 'divida', texto: (r) => `${r.rei.nome} deve uma fortuna a agiotas estrangeiros. O tesouro real está vazio.` },
    { id: 'heresia', texto: (r) => `${r.rei.nome} pratica ritos proibidos nas catacumbas do castelo.` },
  ];

  // ---------- espionagem ----------
  function espionar(state, reinoId, log) {
    const custo = 80;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Espiões custam ${custo} de ouro.` };
    state.jogador.ouro -= custo;
    const reino = state.reinos.find(r => r.id === reinoId);
    const chance = 0.4 + state.jogador.atributos.intriga * 0.05;
    if (Math.random() > chance) {
      if (Math.random() < 0.3) {
        Dialogo.mudarRelacao(state, 'rei_' + reinoId, -15, 'espião capturado');
        return { ok: true, msg: `🚨 Seu espião foi CAPTURADO em ${reino.nome}! ${reino.rei.nome} sabe que foi você. Relação −15.` };
      }
      return { ok: true, msg: `Seu espião voltou de mãos vazias de ${reino.nome}. O ouro, porém, já era.` };
    }
    const jaTem = state.segredos.filter(s => s.reino === reinoId).map(s => s.id);
    const disponiveis = SEGREDOS_MODELO.filter(s => !jaTem.includes(s.id));
    if (!disponiveis.length) return { ok: true, msg: `Você já sabe tudo que há para saber sobre ${reino.nome}.` };
    const s = rnd(disponiveis);
    state.segredos.push({ id: s.id, reino: reinoId, texto: s.texto(reino), usado: false });
    return { ok: true, msg: `🕵️ SEGREDO DESCOBERTO: ${s.texto(reino)} Guarde essa carta na manga.` };
  }

  // ---------- chantagem (via diálogo) ----------
  function chantagear(state, npc) {
    if (!npc.id.startsWith('rei_'))
      return { resposta: 'Chantagem? Eu? Minha vida é um livro aberto e mal escrito. Procure gente mais importante.', efeitos: [] };
    const reinoId = npc.id.replace('rei_', '');
    const segredo = state.segredos.find(s => s.reino === reinoId && !s.usado);
    if (!segredo)
      return { resposta: 'Você fala em segredos... mas seus olhos dizem que não sabe de nada. Patético. Saia.', efeitos: ['[Blefe falhou]'] };
    segredo.usado = true;
    const tags = Dialogo.tagsDe(state, npc.id);
    tags.flags.chantageado = true;
    const efeitos = ['[Segredo usado: ' + segredo.texto + ']'];
    // chantagem funciona, mas planta ódio profundo
    efeitos.push(Dialogo.mudarRelacao(state, npc.id, -20, 'chantagem').tag);
    efeitos.push('[Ele cederá a UMA exigência: ouro, casamento ou casus belli — veja a Mesa de Intrigas]');
    state.chantagemPendente = { reino: reinoId };
    return {
      resposta: `*o sangue foge do rosto de ${npc.nome}* ...Onde você ouviu isso? ONDE?! ...O que você quer? Fale logo. E saiba: quem segura uma adaga pela lâmina também sangra.`,
      efeitos,
    };
  }

  function resolverChantagem(state, escolha, log) {
    const ch = state.chantagemPendente;
    if (!ch) return;
    const reino = state.reinos.find(r => r.id === ch.reino);
    if (escolha === 'ouro') {
      const valor = ri(300, 500);
      state.jogador.ouro += valor;
      log(`💰 ${reino.rei.nome} pagou ${valor} de ouro pelo seu silêncio. Por enquanto.`);
    } else if (escolha === 'casamento') {
      forcarCasamento(state, reino, log);
    } else if (escolha === 'casusbelli') {
      state.casusBelli.push(ch.reino);
      log(`📜 ${reino.rei.nome} assinou, com a mão trêmula, um documento que legitima sua reivindicação sobre terras de ${reino.nome}. Você tem CASUS BELLI.`);
    }
    state.chantagemPendente = null;
  }

  // ---------- casamento e dinastia ----------
  function pedirCasamento(state, npc) {
    if (state.familia.conjuge)
      return { resposta: 'Você JÁ é casado. Que escândalo está tentando armar na minha corte?', efeitos: [] };
    if (!npc.id.startsWith('rei_'))
      return { resposta: 'Casar? Comigo? *ri* Sou casado com meu trabalho. Tente a nobreza.', efeitos: [] };
    const tags = Dialogo.tagsDe(state, npc.id);
    const reinoId = npc.id.replace('rei_', '');
    const reino = state.reinos.find(r => r.id === reinoId);
    const exigencia = npc.personalidade === 'romantica' ? 20 : 45;
    const renomeMin = 40;
    if (state.jogador.renome < renomeMin)
      return { resposta: `Unir minha casa a... quem, exatamente? Um mercenário sem nome? Volte quando os bardos cantarem seus feitos. (Renome ${state.jogador.renome}/${renomeMin})`, efeitos: [] };
    if (tags.relacao < exigencia)
      return { resposta: `Casamento é aliança de sangue, e eu mal confio em você. Prove seu valor à minha corte primeiro. (Relação ${tags.relacao}/${exigencia})`, efeitos: [] };
    return {
      resposta: `Hm... seus feitos falam por você, e uma aliança de sangue tem seu valor. Que seja: concedo a mão de ${reino.rei.genero === 'f' ? 'meu sobrinho' : 'minha filha'} em casamento. Que esta união traga paz — ou ao menos herdeiros.`,
      efeitos: ['[Aliança de casamento firmada]'],
      acao: { tipo: 'casamento', reino: reinoId },
    };
  }

  function forcarCasamento(state, reino, log) {
    realizarCasamento(state, reino.id, true);
    log(`💍 Sob o peso do segredo, ${reino.rei.nome} aceitou casar ${reino.rei.genero === 'f' ? 'o sobrinho' : 'a filha'} com sua casa — sem derramar uma gota de sangue. A corte sussurra, mas assina.`);
  }

  function realizarCasamento(state, reinoId, forcado) {
    const reino = state.reinos.find(r => r.id === reinoId);
    const generoConjuge = reino.rei.genero === 'f' ? 'm' : 'f';
    state.familia.conjuge = {
      nome: (generoConjuge === 'f' ? rnd(NOMES_F) : rnd(NOMES_M)) + ' de ' + reino.capital,
      genero: generoConjuge, reino: reinoId, forcado: !!forcado,
      atributos: { forca: ri(3, 8), carisma: ri(3, 8), gestao: ri(3, 8), intriga: ri(3, 8) },
    };
    // casamento dá reivindicação legal (casus belli dinástico)
    if (!state.casusBelli.includes(reinoId)) state.casusBelli.push(reinoId);
    if (!forcado) Dialogo.mudarRelacao(state, 'rei_' + reinoId, 20, 'aliança de casamento');
  }

  function tickFamilia(state, log) {
    const f = state.familia;
    // nascimento de filhos
    if (f.conjuge && f.filhos.length < 4 && Math.random() < 0.06) {
      const genero = Math.random() < 0.5 ? 'm' : 'f';
      const j = state.jogador.atributos, c = f.conjuge.atributos;
      const heranca = (k) => clamp(Math.round((j[k] + c[k]) / 2 + ri(-2, 2)), 1, 10);
      const filho = {
        nome: genero === 'm' ? rnd(NOMES_M) : rnd(NOMES_F),
        genero, idade: 0, educacao: null,
        atributos: { forca: heranca('forca'), carisma: heranca('carisma'),
                     gestao: heranca('gestao'), intriga: heranca('intriga') },
        // filhos de pais cruéis tendem à crueldade — vassalos notarão
        mimado: (state.jogador.crueldade || 0) >= 3 && Math.random() < 0.5,
      };
      f.filhos.push(filho);
      log(`👶 Nasce ${filho.nome}! ${genero === 'm' ? 'Um herdeiro' : 'Uma herdeira'} para sua casa. Os atributos correm no sangue — mas a educação cabe a você.`);
    }
    // aniversários (idade avança 1 ano a cada 12 meses — controlado em game.js)
  }

  function educar(state, indiceFilho, foco) {
    const filho = state.familia.filhos[indiceFilho];
    if (!filho) return { ok: false, msg: 'Filho não encontrado.' };
    filho.educacao = foco;
    const bonus = { marcial: 'forca', cortesa: 'carisma', administrativa: 'gestao', sombras: 'intriga' }[foco];
    filho.atributos[bonus] = clamp(filho.atributos[bonus] + 2, 1, 10);
    if (foco !== 'sombras' && filho.mimado && Math.random() < 0.5) {
      filho.mimado = false;
      return { ok: true, msg: `${filho.nome} recebe educação ${foco}. A disciplina dos tutores corrigiu os modos mimados a tempo. (+2 ${bonus})` };
    }
    return { ok: true, msg: `${filho.nome} agora recebe educação ${foco} (+2 ${bonus}).` };
  }

  // ---------- casus belli ----------
  function forjarDocumento(state, reinoId, log) {
    const custo = 150;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Escribas falsários custam ${custo} de ouro.` };
    if (state.casusBelli.includes(reinoId)) return { ok: false, msg: 'Você já tem reivindicação sobre esse reino.' };
    state.jogador.ouro -= custo;
    const reino = state.reinos.find(r => r.id === reinoId);
    const chance = 0.35 + state.jogador.atributos.intriga * 0.06;
    if (Math.random() < chance) {
      state.casusBelli.push(reinoId);
      return { ok: true, msg: `📜 Seus escribas "descobriram" um testamento antigo: as terras de ${reino.nome} pertencem à sua linhagem! Reivindicação legal forjada com perfeição.` };
    }
    Dialogo.mudarRelacao(state, 'rei_' + reinoId, -30, 'falsificação exposta');
    // reinos honrados espalham a notícia
    for (const r of state.reinos) {
      if (r.id !== reinoId && r.rei.personalidade === 'honrado')
        Dialogo.mudarRelacao(state, 'rei_' + r.id, -10, 'falsário exposto');
    }
    return { ok: true, msg: `🚨 A falsificação foi EXPOSTA! ${reino.rei.nome} exibe seu documento forjado nas cortes. Sua reputação sangra (−30 com ele, reis honrados desconfiam de você).` };
  }

  function fabricarIntriga(state, reinoId, log) {
    const custo = 250;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Uma rede de boatos custa ${custo} de ouro.` };
    if (state.casusBelli.includes(reinoId)) return { ok: false, msg: 'Você já tem reivindicação sobre esse reino.' };
    state.jogador.ouro -= custo;
    const reino = state.reinos.find(r => r.id === reinoId);
    const chance = 0.5 + state.jogador.atributos.intriga * 0.05;
    if (Math.random() < chance) {
      state.casusBelli.push(reinoId);
      return { ok: true, msg: `🎭 Seus agentes plantaram provas de que ${reino.nome} conspirava contra você. As outras cortes aceitam: você tem motivo legítimo para guerra.` };
    }
    return { ok: true, msg: `A intriga se desfez antes de criar raízes. Ouro perdido, mas ao menos ninguém rastreou até você.` };
  }

  // ---------- assassinos ----------
  function tickAssassinos(state, log) {
    for (const r of state.reinos) {
      const tags = state.tags['rei_' + r.id];
      if (!tags || !tags.flags.marcadoParaMorte) continue;
      if (Politica.aliado(state, r.id) || state.jogador.vassaloDe === r.id) { tags.flags.marcadoParaMorte = false; continue; } // aliados e seu senhor não mandam adagas
      if (Math.random() < 0.15) {
        tags.flags.marcadoParaMorte = false; // tentativa gasta
        const defesa = state.jogador.guardas * 2 + state.jogador.atributos.forca;
        if (ri(1, 20) + defesa >= 16) {
          log(`🗡️ Um ASSASSINO de ${r.nome} invadiu seus aposentos à noite — sua guarda o deteve a um palmo da sua garganta. ${r.rei.nome} não esqueceu suas palavras.`);
          Dialogo.mudarRelacao(state, 'rei_' + r.id, -10, 'assassino frustrado');
        } else {
          state.eventoPendente = { tipo: 'assassinato', reino: r.id };
          log(`🗡️ Uma lâmina no escuro...`);
        }
      }
    }
  }

  // ---------- guerra de conquista ----------
  function declararGuerra(state, reinoId, log) {
    const reino = state.reinos.find(r => r.id === reinoId);
    if (state.jogador.vassaloDe) {
      log(`🛡️ Vassalos não reivindicam tronos. Quebre seu juramento primeiro — e pague o preço.`);
      return { vitoria: false, rodadas: [], contexto: 'Juramento no caminho', baixasJogador: {}, baixasInimigo: {}, bloqueado: true };
    }
    if (!Politica.eNobre(state)) {
      log(`⚖️ As cortes não reconhecem plebeus em tronos. Torne-se CONDE (terra nível 4) antes de reivindicar uma coroa.`);
      return { vitoria: false, rodadas: [], contexto: 'Reivindicação rejeitada', baixasJogador: {}, baixasInimigo: {}, bloqueado: true };
    }
    if (Politica.aliado(state, reinoId)) {
      state.tratados = state.tratados.filter(t => !(t.reino === reinoId && t.tipo === 'alianca'));
      Dialogo.mudarRelacao(state, 'rei_' + reinoId, -40, 'traiu aliança');
      log(`💔 Você marcha contra um ALIADO. O pacto vira cinzas e a palavra 'traidor' corre o continente (relação −40).`);
    }
    const temCB = state.casusBelli.includes(reinoId);
    if (!temCB) {
      log(`⚠️ Você atacou ${reino.nome} SEM reivindicação legal! As cortes dos 6 reinos denunciam sua agressão bárbara.`);
      for (const r of state.reinos)
        Dialogo.mudarRelacao(state, 'rei_' + r.id, r.id === reinoId ? -60 : -35, 'agressão sem casus belli');
    } else {
      log(`⚔️ Com sua reivindicação em punho, você declara guerra a ${reino.nome}. As demais cortes observam — é um assunto legal, dizem.`);
    }
    let forcaDefensor = temCB ? 3 : 4;
    if (reino.imperial) {
      forcaDefensor = 5;   // a legião imperial de Felps é outra categoria
      log(`🟢 A legião do Império marcha: o Destruidor não conhece derrota. Enfraqueça-o aliciando os 10 nobres dele.`);
    }
    const desertores = (state.nobres || []).filter(n => n.reinoOriginal === reinoId && n.reino === 'jogador').length;
    if (desertores > 0) {
      forcaDefensor = Math.max(1, forcaDefensor - Math.floor(desertores / 3));
      log(`🏰 ${desertores} ${desertores === 1 ? 'nobre desertou' : 'nobres desertaram'} para o seu lado: a defesa de ${reino.nome} está minada.`);
    }
    if (Politica.lealdadeDe(state, reinoId) >= 60) {
      forcaDefensor = Math.max(1, forcaDefensor - 1);
      log(`✊ O povo de ${reino.nome} te adora: parte da guarnição se recusa a lutar contra você!`);
    }
    const aliados = state.tratados.filter(t => t.tipo === 'alianca' && t.reino !== reinoId);
    if (aliados.length > 0) {
      state.jogador.tropas.lanceiro = (state.jogador.tropas.lanceiro || 0) + 15;
      log(`🤝 Um contingente aliado de 15 lanceiros marcha sob sua bandeira!`);
    }
    if (reinoId === 'aguias') {
      forcaDefensor = Math.min(5, forcaDefensor + 1);   // fortificações intransponíveis
      log(`🦅 As muralhas do Ninho de Prata são lendárias: a defesa das Águias é implacável.`);
    }
    if (reino.emCrise) {
      forcaDefensor = Math.max(1, forcaDefensor - 2);   // rei morto sem herdeiro: guarnição em frangalhos
      log(`🏚️ ${reino.nome} vive uma crise de sucessão: a guarnição está dividida e desmoralizada.`);
    }
    const inimigo = Combate.exercitoInimigo(forcaDefensor);
    if (reinoId === 'leoes') {   // falange disciplinada: formação fixa e aço superior
      inimigo.formacao = 'linha';
      inimigo.equip = Math.min(3, (inimigo.equip || 0) + 1);
      log(`🦁 A falange dos Leões Carmesins forma diante de você — disciplina de lei marcial.`);
    }
    if (reinoId === 'touros') {  // guerrilha: emboscada antes da batalha
      inimigo.formacao = 'cerco';
      const perda = Math.ceil((state.jogador.tropas.lanceiro || 0) * 0.1);
      if (perda > 0) {
        state.jogador.tropas.lanceiro -= perda;
        log(`🐂 Armadilhas e emboscadas nos pântanos: você perdeu ${perda} lanceiros antes de ver o inimigo.`);
      }
    }
    const rel = Combate.batalhar(state, inimigo, `Conquista de ${reino.nome}`);
    if (rel.vitoria) {
      // conquista ACUMULA tronos: o objetivo é dominar TODOS os reinos
      reino.dominadoPor = 'jogador';
      reino.deposto = true;
      if (!state.jogador.reiDe || state.jogador.reiDe === 'jogador') state.jogador.reiDe = reinoId;
      if (!state.jogador.tronos) state.jogador.tronos = [];
      if (!state.jogador.tronos.includes(reinoId)) state.jogador.tronos.push(reinoId);
      state.jogador.renome += 50;
      log(`👑 VITÓRIA! Os portões de ${reino.capital} se abrem. Você depõe ${reino.rei.nome} e toma o trono de ${reino.nome}!`);
      for (const n of (state.nobres || []).filter(n => n.reino === reinoId)) {
        n.reino = 'jogador';
        log(`🏰 ${n.nome} (${n.cidade}) ajoelha-se ao novo soberano.`);
      }
      const faltam = state.reinos.filter(r => r.dominadoPor !== 'jogador').length;
      if (faltam > 0)
        log(`🗺️ Você domina ${state.reinos.length - faltam}/${state.reinos.length} reinos. Faltam ${faltam} tronos para unificar o continente e vencer.`);
      if (!temCB) log(`Mas cuidado: os reinos livres veem um usurpador sangrento. Espere assassinos e embargos.`);
    } else {
      state.jogador.renome = Math.max(0, state.jogador.renome - 20);
      log(`❌ Seu exército foi despedaçado diante dos muros de ${reino.capital}. Renome −20. Reagrupe-se... se sobrar alguém.`);
    }
    if (typeof Fofoca !== 'undefined')
      Fofoca.plantar(state, 'batalha', { autor: 'jogador', origem: 'rei_' + reinoId,
        vitoria: !!rel.vitoria, contexto: reino.capital });
    return rel;
  }

  // ---------- segredos de taverna ----------
  function perguntarSegredo(state, npc) {
    if (npc.id === 'espiao' || npc.id === 'taverneiro') {
      const custo = 30;
      if (state.jogador.ouro < custo)
        return { resposta: `Informação tem preço: ${custo} de ouro. Volte com a bolsa mais cheia.`, efeitos: [] };
      state.jogador.ouro -= custo;
      const g = state.guerras[0];
      const dicas = [
        g ? `Ouvi que a guerra entre ${state.reinos.find(r => r.id === g.a).nome} e ${state.reinos.find(r => r.id === g.b).nome} fez o trigo triplicar de preço por lá. Quem levar comida fica rico — se as patrulhas não pegarem.`
          : 'Os reinos estão em paz... o que significa que os preços estão baixos e os espiões, ocupados.',
        'Dizem que todo rei tem um segredo que vale mais que ouro. Mande espiões e descubra você mesmo.',
        `Fred Prateado dorme com um provador de venenos ao lado da cama. Medo tem cheiro, sabia?`,
        'Guarda de elite sem soldo é portão aberto. Nunca deixe o tesouro zerar, é o que eu digo.',
      ];
      return { resposta: `*abaixa a voz* ...${rnd(dicas)}`, efeitos: [`[−${custo} ouro]`] };
    }
    return { resposta: 'Rumores? Não sou de espalhar. *olha para os lados* ...ok, mas não fui eu que contei: pergunte ao taverneiro.', efeitos: [] };
  }

  return { espionar, chantagear, resolverChantagem, pedirCasamento, realizarCasamento,
           tickFamilia, educar, forjarDocumento, fabricarIntriga, tickAssassinos,
           declararGuerra, perguntarSegredo };
})();
