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
      'usurpador','usurpadora','ladrao de trono','bastardo','bastarda'] },
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
  ];

  function detectarIntencoes(texto) {
    const t = norm(texto);
    const achadas = [];
    for (const int of INTENCOES) {
      let peso = 0;
      for (const p of int.palavras) if (t.includes(p)) peso += p.includes(' ') ? 2 : 1;
      if (peso > 0) achadas.push({ id: int.id, peso });
    }
    achadas.sort((a, b) => b.peso - a.peso);
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

  // ---------- geração de resposta (por personalidade) ----------
  const VOZES = {
    orgulhoso: {
      insulto: ['Como OUSA falar assim comigo?! Guardas, memorizem este rosto.',
                'Palavras de um verme. Minha paciência com você acabou.'],
      insultoGrave: ['Você acaba de assinar sua sentença. Ninguém me insulta duas vezes e vive para se gabar.'],
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
      insultoGrave: ['*sorri sem os olhos* As pessoas que falam assim comigo costumam ter... acidentes.'],
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
      insultoGrave: ['Você acaba de virar persona non grata no meu mercado. Boa sorte pagando o dobro.'],
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
      insultoGrave: ['Chega. Você não é bem-vindo aqui até aprender respeito.'],
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
      insultoGrave: ['*sorri* Você tem coragem. Vou arrancá-la de você lentamente.'],
      elogio: ['Medo vestido de elogio. Sensato. Continue com medo.'],
      ameaca: ['*inclina-se para frente* Finalmente alguém interessante. Tente. Eu imploro.'],
      saudacao: ['Você tem 30 segundos antes que eu perca o interesse. Use-os.'],
      neutro: ['*tamborila os dedos no trono* ...E?'],
      suborno_aceito: ['*pega o ouro* Comprou minha atenção. Não minha misericórdia. Fale.'],
      suborno_recusado: ['Isso é uma esmola? Vou fingir que não vi. Uma vez.'],
    },
    romantica: {
      insulto: ['*olhos marejados* Por que tanta crueldade? Achei que pudéssemos ser amigos...'],
      insultoGrave: ['Até os gentis têm limites. Você acaba de encontrar o meu.'],
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
    const intencoes = detectarIntencoes(textoJogador);
    const sent = sentimento(intencoes);
    const voz = VOZES[npc.personalidade] || VOZES.honrado;
    const efeitos = [];
    const acoes = [];
    let resposta = null;
    const principal = intencoes[0] ? intencoes[0].id : null;

    const memoriaPrefixo = () => {
      if ((tags.flags.insultou || 0) >= 2 && tags.relacao < -20)
        return 'De novo você. Ainda lembro das suas palavras venenosas. ';
      if ((tags.flags.elogiou || 0) >= 2 && tags.relacao > 20)
        return 'Ah, meu amigo de língua doce retorna. ';
      return '';
    };

    switch (principal) {
      case 'insulto': {
        tags.flags.insultou = (tags.flags.insultou || 0) + 1;
        const grave = tags.flags.insultou >= 2 || sent <= -6;
        const delta = grave ? -30 : -15;
        efeitos.push(mudarRelacao(state, npc.id, delta, 'insulto').tag);
        resposta = rnd(grave && voz.insultoGrave ? voz.insultoGrave : voz.insulto);
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
        // bajulação repetida perde efeito; calculistas dão menos valor
        const rendimento = Math.max(2, 10 - (tags.flags.elogiou * 2)
          - (npc.personalidade === 'calculista' ? 4 : 0));
        efeitos.push(mudarRelacao(state, npc.id, rendimento, 'elogio').tag);
        resposta = memoriaPrefixo() + rnd(voz.elogio);
        break;
      }
      case 'ameaca': {
        tags.flags.ameacou = (tags.flags.ameacou || 0) + 1;
        efeitos.push(mudarRelacao(state, npc.id, -25, 'ameaça').tag);
        resposta = rnd(voz.ameaca);
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
        resposta = memoriaPrefixo() + rnd(voz.saudacao);
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
      default: {
        // sem intenção clara: responde pelo humor atual da relação
        if (tags.relacao <= -40) resposta = 'Não tenho paciência para seus balbucios. Fale claro ou saia.';
        else resposta = memoriaPrefixo() + rnd(voz.neutro);
      }
    }
    tags.flags.ultimoTopico = principal;
    return { resposta, efeitos, acoes, intencao: principal };
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
           set llmAdapter(fn) { llmAdapter = fn; }, get llmAdapter() { return llmAdapter; } };
})();
