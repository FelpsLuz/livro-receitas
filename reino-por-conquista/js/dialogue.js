// ============================================================
// MOTOR DE DIÁLOGO LIVRE (100% offline)
// - O jogador digita o que quiser.
// - O motor detecta INTENÇÃO + SENTIMENTO no texto.
// - O NPC responde conforme personalidade + MEMÓRIA POR TAGS.
// - Cada conversa atualiza tags ([Odiado: -50], [InsultouRei], ...)
//   que afetam preços, contratos, assassinos e casamentos.
//
// ADAPTADOR LLM: veja llmAdapter no fim do arquivo — é o ponto
// de encaixe para um modelo GGUF local (llama.cpp), mantendo o
// mesmo sistema de tags como "memória" do modelo.
// ============================================================
'use strict';

const Dialogo = (() => {

  // ---------- normalização ----------
  function norm(t) {
    return t.toLowerCase()
      .normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ').trim();
  }

  // ---------- léxico de intenções ----------
  const INTENCOES = [
    { id: 'insulto', palavras: ['idiota','burro','burra','covarde','porco','porca','verme','inutil',
      'tolo','tola','patetico','patetica','gordo','gorda','feio','feia','fraco','fraca','lixo',
      'nojento','nojenta','imbecil','canalha','rato','vaca','cachorro','miseravel','tirano','tirana',
      'usurpador','usurpadora','ladrao de trono','bastardo','bastarda','chiqueiro','imundo','imunda',
      'ridiculo','ridicula','desprezivel','palhaco','palhaca','fede','fedorento','fedorenta','podre',
      'incompetente','mentiroso','mentirosa','farsante','vergonha'] },
    { id: 'elogio', palavras: ['sabio','sabia','sabedoria','forte','grande','magnifico','magnifica',
      'honrado','honrada','bela','belo','glorioso','gloriosa','admiro','respeito','corajoso','corajosa',
      'justo','justa','generoso','generosa','lendario','lendaria','brilhante','poderoso','poderosa',
      'nobre','maravilhoso','maravilhosa','excelente','incrivel','esplendido','esplendida'] },
    { id: 'ameaca', palavras: ['vou te matar','cabeca','queimar','destruir','guerra contra voce','vou acabar',
      'te destruo','invadir','arrependera','vinganca','pagara caro','declaro guerra','morrera'] },
    { id: 'saudacao', palavras: ['ola','oi','saudacoes','bom dia','boa noite','boa tarde','majestade',
      'vossa alteza','meu rei','minha rainha','senhor','senhora','salve'] },
    { id: 'despedida', palavras: ['adeus','tchau','ate logo','vou embora','me retiro','ate mais','partir'] },
    { id: 'perguntar_guerra', palavras: ['guerra','batalha','conflito','inimigo','exercito','tropas',
      'lutando','frente de batalha','campanha'] },
    { id: 'perguntar_preco', palavras: ['preco','mercado','comprar','vender','comercio','trigo','ferro',
      'sal','madeira','tecidos','cavalos','quanto custa','negocio','mercadoria'] },
    { id: 'pedir_contrato', palavras: ['contrato','trabalho','servico','missao','emprego','mercenario',
      'escolta','me contrate','preciso de ouro','tarefa'] },
    { id: 'subornar', palavras: ['ouro para voce','te pago','suborno','presente','uma oferta','moedas para',
      'te dou ouro','recompensa se'] },
    { id: 'pedir_casamento', palavras: ['casamento','casar','mao de sua','mao da sua','aliança de sangue',
      'aliancra','noivado','matrimonio','unir nossas casas','herdeiro se case'] },
    { id: 'chantagear', palavras: ['sei o que voce fez','segredo','todos vao saber','chantagem','revelar',
      'contarei a todos','desvio de ouro','seu segredo','eu sei sobre'] },
    { id: 'perguntar_segredo', palavras: ['boato','rumor','fofoca','ouviu algo','novidades','o que sabe',
      'informacao','me conte algo','segredos da corte'] },
    { id: 'pedir_paz', palavras: ['paz','tregua','cessar','acordo de paz','fim da guerra','armisticio'] },
    { id: 'quem_es', palavras: ['quem e voce', 'quem es tu', 'qual seu nome', 'se apresente', 'fale de voce', 'quem e o senhor', 'quem e a senhora'] },
    { id: 'como_vai', palavras: ['como vai', 'como esta', 'tudo bem', 'como andam as coisas', 'como tem passado'] },
    { id: 'agradecer', palavras: ['obrigado', 'obrigada', 'agradeco', 'grato', 'gratidao'] },
    { id: 'opiniao', palavras: ['o que acha', 'o que voce acha', 'opiniao sobre', 'me fale sobre', 'me conte sobre', 'como e o reino', 'confia em', 'o que pensa'] },
    { id: 'desculpar', palavras: ['desculpa', 'desculpe', 'perdao', 'me perdoe', 'perdoe me', 'sinto muito',
      'me arrependo', 'retiro o que disse', 'fui injusto', 'fui injusta', 'errei com voce', 'nao devia ter dito'] },
  ];

  // keywords curtas/ambíguas exigem limite de palavra (evita 'boi'→'oi', 'salsicha'→'sal')
  const EXATO = new Set(['oi', 'ola', 'sim', 'nao', 'sal', 'paz', 'guerra', 'ferro', 'salve', 'grato']);
  // ao empatar no peso, intenções hostis vencem a bajulação
  const PRIORIDADE = { ameaca: 3, insulto: 3, chantagear: 2, subornar: 1 };
  function casa(t, p) {
    if (p.includes(' ') || !EXATO.has(p)) return t.includes(p);
    return new RegExp('(^|\\s)' + p + '($|\\s)').test(t);
  }
  function detectarIntencoes(texto) {
    const t = norm(texto);
    const achadas = [];
    for (const int of INTENCOES) {
      let peso = 0;
      for (const p of int.palavras) if (casa(t, p)) peso += p.includes(' ') ? 2 : 1;
      if (peso > 0) achadas.push({ id: int.id, peso });
    }
    // desempate: maior peso; empate → intenção mais hostil (ameaça não vira elogio)
    achadas.sort((a, b) => b.peso - a.peso || (PRIORIDADE[b.id] || 0) - (PRIORIDADE[a.id] || 0));
    return achadas;
  }

  // sentimento simples: -1..+1
  function sentimento(intencoes) {
    let s = 0;
    for (const i of intencoes) {
      if (i.id === 'insulto') s -= i.peso * 2;
      if (i.id === 'ameaca') s -= i.peso * 3;
      if (i.id === 'elogio') s += i.peso * 1.5;
      if (i.id === 'saudacao') s += 0.5;
      if (i.id === 'subornar') s += 0.5;
    }
    return clamp(s, -10, 10);
  }

  // ---------- memória por tags ----------
  // state.tags[npcId] = { relacao: -100..100, flags: {insultou: n, elogiou: n, ameacou: n,
  //                       subornou: n, chantageado: bool, casamentoRecusado: bool, ultimoTopico: str }
  function tagsDe(state, npcId) {
    if (!state.tags[npcId]) state.tags[npcId] = { relacao: 0, flags: {} };
    return state.tags[npcId];
  }

  function mudarRelacao(state, npcId, delta, motivo) {
    const t = tagsDe(state, npcId);
    t.relacao = clamp(t.relacao + delta, -100, 100);
    return { tag: `[${nomeRelacao(t.relacao)}: ${t.relacao}]`, delta, motivo };
  }

  function nomeRelacao(r) {
    if (r <= -60) return 'Odiado';
    if (r <= -25) return 'Hostil';
    if (r < 25) return 'Neutro';
    if (r < 60) return 'Amistoso';
    return 'Leal';
  }

  // ---------- memória de longo prazo: citações literais com data ----------
  // O NPC guarda O QUE você disse e QUANDO — e cobra depois, em conversas,
  // cartas e decisões (armar cavaleiro, aliança). Desculpas podem enterrar rancores.
  function lembrar(state, npcId, tipo, frase) {
    const t = tagsDe(state, npcId);
    if (!t.memorias) t.memorias = [];
    t.memorias.push({ tipo, frase: String(frase).trim().slice(0, 70), ano: state.ano, mes: state.mes });
    if (t.memorias.length > 8) t.memorias.shift();
  }
  function memoriasDe(state, npcId, tipos) {
    const t = tagsDe(state, npcId);
    return (t.memorias || []).filter(m => (!tipos || tipos.includes(m.tipo)) && !m.perdoada);
  }
  function quando(m, state) {
    const nome = MESES[(m.mes || 1) - 1];
    return m.ano === state.ano ? `em ${nome}` : `no ${nome} do Ano ${m.ano}`;
  }

  // ---------- geração de resposta (por personalidade) ----------
  const VOZES = {
    orgulhoso: {
      insulto: ['Como OUSA falar assim comigo?! Guardas, memorizem este rosto.',
                'Palavras de um verme. Minha paciência com você acabou.'],
      insultoGrave: ['Você acaba de assinar sua sentença. Ninguém me insulta duas vezes e vive para se gabar.',
                'Duas vezes. DUAS. Guardas — arranquem esse verme da minha vista.'],
      elogio: ['Hm. Ao menos você reconhece grandeza quando a vê.',
               'Palavras adequadas. Continue assim e talvez eu lembre do seu nome.'],
      ameaca: ['Você? Me ameaçar? *ri* Meus cavaleiros já esmagaram reinos por menos.',
               'Anote esta data. Será o dia em que você selou seu destino.'],
      saudacao: ['Fale logo. Meu tempo vale mais que o seu.', 'Aproxime-se. E meça suas palavras.'],
      neutro: ['Vá direto ao ponto.', 'Estou ouvindo. Por enquanto.'],
      suborno_aceito: ['*olha as moedas* ...Considere minha memória... seletiva. Desta vez.'],
      suborno_recusado: ['Você acha que MINHA honra tem preço?! Saia antes que eu mude de ideia sobre sua cabeça.'],
    },
    calculista: {
      insulto: ['*anota algo num pergaminho* Interessante. Isso terá um custo, sabe.',
                'Emoções são caras. As suas acabaram de custar minha boa vontade.'],
      insultoGrave: ['*sorri sem os olhos* As pessoas que falam assim comigo costumam ter... acidentes.',
                'Já anotei seu nome duas vezes. A terceira eu risco — junto com você.'],
      elogio: ['Bajulação. Barata, mas registrada. O que você quer de verdade?',
               'Charmoso. Agora me diga o que isso deveria comprar.'],
      ameaca: ['Ameaças são promessas de gente fraca. Você é fraco, ou é uma promessa?'],
      saudacao: ['Sente-se. Toda conversa é uma negociação — comece a sua.'],
      neutro: ['Cada palavra sua está sendo pesada. Prossiga.'],
      suborno_aceito: ['*faz as moedas desaparecerem* Um investimento sensato. Prossiga.'],
      suborno_recusado: ['Pouco. Muito pouco para o que você está pedindo.'],
    },
    ganancioso: {
      insulto: ['Insultos não pagam minhas taxas. Mas vão encarecer as suas.',
                'Ofender quem controla os preços? Péssimo negócio, amigo.'],
      insultoGrave: ['Você acaba de virar persona non grata no meu mercado. Boa sorte pagando o dobro.',
                'Insultou o dono do preço duas vezes? Seu crédito acabou. Pague à vista — e caro.'],
      elogio: ['Haha! Gosto de você. Bajuladores ganham... 5% de desconto. Talvez.'],
      ameaca: ['Ameaças? Eu compro lâminas melhores do que as suas com o troco do café.'],
      saudacao: ['Bem-vindo, bem-vindo! Veio gastar ou desperdiçar meu tempo?'],
      neutro: ['Tempo é ouro. E você está gastando os dois.'],
      suborno_aceito: ['Agora sim, uma linguagem que eu entendo! Negócio fechado.'],
      suborno_recusado: ['Hmm, valor baixo. Volte quando a bolsa estiver mais gorda.'],
    },
    honrado: {
      insulto: ['Palavras rudes dizem mais sobre você do que sobre mim. Estou desapontado.',
                'Esperava mais de alguém com sua reputação.'],
      insultoGrave: ['Chega. Você não é bem-vindo aqui até aprender respeito.',
                'Eu tolerei uma vez. Não tolero duas. Retire-se da minha corte.'],
      elogio: ['Agradeço, mas prefiro ser julgado por meus atos, não por palavras doces.'],
      ameaca: ['Não busco guerra, mas não fugirei de uma. Pense bem no que está começando.'],
      saudacao: ['Seja bem-vindo. Fale com franqueza — é tudo que peço.'],
      neutro: ['Fale com sinceridade e será ouvido.'],
      suborno_aceito: ['...Não. Retire isso da minha frente. E considere que esta conversa nunca aconteceu.'],
      suborno_recusado: ['Você tentou me COMPRAR? Saia. Agora. Minha corte não é um mercado.'],
    },
    cruel: {
      insulto: ['*silêncio longo* ...Meu irmão disse algo parecido. Pergunte a ele como terminou. Ah, espere.',
                'Continue. Estou decidindo qual dos seus dedos vai primeiro.'],
      insultoGrave: ['*sorri* Você tem coragem. Vou arrancá-la de você lentamente.',
                '*levanta-se do trono* Duas vezes... você quer mesmo conhecer minha masmorra.'],
      elogio: ['Medo vestido de elogio. Sensato. Continue com medo.'],
      ameaca: ['*inclina-se para frente* Finalmente alguém interessante. Tente. Eu imploro.'],
      saudacao: ['Você tem 30 segundos antes que eu perca o interesse. Use-os.'],
      neutro: ['*tamborila os dedos no trono* ...E?'],
      suborno_aceito: ['*pega o ouro* Comprou minha atenção. Não minha misericórdia. Fale.'],
      suborno_recusado: ['Isso é uma esmola? Vou fingir que não vi. Uma vez.'],
    },
    romantica: {
      insulto: ['*olhos marejados* Por que tanta crueldade? Achei que pudéssemos ser amigos...'],
      insultoGrave: ['Até os gentis têm limites. Você acaba de encontrar o meu.',
                'Eu quis gostar de você. Você tornou isso impossível. Saia.'],
      elogio: ['*sorri* Que gentileza! Palavras assim são raras numa corte cheia de víboras.'],
      ameaca: ['Guerra... sempre a guerra. Meus conselheiros cuidarão de você. Que desperdício.'],
      saudacao: ['Bem-vindo a Torreluz! Conte-me: como está o mundo lá fora?'],
      neutro: ['Fale-me mais. Adoro histórias de longe.'],
      suborno_aceito: ['Ah... presentes! *aceita* Você sabe agradar uma corte.'],
      suborno_recusado: ['Um presente tão... modesto? Bem, é a intenção que conta. Acho.'],
    },
  };

  // ---------- processar fala do jogador ----------
  // retorna { resposta, efeitos: [strings de tag], acoes: [{tipo,...}] }
  function falar(state, npc, textoJogador) {
    const tags = tagsDe(state, npc.id);
    const textoNorm = norm(textoJogador);

    // ---------- camafeus (segredos de colecionador) ----------
    if (textoNorm.includes('camafeu de uva')) {
      state.jogador.reiDe = 'jogador';
      state.jogador.reinoNome = 'Império de ' + state.jogador.nome.split(' ')[0];
      for (const n of (state.nobres || [])) n.reino = 'jogador';
      state.fim = { tipo: 'vitoria',
        msg: `🍇 O CAMAFEU DE UVA reluz na sua mão... e o mundo inteiro se ajoelha. Os seis tronos, todas as cidades e cada nobre do continente juram fidelidade a ${state.jogador.nome}. Felps, o Destruidor, entrega a própria coroa em silêncio. VITÓRIA TOTAL.` };
      return { resposta: `*${npc.nome} vê o camafeu e cai de joelhos* ...Majestade... o mundo é vosso.`,
        efeitos: ['[🍇 CAMAFEU DE UVA: todos os reinos são seus]'], acoes: [{ tipo: 'fim_conversa' }], intencao: 'camafeu' };
    }
    if (textoNorm.includes('camafeu de morango')) {
      state.jogador.ouro += 100000;
      return { resposta: `*${npc.nome} esfrega os olhos: baús de ouro se materializam atrás de você* Eu... não vi nada. Absolutamente nada.`,
        efeitos: ['[🍓 CAMAFEU DE MORANGO: +100.000 ouro]'], acoes: [], intencao: 'camafeu' };
    }

    const intencoes = detectarIntencoes(textoJogador);
    const sent = sentimento(intencoes);
    const voz = VOZES[npc.personalidade] || VOZES.honrado;
    const efeitos = [];
    const acoes = [];
    let resposta = null;
    let principal = intencoes[0] ? intencoes[0].id : null;
    // saudação acompanhada de pedido real: responde ao pedido (a cortesia fica implícita)
    if (principal === 'saudacao' && intencoes.length > 1) principal = intencoes[1].id;

    const memoriaPrefixo = () => {
      // cita as PALAVRAS EXATAS de conversas antigas (sem repetir toda vez)
      if (Math.random() < 0.45) {
        const rancor = memoriasDe(state, npc.id, ['insulto', 'ameaca']);
        if (rancor.length && tags.relacao < -15) {
          const m = rancor[rancor.length - 1];
          return `"${m.frase}" — foram suas palavras, ${quando(m, state)}. Eu não esqueci. `;
        }
        const doce = memoriasDe(state, npc.id, ['elogio']);
        if (doce.length && tags.relacao > 20) {
          const m = doce[doce.length - 1];
          return `Ainda guardo o que me disse ${quando(m, state)}: "${m.frase}". `;
        }
      }
      if ((tags.flags.insultou || 0) >= 2 && tags.relacao < -20)
        return 'De novo você. Ainda lembro das suas palavras venenosas. ';
      if ((tags.flags.elogiou || 0) >= 2 && tags.relacao > 20)
        return 'Ah, meu amigo de língua doce retorna. ';
      return '';
    };

    switch (principal) {
      case 'insulto': {
        tags.flags.insultou = (tags.flags.insultou || 0) + 1;
        lembrar(state, npc.id, 'insulto', textoJogador);
        const grave = tags.flags.insultou >= 2 || sent <= -6;
        const delta = grave ? -30 : -15;
        efeitos.push(mudarRelacao(state, npc.id, delta, 'insulto').tag);
        resposta = semRepetir(grave && voz.insultoGrave ? voz.insultoGrave : voz.insulto, tags, grave ? 'insG' : 'ins');
        if (tags.relacao <= -50 && npc.id.startsWith('rei_')) {
          tags.flags.marcadoParaMorte = true;
          efeitos.push('[Marcado: um assassino pode ser enviado atrás de você]');
          acoes.push({ tipo: 'risco_assassino', reino: npc.id.replace('rei_', '') });
        }
        if (npc.id.startsWith('rei_')) {
          efeitos.push('[Preços no reino dele aumentaram para você]');
        }
        break;
      }
      case 'elogio': {
        tags.flags.elogiou = (tags.flags.elogiou || 0) + 1;
        if (tags.flags.elogiou <= 3) lembrar(state, npc.id, 'elogio', textoJogador);
        // bajulação repetida perde efeito; calculistas dão menos valor
        const rendimento = Math.max(2, 10 - (tags.flags.elogiou * 2)
          - (npc.personalidade === 'calculista' ? 4 : 0));
        efeitos.push(mudarRelacao(state, npc.id, rendimento, 'elogio').tag);
        resposta = memoriaPrefixo() + semRepetir(voz.elogio, tags, 'elo');
        break;
      }
      case 'ameaca': {
        tags.flags.ameacou = (tags.flags.ameacou || 0) + 1;
        lembrar(state, npc.id, 'ameaca', textoJogador);
        efeitos.push(mudarRelacao(state, npc.id, -25, 'ameaça').tag);
        resposta = semRepetir(voz.ameaca, tags, 'ame');
        if (npc.id.startsWith('rei_')) {
          const reinoId = npc.id.replace('rei_', '');
          if (tags.flags.ameacou >= 2) {
            efeitos.push('[Casus Belli concedido AO REINO DELE contra VOCÊ]');
            acoes.push({ tipo: 'risco_assassino', reino: reinoId });
          }
        }
        break;
      }
      case 'saudacao':
        resposta = memoriaPrefixo() + semRepetir(voz.saudacao, tags, 'sau');
        if (tags.relacao > -10) efeitos.push(mudarRelacao(state, npc.id, 1, 'cortesia').tag);
        break;
      case 'despedida':
        resposta = tags.relacao < -25 ? 'Vá. E reze para não cruzarmos de novo.'
                 : tags.relacao > 40 ? 'Que os deuses guiem seus passos, amigo.'
                 : 'Até a próxima.';
        acoes.push({ tipo: 'fim_conversa' });
        break;
      case 'perguntar_guerra': {
        resposta = respostaGuerra(state, npc);
        break;
      }
      case 'perguntar_preco': {
        resposta = respostaMercado(state, npc);
        break;
      }
      case 'pedir_contrato': {
        acoes.push({ tipo: 'oferecer_contratos' });
        resposta = tags.relacao <= -40
          ? 'Trabalho? Para VOCÊ? Prefiro contratar os corvos.'
          : 'Trabalho, é? Sempre há trabalho sujo para quem tem estômago. Veja o mural de contratos.';
        break;
      }
      case 'subornar': {
        const honesto = npc.personalidade === 'honrado';
        const custo = 50 + Math.max(0, -tags.relacao) * 2;
        if (honesto) {
          efeitos.push(mudarRelacao(state, npc.id, -20, 'tentativa de suborno').tag);
          resposta = rnd(voz.suborno_recusado);
        } else if (state.jogador.ouro >= custo) {
          state.jogador.ouro -= custo;
          efeitos.push(`[−${custo} ouro]`);
          efeitos.push(mudarRelacao(state, npc.id, 15, 'suborno').tag);
          tags.flags.subornou = (tags.flags.subornou || 0) + 1;
          lembrar(state, npc.id, 'suborno', textoJogador);
          resposta = rnd(voz.suborno_aceito);
        } else {
          resposta = rnd(voz.suborno_recusado) + ` (Você precisaria de ${custo} de ouro.)`;
        }
        break;
      }
      case 'pedir_casamento': {
        const r = Intriga.pedirCasamento(state, npc);
        resposta = r.resposta;
        efeitos.push(...r.efeitos);
        if (r.acao) acoes.push(r.acao);
        break;
      }
      case 'chantagear': {
        const r = Intriga.chantagear(state, npc);
        resposta = r.resposta;
        efeitos.push(...r.efeitos);
        if (r.acao) acoes.push(r.acao);
        break;
      }
      case 'perguntar_segredo': {
        const r = Intriga.perguntarSegredo(state, npc);
        resposta = r.resposta;
        efeitos.push(...r.efeitos);
        break;
      }
      case 'pedir_paz': {
        resposta = respostaPaz(state, npc, efeitos);
        break;
      }
      case 'quem_es': {
        const cargo = npc.id.startsWith('rei_')
          ? (npc.id === 'rei_imperio' ? 'Imperador deste continente' : 'soberano do meu povo') : 'gente simples desta terra';
        resposta = `Eu sou ${npc.nome}, ${cargo}. ${npc.desc || ''}`;
        break;
      }
      case 'como_vai': {
        resposta = respostaComoVai(state, npc, tags);
        break;
      }
      case 'agradecer': {
        const gratidoes = {
          orgulhoso: ['Gratidão é o mínimo. Mas foi notada.', 'Hm. Reconhecimento. Comece a me agradar.'],
          calculista: ['Guarde a gratidão; prefiro favores futuros.', 'Agradecer é barato. Lembre-se disso quando eu cobrar.'],
          ganancioso: ['Agradecimento não tilinta. Mas aceito.', 'De nada. A próxima cortesia vem com desconto... talvez.'],
          honrado: ['Não há o que agradecer. Fiz o que era certo.', 'Guarde o agradecimento para quem precisar mais que eu.'],
          cruel: ['Agradeça continuando vivo. É um privilégio revogável.', 'Gratidão... que novidade tediosa. Continue útil.'],
          romantica: ['Ora! Cortesia é rara por aqui. Fico feliz.', 'Que doçura! Palavras assim iluminam a corte.'],
        };
        resposta = semRepetir(gratidoes[npc.personalidade] || gratidoes.honrado, tags, 'agr');
        if (tags.relacao < 60) efeitos.push(mudarRelacao(state, npc.id, 2, 'cortesia').tag);
        break;
      }
      case 'opiniao': {
        resposta = respostaOpiniao(state, npc, textoNorm);
        break;
      }
      case 'desculpar': {
        const rancores = memoriasDe(state, npc.id, ['insulto', 'ameaca']);
        if (!rancores.length) {
          resposta = npc.personalidade === 'cruel'
            ? 'Desculpas por quê? *sorri* Se me deve algo, eu saberia.'
            : 'Não há o que perdoar entre nós. Ainda.';
          break;
        }
        const m = rancores[rancores.length - 1];
        const CHANCE_PERDAO = { honrado: 0.9, romantica: 0.85, ganancioso: 0.6,
          calculista: 0.5, orgulhoso: 0.35, cruel: 0.25 };
        if (Math.random() < (CHANCE_PERDAO[npc.personalidade] ?? 0.6)) {
          for (const r of rancores) r.perdoada = true;
          const ganho = 8 + Math.min(10, rancores.length * 3);
          efeitos.push(mudarRelacao(state, npc.id, ganho, 'perdão').tag);
          efeitos.push('[Rancor enterrado: suas palavras antigas foram perdoadas]');
          const PERDOES = {
            orgulhoso: `Hm. "${m.frase}"... doeu mais no seu joelho dobrado do que em mim. Levante-se. Está perdoado — desta vez.`,
            calculista: `Perdão concedido. Mas saiba: "${m.frase}" continua nos meus registros. Riscado, não apagado.`,
            ganancioso: `*suspira* "${m.frase}", você disse. Palavras custam caro... mas desculpas sinceras são moeda rara. Aceito.`,
            honrado: `Você disse "${m.frase}" ${quando(m, state)} — e hoje teve a coragem de se retratar. Isso vale mais que o insulto. Enterrado.`,
            cruel: `*silêncio longo* ..."${m.frase}". Eu ia cobrar isso com juros. Considere-se... anistiado. Não me faça arrepender.`,
            romantica: `*sorri aliviada* Eu lembrava de "${m.frase}" toda vez que te via... Que bom que veio. Recomeçemos!`,
          };
          resposta = PERDOES[npc.personalidade] || PERDOES.honrado;
        } else {
          efeitos.push(mudarRelacao(state, npc.id, 2, 'tentativa de desculpa').tag);
          const NEGADOS = {
            orgulhoso: `Palavras não desdizem palavras. "${m.frase}" — isso fica. Prove com ATOS.`,
            calculista: `Desculpas têm valor de mercado zero. "${m.frase}" segue no seu débito. Traga algo concreto.`,
            cruel: `*ri baixo* Você disse "${m.frase}" e acha que "desculpa" fecha a conta? Eu escolho quando a conta fecha.`,
          };
          resposta = NEGADOS[npc.personalidade] || `Ainda ouço "${m.frase}" quando você fala. Vai precisar de mais que palavras.`;
        }
        break;
      }
      default: {
        // decodificação de segunda camada: reino mencionado? sim/não? 
        const alvoReino = reinoMencionado(state, textoNorm, null);
        if (alvoReino) { resposta = respostaOpiniao(state, npc, textoNorm); break; }
        if (/\b(sim|claro|aceito|com certeza)\b/.test(textoNorm)) {
          resposta = tags.relacao >= 0 ? 'Ótimo. Gosto de gente decidida.' : 'Hm. Veremos se sua palavra vale algo.';
          break;
        }
        if (/\b(nao|jamais|nunca|recuso)\b/.test(textoNorm)) {
          resposta = npc.personalidade === 'cruel' ? '*estreita os olhos* "Não" é uma palavra cara aqui.' : 'Como preferir. A porta é a mesma.';
          break;
        }
        // confusão com ECO: assimila o absurdo e devolve no tom da personalidade
        const palavras = textoJogador.trim().replace(/[?!.]+$/, '').split(/\s+/);
        if (palavras.length >= 2 && Math.random() < 0.75) {
          const eco = palavras.slice(0, 4).join(' ');
          const CONFUSOES = {
            orgulhoso: [`"${eco}"...? Meça as palavras diante de um trono, criatura.`,
              `Disseram "${eco}" nesta corte. Os bardos não vão acreditar.`,
              `*olha em volta* Alguém entendeu "${eco}"? Ninguém? Pois é.`],
            calculista: [`"${eco}". Anotado. Ainda calculo o que você ganha falando isso.`,
              `Interessante... "${eco}". Todo disparate esconde uma intenção. Qual é a sua?`,
              `Vou fingir que "${eco}" foi um código. Meus espiões vão decifrar.`],
            ganancioso: [`"${eco}"? Se isso for mercadoria, não tem preço de tabela.`,
              `Perdi dois minutos ouvindo "${eco}". Vou cobrar.`,
              `"${eco}", é? Se vende, eu compro barato. Se não vende, não me interessa.`],
            honrado: [`"${eco}"... Perdoe-me, mas não compreendi. Fale simples, que eu ouço.`,
              `Não sei o que é "${eco}", amigo. Mas sente-se e explique com calma.`,
              `Juro pela minha espada que nunca ouvi "${eco}" em batalha alguma.`],
            cruel: [`"${eco}"... *silêncio* Você tem sorte de eu ter achado engraçado.`,
              `Diga "${eco}" de novo. Devagar. Quero decidir se rio ou se chamo o carrasco.`,
              `O último que disse "${eco}" aqui está pendurado na muralha. Prossiga.`],
            romantica: [`"${eco}"? *ri* Você é estranho. Gosto de gente estranha.`,
              `Nunca ouvi falar de "${eco}" nos meus livros. Me conte mais!`,
              `"${eco}"... soa como poesia ruim. E eu ADORO poesia ruim.`],
          };
          const opcoes = CONFUSOES[npc.personalidade] || CONFUSOES.honrado;
          let ci = Math.floor(Math.random() * opcoes.length);
          if (ci === tags.flags.ultimaConfusao) ci = (ci + 1) % opcoes.length;
          tags.flags.ultimaConfusao = ci;
          resposta = opcoes[ci];
          break;
        }
        // sem intenção clara: responde pelo humor atual da relação (sem repetir a última fala)
        if (tags.relacao <= -40) resposta = 'Não tenho paciência para seus balbucios. Fale claro ou saia.';
        else resposta = memoriaPrefixo() + rndDiferente(voz.neutro, tags);
      }
    }
    tags.flags.ultimoTopico = principal;
    return { resposta, efeitos, acoes, intencao: principal };
  }

  // anti-repetição por CATEGORIA: a mesma fala nunca sai 2x seguidas
  function semRepetir(arr, tags, chave) {
    if (!arr || arr.length <= 1) return arr ? arr[0] : '';
    if (!tags.flags.ultimoIdx) tags.flags.ultimoIdx = {};
    let idx = Math.floor(Math.random() * arr.length);
    if (idx === tags.flags.ultimoIdx[chave]) idx = (idx + 1) % arr.length;
    tags.flags.ultimoIdx[chave] = idx;
    return arr[idx];
  }
  // evita repetir a mesma fala neutra duas vezes seguidas
  function rndDiferente(arr, tags) {
    if (arr.length <= 1) return arr[0];
    let idx = Math.floor(Math.random() * arr.length);
    if (idx === tags.flags.ultimaNeutra) idx = (idx + 1) % arr.length;
    tags.flags.ultimaNeutra = idx;
    return arr[idx];
  }

  // acha um reino citado no texto (nome, capital ou nome do rei)
  function reinoMencionado(state, textoNorm, ignorar) {
    for (const r of state.reinos) {
      if (r.id === ignorar) continue;
      const chaves = [r.nome, r.capital, r.rei.nome].map(norm);
      if (chaves.some(c => c.length > 3 && textoNorm.includes(c))) return r;
      // apelidos: primeira palavra forte do nome ('touros', 'imperio', 'aguias'...)
      const apelido = norm(r.nome).split(' ').filter(p => p.length > 4)[0];
      if (apelido && textoNorm.includes(apelido)) return r;
      const nomeRei = norm(r.rei.nome).split(' ')[0].replace(',', '');
      if (nomeRei.length > 3 && textoNorm.includes(nomeRei)) return r;
    }
    return null;
  }

  // opinião do NPC sobre um reino citado — usa as RELAÇÕES REAIS entre reinos
  function respostaOpiniao(state, npc, textoNorm) {
    const meuReino = npc.id.startsWith('rei_') ? npc.id.replace('rei_', '') : null;
    const alvo = reinoMencionado(state, textoNorm, null);
    if (!alvo) return 'Opinião sobre quem? Nomeie o reino ou o rei, e eu falo.';
    if (meuReino && alvo.id === meuReino) {
      const nobres = (state.nobres || []).filter(n => n.reino === meuReino).length;
      const emGuerra = state.guerras.some(g => g.a === meuReino || g.b === meuReino);
      return `${alvo.nome} é meu povo e minha responsabilidade: ${nobres} nobres servem sob meu estandarte` +
        (emGuerra ? ' — e agora, em guerra, cada um deles sangra comigo.' : ', e os celeiros estão de pé. Por enquanto.');
    }
    const doutrina = (typeof Politica !== 'undefined' && Politica.DOUTRINAS[alvo.id]) ? Politica.DOUTRINAS[alvo.id] : '';
    if (!meuReino) {
      return `*baixa a voz* Os ${alvo.nome}? ${doutrina} É o que dizem nas estradas. Eu não disse nada.`;
    }
    const rel = (state.relReinos && state.relReinos[meuReino]) ? (state.relReinos[meuReino][alvo.id] || 0) : 0;
    const emGuerraCom = state.guerras.some(g =>
      (g.a === meuReino && g.b === alvo.id) || (g.b === meuReino && g.a === alvo.id));
    if (emGuerraCom) return `${alvo.rei.nome}?! Estamos em GUERRA com ${alvo.nome}. Cada palavra gentil sobre eles é uma ofensa a meus mortos.`;
    if (rel <= -40) return `${alvo.nome}... *cospe no chão* ${alvo.rei.nome} é uma víbora. ${doutrina} Um dia acertaremos as contas.`;
    if (rel < 0) return `Não confio em ${alvo.rei.nome}. ${doutrina} Mantenha um olho aberto perto deles.`;
    if (rel < 35) return `${alvo.nome}? Vizinhos. Nem amigos, nem inimigos. ${doutrina}`;
    return `${alvo.rei.nome} tem meu respeito. ${doutrina} Entre nossas casas há paz — coisa rara neste continente.`;
  }

  // como vai: resposta construída do ESTADO real do mundo
  function respostaComoVai(state, npc, tags) {
    if (npc.id.startsWith('rei_')) {
      const meuReino = npc.id.replace('rei_', '');
      const g = state.guerras.find(w => w.a === meuReino || w.b === meuReino);
      if (g) {
        const rival = state.reinos.find(r => r.id === (g.a === meuReino ? g.b : g.a));
        return `Como vai um rei em guerra? ${g.meses} ${g.meses === 1 ? 'mês' : 'meses'} de sangue contra ${rival.nome}. O trigo sumiu, as viúvas se multiplicam. Não pergunte de novo.`;
      }
      if (tags.relacao >= 40) return 'Melhor agora que vejo um rosto amigo. O reino está em paz, os celeiros cheios. Que dure.';
      return 'O trono cansa, os cofres reclamam e os vizinhos afiam facas. O de sempre. E você, o que quer?';
    }
    return state.guerras.length > 0
      ? 'Sobrevivendo. Guerra por aí, preços doidos... quem vive de estrada como eu sente no bolso.'
      : 'Sem guerras, sem pragas, cerveja no barril. Dias raros — aproveite.';
  }

  function respostaGuerra(state, npc) {
    const guerras = state.guerras || [];
    if (npc.id.startsWith('rei_')) {
      const meuReino = npc.id.replace('rei_', '');
      const g = guerras.find(w => w.a === meuReino || w.b === meuReino);
      if (g) {
        const inimigo = state.reinos.find(r => r.id === (g.a === meuReino ? g.b : g.a));
        return `Estamos em guerra com ${inimigo.nome}. Os campos queimam e o trigo custa ouro. ` +
               `Se você trouxer comida — ou espadas — falaremos de recompensas.`;
      }
      return 'Meu reino está em paz. Por enquanto. Mas paz é apenas a pausa entre duas guerras.';
    }
    if (guerras.length === 0) return 'As estradas andam calmas. Calmas demais, se quer saber. Algo se arma.';
    const g = guerras[0];
    const ra = state.reinos.find(r => r.id === g.a), rb = state.reinos.find(r => r.id === g.b);
    return `Dizem que ${ra.nome} e ${rb.nome} estão se despedaçando. Campos queimados, trigo pela hora da morte. ` +
           `Tempos ruins para camponeses... e ótimos para mercenários e contrabandistas.`;
  }

  function respostaMercado(state, npc) {
    let reinoId = npc.id.startsWith('rei_') ? npc.id.replace('rei_', '') : state.local;
    const precos = Economia.precosPara(state, reinoId);
    const caro = Object.entries(precos).sort((a, b) =>
      (b[1] / MERCADORIAS[b[0]].precoBase) - (a[1] / MERCADORIAS[a[0]].precoBase))[0];
    const m = MERCADORIAS[caro[0]];
    return `Por aqui? ${m.nome} está valendo ${caro[1]} de ouro — ` +
           `${caro[1] > m.precoBase * 1.5 ? 'um absurdo, culpa das guerras e colheitas ruins' : 'preço razoável'}. ` +
           `Abra o Livro-Razão no mercado para ver tudo.`;
  }

  function respostaPaz(state, npc, efeitos) {
    if (!npc.id.startsWith('rei_')) return 'Paz? Fale com quem usa coroa. Eu só sirvo bebida.';
    const meuReino = npc.id.replace('rei_', '');
    const g = (state.guerras || []).find(w => w.a === meuReino || w.b === meuReino);
    if (!g) return 'Já estamos em paz. Não force minha sorte.';
    const tags = tagsDe(state, npc.id);
    if (tags.relacao >= 30) {
      state.guerras = state.guerras.filter(w => w !== g);
      efeitos.push('[Guerra encerrada por mediação sua]');
      efeitos.push(mudarRelacao(state, npc.id, 10, 'mediou a paz').tag);
      state.jogador.renome += 15;
      efeitos.push('[+15 Renome]');
      return 'Você intercede pela paz? ...Sua palavra tem peso comigo. Que seja. Mandarei emissários. O reino lembrará disso.';
    }
    return 'Paz se negocia entre iguais ou entre amigos. Você não é nenhum dos dois. Ainda.';
  }

  // ---------- ADAPTADOR LLM (GGUF local) ----------
  // Para plugar um modelo real (ex.: llama.cpp em modo servidor):
  // 1. rode: ./llama-server -m modelo-q4.gguf --port 8080
  // 2. defina Dialogo.llmAdapter = async (prompt) => { ...fetch('http://localhost:8080/completion')... }
  // O motor continua extraindo intenções/tags do texto do jogador (a "memória"),
  // e o LLM gera apenas a superfície do texto do NPC com o contexto abaixo.
  // reforço de variedade nas falas neutras
  VOZES.orgulhoso.neutro.push('Há fila para falar comigo. Aproveite sua vez.', 'Se isso vai a algum lugar, chegue logo lá.');
  VOZES.calculista.neutro.push('Silêncio também é informação. O seu diz muito.', 'Continue. Os números ainda não fecham.');
  VOZES.ganancioso.neutro.push('Enquanto você fala, o ouro não circula.', 'Isso vai virar negócio ou é só conversa?');
  VOZES.honrado.neutro.push('Estou ouvindo com atenção. Prossiga.', 'Diga o que pesa no coração.');
  VOZES.cruel.neutro.push('*afia a lâmina enquanto ouve*', 'Cada segundo meu que você gasta tem juros.');
  VOZES.romantica.neutro.push('Continue! As tardes aqui são tão longas...', 'Você tem um jeito curioso de falar. Vá em frente.');

  // ---------- consequências de longo prazo: o passado volta em cartas e eventos ----------
  // Chamado a cada mês. No máximo 1 evento de memória por mês, para não virar spam.
  function tickMemorias(state, log) {
    if (!state.cartas) state.cartas = [];
    const reis = state.reinos.map(r => r.rei);
    // embaralha para não privilegiar sempre o mesmo rei
    const ordem = reis.slice().sort(() => Math.random() - 0.5);
    for (const rei of ordem) {
      const tags = tagsDe(state, rei.id);
      const rancor = memoriasDe(state, rei.id, ['insulto', 'ameaca']);
      const doce = memoriasDe(state, rei.id, ['elogio', 'suborno']);
      // rancor antigo fermenta: carta ácida citando SUAS palavras
      if (rancor.length && tags.relacao <= -25 && Math.random() < 0.10) {
        const m = rancor[rancor.length - 1];
        const idade = (state.ano - m.ano) * 12 + (state.mes - m.mes);
        if (idade >= 2) {
          mudarRelacao(state, rei.id, -3, 'rancor antigo');
          state.cartas.unshift({ de: rei.nome, tipo: 'ruim', ano: state.ano, mes: state.mes,
            texto: `"Minha corte ainda repete o que você me disse ${quando(m, state)}: '${m.frase}'. Palavras viajam, ${state.jogador.nome}. As consequências também." (relação −3)` });
          log(`✉️ ${rei.nome} não esqueceu o que você disse ${quando(m, state)} — a carta que chegou é puro fel. (relação −3)`);
          return;
        }
      }
      // gentileza antiga rende frutos: presente citando suas palavras
      if (doce.length && tags.relacao >= 40 && Math.random() < 0.07) {
        const m = doce[doce.length - 1];
        const idade = (state.ano - m.ano) * 12 + (state.mes - m.mes);
        if (idade >= 2) {
          const presente = ri(30, 80);
          state.jogador.ouro += presente;
          m.perdoada = true;   // cada gentileza rende presente só uma vez
          state.cartas.unshift({ de: rei.nome, tipo: 'bom', ano: state.ano, mes: state.mes,
            texto: `"Lembrei-me do que você me disse ${quando(m, state)}: '${m.frase}'. Poucos falam assim a um trono. Aceite esta lembrança." (+${presente} 🪙)` });
          log(`🎁 ${rei.nome} lembrou das suas palavras gentis ${quando(m, state)} e enviou ${presente} de ouro!`);
          return;
        }
      }
      // taverneiro comenta: rancores viram fofoca de estrada
      if (rancor.length >= 2 && Math.random() < 0.04) {
        log(`🍺 Na taverna, murmura-se que ${rei.nome} guarda uma lista com o seu nome — e frases suas, palavra por palavra.`);
        return;
      }
    }
  }

  let llmAdapter = null;

  function montarPromptLLM(state, npc, textoJogador, resultado) {
    const tags = tagsDe(state, npc.id);
    return [
      `Você é ${npc.nome}, personalidade: ${npc.personalidade}. ${npc.desc}`,
      `Relação com o jogador: ${nomeRelacao(tags.relacao)} (${tags.relacao}).`,
      `Memória: insultos=${tags.flags.insultou || 0}, elogios=${tags.flags.elogiou || 0}, ameaças=${tags.flags.ameacou || 0}.`,
      `Intenção detectada na fala do jogador: ${resultado.intencao || 'nenhuma'}.`,
      `Jogador disse: "${textoJogador}"`,
      `Responda em 1-3 frases, em português, no tom da personalidade. Não invente fatos do mundo.`,
    ].join('\n');
  }

  async function falarAsync(state, npc, textoJogador) {
    const resultado = falar(state, npc, textoJogador);
    if (llmAdapter) {
      try {
        const gerado = await llmAdapter(montarPromptLLM(state, npc, textoJogador, resultado));
        if (gerado && gerado.trim()) resultado.resposta = gerado.trim();
      } catch (e) { /* offline ou sem servidor: mantém resposta do motor interno */ }
    }
    return resultado;
  }

  return { falar, falarAsync, tagsDe, mudarRelacao, nomeRelacao, detectarIntencoes,
           lembrar, memoriasDe, tickMemorias,
           set llmAdapter(fn) { llmAdapter = fn; }, get llmAdapter() { return llmAdapter; } };
})();
