const assert = require('assert');
const { diasRestantes, situacao, prazosParaAlertar, formatarMensagem } = require('../src/prazos');

function addDias(base, dias) {
  const d = new Date(base);
  d.setDate(d.getDate() + dias);
  return d.toISOString().slice(0, 10);
}

const hoje = new Date('2026-07-30T12:00:00');

// diasRestantes
assert.strictEqual(diasRestantes(addDias(hoje, 7), hoje), 7);
assert.strictEqual(diasRestantes(addDias(hoje, 0), hoje), 0);
assert.strictEqual(diasRestantes(addDias(hoje, -2), hoje), -2);
console.log('OK: diasRestantes');

// situacao
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, -1), status: 'Pendente' }, hoje), 'vencido');
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, 0), status: 'Pendente' }, hoje), 'hoje');
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, 2), status: 'Pendente' }, hoje), 'urgente');
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, 5), status: 'Pendente' }, hoje), 'atencao');
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, 10), status: 'Pendente' }, hoje), 'ok');
assert.strictEqual(situacao({ dataVencimento: addDias(hoje, 10), status: 'Concluido' }, hoje), 'concluido');
console.log('OK: situacao');

// prazosParaAlertar - dispara apenas em 7, 3 e 0 dias, e nao duplica no mesmo dia
const prazos = [
  { id: '1', dataVencimento: addDias(hoje, 7), status: 'Pendente', alertasEnviados: [] },
  { id: '2', dataVencimento: addDias(hoje, 5), status: 'Pendente', alertasEnviados: [] },
  { id: '3', dataVencimento: addDias(hoje, 3), status: 'Pendente', alertasEnviados: [] },
  { id: '4', dataVencimento: addDias(hoje, 0), status: 'Pendente', alertasEnviados: [] },
  { id: '5', dataVencimento: addDias(hoje, -3), status: 'Pendente', alertasEnviados: [] },
  { id: '6', dataVencimento: addDias(hoje, 0), status: 'Concluido', alertasEnviados: [] },
  { id: '7', dataVencimento: addDias(hoje, 3), status: 'Pendente', alertasEnviados: [{ limiar: 3, data: '2026-07-30' }] },
];

const alertas = prazosParaAlertar(prazos, hoje);
const ids = alertas.map((a) => a.prazo.id).sort();
assert.deepStrictEqual(ids, ['1', '3', '4']);
console.log('OK: prazosParaAlertar (limiares 7/3/0, ignora concluido, ignora vencido antigo, evita duplicar)');

// formatarMensagem
const msg = formatarMensagem({
  prazo: { processo: '123', acao: 'Réplica', cliente: 'João', advogadoResponsavel: 'Dra. Maria' },
  dias: 3,
});
assert.ok(msg.includes('Vence em 3 dias'));
assert.ok(msg.includes('123'));
console.log('OK: formatarMensagem');

console.log('\nTodos os testes passaram.');
