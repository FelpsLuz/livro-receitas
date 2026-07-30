const LIMIARES_ALERTA = [7, 3, 0];

function inicioDoDia(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function diasRestantes(dataVencimento, hoje = new Date()) {
  const venc = inicioDoDia(dataVencimento);
  const base = inicioDoDia(hoje);
  const diffMs = venc.getTime() - base.getTime();
  return Math.round(diffMs / (1000 * 60 * 60 * 24));
}

function situacao(prazo, hoje = new Date()) {
  if (prazo.status === 'Concluido') return 'concluido';
  const dias = diasRestantes(prazo.dataVencimento, hoje);
  if (dias < 0) return 'vencido';
  if (dias === 0) return 'hoje';
  if (dias <= 3) return 'urgente';
  if (dias <= 7) return 'atencao';
  return 'ok';
}

// Retorna os prazos que devem disparar alerta hoje (7, 3 ou 0 dias restantes),
// ignorando os que ja receberam alerta para aquele limiar especifico hoje.
function prazosParaAlertar(prazos, hoje = new Date()) {
  const hojeStr = inicioDoDia(hoje).toISOString().slice(0, 10);
  const alertas = [];

  for (const prazo of prazos) {
    if (prazo.status === 'Concluido') continue;
    const dias = diasRestantes(prazo.dataVencimento, hoje);
    if (!LIMIARES_ALERTA.includes(dias)) continue;

    const jaEnviado = (prazo.alertasEnviados || []).some(
      (a) => a.limiar === dias && a.data === hojeStr
    );
    if (jaEnviado) continue;

    alertas.push({ prazo, dias, hojeStr });
  }

  return alertas;
}

function formatarMensagem({ prazo, dias }) {
  const linhaPrazo =
    dias === 0
      ? 'VENCE HOJE'
      : `Vence em ${dias} dia${dias === 1 ? '' : 's'}`;
  return (
    `⚠️ ALERTA DE PRAZO (${linhaPrazo}):\n` +
    `Processo: ${prazo.processo}\n` +
    `Acao: ${prazo.acao}\n` +
    `Cliente: ${prazo.cliente}\n` +
    `Responsavel: ${prazo.advogadoResponsavel}`
  );
}

module.exports = {
  LIMIARES_ALERTA,
  diasRestantes,
  situacao,
  prazosParaAlertar,
  formatarMensagem,
};
