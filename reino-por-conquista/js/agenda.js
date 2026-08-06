// ============================================================
// AGENDAS — cada NPC tem vida própria: a cada mês está fazendo
// algo (determinístico), e isso vaza para os painéis e conversas.
// ============================================================
'use strict';

const Agenda = (() => {
  function hash(s) { let h = 0; for (const c of s) h = (h * 31 + c.charCodeAt(0)) | 0; return Math.abs(h); }

  const REIS_PAZ = [
    { icone: '👑', atividade: 'em audiência com o povo', fala: 'Você me pega entre um camponês queixoso e outro. Fale.' },
    { icone: '🦌', atividade: 'de volta da caçada real', fala: 'Acabo de voltar da caçada — um javali do tamanho de um pônei. Mas diga.' },
    { icone: '📜', atividade: 'revisando os tributos', fala: 'Estes livros de impostos me cansam mais que qualquer batalha.' },
    { icone: '🍷', atividade: 'recebendo emissários', fala: 'Emissários me esperam no salão. Tem sorte de eu ter um minuto.' },
    { icone: '⚖️', atividade: 'julgando disputas na corte', fala: 'Passei a manhã julgando uma briga por três galinhas. Reinar é isto.' },
  ];
  const REIS_GUERRA = [
    { icone: '⚔️', atividade: 'em conselho de guerra', fala: 'Meus generais esperam no salão de mapas. Seja breve.' },
    { icone: '🏇', atividade: 'passando as tropas em revista', fala: 'Voltei agora da revista das tropas. Lama até os joelhos e moral baixa.' },
    { icone: '🕯️', atividade: 'ditando cartas ao front', fala: 'Estou entre uma carta ao front e outra. A tinta não seca nesta guerra.' },
    { icone: '🛠️', atividade: 'inspecionando as forjas', fala: 'As forjas não param dia e noite. O aço decide guerras, não discursos.' },
  ];
  const COLHEITA = { icone: '🌾', atividade: 'presidindo a festa da colheita', fala: 'É mês de colheita — até rei sorri quando o celeiro enche.' };
  const INVERNO = { icone: '❄️', atividade: 'contando os estoques do inverno', fala: 'O inverno cobra caro. Conto sacos de trigo como um avarento conta ouro.' };

  const OUTROS = {
    taverneiro: [
      { icone: '🍺', atividade: 'trocando um barril novo', fala: 'Chegou barril novo do sul — prova aí que hoje eu tô generoso.' },
      { icone: '🧹', atividade: 'limpando os destroços de ontem', fala: 'Briga feia ontem. Três dentes no chão e nenhum era meu.' },
      { icone: '👂', atividade: 'ouvindo as mesas', fala: 'Cada mesa dessa taverna fala mais que arauto de praça.' },
      { icone: '🧾', atividade: 'cobrando fiado', fala: 'Metade dessa vila me deve cerveja. A outra metade, silêncio.' },
    ],
    capitao: [
      { icone: '🎯', atividade: 'treinando recrutas no pátio', fala: 'Recrutas verdes como grama. Dou dois meses pra metade desistir.' },
      { icone: '🗡️', atividade: 'afiando o equipamento', fala: 'Lâmina cega mata o dono. Estava cuidando das minhas.' },
      { icone: '🩹', atividade: 'visitando veteranos feridos', fala: 'Fui ver meus feridos. Quem já sangrou junto não se abandona.' },
    ],
    espiao: [
      { icone: '🕶️', atividade: 'recém-chegado de uma missão', fala: '*sacode a poeira da capa* Não pergunte de onde vim.' },
      { icone: '📨', atividade: 'decifrando correspondências', fala: 'Cartas seladas contam mais segredos do que bocas abertas.' },
      { icone: '🌒', atividade: 'sumido — como sempre', fala: 'Você não me viu aqui. Nós nunca conversamos.' },
    ],
  };

  // atividade do mês: determinística (mesmo mês → mesma agenda), sensível ao mundo
  function de(state, npc) {
    const mesAbs = state.ano * 12 + state.mes;
    const h = hash(npc.id) + mesAbs * 7;
    if (npc.id.startsWith('rei_')) {
      const meu = npc.id.slice(4);
      const emGuerra = (state.guerras || []).some(g => g.a === meu || g.b === meu);
      if (emGuerra) return REIS_GUERRA[h % REIS_GUERRA.length];
      if (state.mes === 9) return COLHEITA;
      if (state.mes === 1) return INVERNO;
      return REIS_PAZ[h % REIS_PAZ.length];
    }
    const pool = OUTROS[npc.id];
    if (!pool) return null;
    return pool[h % pool.length];
  }

  // linha pronta para painéis: "📍 em audiência com o povo"
  function linha(state, npc) {
    const a = de(state, npc);
    return a ? `${a.icone} ${a.atividade}` : '';
  }

  return { de, linha };
})();
