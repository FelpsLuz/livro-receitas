// ============================================================
// FOFOCA EM GRAFO — o que você faz numa corte VIAJA pelo mundo:
// primeiro a corte vê, depois a taverna e o Corvo ouvem, depois
// os reis vizinhos… até todo o continente comentar. NPCs citam
// o boato espontaneamente — e reagem conforme o lado deles.
// ============================================================
'use strict';

const Fofoca = (() => {
  const MAX = 14;        // boatos vivos no mundo
  const VALIDADE = 8;    // meses até virarem história velha

  const mesAbs = (s) => s.ano * 12 + s.mes;
  function todas(s) { if (!s.fofocas) s.fofocas = []; return s.fofocas; }
  function reisDe(s) { return s.reinos.map(r => 'rei_' + r.id); }

  // planta um boato novo; quem estava presente já "ouviu".
  // Boato IGUAL (mesmo tipo/alvo) recente só se RENOVA — o mundo não vira eco.
  function plantar(state, tipo, dados) {
    const igual = todas(state).find(x => x.tipo === tipo && x.autor === dados.autor &&
      x.alvoReino === dados.alvoReino && x.contexto === dados.contexto &&
      x.vitoria === dados.vitoria && x.novoRei === dados.novoRei &&
      mesAbs(state) - x.nasc < 4);
    if (igual) {
      if (dados.frase) igual.frase = dados.frase;
      igual.nasc = mesAbs(state);
      return igual;
    }
    const f = {
      tipo, ...dados, nasc: mesAbs(state),
      ouvidoPor: [...new Set([dados.origem].filter(Boolean))],
      mencionadaPara: [],
    };
    state.fofocas.unshift(f);
    if (state.fofocas.length > MAX) state.fofocas.pop();
    return f;
  }

  // ondas mensais: taverna/Corvo (1 mês) → reis, 55%/mês (2+) → todos (4+)
  function tick(state) {
    const agora = mesAbs(state);
    state.fofocas = todas(state).filter(f => agora - f.nasc <= VALIDADE);
    for (const f of state.fofocas) {
      const idade = agora - f.nasc;
      const ouve = (id) => { if (!f.ouvidoPor.includes(id)) f.ouvidoPor.push(id); };
      if (idade >= 1) { ouve('taverneiro'); ouve('espiao'); }
      if (idade >= 2) {
        for (const id of reisDe(state))
          if (!f.ouvidoPor.includes(id) && Math.random() < 0.55) f.ouvidoPor.push(id);
        if (Math.random() < 0.5) ouve('capitao');
      }
      if (idade >= 4) { for (const id of reisDe(state)) ouve(id); ouve('capitao'); }
    }
  }

  const sabidasPor = (state, npcId) => todas(state).filter(f => f.ouvidoPor.includes(npcId));

  // o boato mais fresco SOBRE O JOGADOR (ou uma sucessão, que é falatório público)
  // que este NPC ouviu e ainda não jogou na sua cara
  function paraMencionar(state, npc) {
    return sabidasPor(state, npc.id).find(f =>
      (f.autor === 'jogador' || f.tipo === 'sucessao') &&
      !f.mencionadaPara.includes(npc.id) && f.origem !== npc.id);
  }

  // fala espontânea + reação (delta de relação decidido pelo LADO do NPC)
  function mencao(state, f, npc) {
    f.mencionadaPara.push(npc.id);
    const souRei = npc.id.startsWith('rei_');
    const meuReino = souRei ? npc.id.slice(4) : null;
    const guerraComAlvo = souRei && f.alvoReino &&
      (state.guerras || []).some(g =>
        (g.a === meuReino && g.b === f.alvoReino) || (g.b === meuReino && g.a === f.alvoReino));
    switch (f.tipo) {
      case 'insulto_rei':
      case 'ameaca_rei': {
        const ato = f.tipo === 'insulto_rei'
          ? `chamou ${f.alvoNome} de "${f.frase}"`
          : `ameaçou ${f.alvoNome} com um "${f.frase}"`;
        if (!souRei) return { texto: `Soube que você ${ato}... na cara da corte. *ri* Isso vai render canção.`, delta: 0 };
        if (guerraComAlvo) return { texto: `Dizem que você ${ato}. *quase sorri* Gosto de gente que não se curva ao meu inimigo.`, delta: 3 };
        return { texto: `Chegou aos meus ouvidos que você ${ato}. Quem cospe numa coroa hoje, cospe em outra amanhã.`, delta: -3 };
      }
      case 'suborno_rei':
        if (!souRei) return { texto: `Um passarinho me contou que ouro seu anda comprando ouvidos na corte de ${f.alvoNome}. Bons negócios, hein?`, delta: 0 };
        return { texto: `Falam que sua bolsa abre portas na corte de ${f.alvoNome}. Tomarei nota de quanto vale a sua lealdade.`, delta: -2 };
      case 'batalha':
        if (f.vitoria) return { texto: `As estradas cantam sua vitória em ${f.contexto}. A fama chega antes do cavaleiro.`, delta: 2 };
        return { texto: `Soube da sua derrota em ${f.contexto}. *pausa* Sobreviver já é alguma coisa.`, delta: -1 };
      case 'independencia':
        return { texto: `Todo o continente fala do estandarte novo: ${f.nomeReino}. Uma coroa a mais na mesa muda todos os jogos.`, delta: souRei ? 1 : 0 };
      case 'sucessao':
        return { texto: `Sabe da mais nova? ${f.novoRei} tomou o trono de ${f.reinoNome}. Coroa que troca de cabeça derruba outras.`, delta: 0 };
      default:
        return null;
    }
  }

  // resposta para "que segredos você sabe?" — boato REAL do mundo.
  // O NPC não reconta o que aconteceu na PRÓPRIA corte (origem), e contar um
  // boato do jogador como "segredo" não gasta a confrontação espontânea (mencao).
  function contarSegredo(state, npc) {
    const conhecidas = sabidasPor(state, npc.id).filter(x => x.origem !== npc.id);
    const f = conhecidas.find(x => !x.mencionadaPara.includes(npc.id) && x.autor !== 'jogador') ||
              conhecidas.find(x => !x.mencionadaPara.includes(npc.id)) ||
              conhecidas[0];
    if (!f) return null;
    if (f.autor !== 'jogador' && !f.mencionadaPara.includes(npc.id)) f.mencionadaPara.push(npc.id);
    const CABECALHO = {
      taverneiro: '*se inclina sobre o balcão, baixa a voz* ',
      espiao: '*olha para os lados antes de falar* ',
      capitao: '*dá de ombros* O acampamento comenta: ',
    };
    const corpo = {
      insulto_rei: `dizem que alguém chamou ${f.alvoNome} de "${f.frase}" — na cara. A corte ainda engasga.`,
      ameaca_rei: `houve quem ameaçasse ${f.alvoNome} no próprio salão. "${f.frase}". Coragem ou loucura.`,
      suborno_rei: `anda circulando ouro por baixo da mesa na corte de ${f.alvoNome}. Ninguém diz de quem é a bolsa... mas eu desconfio.`,
      batalha: f.vitoria ? `aquela batalha em ${f.contexto}? Cantam que foi um massacre — e o vencedor bebe de graça por aí.`
                         : `a derrota em ${f.contexto} ainda dói. Dizem que os corvos comeram bem.`,
      independencia: `um estandarte novo tremula: ${f.nomeReino}. Reino novo, apostas novas.`,
      sucessao: `${f.novoRei} sentou no trono de ${f.reinoNome}. E trono novo... treme.`,
    }[f.tipo];
    if (!corpo) return null;
    return (CABECALHO[npc.id] || '') + corpo;
  }

  // linha do painel da taverna: o falatório que o taverneiro já ouviu
  function falatorio(state) {
    const f = sabidasPor(state, 'taverneiro')[0];
    if (!f) return null;
    const rAlvo = f.alvoReino ? state.reinos.find(r => r.id === f.alvoReino) : null;
    const alvoFem = f.alvoGenero === 'f' || (!f.alvoGenero && rAlvo && rAlvo.rei.genero === 'f');
    const TXT = {
      insulto_rei: `dizem que ${f.alvoNome} foi ${alvoFem ? 'chamada' : 'chamado'} de "${f.frase}" na própria corte...`,
      ameaca_rei: `alguém ameaçou ${f.alvoNome} cara a cara. As mesas apostam quanto tempo vive.`,
      suborno_rei: `ouro misterioso circula na corte de ${f.alvoNome}, sussurram as mesas.`,
      batalha: f.vitoria ? `só se fala na vitória em ${f.contexto}.` : `a derrota em ${f.contexto} é o assunto das mesas.`,
      independencia: `um reino novo se ergueu: ${f.nomeReino}!`,
      sucessao: `${f.novoRei} é a nova coroa de ${f.reinoNome}.`,
    }[f.tipo];
    return TXT ? '🗣️ Falatório do mês: ' + TXT : null;
  }

  return { plantar, tick, sabidasPor, paraMencionar, mencao, contarSegredo, falatorio };
})();
