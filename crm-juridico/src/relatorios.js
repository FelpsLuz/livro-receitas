// Calculos do dashboard de ROI. Funcoes puras: recebem os dados e devolvem os
// numeros, sem tocar em disco nem em rede (o que as torna faceis de testar).

const { etapasEmOrdem, obterEtapa } = require('./funil');

function dentroDoPeriodo(iso, inicio, fim) {
  if (!iso) return false;
  const t = new Date(iso).getTime();
  return t >= inicio.getTime() && t <= fim.getTime();
}

function periodoUltimosDias(dias, hoje = new Date()) {
  const fim = new Date(hoje);
  fim.setHours(23, 59, 59, 999);
  const inicio = new Date(hoje);
  inicio.setDate(inicio.getDate() - (dias - 1));
  inicio.setHours(0, 0, 0, 0);
  return { inicio, fim };
}

/** Quantos clientes atingiram cada etapa do funil no periodo. */
function calcularFunil(clientes, { inicio, fim }) {
  return etapasEmOrdem().map((etapa) => {
    const atingiram = clientes.filter((c) =>
      dentroDoPeriodo((c.etapasAtingidas || {})[etapa.id], inicio, fim)
    );
    return {
      id: etapa.id,
      rotulo: etapa.rotulo,
      quantidade: atingiram.length,
      valor: atingiram.reduce((s, c) => s + (Number(c.valorHonorarios) || 0), 0),
    };
  });
}

/**
 * Consolida investimento (Google Ads) x receita (CRM).
 *
 * `metricas` e o retorno de buscarCustosCampanhas; quando o Google Ads nao esta
 * conectado ele vem vazio e o relatorio mostra so o lado do CRM - o dashboard
 * continua util, apenas sem o custo.
 */
function calcularResumo(clientes, metricas, periodo) {
  const { inicio, fim } = periodo;

  const fechados = clientes.filter((c) =>
    dentroDoPeriodo((c.etapasAtingidas || {}).ContratoFechado, inicio, fim)
  );
  const novosLeads = clientes.filter((c) =>
    dentroDoPeriodo((c.etapasAtingidas || {}).Lead, inicio, fim)
  );

  const receita = fechados.reduce((s, c) => s + (Number(c.valorHonorarios) || 0), 0);
  const investimento = Number(metricas && metricas.totalCusto) || 0;
  const lucro = receita - investimento;

  return {
    investimento,
    receita,
    lucro,
    // ROI em %: quanto sobrou em relacao ao que foi investido
    roi: investimento > 0 ? (lucro / investimento) * 100 : null,
    // ROAS: quantos reais de contrato para cada real de anuncio
    roas: investimento > 0 ? receita / investimento : null,
    contratosFechados: fechados.length,
    novosLeads: novosLeads.length,
    ticketMedio: fechados.length > 0 ? receita / fechados.length : 0,
    // Custo de aquisicao por cliente efetivamente fechado
    cac: fechados.length > 0 && investimento > 0 ? investimento / fechados.length : null,
    taxaConversao: novosLeads.length > 0 ? (fechados.length / novosLeads.length) * 100 : null,
    temDadosDeCusto: investimento > 0,
  };
}

/**
 * Cruza o que cada campanha custou com o que ela realmente trouxe de contrato.
 * A ligacao vem do GCLID: o cliente guarda o gclid, e `origemPorGclid` diz de
 * qual campanha/palavra-chave aquele clique veio.
 */
