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

document.getElementById('btn-atualizar-prazos').addEventListener('click', carregarPrazos);

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

// ===================== Clientes =====================

const corpoTabelaClientes = document.getElementById('corpo-tabela-clientes');
const modalCliente = document.getElementById('modal-cliente');
const formCliente = document.getElementById('form-cliente');
const statusClientes = document.getElementById('status-clientes');

function extrairGclid(valor) {
  const texto = (valor || '').trim();
  const match = texto.match(/GCLID:\s*([^\s)]+)/i);
  return match ? match[1] : texto;
}

function formatarMoedaBRL(valor) {
  return (Number(valor) || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function rotuloConversao(cliente, ultimaConversao) {
  if (cliente.status !== 'Contrato Fechado') return { classe: 'pendente', texto: '—' };
  if (!ultimaConversao) return { classe: 'pendente', texto: 'Não enviada' };
  return ultimaConversao.sucesso
    ? { classe: 'enviada', texto: 'Enviada ✅' }
    : { classe: 'falhou', texto: 'Falhou ❌' };
}

async function carregarClientes() {
  const clientes = await window.api.listarClientes();
  corpoTabelaClientes.innerHTML = '';

  for (const cliente of clientes) {
    const conversoes = await window.api.listarConversoesPorCliente(cliente.id);
    const ultimaConversao = conversoes.sort((a, b) => new Date(b.enviadoEm) - new Date(a.enviadoEm))[0];
    const fechado = cliente.status === 'Contrato Fechado';
    const infoConversao = rotuloConversao(cliente, ultimaConversao);

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${escapeHtml(cliente.nome)}</td>
      <td>${escapeHtml(cliente.cpf)}</td>
      <td>${escapeHtml(cliente.telefone)}</td>
      <td>${formatarMoedaBRL(cliente.valorHonorarios)}</td>
      <td>${escapeHtml(cliente.formaPagamento)}</td>
      <td><span class="pill ${fechado ? 'fechado' : 'lead'}">${fechado ? 'Contrato Fechado' : 'Lead'}</span></td>
      <td title="${escapeHtml((ultimaConversao && ultimaConversao.erro) || '')}">
        <span class="pill ${infoConversao.classe}">${infoConversao.texto}</span>
      </td>
      <td class="linha-acoes">
        <button class="gerar-contrato" data-id="${cliente.id}">Gerar Contrato</button>
        ${
          fechado
            ? `<button class="reenviar-conversao" data-id="${cliente.id}">Reenviar Conversão</button>
               <button class="reabrir" data-id="${cliente.id}">Reabrir</button>`
            : `<button class="fechar-contrato" data-id="${cliente.id}">Marcar Contrato Fechado</button>`
        }
        <button class="editar" data-id="${cliente.id}">Editar</button>
        <button class="excluir" data-id="${cliente.id}">Excluir</button>
      </td>
    `;
    corpoTabelaClientes.appendChild(tr);
  }

  corpoTabelaClientes.querySelectorAll('.editar').forEach((b) =>
    b.addEventListener('click', () => abrirEdicaoCliente(b.dataset.id, clientes))
  );
  corpoTabelaClientes.querySelectorAll('.excluir').forEach((b) =>
    b.addEventListener('click', async () => {
      if (confirm('Excluir este cliente?')) {
        await window.api.excluirCliente(b.dataset.id);
        carregarClientes();
      }
    })
  );
  corpoTabelaClientes.querySelectorAll('.gerar-contrato').forEach((b) =>
    b.addEventListener('click', () => abrirModalContrato(b.dataset.id, clientes))
  );
  corpoTabelaClientes.querySelectorAll('.fechar-contrato').forEach((b) =>
    b.addEventListener('click', async () => {
      if (!confirm('Marcar este cliente como Contrato Fechado? Isso tentará enviar a conversão para o Google Ads.')) return;
      statusClientes.textContent = 'Marcando contrato como fechado...';
      const resultado = await window.api.fecharContratoCliente(b.dataset.id);
      statusClientes.textContent = resultado.enviouConversao
        ? 'Contrato fechado e conversão enviada ao Google Ads com sucesso.'
        : `Contrato fechado. Conversão não enviada: ${resultado.erro}`;
      setTimeout(() => (statusClientes.textContent = ''), 5000);
      carregarClientes();
    })
  );
  corpoTabelaClientes.querySelectorAll('.reenviar-conversao').forEach((b) =>
    b.addEventListener('click', async () => {
      statusClientes.textContent = 'Reenviando conversão...';
      const resultado = await window.api.reenviarConversao(b.dataset.id);
      statusClientes.textContent = resultado.enviouConversao
        ? 'Conversão reenviada com sucesso.'
        : `Falha ao reenviar: ${resultado.erro}`;
      setTimeout(() => (statusClientes.textContent = ''), 5000);
      carregarClientes();
    })
  );
  corpoTabelaClientes.querySelectorAll('.reabrir').forEach((b) =>
    b.addEventListener('click', async () => {
      if (confirm('Reabrir este cliente como Lead?')) {
        await window.api.reabrirCliente(b.dataset.id);
        carregarClientes();
      }
    })
  );

  return clientes;
}

function abrirModalCliente() {
  modalCliente.classList.remove('oculto');
}
function fecharModalCliente() {
  modalCliente.classList.add('oculto');
  formCliente.reset();
  document.getElementById('cliente-id').value = '';
}

document.getElementById('btn-novo-cliente').addEventListener('click', () => {
  document.getElementById('modal-cliente-titulo').textContent = 'Novo Cliente';
  abrirModalCliente();
});
document.getElementById('btn-cancelar-cliente').addEventListener('click', fecharModalCliente);
document.getElementById('btn-atualizar-clientes').addEventListener('click', async () => {
  await carregarClientes();
  statusClientes.textContent = 'Lista atualizada.';
  setTimeout(() => (statusClientes.textContent = ''), 2000);
});

function abrirEdicaoCliente(id, clientes) {
  const cliente = clientes.find((c) => c.id === id);
  if (!cliente) return;
  document.getElementById('modal-cliente-titulo').textContent = 'Editar Cliente';
  document.getElementById('cliente-id').value = cliente.id;
  document.getElementById('cliente-nome').value = cliente.nome;
  document.getElementById('cliente-cpf').value = cliente.cpf;
  document.getElementById('cliente-telefone').value = cliente.telefone;
  document.getElementById('cliente-endereco').value = cliente.endereco;
  document.getElementById('cliente-honorarios').value = cliente.valorHonorarios;
  document.getElementById('cliente-forma-pagamento').value = cliente.formaPagamento;
  document.getElementById('cliente-gclid').value = cliente.gclid || '';
  abrirModalCliente();
}

formCliente.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = document.getElementById('cliente-id').value;
  const dados = {
    nome: document.getElementById('cliente-nome').value,
    cpf: document.getElementById('cliente-cpf').value,
    telefone: document.getElementById('cliente-telefone').value,
    endereco: document.getElementById('cliente-endereco').value,
    valorHonorarios: parseFloat(document.getElementById('cliente-honorarios').value) || 0,
    formaPagamento: document.getElementById('cliente-forma-pagamento').value,
    gclid: extrairGclid(document.getElementById('cliente-gclid').value),
  };

  if (id) {
    await window.api.atualizarCliente(id, dados);
  } else {
    await window.api.adicionarCliente(dados);
  }
  fecharModalCliente();
  carregarClientes();
});

// ===================== Modelos de Contrato =====================

const corpoTabelaModelos = document.getElementById('corpo-tabela-modelos');
const statusModelos = document.getElementById('status-modelos');

function formatarDataHora(iso) {
  return new Date(iso).toLocaleString('pt-BR');
}

async function carregarModelos() {
  const templates = await window.api.listarTemplates();
  corpoTabelaModelos.innerHTML = '';

  for (const template of templates) {
    const tr = document.createElement('tr');
    const tagsHtml = (template.tags || []).map((t) => `<span class="tag-pill">${t}</span>`).join('') || '—';
    tr.innerHTML = `
      <td>${escapeHtml(template.nome)}</td>
      <td>${tagsHtml}</td>
      <td>${formatarDataHora(template.importadoEm)}</td>
      <td class="linha-acoes">
        <button class="excluir" data-id="${template.id}">Excluir</button>
      </td>
    `;
    corpoTabelaModelos.appendChild(tr);
  }

  corpoTabelaModelos.querySelectorAll('.excluir').forEach((b) =>
    b.addEventListener('click', async () => {
      if (confirm('Excluir este modelo de contrato?')) {
        await window.api.excluirTemplate(b.dataset.id);
        carregarModelos();
      }
    })
  );

  return templates;
}

document.getElementById('btn-importar-modelo').addEventListener('click', async () => {
  const template = await window.api.importarTemplate();
  if (template) {
    statusModelos.textContent = `Modelo "${template.nome}" importado com sucesso.`;
    setTimeout(() => (statusModelos.textContent = ''), 3000);
  }
  carregarModelos();
});
document.getElementById('btn-atualizar-modelos').addEventListener('click', async () => {
  await carregarModelos();
  statusModelos.textContent = 'Lista atualizada.';
  setTimeout(() => (statusModelos.textContent = ''), 2000);
});

// ===================== Gerar Contrato =====================

const modalContrato = document.getElementById('modal-contrato');
const selectModelo = document.getElementById('contrato-select-modelo');
const resultadoContrato = document.getElementById('contrato-resultado');
const resultadoAcoes = document.getElementById('contrato-resultado-acoes');
const listaHistorico = document.getElementById('lista-historico-contratos');

let clienteAtualContrato = null;
let ultimoResultadoContrato = null;

async function abrirModalContrato(clienteId, clientesCache) {
  const clientes = clientesCache || (await window.api.listarClientes());
  const cliente = clientes.find((c) => c.id === clienteId);
  if (!cliente) return;

  clienteAtualContrato = cliente;
  document.getElementById('contrato-cliente-nome').textContent = cliente.nome;
  resultadoContrato.classList.add('oculto');
  resultadoAcoes.classList.add('oculto');
  resultadoContrato.textContent = '';

  const templates = await window.api.listarTemplates();
  selectModelo.innerHTML = templates
    .map((t) => `<option value="${t.id}">${escapeHtml(t.nome)}</option>`)
    .join('');

  await carregarHistoricoContratos(cliente.id);
  modalContrato.classList.remove('oculto');
}

async function carregarHistoricoContratos(clienteId) {
  const historico = await window.api.listarContratosPorCliente(clienteId);
  listaHistorico.innerHTML = '';
  if (historico.length === 0) {
    listaHistorico.innerHTML = '<li>Nenhum contrato gerado ainda.</li>';
    return;
  }
  historico
    .sort((a, b) => new Date(b.geradoEm) - new Date(a.geradoEm))
    .forEach((registro) => {
      const li = document.createElement('li');
      li.innerHTML = `
        <span>${escapeHtml(registro.templateNome)} — ${formatarDataHora(registro.geradoEm)}</span>
        <button class="abrir-historico" data-caminho="${escapeHtml(registro.arquivoDocx)}">Abrir pasta</button>
      `;
      listaHistorico.appendChild(li);
    });
  listaHistorico.querySelectorAll('.abrir-historico').forEach((b) =>
    b.addEventListener('click', () => window.api.abrirCaminho(b.dataset.caminho))
  );
}

document.getElementById('btn-gerar-contrato').addEventListener('click', async () => {
  if (!clienteAtualContrato || !selectModelo.value) return;
  resultadoContrato.classList.remove('oculto');
  resultadoContrato.textContent = 'Gerando contrato...';
  resultadoAcoes.classList.add('oculto');

  try {
    const registro = await window.api.gerarContrato(clienteAtualContrato.id, selectModelo.value);
    ultimoResultadoContrato = registro;
    resultadoContrato.textContent = registro.arquivoPdf
      ? `Contrato gerado (.docx e .pdf) em: ${registro.arquivoDocx}`
      : `Contrato gerado (.docx) em: ${registro.arquivoDocx}. PDF não gerado automaticamente — instale o LibreOffice para conversão automática, ou abra o .docx e exporte manualmente.`;
    resultadoAcoes.classList.remove('oculto');
    await carregarHistoricoContratos(clienteAtualContrato.id);
  } catch (err) {
    resultadoContrato.textContent = `Erro ao gerar contrato: ${err.message}`;
  }
});

document.getElementById('btn-abrir-pasta-contrato').addEventListener('click', () => {
  if (ultimoResultadoContrato) window.api.abrirCaminho(ultimoResultadoContrato.arquivoDocx);
});

document.getElementById('btn-abrir-whatsapp-contrato').addEventListener('click', () => {
  if (!clienteAtualContrato) return;
  const mensagem = `Olá ${clienteAtualContrato.nome}, segue o contrato de honorários. Qualquer dúvida estou à disposição!`;
  window.api.abrirWhatsapp(clienteAtualContrato.telefone, mensagem);
});

document.getElementById('btn-fechar-contrato').addEventListener('click', () => {
  modalContrato.classList.add('oculto');
  clienteAtualContrato = null;
  ultimoResultadoContrato = null;
});

// ===================== Google Ads (Configurações) =====================

const formGoogleAds = document.getElementById('form-google-ads');
const statusGoogleAds = document.getElementById('status-google-ads');
const statusConexaoGoogleAds = document.getElementById('ga-status-conexao');

async function carregarConfigGoogleAds() {
  const config = await window.api.obterConfig();
  document.getElementById('ga-developer-token').value = config.googleAdsDeveloperToken || '';
  document.getElementById('ga-client-id').value = config.googleAdsClientId || '';
  document.getElementById('ga-client-secret').value = config.googleAdsClientSecret || '';
  document.getElementById('ga-customer-id').value = config.googleAdsCustomerId || '';
  document.getElementById('ga-conversion-action-id').value = config.googleAdsConversionActionId || '';
  document.getElementById('ga-nome-conversao').value = config.googleAdsNomeConversao || 'Contrato_Fechado';
  document.getElementById('ga-moeda').value = config.googleAdsMoeda || 'BRL';
  statusConexaoGoogleAds.textContent = config.googleAdsRefreshToken ? 'Conectado ✅' : 'Não conectado';
}

function dadosFormularioGoogleAds() {
  return {
    googleAdsDeveloperToken: document.getElementById('ga-developer-token').value.trim(),
    googleAdsClientId: document.getElementById('ga-client-id').value.trim(),
    googleAdsClientSecret: document.getElementById('ga-client-secret').value.trim(),
    googleAdsCustomerId: document.getElementById('ga-customer-id').value.trim(),
    googleAdsConversionActionId: document.getElementById('ga-conversion-action-id').value.trim(),
    googleAdsNomeConversao: document.getElementById('ga-nome-conversao').value.trim(),
    googleAdsMoeda: document.getElementById('ga-moeda').value.trim() || 'BRL',
  };
}

formGoogleAds.addEventListener('submit', async (e) => {
  e.preventDefault();
  await window.api.salvarConfig(dadosFormularioGoogleAds());
  statusGoogleAds.textContent = 'Dados do Google Ads salvos.';
  setTimeout(() => (statusGoogleAds.textContent = ''), 3000);
});

document.getElementById('btn-conectar-google').addEventListener('click', async () => {
  const { googleAdsClientId, googleAdsClientSecret } = dadosFormularioGoogleAds();
  if (!googleAdsClientId || !googleAdsClientSecret) {
    statusGoogleAds.textContent = 'Preencha o Client ID e o Client Secret antes de conectar.';
    return;
  }
  await window.api.salvarConfig(dadosFormularioGoogleAds());
  statusGoogleAds.textContent = 'Abrindo o navegador para autorização... conclua o login e volte aqui.';
  try {
    await window.api.autorizarGoogleAds(googleAdsClientId, googleAdsClientSecret);
    statusGoogleAds.textContent = 'Conectado ao Google Ads com sucesso!';
    await carregarConfigGoogleAds();
  } catch (err) {
    statusGoogleAds.textContent = `Erro ao conectar: ${err.message}`;
  }
});

document.getElementById('btn-testar-google-ads').addEventListener('click', async () => {
  statusGoogleAds.textContent = 'Testando conexão...';
  try {
    await window.api.testarGoogleAds();
    statusGoogleAds.textContent = 'Conexão com Google Ads funcionando!';
  } catch (err) {
    statusGoogleAds.textContent = `Erro: ${err.message}`;
  }
});

document.getElementById('btn-desconectar-google').addEventListener('click', async () => {
  if (!confirm('Desconectar a conta do Google Ads?')) return;
  await window.api.desconectarGoogleAds();
  await carregarConfigGoogleAds();
  statusGoogleAds.textContent = 'Desconectado.';
  setTimeout(() => (statusGoogleAds.textContent = ''), 3000);
});

document.getElementById('link-google-cloud-console').addEventListener('click', (e) => {
  e.preventDefault();
  window.api.abrirExterno('https://console.cloud.google.com/apis/credentials');
});

carregarPrazos();
carregarConfig();
carregarClientes();
carregarModelos();
carregarConfigGoogleAds();
