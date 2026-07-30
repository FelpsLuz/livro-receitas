// Limiares de alerta, do mais distante ao mais proximo.
const LIMIARES_ALERTA = [7, 3, 1, 0];

// Prazos ja vencidos e ainda nao concluidos continuam cobrando todo dia,
// ate que alguem conclua ou remova o prazo.
const ALERTA_VENCIDO = 'vencido';

function inicioDoDia(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function diaISO(date) {
  const d = inicioDoDia(date);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function diasRestantes(dataVencimento, hoje = new Date()) {
  const venc = inicioDoDia(dataVencimento);
  const base = inicioDoDia(hoje);
  return Math.round((venc.getTime() - base.getTime()) / (1000 * 60 * 60 * 24));
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

/**
 * Decide quais alertas devem ser disparados agora.
 *
 * A regra e "menor OU IGUAL ao limiar, ainda nao alertado" - e nao igualdade
 * exata. Isso e o que garante o catch-up: se o computador ficou desligado no
 * dia em que faltavam exatamente 3 dias, o alerta de 3 dias ainda dispara na
 * primeira vez que o app abrir (faltando 2 dias), em vez de se perder para
 * sempre. Cada limiar dispara no maximo uma vez por prazo.
 */
function prazosParaAlertar(prazos, hoje = new Date()) {
  const hojeStr = diaISO(hoje);
  const alertas = [];

  for (const prazo of prazos) {
    if (prazo.status === 'Concluido') continue;

    const dias = diasRestantes(prazo.dataVencimento, hoje);
    const enviados = prazo.alertasEnviados || [];

    if (dias < 0) {
      // Vencido: cobra uma vez por dia, sem parar.
      const jaHoje = enviados.some((a) => a.limiar === ALERTA_VENCIDO && a.data === hojeStr);
      if (!jaHoje) {
        alertas.push({ prazo, dias, limiar: ALERTA_VENCIDO, hojeStr });
      }
      continue;
    }

    // Dispara o limiar mais urgente ainda pendente, para nao mandar 3 mensagens
    // de uma vez quando o app ficou dias sem abrir.
    const pendentes = LIMIARES_ALERTA.filter(
      (limiar) => dias <= limiar && !enviados.some((a) => a.limiar === limiar)
    );
    if (pendentes.length === 0) continue;

    const limiar = Math.min(...pendentes);
    alertas.push({ prazo, dias, limiar, hojeStr, limiaresCobertos: pendentes });
  }

  return alertas;
}

function descreverPrazo(dias) {
  if (dias < 0) {
    const atraso = Math.abs(dias);
    return `VENCIDO há ${atraso} dia${atraso === 1 ? '' : 's'}`;
  }
  if (dias === 0) return 'VENCE HOJE';
  return `Vence em ${dias} dia${dias === 1 ? '' : 's'}`;
}

function formatarMensagem({ prazo, dias }) {
  const icone = dias < 0 ? '🚨' : '⚠️';
  const linhas = [
    `${icone} ALERTA DE PRAZO (${descreverPrazo(dias)})`,
    '',
    `Processo: ${prazo.processo}`,
    `Ação: ${prazo.acao}`,
  ];
  if (prazo.cliente) linhas.push(`Cliente: ${prazo.cliente}`);
  if (prazo.advogadoResponsavel) linhas.push(`Responsável: ${prazo.advogadoResponsavel}`);
  return linhas.join('\n');
}

// Marca no proprio prazo quais limiares ja foram alertados, para nao repetir.
function registrarAlertaEnviado(prazo, alerta, telegramOk) {
  const enviados = [...(prazo.alertasEnviados || [])];
  const limiares = alerta.limiaresCobertos || [alerta.limiar];

  for (const limiar of limiares) {
    if (limiar === ALERTA_VENCIDO) {
      enviados.push({ limiar, data: alerta.hojeStr, telegramOk });
    } else if (!enviados.some((a) => a.limiar === limiar)) {
      enviados.push({ limiar, data: alerta.hojeStr, telegramOk });
    }
  }
  return enviados;
}

module.exports = {
  LIMIARES_ALERTA,
  ALERTA_VENCIDO,
  diaISO,
  diasRestantes,
  situacao,
  prazosParaAlertar,
  formatarMensagem,
  descreverPrazo,
  registrarAlertaEnviado,
};