function calcularDesempenhoPorCampanha(clientes, metricas, origemPorGclid, periodo) {
  const { inicio, fim } = periodo;
  const origem = origemPorGclid || {};

  const porCampanha = new Map();

  for (const campanha of (metricas && metricas.campanhas) || []) {
    porCampanha.set(campanha.nome, {
      campanha: campanha.nome,
      custo: campanha.custo,
      cliques: campanha.cliques,
      leads: 0,
      contratos: 0,
      receita: 0,
    });
  }

  const semAtribuicao = {
    campanha: 'Não identificada',
    custo: 0,
    cliques: 0,
    leads: 0,
    contratos: 0,
    receita: 0,
  };

  for (const cliente of clientes) {
    const info = cliente.gclid ? origem[cliente.gclid] : null;
    const nome = (info && info.campanha) || null;
    const alvo = (nome && porCampanha.get(nome)) || semAtribuicao;

    if (dentroDoPeriodo((cliente.etapasAtingidas || {}).Lead, inicio, fim)) {
      alvo.leads += 1;
    }
    if (dentroDoPeriodo((cliente.etapasAtingidas || {}).ContratoFechado, inicio, fim)) {
      alvo.contratos += 1;
      alvo.receita += Number(cliente.valorHonorarios) || 0;
    }
  }

  const linhas = Array.from(porCampanha.values());
  if (semAtribuicao.leads > 0 || semAtribuicao.contratos > 0) {
    linhas.push(semAtribuicao);
  }

  return linhas
    .map((l) => ({
      ...l,
      roi: l.custo > 0 ? ((l.receita - l.custo) / l.custo) * 100 : null,
      cac: l.contratos > 0 && l.custo > 0 ? l.custo / l.contratos : null,
    }))
    .sort((a, b) => b.receita - a.receita || b.custo - a.custo);
}

/** Ranking de palavras-chave por receita gerada (nao por cliques). */
function calcularDesempenhoPorPalavraChave(clientes, origemPorGclid, periodo) {
  const { inicio, fim } = periodo;
  const origem = origemPorGclid || {};
  const porPalavra = new Map();

  for (const cliente of clientes) {
    const info = cliente.gclid ? origem[cliente.gclid] : null;
    const palavra = (info && info.palavraChave) || null;
    if (!palavra) continue;

    const atual = porPalavra.get(palavra) || { palavraChave: palavra, leads: 0, contratos: 0, receita: 0 };
    if (dentroDoPeriodo((cliente.etapasAtingidas || {}).Lead, inicio, fim)) atual.leads += 1;
    if (dentroDoPeriodo((cliente.etapasAtingidas || {}).ContratoFechado, inicio, fim)) {
      atual.contratos += 1;
      atual.receita += Number(cliente.valorHonorarios) || 0;
    }
    porPalavra.set(palavra, atual);
  }

  return Array.from(porPalavra.values())
    .filter((p) => p.leads > 0 || p.contratos > 0)
    .sort((a, b) => b.receita - a.receita || b.leads - a.leads);
}

/** Saude do envio de conversoes: quantas foram, quantas estao presas na fila. */
function calcularSaudeConversoes(conversoes) {
  const contar = (status) => conversoes.filter((c) => c.status === status).length;
  return {
    total: conversoes.length,
    enviadas: contar('enviada'),
    pendentes: contar('pendente'),
    falhas: contar('falhou'),
  };
}

function montarDashboard({ clientes, conversoes, metricas, origemPorGclid, dias = 30, hoje = new Date() }) {
  const periodo = periodoUltimosDias(dias, hoje);
  return {
    dias,
    periodo: { inicio: periodo.inicio.toISOString(), fim: periodo.fim.toISOString() },
    resumo: calcularResumo(clientes, metricas, periodo),
    funil: calcularFunil(clientes, periodo),
    campanhas: calcularDesempenhoPorCampanha(clientes, metricas, origemPorGclid, periodo),
    palavrasChave: calcularDesempenhoPorPalavraChave(clientes, origemPorGclid, periodo),
    conversoes: calcularSaudeConversoes(conversoes),
    metricasSincronizadasEm: (metricas && metricas.sincronizadoEm) || null,
  };
}

module.exports = {
  periodoUltimosDias,
  calcularFunil,
  calcularResumo,
  calcularDesempenhoPorCampanha,
  calcularDesempenhoPorPalavraChave,
  calcularSaudeConversoes,
  montarDashboard,
  obterEtapa,
};
