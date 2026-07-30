const corpoTabela = document.getElementById('corpo-tabela-prazos');
const modal = document.getElementById('modal-prazo');
const formPrazo = document.getElementById('form-prazo');
const formConfig = document.getElementById('form-config');
const statusVerificacao = document.getElementById('status-verificacao');
const statusConfig = document.getElementById('status-config');

document.querySelectorAll('.tab-btn').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
  });
});

function rotuloSituacao(situacao) {
  const rotulos = {
    vencido: 'Vencido',
    hoje: 'Vence hoje',
    urgente: 'Urgente',
    atencao: 'Atenção',
    ok: 'Em dia',
    concluido: 'Concluído',
  };
  return rotulos[situacao] || situacao;
}

async function carregarPrazos() {
  const prazos = await window.api.listarPrazos();
  prazos.sort((a, b) => new Date(a.dataVencimento) - new Date(b.dataVencimento));
  corpoTabela.innerHTML = '';

  for (const prazo of prazos) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${escapeHtml(prazo.processo)}</td>
      <td>${escapeHtml(prazo.cliente)}</td>
      <td>${escapeHtml(prazo.acao)}</td>
      <td>${escapeHtml(prazo.advogadoResponsavel)}</td>
      <td>${formatarData(prazo.dataVencimento)}</td>
      <td>${prazo.dias}</td>
      <td><span class="situacao ${prazo.situacao}">${rotuloSituacao(prazo.situacao)}</span></td>
      <td class="linha-acoes">
        <button class="editar" data-id="${prazo.id}">Editar</button>
        ${prazo.status !== 'Concluido' ? `<button class="concluir" data-id="${prazo.id}">Concluir</button>` : ''}
        <button class="excluir" data-id="${prazo.id}">Excluir</button>
      </td>
    `;
    corpoTabela.appendChild(tr);
  }

  corpoTabela.querySelectorAll('.editar').forEach((b) => b.addEventListener('click', () => abrirEdicao(b.dataset.id, prazos)));
  corpoTabela.querySelectorAll('.concluir').forEach((b) => b.addEventListener('click', async () => {
    await window.api.concluirPrazo(b.dataset.id);
    carregarPrazos();
  }));
  corpoTabela.querySelectorAll('.excluir').forEach((b) => b.addEventListener('click', async () => {
    if (confirm('Excluir este prazo?')) {
      await window.api.excluirPrazo(b.dataset.id);
      carregarPrazos();
    }
  }));
}

function escapeHtml(texto) {
  const div = document.createElement('div');
  div.textContent = texto ?? '';
  return div.innerHTML;
}

function formatarData(iso) {
  const [ano, mes, dia] = iso.split('-');
  return `${dia}/${mes}/${ano}`;
}

function abrirModal() {
  modal.classList.remove('oculto');
}
function fecharModal() {
  modal.classList.add('oculto');
  formPrazo.reset();
  document.getElementById('prazo-id').value = '';
}

document.getElementById('btn-novo-prazo').addEventListener('click', () => {
  document.getElementById('modal-titulo').textContent = 'Novo Prazo';
  abrirModal();
});
document.getElementById('btn-cancelar-prazo').addEventListener('click', fecharModal);

function abrirEdicao(id, prazos) {
  const prazo = prazos.find((p) => p.id === id);
  if (!prazo) return;
  document.getElementById('modal-titulo').textContent = 'Editar Prazo';
  document.getElementById('prazo-id').value = prazo.id;
  document.getElementById('prazo-processo').value = prazo.processo;
  document.getElementById('prazo-cliente').value = prazo.cliente;
  document.getElementById('prazo-acao').value = prazo.acao;
  document.getElementById('prazo-advogado').value = prazo.advogadoResponsavel;
  document.getElementById('prazo-data').value = prazo.dataVencimento;
  abrirModal();
}

formPrazo.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = document.getElementById('prazo-id').value;
  const dados = {
    processo: document.getElementById('prazo-processo').value,
    cliente: document.getElementById('prazo-cliente').value,
    acao: document.getElementById('prazo-acao').value,
    advogadoResponsavel: document.getElementById('prazo-advogado').value,
    dataVencimento: document.getElementById('prazo-data').value,
  };

  if (id) {
    await window.api.atualizarPrazo(id, dados);
  } else {
    await window.api.adicionarPrazo(dados);
  }
  fecharModal();
  carregarPrazos();
});

document.getElementById('btn-verificar-agora').addEventListener('click', async () => {
  statusVerificacao.textContent = 'Verificando...';
  const resultado = await window.api.verificarAgora();
  statusVerificacao.textContent = resultado.length
    ? `${resultado.length} alerta(s) processado(s).`
    : 'Nenhum prazo para alertar hoje.';
  carregarPrazos();
});

async function carregarConfig() {
  const config = await window.api.obterConfig();
  document.getElementById('cfg-token').value = config.telegramBotToken || '';
  document.getElementById('cfg-chatid').value = config.telegramChatId || '';
  document.getElementById('cfg-horario').value = config.horarioVerificacao || '08:00';
  document.getElementById('cfg-ativas').checked = config.notificacoesAtivas !== false;
}

formConfig.addEventListener('submit', async (e) => {
  e.preventDefault();
  await window.api.salvarConfig({
    telegramBotToken: document.getElementById('cfg-token').value.trim(),
    telegramChatId: document.getElementById('cfg-chatid').value.trim(),
    horarioVerificacao: document.getElementById('cfg-horario').value,
    notificacoesAtivas: document.getElementById('cfg-ativas').checked,
  });
  statusConfig.textContent = 'Configurações salvas.';
  setTimeout(() => (statusConfig.textContent = ''), 3000);
});

document.getElementById('btn-testar-telegram').addEventListener('click', async () => {
  statusConfig.textContent = 'Testando...';
  try {
    await window.api.testarTelegram({
      telegramBotToken: document.getElementById('cfg-token').value.trim(),
      telegramChatId: document.getElementById('cfg-chatid').value.trim(),
    });
    statusConfig.textContent = 'Mensagem de teste enviada com sucesso!';
  } catch (err) {
    statusConfig.textContent = `Erro: ${err.message}`;
  }
});

carregarPrazos();
carregarConfig();
