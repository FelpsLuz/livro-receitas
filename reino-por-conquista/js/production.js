// ============================================================
// PRODUÇÃO DA SUA TERRA — fazenda, serraria, mina e ferreiro
// Cada edifício evolui até o NÍVEL 30 com custo crescente
// (curva exponencial: virar magnata produtor é jornada longa —
// comprar barato e vender caro continua sendo o dinheiro rápido).
// - Fazenda: alimento para os celeiros
// - Serraria (floresta): madeira para construir
// - Mina de ferro: FERRO vai para a sua carga (venda ou forje!)
// - Ferreiro: converte 2 ferro → 1 arma (mercadoria valiosa) e
//   dá desconto no equipamento do exército
// Mão de obra: produção limitada pela população disponível.
// ============================================================
'use strict';

const Producao = (() => {

  const EDIFICIOS = {
    fazenda:  { nome: 'Fazenda',        icone: '🌾', base: 120, desc: 'Produz alimento para os celeiros.' },
    serraria: { nome: 'Serraria',       icone: '🌲', base: 150, desc: 'Corta madeira da floresta.' },
    mina:     { nome: 'Mina de Ferro',  icone: '⛏️', base: 200, desc: 'Extrai ferro — venda-o ou forje armas.' },
    ferreiro: { nome: 'Ferreiro',       icone: '🔨', base: 250, desc: 'Converte 2 ferro em 1 arma; barateia o equipamento das tropas.' },
  };
  const NIVEL_MAX = 30;

  function garantir(state) {
    if (state.terra && !state.terra.edificios)
      state.terra.edificios = { fazenda: 0, serraria: 0, mina: 0, ferreiro: 0 };
  }

  function custo(id, nivel) {
    // exponencial suave: nível 1 ≈ base, nível 10 ≈ 4x, nível 30 ≈ 90x
    return Math.round(EDIFICIOS[id].base * Math.pow(1.165, nivel));
  }

  function producaoDe(state, id, nivel) {
    switch (id) {
      case 'fazenda': return nivel * 5;                       // alimento/mês
      case 'serraria': return nivel * 3;                      // madeira/mês
      case 'mina': return Math.floor(nivel / 2);              // ferro/mês (valioso)
      case 'ferreiro': return Math.floor(nivel / 2);          // máx. de armas forjadas/mês
    }
    return 0;
  }

  function construir(state, id) {
    if (!state.terra) return { ok: false, msg: 'Você não tem terras.' };
    garantir(state);
    const nivel = state.terra.edificios[id];
    if (nivel >= NIVEL_MAX) return { ok: false, msg: `${EDIFICIOS[id].nome} já está no nível máximo (${NIVEL_MAX}).` };
    const ouro = custo(id, nivel);
    const madeira = Math.round(ouro / 4);
    if (state.jogador.ouro < ouro) return { ok: false, msg: `Faltam ${ouro - state.jogador.ouro} de ouro (custa ${ouro}).` };
    if (state.terra.madeira < madeira) return { ok: false, msg: `Falta madeira: ${state.terra.madeira}/${madeira}.` };
    state.jogador.ouro -= ouro;
    state.terra.madeira -= madeira;
    state.terra.edificios[id]++;
    return { ok: true, msg: `${EDIFICIOS[id].icone} ${EDIFICIOS[id].nome} evoluiu para o nível ${state.terra.edificios[id]}!` };
  }

  // desconto do ferreiro no equipamento do exército (até 30%)
  function descontoEquip(state) {
    if (!state.terra || !state.terra.edificios) return 0;
    return Math.min(0.30, state.terra.edificios.ferreiro * 0.01);
  }

  function tick(state, log) {
    if (!state.terra) return;
    garantir(state);
    const ed = state.terra.edificios;
    const somaNiveis = ed.fazenda + ed.serraria + ed.mina + ed.ferreiro;
    if (somaNiveis === 0) return;
    // mão de obra: cada nível ocupa 1 trabalhador; sem gente, eficiência cai
    const convocados = state.jogador.tropas.campones || 0;
    const disponiveis = Math.max(0, state.terra.populacao - convocados);
    const eficiencia = Math.min(1, disponiveis / somaNiveis);
    if (eficiencia < 0.6)
      log(`⚠️ Faltam braços em ${state.terra.nome}: os edifícios operam a ${Math.round(eficiencia * 100)}% (população ocupada demais).`);

    const alimento = Math.round(producaoDe(state, 'fazenda', ed.fazenda) * eficiencia);
    const madeira = Math.round(producaoDe(state, 'serraria', ed.serraria) * eficiencia);
    const ferro = Math.round(producaoDe(state, 'mina', ed.mina) * eficiencia);
    state.terra.alimento += alimento;
    state.terra.madeira += madeira;
    if (ferro > 0) state.carga.ferro = (state.carga.ferro || 0) + ferro;

    // ferreiro forja: consome 2 ferro da carga por arma
    let armas = 0;
    const capacidade = Math.round(producaoDe(state, 'ferreiro', ed.ferreiro) * eficiencia);
    while (armas < capacidade && (state.carga.ferro || 0) >= 2) {
      state.carga.ferro -= 2;
      armas++;
    }
    if (armas > 0) state.carga.armas = (state.carga.armas || 0) + armas;

    if (alimento + madeira + ferro + armas > 0)
      state.terra.ultimaProducao = { alimento, madeira, ferro, armas, eficiencia };
  }

  // estágio visual do sprite: muda a cada 5 níveis (0..6)
  function estagio(nivel) { return Math.min(6, Math.floor(nivel / 5) + (nivel > 0 ? 1 : 0)); }

  return { EDIFICIOS, NIVEL_MAX, custo, producaoDe, construir, descontoEquip, tick, garantir, estagio };
})();
