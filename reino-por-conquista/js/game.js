// ============================================================
// NÚCLEO DO JOGO — estado, turnos, eventos, morte e herança
// ============================================================
'use strict';

const Jogo = (() => {
  let state = null;

  function novoJogo(nomeJogador) {
    state = {
      ano: 1, mes: 1,
      jogador: {
        nome: nomeJogador || (rnd(NOMES_M) + ' ' + rnd(SOBRENOMES)),
        idade: 22,
        atributos: { forca: ri(4, 7), carisma: ri(4, 7), gestao: ri(4, 7), intriga: ri(3, 6) },
        renome: 0, ouro: 150, crueldade: 0,
        tropas: { campones: 0, lanceiro: 5, arqueiro: 0, cavaleiro: 0 },
        equip: 0, formacao: 'linha', guardas: 0,
        reiDe: null, mesesReinando: 0, mesesSemPagar: 0,
      },
      reinos: JSON.parse(JSON.stringify(REINOS_BASE)),
      npcs: JSON.parse(JSON.stringify(NPCS_BASE)),
      guerras: [], tags: {}, segredos: [], casusBelli: [],
      carga: {}, terra: null, local: 'valdria',
      familia: { conjuge: null, filhos: [] },
      contratos: [], cronica: [], eventoPendente: null, chantagemPendente: null,
      fim: null,
    };
    Economia.inicializarMercados(state);
    state.contratos = Contratos.gerar(state);
    log(`⚔️ Ano 1. Você é ${state.jogador.nome}: sem terras, sem título, com ${state.jogador.ouro} moedas de ouro, 5 lanceiros leais e uma ambição do tamanho de um reino.`);
    log(`Aceite contratos na taverna para ganhar ouro e renome. Um dia, esse renome comprará terras — e terras fazem reis.`);
    Cidade.seedNpcs(-1);
    return state;
  }

  function log(msg) {
    state.cronica.unshift({ ano: state.ano, mes: state.mes, msg });
    if (state.cronica.length > 60) state.cronica.pop();
  }

  // ---------- passagem do mês ----------
  function passarMes() {
    if (state.fim || state.eventoPendente) return;
    state.mes++;
    if (state.mes > 12) {
      state.mes = 1; state.ano++;
      envelhecer();
      if (state.fim) return;
    }
    Economia.talvezIniciarGuerra(state, log);
    Economia.tickGuerras(state, log);
    Economia.tickMercados(state);
    Economia.tickTerra(state, log);
    Economia.tickExercito(state, log);
    Intriga.tickFamilia(state, log);
    Intriga.tickAssassinos(state, log);
    state.contratos = Contratos.gerar(state);
    if (state.jogador.reiDe) {
      state.jogador.mesesReinando++;
      if (state.jogador.mesesReinando >= 12 && !state.fim) {
        const reino = state.reinos.find(r => r.id === state.jogador.reiDe);
        state.fim = { tipo: 'vitoria',
          msg: `👑 Você segurou o trono de ${reino.nome} por um ano inteiro contra assassinos, rebeliões e credores. De mercenário sem nome a REI. Os bardos cantarão a saga de ${state.jogador.nome} por gerações.` };
      }
    }
  }

  function envelhecer() {
    state.jogador.idade++;
    for (const f of state.familia.filhos) f.idade++;
    // mortalidade por idade
    const idade = state.jogador.idade;
    const chanceMorte = idade > 65 ? 0.25 : idade > 55 ? 0.10 : idade > 45 ? 0.04 : 0;
    if (Math.random() < chanceMorte) morrer('idade');
  }

  // ---------- morte e herança ----------
  function morrer(causa) {
    const causas = {
      idade: 'A velhice fez o que nenhuma lâmina conseguiu.',
      assassinato: 'Uma lâmina no escuro encontrou sua garganta.',
      rebeliao: 'O povo que você deixou faminto cortou a sua cabeça na praça.',
      batalha: 'Você caiu em batalha, de espada na mão.',
    };
    const herdeiro = state.familia.filhos.find(f => f.idade >= 16);
    if (!herdeiro) {
      state.fim = { tipo: 'derrota',
        msg: `💀 ${causas[causa]} Sem herdeiro adulto, sua casa morre com você. ${state.jogador.nome} vira nota de rodapé nas crônicas. FIM DA LINHAGEM.` };
      return;
    }
    // vassalos conspiram contra herdeiro mimado e cruel
    if (herdeiro.mimado && state.terra) {
      state.terra.felicidade = clamp(state.terra.felicidade - 30, 0, 100);
      log(`⚠️ Os vassalos desprezam ${herdeiro.nome}, ${herdeiro.genero === 'm' ? 'conhecido' : 'conhecida'} por ser cruel e ${herdeiro.genero === 'm' ? 'mimado' : 'mimada'}. Conspirações brotam como ervas daninhas.`);
    }
    log(`⚰️ ${causas[causa]} ${state.jogador.nome} morre aos ${state.jogador.idade} anos. ${herdeiro.nome} assume o comando da casa — a saga continua.`);
    const antigo = state.jogador;
    state.jogador = {
      ...antigo,
      nome: herdeiro.nome + ' ' + antigo.nome.split(' ').slice(1).join(' '),
      idade: herdeiro.idade,
      atributos: herdeiro.atributos,
      crueldade: herdeiro.mimado ? 2 : 0,
      mesesReinando: antigo.reiDe ? 0 : antigo.mesesReinando,
    };
    state.familia.filhos = state.familia.filhos.filter(f => f !== herdeiro);
    state.familia.conjuge = null;
  }

  // ---------- resolução de eventos pendentes ----------
  function resolverEvento(escolha) {
    const ev = state.eventoPendente;
    if (!ev) return null;
    state.eventoPendente = null;
    let resultado = null;

    if (ev.tipo === 'rebeliao') {
      if (escolha === 'reprimir') {
        const rebeldes = { tropas: { campones: ri(15, 30), lanceiro: ri(2, 5) }, equip: 0, formacao: 'cerco' };
        resultado = Combate.batalhar(state, rebeldes, 'Rebelião camponesa');
        if (resultado.vitoria) {
          state.terra.felicidade = 35;
          state.terra.populacao = Math.max(5, state.terra.populacao - ri(4, 8));
          state.jogador.crueldade++;
          log(`🩸 Você afogou a rebelião em sangue. A vila obedece — e odeia em silêncio.`);
        } else {
          morrer('rebeliao');
        }
      } else { // conceder
        const custo = Math.min(state.jogador.ouro, 200);
        state.jogador.ouro -= custo;
        state.terra.alimento += 60;
        state.terra.felicidade = 55;
        log(`🕊️ Você abriu os celeiros e o tesouro (−${custo} ouro, +60 alimento). O povo abaixa as foices. Por ora, a paz custou mais barato que caixões.`);
      }
    } else if (ev.tipo === 'traicao_guardas') {
      if (escolha === 'pagar') {
        const custo = state.jogador.guardas * 15;
        if (state.jogador.ouro >= custo) {
          state.jogador.ouro -= custo;
          state.jogador.mesesSemPagar = 0;
          log(`💰 Você raspou o cofre (−${custo}) e pagou a guarda em dobro. Os portões continuam seus. Lealdade comprada é lealdade alugada — não esqueça.`);
        } else {
          escolha = 'recusar';
        }
      }
      if (escolha === 'recusar') {
        log(`🌙 Na calada da noite, sua guarda de elite abriu os portões para agentes rivais. Você escapou pelo esgoto com a roupa do corpo.`);
        state.jogador.guardas = 0;
        if (state.terra) { state.terra.nivel = Math.max(0, state.terra.nivel - 2); Cidade.seedNpcs(state.terra.nivel); }
        state.jogador.ouro = Math.floor(state.jogador.ouro / 2);
        state.jogador.renome = Math.max(0, state.jogador.renome - 15);
      }
    } else if (ev.tipo === 'assassinato') {
      const reino = state.reinos.find(r => r.id === ev.reino);
      const teste = ri(1, 20) + state.jogador.atributos.forca;
      if (escolha === 'lutar' && teste >= 14) {
        log(`⚔️ Você acordou a tempo e matou o assassino de ${reino.nome} com as próprias mãos. Há uma adaga com o selo real cravada na sua mesa — que prova conveniente.`);
        if (!state.casusBelli.includes(ev.reino)) {
          state.casusBelli.push(ev.reino);
          log(`📜 Tentativa de assassinato real comprovada: você ganhou CASUS BELLI contra ${reino.nome}.`);
        }
      } else {
        morrer('assassinato');
      }
    }
    return resultado;
  }

  // ---------- ações do jogador ----------
  function comprarTerra() {
    const custo = 300;
    if (state.terra) return { ok: false, msg: 'Você já tem terras.' };
    if (state.jogador.renome < 25) return { ok: false, msg: `Nenhum rei vende terra a um zé-ninguém. Renome ${state.jogador.renome}/25.` };
    if (state.jogador.ouro < custo) return { ok: false, msg: `Terra custa ${custo} de ouro.` };
    state.jogador.ouro -= custo;
    state.terra = {
      nome: 'Vale ' + rnd(['Sereno', 'das Pedras', 'do Corvo', 'Dourado', 'Frio']),
      nivel: 0, populacao: 20, alimento: 80, madeira: 20, felicidade: 60, ultimaColeta: null,
    };
    Cidade.seedNpcs(0);
    log(`🏕️ Você comprou ${state.terra.nome}: mato, pedras e vinte camponeses desconfiados. Todo império começa com uma tenda.`);
    return { ok: true, msg: 'Terra adquirida! Veja a aba "Sua Terra".' };
  }

  function melhorarTerra() {
    const t = state.terra;
    if (!t) return { ok: false, msg: 'Você não tem terras.' };
    if (t.nivel >= 5) return { ok: false, msg: 'Seu castelo já toca as nuvens.' };
    const prox = NIVEIS_TERRA[t.nivel + 1];
    if (state.jogador.ouro < prox.custoOuro) return { ok: false, msg: `Faltam ${prox.custoOuro - state.jogador.ouro} de ouro (custa ${prox.custoOuro}).` };
    if (t.madeira < prox.custoMadeira) return { ok: false, msg: `Falta madeira: ${t.madeira}/${prox.custoMadeira}.` };
    state.jogador.ouro -= prox.custoOuro;
    t.madeira -= prox.custoMadeira;
    t.nivel++;
    t.populacao += ri(10, 20);
    Cidade.seedNpcs(t.nivel);
    log(`🏗️ ${t.nome} evolui para ${prox.nome}! ${prox.desc} Novos moradores chegam atraídos pela prosperidade.`);
    return { ok: true, msg: `Agora você governa um(a) ${prox.nome}.` };
  }

  function recrutar(tipo, qtd) {
    const t = TROPAS[tipo];
    const custo = t.custo * qtd;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Custa ${custo} de ouro.` };
    if (tipo === 'campones') {
      if (!state.terra) return { ok: false, msg: 'Camponeses vêm da SUA terra — e você não tem uma.' };
      const disponiveis = state.terra.populacao - (state.jogador.tropas.campones || 0);
      if (qtd > disponiveis) return { ok: false, msg: `Só há ${disponiveis} camponeses disponíveis na vila.` };
    }
    state.jogador.ouro -= custo;
    state.jogador.tropas[tipo] = (state.jogador.tropas[tipo] || 0) + qtd;
    let aviso = '';
    if (tipo === 'campones' && state.jogador.tropas.campones > state.terra.populacao * 0.4)
      aviso = ' ⚠️ Cuidado: com tanta gente no exército, a colheita vai sofrer.';
    return { ok: true, msg: `Recrutou ${qtd}× ${t.nome}.${aviso}` };
  }

  function contratarGuardas(qtd) {
    const custo = 60 * qtd;
    if (state.jogador.ouro < custo) return { ok: false, msg: `Guarda de elite custa 60/homem (${custo}).` };
    state.jogador.ouro -= custo;
    state.jogador.guardas += qtd;
    return { ok: true, msg: `${qtd} guardas de elite contratados. Eles protegem você de assassinos — enquanto o soldo estiver em dia.` };
  }

  function melhorarEquip() {
    if (state.jogador.equip >= 3) return { ok: false, msg: 'Equipamento já é o melhor que ferreiros forjam.' };
    const custo = 200 * (state.jogador.equip + 1);
    if (state.jogador.ouro < custo) return { ok: false, msg: `Melhoria custa ${custo} de ouro.` };
    state.jogador.ouro -= custo;
    state.jogador.equip++;
    return { ok: true, msg: `Equipamento nível ${state.jogador.equip}: aço melhor, escudos mais firmes (+15% de força).` };
  }

  // ---------- save / load ----------
  const SAVE_KEY = 'reino_por_conquista_save';
  function salvar() {
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(state)); return true; }
    catch (e) { return false; }
  }
  function carregar() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return false;
      state = JSON.parse(raw);
      Cidade.seedNpcs(state.terra ? state.terra.nivel : -1);
      return true;
    } catch (e) { return false; }
  }
  function temSave() { return !!localStorage.getItem(SAVE_KEY); }
  function apagarSave() { localStorage.removeItem(SAVE_KEY); }

  return {
    novoJogo, passarMes, resolverEvento, comprarTerra, melhorarTerra,
    recrutar, contratarGuardas, melhorarEquip, morrer, log,
    salvar, carregar, temSave, apagarSave,
    get state() { return state; },
  };
})();
