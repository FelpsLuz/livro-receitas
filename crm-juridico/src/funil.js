// Definicao das etapas do funil de vendas.
//
// Cada etapa marcada com `conversao: true` pode ser enviada ao Google Ads como
// uma acao de conversao offline propria. Enviar o funil inteiro (e nao apenas o
// contrato fechado) da MUITO mais sinal para o algoritmo aprender: um escritorio
// que fecha 5 contratos/mes gera poucos dados, mas gera dezenas de leads
// qualificados - volume suficiente para o Google otimizar.

const ETAPAS = [
  {
    id: 'Lead',
    rotulo: 'Lead',
    ordem: 0,
    conversao: false,
    descricao: 'Entrou em contato, ainda sem triagem.',
  },
  {
    id: 'Qualificado',
    rotulo: 'Lead Qualificado',
    ordem: 1,
    conversao: true,
    chaveAcao: 'googleAdsAcaoQualificado',
    chaveValor: 'googleAdsValorQualificado',
    descricao: 'Caso tem viabilidade e o cliente tem perfil.',
  },
  {
    id: 'Reuniao',
    rotulo: 'Reunião Agendada',
    ordem: 2,
    conversao: true,
    chaveAcao: 'googleAdsAcaoReuniao',
    chaveValor: 'googleAdsValorReuniao',
    descricao: 'Consulta marcada com o advogado.',
  },
  {
    id: 'ContratoFechado',
    rotulo: 'Contrato Fechado',
    ordem: 3,
    conversao: true,
    chaveAcao: 'googleAdsAcaoContrato',
    // O valor desta etapa e o proprio valor dos honorarios do cliente.
    usaValorHonorarios: true,
    descricao: 'Contrato assinado.',
  },
  {
    id: 'Perdido',
    rotulo: 'Perdido',
    ordem: -1,
    conversao: false,
    descricao: 'Nao seguiu adiante.',
  },
];

const ETAPAS_POR_ID = new Map(ETAPAS.map((e) => [e.id, e]));

function obterEtapa(id) {
  return ETAPAS_POR_ID.get(id) || ETAPAS_POR_ID.get('Lead');
}

function rotuloEtapa(id) {
  return obterEtapa(id).rotulo;
}

function etapasDeConversao() {
  return ETAPAS.filter((e) => e.conversao);
}

// Etapas ativas do funil, em ordem (exclui "Perdido", que e um desfecho lateral).
function etapasEmOrdem() {
  return ETAPAS.filter((e) => e.ordem >= 0).sort((a, b) => a.ordem - b.ordem);
}

// Ao avancar um cliente para uma etapa, todas as etapas anteriores tambem foram
// atingidas. Ex: quem fecha contrato passou por qualificado e reuniao, mesmo que
// o estagiario nao tenha clicado em cada uma - entao enviamos todas.
function etapasAtingidasAte(idEtapa) {
  const alvo = obterEtapa(idEtapa);
  if (alvo.ordem < 0) return [];
  return etapasEmOrdem().filter((e) => e.ordem > 0 && e.ordem <= alvo.ordem);
}

// Valor a enviar ao Google Ads para uma etapa. Contrato usa os honorarios reais;
// as etapas intermediarias usam um valor estimado configuravel (ajuda o Google a
// entender que um lead qualificado vale mais que um clique qualquer).
function valorDaEtapa(etapa, cliente, config) {
  if (etapa.usaValorHonorarios) return Number(cliente.valorHonorarios) || 0;
  return Number(config[etapa.chaveValor]) || 0;
}

function acaoDaEtapa(etapa, config) {
  if (etapa.usaValorHonorarios) {
    return config.googleAdsAcaoContrato || config.googleAdsConversionActionId || '';
  }
  return config[etapa.chaveAcao] || '';
}

module.exports = {
  ETAPAS,
  obterEtapa,
  rotuloEtapa,
  etapasDeConversao,
  etapasEmOrdem,
  etapasAtingidasAte,
  valorDaEtapa,
  acaoDaEtapa,
};
