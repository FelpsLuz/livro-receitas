'use strict';

// ---------------------------------------------------------------
// Utilitarios
// ---------------------------------------------------------------

/**
 * Cria elementos via DOM em vez de montar HTML por concatenacao de texto.
 * Com textContent/setAttribute o navegador nunca interpreta o conteudo como
 * markup, entao nome de cliente com "<" ou mensagem de erro da API com aspas
 * simplesmente aparecem como texto - a classe inteira de bug de escape some.
 */
function el(tag, props = {}, ...filhos) {
  const node = document.createElement(tag);
  for (const [chave, valor] of Object.entries(props)) {
    if (valor === null || valor === undefined) continue;
    if (chave === 'class') node.className = valor;
    else if (chave === 'text') node.textContent = valor;
    else if (chave.startsWith('on') && typeof valor === 'function') {
      node.addEventListener(chave.slice(2).toLowerCase(), valor);
    } else if (chave === 'style') {
      // O CSP da pagina bloqueia atributo style inline; aplicar via CSSOM e
      // permitido e evita ter que afrouxar a politica de seguranca.
      for (const regra of String(valor).split(';')) {
        const [prop, ...resto] = regra.split(':');
        if (prop && resto.length) node.style.setProperty(prop.trim(), resto.join(':').trim());
      }
    } else node.setAttribute(chave, valor);
  }
  for (const filho of filhos.flat()) {
    if (filho === null || filho === undefined || filho === false) continue;
    node.append(typeof filho === 'object' ? filho : document.createTextNode(String(filho)));
  }
  return node;
}

const $ = (id) => document.getElementById(id);

const brl = (v) =>
  (Number(v) || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
const brlExato = (v) => (Number(v) || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const numero = (v) => (Number(v) || 0).toLocaleString('pt-BR');
const pct = (v) => (v === null || v === undefined ? '—' : `${Number(v).toFixed(0)}%`);

function dataBR(iso) {
  if (!iso) return '—';
  const [ano, mes, dia] = String(iso).slice(0, 10).split('-');
  return `${dia}/${mes}/${ano}`;
}
function dataHoraBR(iso) {
  return iso ? new Date(iso).toLocaleString('pt-BR') : '—';
}

function mostrarStatus(elemento, texto, ehErro = false, limpaApos = 4000) {
  elemento.textContent = texto;
  elemento.classList.toggle('erro', ehErro);
  if (limpaApos) setTimeout(() => { elemento.textContent = ''; }, limpaApos);
}

function linhaVazia(colunas, texto) {
  return el('tr', {}, el('td', { colspan: colunas, class: 'vazio', text: texto }));
}

async function comErro(elementoStatus, mensagemOcupado, fn) {
  try {
    if (mensagemOcupado) mostrarStatus(elementoStatus, mensagemOcupado, false, 0);
    const resultado = await fn();
    return { ok: true, resultado };
  } catch (e) {
    mostrarStatus(elementoStatus, e.message, true, 8000);
    return { ok: false, erro: e };
  }
}

// ---------------------------------------------------------------
// Navegacao entre abas
// ---------------------------------------------------------------

const recarregadoresPorAba = {};

document.querySelectorAll('.tab-btn').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));
    btn.classList.add('active');
    $(`tab-${btn.dataset.tab}`).classList.add('active');
    const recarregar = recarregadoresPorAba[btn.dataset.tab];
    if (recarregar) recarregar();
  });
});

let ETAPAS = [];
let clientesCache = [];

// ===============================================================
// DASHBOARD
// ===============================================================

const statusDashboard = $('status-dashboard');

function montarCard({ rotulo, valor, sub, classe, classeValor }) {
  return el(
    'div',
    { class: `card ${classe || ''}` },
    el('div', { class: 'rotulo', text: rotulo }),
    el('div', { class: `valor ${classeValor || ''}`, text: valor }),
    sub ? el('div', { class: 'sub', text: sub }) : null
  );
}

function renderizarCards(d) {
  const { resumo } = d;
  const cards = $('dash-cards');
  cards.replaceChildren();

  if (resumo.temDadosDeCusto) {
    cards.append(
      montarCard({ rotulo: 'Investido em anúncios', valor: brl(resumo.investimento), classe: 'destaque' })
    );
  }
  cards.append(
    montarCard({
      rotulo: 'Receita em contratos',
      valor: brl(resumo.receita),
      sub: `${resumo.contratosFechados} contrato(s) fechado(s)`,
      classe: 'positivo',
    })
  );

  if (resumo.temDadosDeCusto) {
    cards.append(
      montarCard({
        rotulo: 'Lucro',
        valor: brl(resumo.lucro),
        classe: resumo.lucro >= 0 ? 'positivo' : 'negativo',
        classeValor: resumo.lucro >= 0 ? 'positivo' : 'negativo',
      }),
      montarCard({
        rotulo: 'ROI',
        valor: pct(resumo.roi),
        sub: resumo.roas ? `${resumo.roas.toFixed(2)}x de retorno` : null,
        classe: (resumo.roi || 0) >= 0 ? 'positivo' : 'negativo',
        classeValor: (resumo.roi || 0) >= 0 ? 'positivo' : 'negativo',
      }),
      montarCard({
        rotulo: 'Custo por contrato',
        valor: resumo.cac === null ? '—' : brl(resumo.cac),
      })
    );
  }

  cards.append(
    montarCard({ rotulo: 'Novos leads', valor: numero(resumo.novosLeads) }),
    montarCard({ rotulo: 'Ticket médio', valor: brl(resumo.ticketMedio) }),
    montarCard({
      rotulo: 'Taxa de conversão',
      valor: pct(resumo.taxaConversao),
      sub: 'lead → contrato',
    })
  );
}

function renderizarFunil(d) {
  const container = $('dash-funil');
  container.replaceChildren();
  const maximo = Math.max(...d.funil.map((f) => f.quantidade), 1);

  if (d.funil.every((f) => f.quantidade === 0)) {
    container.append(el('p', { class: 'nota', text: 'Nenhum movimento no funil neste período.' }));
    return;
  }

  for (const etapa of d.funil) {
    container.append(
      el(
        'div',
        { class: 'funil-etapa' },
        el('div', { class: 'nome', text: etapa.rotulo }),
        el(
          'div',
          { class: 'funil-barra-fundo' },
          el('div', { class: 'funil-barra', style: `width:${(etapa.quantidade / maximo) * 100}%` })
        ),
        el('div', {
          class: 'qtd',
          text: `${etapa.quantidade}${etapa.valor ? ` · ${brl(etapa.valor)}` : ''}`,
        })
      )
    );
  }
}

function renderizarCampanhas(d) {
  const tbody = $('dash-campanhas');
  tbody.replaceChildren();
  if (!d.campanhas.length) {
    tbody.append(linhaVazia(8, 'Sincronize os custos do Google Ads para ver esta análise.'));
    return;
  }
  for (const c of d.campanhas) {
    tbody.append(
      el(
        'tr',
        {},
        el('td', { text: c.campanha }),
        el('td', { class: 'num', text: c.custo ? brl(c.custo) : '—' }),
        el('td', { class: 'num', text: numero(c.cliques) }),
        el('td', { class: 'num', text: numero(c.leads) }),
        el('td', { class: 'num', text: numero(c.contratos) }),
        el('td', { class: 'num', text: brl(c.receita) }),
        el('td', { class: 'num', text: c.cac === null ? '—' : brl(c.cac) }),
        el(
          'td',
          { class: 'num' },
          c.roi === null
            ? '—'
            : el('span', { class: `pill ${c.roi >= 0 ? 'ok' : 'vencido'}`, text: pct(c.roi) })
        )
      )
    );
  }
}

function renderizarPalavras(d) {
  const tbody = $('dash-palavras');
  tbody.replaceChildren();
  if (!d.palavrasChave.length) {
    tbody.append(
      linhaVazia(4, 'Sem atribuição de palavra-chave ainda. Requer GCLID nos clientes + sincronização do Google Ads.')
    );
    return;
  }
  for (const p of d.palavrasChave) {
    tbody.append(
      el(
        'tr',
        {},
        el('td', { text: p.palavraChave }),
        el('td', { class: 'num', text: numero(p.leads) }),
        el('td', { class: 'num', text: numero(p.contratos) }),
        el('td', { class: 'num', text: brl(p.receita) })
      )
    );
  }
}

function renderizarSaudeConversoes(d) {
  const c = d.conversoes;
  $('dash-conversoes').replaceChildren(
    el('div', {}, el('b', { text: numero(c.enviadas) }), 'Enviadas ao Google'),
    el('div', {}, el('b', { text: numero(c.pendentes) }), 'Na fila'),
    el('div', {}, el('b', { text: numero(c.falhas) }), 'Falharam'),
    el(
      'div',
      {},
      el('b', { text: d.metricasSincronizadasEm ? '✅' : '—' }),
      d.metricasSincronizadasEm ? `Custos de ${dataHoraBR(d.metricasSincronizadasEm)}` : 'Custos não sincronizados'
    )
  );
}

async function carregarDashboard() {
  const dias = Number($('dash-periodo').value);
  const { ok, resultado } = await comErro(statusDashboard, null, () => window.api.obterDashboard(dias));
  if (!ok) return;

  renderizarCards(resultado);
  renderizarFunil(resultado);
  renderizarCampanhas(resultado);
  renderizarPalavras(resultado);
  renderizarSaudeConversoes(resultado);
  $('dash-aviso-custos').classList.toggle('oculto', resultado.resumo.temDadosDeCusto);
}

$('dash-periodo').addEventListener('change', carregarDashboard);
$('btn-atualizar-dashboard').addEventListener('click', carregarDashboard);

$('btn-sincronizar-ads').addEventListener('click', async () => {
  const dias = Number($('dash-periodo').value);
  const { ok } = await comErro(statusDashboard, 'Buscando dados no Google Ads...', () =>
    window.api.sincronizarAds(dias)
  );
  if (ok) mostrarStatus(statusDashboard, 'Custos sincronizados com sucesso.');
  carregarDashboard();
});

$('btn-reprocessar-conversoes').addEventListener('click', async () => {
  const { ok, resultado } = await comErro(statusDashboard, 'Reenviando...', () =>
    window.api.reprocessarConversoes()
  );
  if (ok) {
    mostrarStatus(
      statusDashboard,
      `${resultado.enviadas} enviada(s), ${resultado.pendentes} ainda pendente(s), ${resultado.falhas} falha(s).`
    );
  }
  carregarDashboard();
});

recarregadoresPorAba.dashboard = carregarDashboard;

// ===============================================================
// PRAZOS
// ===============================================================

const statusVerificacao = $('status-verificacao');
let prazosCache = [];

const ROTULO_SITUACAO = {
  vencido: 'Vencido',
  hoje: 'Vence hoje',
  urgente: 'Urgente',
  atencao: 'Atenção',
  ok: 'Em dia',
  concluido: 'Concluído',
};

function prazosFiltrados() {
  const busca = $('busca-prazos').value.trim().toLowerCase();
  const ocultarConcluidos = $('filtro-ocultar-concluidos').checked;

  return prazosCache
    .filter((p) => !(ocultarConcluidos && p.status === 'Concluido'))
    .filter((p) => {
      if (!busca) return true;
      return [p.processo, p.cliente, p.acao, p.advogadoResponsavel]
        .filter(Boolean)
        .some((campo) => String(campo).toLowerCase().includes(busca));
    })
    .sort((a, b) => {
      if (a.status === 'Concluido' && b.status !== 'Concluido') return 1;
      if (b.status === 'Concluido' && a.status !== 'Concluido') return -1;
      return new Date(a.dataVencimento) - new Date(b.dataVencimento);
    });
}

function renderizarPrazos() {
  const tbody = $('corpo-tabela-prazos');
  tbody.replaceChildren();
  const lista = prazosFiltrados();

  if (!lista.length) {
    tbody.append(linhaVazia(8, prazosCache.length ? 'Nenhum prazo corresponde ao filtro.' : 'Nenhum prazo cadastrado.'));
    return;
  }

  for (const prazo of lista) {
    const concluido = prazo.status === 'Concluido';
    const acoes = el('div', { class: 'acoes' });

    acoes.append(el('button', { class: 'secundario', text: 'Editar', onClick: () => abrirEdicaoPrazo(prazo.id) }));
    acoes.append(
      concluido
        ? el('button', { class: 'secundario', text: 'Reabrir', onClick: () => acaoPrazo(() => window.api.reabrirPrazo(prazo.id)) })
        : el('button', { class: 'sucesso', text: 'Concluir', onClick: () => acaoPrazo(() => window.api.concluirPrazo(prazo.id)) })
    );
    acoes.append(
      el('button', {
        class: 'perigo',
        text: 'Excluir',
        onClick: () => {
          if (confirm(`Excluir o prazo do processo ${prazo.processo}?`)) {
            acaoPrazo(() => window.api.excluirPrazo(prazo.id));
          }
        },
      })
    );

    tbody.append(
      el(
        'tr',
        {},
        el('td', { text: prazo.processo }),
        el('td', { text: prazo.cliente || '—' }),
        el('td', { text: prazo.acao }),
        el('td', { text: prazo.advogadoResponsavel || '—' }),
        el('td', { text: dataBR(prazo.dataVencimento) }),
        el('td', { class: 'num', text: concluido ? '—' : prazo.dias }),
        el('td', {}, el('span', { class: `pill ${prazo.situacao}`, text: ROTULO_SITUACAO[prazo.situacao] || prazo.situacao })),
        el('td', {}, acoes)
      )
    );
  }
}

async function carregarPrazos() {
  prazosCache = await window.api.listarPrazos();
  renderizarPrazos();
}

async function acaoPrazo(fn) {
  await comErro(statusVerificacao, null, fn);
  carregarPrazos();
}

$('busca-prazos').addEventListener('input', renderizarPrazos);
$('filtro-ocultar-concluidos').addEventListener('change', renderizarPrazos);
$('btn-atualizar-prazos').addEventListener('click', async () => {
  await carregarPrazos();
  mostrarStatus(statusVerificacao, 'Lista atualizada.', false, 2000);
});

$('btn-verificar-agora').addEventListener('click', async () => {
  const { ok, resultado } = await comErro(statusVerificacao, 'Verificando...', () => window.api.verificarAgora());
  if (ok) {
    mostrarStatus(
      statusVerificacao,
      resultado.length ? `${resultado.length} alerta(s) disparado(s).` : 'Nenhum alerta pendente hoje.'
    );
  }
  carregarPrazos();
});

// --- modal de prazo ---

const modalPrazo = $('modal-prazo');
const formPrazo = $('form-prazo');

function preencherSelectClientes() {
  const select = $('prazo-cliente-id');
  const atual = select.value;
  select.replaceChildren(el('option', { value: '', text: '— Sem cliente vinculado —' }));
  for (const c of clientesCache) {
    select.append(el('option', { value: c.id, text: c.nome || '(sem nome)' }));
  }
  select.value = atual;
}

function abrirModalPrazo(titulo) {
  $('modal-titulo').textContent = titulo;
  preencherSelectClientes();
  modalPrazo.classList.remove('oculto');
}

function fecharModalPrazo() {
  modalPrazo.classList.add('oculto');
  formPrazo.reset();
  $('prazo-id').value = '';
}

$('btn-novo-prazo').addEventListener('click', () => {
  formPrazo.reset();
  $('prazo-id').value = '';
  abrirModalPrazo('Novo Prazo');
});
$('btn-cancelar-prazo').addEventListener('click', fecharModalPrazo);

function abrirEdicaoPrazo(id) {
  const prazo = prazosCache.find((p) => p.id === id);
  if (!prazo) return;
  $('prazo-id').value = prazo.id;
  $('prazo-processo').value = prazo.processo || '';
  $('prazo-acao').value = prazo.acao || '';
  $('prazo-advogado').value = prazo.advogadoResponsavel || '';
  $('prazo-data').value = (prazo.dataVencimento || '').slice(0, 10);
  abrirModalPrazo('Editar Prazo');
  $('prazo-cliente-id').value = prazo.clienteId || '';
}

formPrazo.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = $('prazo-id').value;
  const clienteId = $('prazo-cliente-id').value || null;
  const cliente = clientesCache.find((c) => c.id === clienteId);

  const dados = {
    processo: $('prazo-processo').value.trim(),
    clienteId,
    cliente: cliente ? cliente.nome : '',
    acao: $('prazo-acao').value.trim(),
    advogadoResponsavel: $('prazo-advogado').value.trim(),
    dataVencimento: $('prazo-data').value,
  };

  const { ok } = await comErro(statusVerificacao, null, () =>
    id ? window.api.atualizarPrazo(id, dados) : window.api.adicionarPrazo(dados)
  );
  if (ok) {
    fecharModalPrazo();
    carregarPrazos();
  }
});

recarregadoresPorAba.prazos = carregarPrazos;

// ===============================================================
// CLIENTES
// ===============================================================

const statusClientes = $('status-clientes');

function etapaPorId(id) {
  return ETAPAS.find((e) => e.id === id) || { id, rotulo: id, ordem: 0 };
}

function classeDaEtapa(id) {
  if (id === 'ContratoFechado') return 'ok';
  if (id === 'Perdido') return 'vencido';
  if (id === 'Lead') return 'neutro';
  return 'roxo';
}

function extrairGclid(valor) {
  const texto = (valor || '').trim();
  const m = texto.match(/GCLID[:\s]*([A-Za-z0-9_\-.]+)/i);
  return m ? m[1] : texto;
}

function clientesFiltrados() {
  const busca = $('busca-clientes').value.trim().toLowerCase();
  const etapa = $('filtro-etapa').value;

  return clientesCache
    .filter((c) => !etapa || c.etapa === etapa)
    .filter((c) => {
      if (!busca) return true;
      return [c.nome, c.cpf, c.telefone, c.gclid]
        .filter(Boolean)
        .some((campo) => String(campo).toLowerCase().includes(busca));
    })
    .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
}

function celulaConversao(cliente) {
  const r = cliente.resumoConversoes || {};
  if (!cliente.gclid) return el('span', { class: 'pill neutro', text: 'Sem GCLID' });
  if (r.falhas) return el('span', { class: 'pill falhou', title: r.ultimoErro || '', text: `${r.falhas} falha(s)` });
  if (r.pendentes) return el('span', { class: 'pill pendente', title: r.ultimoErro || '', text: `${r.pendentes} na fila` });
  if (r.enviadas) return el('span', { class: 'pill enviada', text: `${r.enviadas} enviada(s)` });
  return el('span', { class: 'pill neutro', text: '—' });
}

function proximaEtapaDe(idEtapa) {
  const atual = etapaPorId(idEtapa);
  const seguintes = ETAPAS.filter((e) => e.ordem > atual.ordem && e.ordem >= 0).sort((a, b) => a.ordem - b.ordem);
  return seguintes[0] || null;
}

function renderizarClientes() {
  const tbody = $('corpo-tabela-clientes');
  tbody.replaceChildren();
  const lista = clientesFiltrados();

  if (!lista.length) {
    tbody.append(linhaVazia(7, clientesCache.length ? 'Nenhum cliente corresponde ao filtro.' : 'Nenhum cliente cadastrado.'));
    return;
  }

  for (const cliente of lista) {
    const acoes = el('div', { class: 'acoes' });
    const proxima = proximaEtapaDe(cliente.etapa);

    acoes.append(el('button', { text: 'Ficha', onClick: () => abrirFicha(cliente.id) }));
    if (proxima) {
      acoes.append(
        el('button', {
          class: 'sucesso',
          text: `→ ${proxima.rotulo}`,
          onClick: () => avancarEtapaCliente(cliente, proxima.id),
        })
      );
    }
    acoes.append(el('button', { class: 'secundario', text: 'Contrato', onClick: () => abrirModalContrato(cliente.id) }));
    acoes.append(el('button', { class: 'secundario', text: 'Editar', onClick: () => abrirEdicaoCliente(cliente.id) }));
    acoes.append(
      el('button', {
        class: 'perigo',
        text: 'Excluir',
        onClick: async () => {
          if (!confirm(`Excluir ${cliente.nome} e todo o histórico dele?`)) return;
          await comErro(statusClientes, null, () => window.api.excluirCliente(cliente.id));
          carregarClientes();
        },
      })
    );

    const etapa = etapaPorId(cliente.etapa);
    tbody.append(
      el(
        'tr',
        {},
        el('td', {}, el('b', { text: cliente.nome || '(sem nome)' }), cliente.prazosAbertos
          ? el('div', { class: 'sub', style: 'font-size:11px;color:#6b7280', text: `${cliente.prazosAbertos} prazo(s) aberto(s)` })
          : null),
        el('td', { text: cliente.telefone || '—' }),
        el('td', { class: 'num', text: brlExato(cliente.valorHonorarios) }),
        el('td', {}, el('span', { class: `pill ${classeDaEtapa(cliente.etapa)}`, text: etapa.rotulo })),
        el('td', { text: cliente.gclid ? 'Google Ads' : 'Orgânico/Indicação' }),
        el('td', {}, celulaConversao(cliente)),
        el('td', {}, acoes)
      )
    );
  }
}

async function carregarClientes() {
  clientesCache = await window.api.listarClientes();
  renderizarClientes();
}

async function avancarEtapaCliente(cliente, idEtapa) {
  const etapa = etapaPorId(idEtapa);
  if (!confirm(`Mover ${cliente.nome} para "${etapa.rotulo}"?`)) return;

  const { ok, resultado } = await comErro(statusClientes, 'Atualizando...', () =>
    window.api.avancarEtapa(cliente.id, idEtapa)
  );
  if (ok) {
    if (resultado.aviso) {
      mostrarStatus(statusClientes, `Etapa atualizada. Conversão não enviada: ${resultado.aviso}`, true, 8000);
    } else if (resultado.enviadas) {
      mostrarStatus(statusClientes, `Etapa atualizada e ${resultado.enviadas} conversão(ões) enviada(s) ao Google Ads.`);
    } else {
      mostrarStatus(statusClientes, 'Etapa atualizada.');
    }
  }
  carregarClientes();
}

$('busca-clientes').addEventListener('input', renderizarClientes);
$('filtro-etapa').addEventListener('change', renderizarClientes);
$('btn-atualizar-clientes').addEventListener('click', async () => {
  await carregarClientes();
  mostrarStatus(statusClientes, 'Lista atualizada.', false, 2000);
});

// --- modal de cliente ---

const modalCliente = $('modal-cliente');
const formCliente = $('form-cliente');

function fecharModalCliente() {
  modalCliente.classList.add('oculto');
  formCliente.reset();
  $('cliente-id').value = '';
}

$('btn-novo-cliente').addEventListener('click', () => {
  formCliente.reset();
  $('cliente-id').value = '';
  $('modal-cliente-titulo').textContent = 'Novo Cliente';
  modalCliente.classList.remove('oculto');
});
$('btn-cancelar-cliente').addEventListener('click', fecharModalCliente);

function abrirEdicaoCliente(id) {
  const c = clientesCache.find((x) => x.id === id);
  if (!c) return;
  $('modal-cliente-titulo').textContent = 'Editar Cliente';
  $('cliente-id').value = c.id;
  $('cliente-nome').value = c.nome || '';
  $('cliente-cpf').value = c.cpf || '';
  $('cliente-telefone').value = c.telefone || '';
  $('cliente-endereco').value = c.endereco || '';
  $('cliente-honorarios').value = c.valorHonorarios || '';
  $('cliente-forma-pagamento').value = c.formaPagamento || '';
  $('cliente-gclid').value = c.gclid || '';
  modalCliente.classList.remove('oculto');
}

formCliente.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = $('cliente-id').value;
  const dados = {
    nome: $('cliente-nome').value.trim(),
    cpf: $('cliente-cpf').value.trim(),
    telefone: $('cliente-telefone').value.trim(),
    endereco: $('cliente-endereco').value.trim(),
    valorHonorarios: parseFloat($('cliente-honorarios').value) || 0,
    formaPagamento: $('cliente-forma-pagamento').value.trim(),
    gclid: extrairGclid($('cliente-gclid').value),
  };

  const { ok } = await comErro(statusClientes, null, () =>
    id ? window.api.atualizarCliente(id, dados) : window.api.adicionarCliente(dados)
  );
  if (ok) {
    fecharModalCliente();
    carregarClientes();
  }
});

// --- ficha 360 ---

function itemFicha(rotulo, valor) {
  return el('div', { class: 'ficha-item' },
    el('div', { class: 'rotulo', text: rotulo }),
    el('div', { class: 'valor', text: valor || '—' })
  );
}

function secaoFicha(titulo, ...conteudo) {
  return el('div', { class: 'ficha-secao' }, el('h3', { text: titulo }), ...conteudo);
}

async function abrirFicha(clienteId) {
  const { ok, resultado } = await comErro(statusClientes, null, () => window.api.obterFichaCliente(clienteId));
  if (!ok) return;

  const { cliente, prazos, contratos, conversoes, impedimentoConversao } = resultado;
  $('ficha-nome').textContent = cliente.nome || '(sem nome)';
  const corpo = $('ficha-conteudo');
  corpo.replaceChildren();

  corpo.append(
    secaoFicha(
      'Dados',
      el('div', { class: 'ficha-grid' },
        itemFicha('CPF', cliente.cpf),
        itemFicha('Telefone', cliente.telefone),
        itemFicha('Honorários', brlExato(cliente.valorHonorarios)),
        itemFicha('Forma de pagamento', cliente.formaPagamento),
        itemFicha('Etapa', etapaPorId(cliente.etapa).rotulo),
        itemFicha('Origem', cliente.gclid ? 'Google Ads' : 'Orgânico/Indicação'),
        itemFicha('GCLID', cliente.gclid),
        itemFicha('Cadastrado em', dataHoraBR(cliente.createdAt))
      )
    )
  );

  const historico = el('ul', { class: 'lista' });
  for (const etapa of ETAPAS.filter((e) => e.ordem >= 0).sort((a, b) => a.ordem - b.ordem)) {
    const quando = (cliente.etapasAtingidas || {})[etapa.id];
    if (!quando) continue;
    historico.append(el('li', {}, el('span', { text: etapa.rotulo }), el('span', { text: dataHoraBR(quando) })));
  }
  if (historico.childElementCount) corpo.append(secaoFicha('Linha do tempo', historico));

  const listaPrazos = el('ul', { class: 'lista' });
  if (prazos.length) {
    for (const p of prazos) {
      listaPrazos.append(
        el('li', {},
          el('span', { text: `${p.processo} — ${p.acao}` }),
          el('span', {},
            el('span', { class: `pill ${p.situacao}`, text: ROTULO_SITUACAO[p.situacao] || p.situacao }),
            ` ${dataBR(p.dataVencimento)}`
          )
        )
      );
    }
  } else {
    listaPrazos.append(el('li', { class: 'nota', text: 'Nenhum prazo vinculado.' }));
  }
  corpo.append(secaoFicha(`Prazos (${prazos.length})`, listaPrazos));

  const listaContratos = el('ul', { class: 'lista' });
  if (contratos.length) {
    for (const c of contratos.sort((a, b) => new Date(b.geradoEm) - new Date(a.geradoEm))) {
      listaContratos.append(
        el('li', {},
          el('span', { text: `${c.templateNome} — ${dataHoraBR(c.geradoEm)}` }),
          el('button', { class: 'secundario', text: 'Abrir pasta', onClick: () => window.api.abrirCaminho(c.arquivoDocx) })
        )
      );
    }
  } else {
    listaContratos.append(el('li', { class: 'nota', text: 'Nenhum contrato gerado.' }));
  }
  corpo.append(secaoFicha(`Contratos (${contratos.length})`, listaContratos));

  const listaConv = el('ul', { class: 'lista' });
  if (impedimentoConversao) {
    listaConv.append(el('li', { class: 'nota', text: `⚠️ ${impedimentoConversao}` }));
  }
  if (conversoes.length) {
    for (const c of conversoes) {
      listaConv.append(
        el('li', {},
          el('span', { text: `${etapaPorId(c.etapa).rotulo} · ${brlExato(c.valor)}` }),
          el('span', { class: `pill ${c.status === 'enviada' ? 'enviada' : c.status === 'falhou' ? 'falhou' : 'pendente'}`,
            title: c.erro || '', text: c.status })
        )
      );
    }
  } else if (!impedimentoConversao) {
    listaConv.append(el('li', { class: 'nota', text: 'Nenhuma conversão enviada ainda.' }));
  }
  corpo.append(secaoFicha('Conversões Google Ads', listaConv));

  $('modal-ficha').classList.remove('oculto');
}

$('btn-fechar-ficha').addEventListener('click', () => $('modal-ficha').classList.add('oculto'));

recarregadoresPorAba.clientes = carregarClientes;

// ===============================================================
// MODELOS DE CONTRATO
// ===============================================================

const statusModelos = $('status-modelos');

async function carregarModelos() {
  const templates = await window.api.listarTemplates();
  const tbody = $('corpo-tabela-modelos');
  tbody.replaceChildren();

  if (!templates.length) {
    tbody.append(linhaVazia(4, 'Nenhum modelo importado.'));
    return templates;
  }

  for (const t of templates) {
    const tags = el('td', {});
    if (t.erro) tags.append(el('span', { class: 'pill falhou', text: t.erro }));
    else if (t.tags && t.tags.length) t.tags.forEach((tag) => tags.append(el('span', { class: 'tag-pill', text: tag })));
    else tags.append(el('span', { class: 'nota', text: 'Nenhuma tag encontrada' }));

    tbody.append(
      el('tr', {},
        el('td', { text: t.nome }),
        tags,
        el('td', { text: dataHoraBR(t.importadoEm) }),
        el('td', {}, el('div', { class: 'acoes' },
          el('button', {
            class: 'perigo', text: 'Excluir',
            onClick: async () => {
              if (!confirm(`Excluir o modelo "${t.nome}"?`)) return;
              await comErro(statusModelos, null, () => window.api.excluirTemplate(t.id));
              carregarModelos();
            },
          })
        ))
      )
    );
  }
  return templates;
}

$('btn-importar-modelo').addEventListener('click', async () => {
  const { ok, resultado } = await comErro(statusModelos, null, () => window.api.importarTemplate());
  if (ok && resultado) mostrarStatus(statusModelos, `Modelo "${resultado.nome}" importado.`);
  carregarModelos();
});
$('btn-atualizar-modelos').addEventListener('click', async () => {
  await carregarModelos();
  mostrarStatus(statusModelos, 'Lista atualizada.', false, 2000);
});

recarregadoresPorAba.modelos = carregarModelos;

// ===============================================================
// GERAR CONTRATO
// ===============================================================

const modalContrato = $('modal-contrato');
const selectModelo = $('contrato-select-modelo');
const resultadoContrato = $('contrato-resultado');
const resultadoAcoes = $('contrato-resultado-acoes');

let clienteAtualContrato = null;
let ultimoContratoGerado = null;

async function abrirModalContrato(clienteId) {
  const cliente = clientesCache.find((c) => c.id === clienteId);
  if (!cliente) return;

  clienteAtualContrato = cliente;
  ultimoContratoGerado = null;
  $('contrato-cliente-nome').textContent = cliente.nome;
  resultadoContrato.classList.add('oculto');
  resultadoAcoes.classList.add('oculto');

  const templates = await window.api.listarTemplates();
  selectModelo.replaceChildren();
  for (const t of templates) selectModelo.append(el('option', { value: t.id, text: t.nome }));

  await carregarHistoricoContratos(cliente.id);
  modalContrato.classList.remove('oculto');
}

async function carregarHistoricoContratos(clienteId) {
  const historico = await window.api.listarContratosPorCliente(clienteId);
  const lista = $('lista-historico-contratos');
  lista.replaceChildren();

  if (!historico.length) {
    lista.append(el('li', { class: 'nota', text: 'Nenhum contrato gerado ainda.' }));
    return;
  }
  for (const r of historico.sort((a, b) => new Date(b.geradoEm) - new Date(a.geradoEm))) {
    lista.append(
      el('li', {},
        el('span', { text: `${r.templateNome} — ${dataHoraBR(r.geradoEm)}${r.arquivoPdf ? ' (PDF)' : ''}` }),
        el('button', { class: 'secundario', text: 'Abrir pasta', onClick: () => window.api.abrirCaminho(r.arquivoDocx) })
      )
    );
  }
}

$('btn-gerar-contrato').addEventListener('click', async () => {
  if (!clienteAtualContrato || !selectModelo.value) return;
  resultadoContrato.classList.remove('oculto');
  resultadoContrato.textContent = 'Gerando contrato...';
  resultadoAcoes.classList.add('oculto');

  try {
    const registro = await window.api.gerarContrato(clienteAtualContrato.id, selectModelo.value);
    ultimoContratoGerado = registro;
    resultadoContrato.textContent = registro.arquivoPdf
      ? `Contrato gerado em .docx e .pdf: ${registro.arquivoDocx}`
      : `Contrato gerado (.docx): ${registro.arquivoDocx}\nPara gerar PDF automaticamente, instale o LibreOffice.`;
    resultadoAcoes.classList.remove('oculto');
    await carregarHistoricoContratos(clienteAtualContrato.id);
  } catch (e) {
    resultadoContrato.textContent = `Erro ao gerar contrato: ${e.message}`;
  }
});

$('btn-abrir-pasta-contrato').addEventListener('click', () => {
  if (ultimoContratoGerado) window.api.abrirCaminho(ultimoContratoGerado.arquivoDocx);
});

$('btn-abrir-whatsapp-contrato').addEventListener('click', async () => {
  if (!clienteAtualContrato) return;
  await comErro(
    statusClientes,
    null,
    () => window.api.abrirWhatsapp(
      clienteAtualContrato.telefone,
      `Olá ${clienteAtualContrato.nome}, segue o contrato de honorários. Qualquer dúvida, estou à disposição!`
    )
  );
});

$('btn-fechar-contrato').addEventListener('click', () => {
  modalContrato.classList.add('oculto');
  clienteAtualContrato = null;
  ultimoContratoGerado = null;
});

// ===============================================================
// CONFIGURAÇÕES
// ===============================================================

const statusConfig = $('status-config');
const statusGoogleAds = $('status-google-ads');

async function carregarConfig() {
  const c = await window.api.obterConfig();

  $('cfg-token').value = c.telegramBotToken || '';
  $('cfg-chatid').value = c.telegramChatId || '';
  $('cfg-horario').value = c.horarioVerificacao || '08:00';
  $('cfg-ativas').checked = c.notificacoesAtivas !== false;
  $('cfg-autostart').checked = c.iniciarComWindows !== false;

  $('ga-developer-token').value = c.googleAdsDeveloperToken || '';
  $('ga-client-id').value = c.googleAdsClientId || '';
  $('ga-client-secret').value = c.googleAdsClientSecret || '';
  $('ga-customer-id').value = c.googleAdsCustomerId || '';
  $('ga-login-customer-id').value = c.googleAdsLoginCustomerId || '';
  $('ga-acao-contrato').value = c.googleAdsAcaoContrato || '';
  $('ga-acao-qualificado').value = c.googleAdsAcaoQualificado || '';
  $('ga-valor-qualificado').value = c.googleAdsValorQualificado || '';
  $('ga-acao-reuniao').value = c.googleAdsAcaoReuniao || '';
  $('ga-valor-reuniao').value = c.googleAdsValorReuniao || '';
  $('ga-funil-completo').checked = c.googleAdsEnviarFunilCompleto !== false;
  $('ga-moeda').value = c.googleAdsMoeda || 'BRL';
  $('ga-api-version').value = c.googleAdsApiVersion || '';
  $('ga-status-conexao').textContent = c.googleAdsRefreshToken ? 'Conectado ✅' : 'Não conectado';
}

$('form-config').addEventListener('submit', async (e) => {
  e.preventDefault();
  const { ok } = await comErro(statusConfig, null, () =>
    window.api.salvarConfig({
      telegramBotToken: $('cfg-token').value.trim(),
      telegramChatId: $('cfg-chatid').value.trim(),
      horarioVerificacao: $('cfg-horario').value,
      notificacoesAtivas: $('cfg-ativas').checked,
      iniciarComWindows: $('cfg-autostart').checked,
    })
  );
  if (ok) mostrarStatus(statusConfig, 'Configurações salvas.');
});

$('btn-testar-telegram').addEventListener('click', async () => {
  const { ok } = await comErro(statusConfig, 'Testando...', () =>
    window.api.testarTelegram({
      telegramBotToken: $('cfg-token').value.trim(),
      telegramChatId: $('cfg-chatid').value.trim(),
    })
  );
  if (ok) mostrarStatus(statusConfig, 'Mensagem de teste enviada!');
});

function dadosGoogleAds() {
  return {
    googleAdsDeveloperToken: $('ga-developer-token').value.trim(),
    googleAdsClientId: $('ga-client-id').value.trim(),
    googleAdsClientSecret: $('ga-client-secret').value.trim(),
    googleAdsCustomerId: $('ga-customer-id').value.trim(),
    googleAdsLoginCustomerId: $('ga-login-customer-id').value.trim(),
    googleAdsAcaoContrato: $('ga-acao-contrato').value.trim(),
    googleAdsAcaoQualificado: $('ga-acao-qualificado').value.trim(),
    googleAdsValorQualificado: parseFloat($('ga-valor-qualificado').value) || 0,
    googleAdsAcaoReuniao: $('ga-acao-reuniao').value.trim(),
    googleAdsValorReuniao: parseFloat($('ga-valor-reuniao').value) || 0,
    googleAdsEnviarFunilCompleto: $('ga-funil-completo').checked,
    googleAdsMoeda: $('ga-moeda').value.trim() || 'BRL',
    googleAdsApiVersion: $('ga-api-version').value.trim(),
  };
}

$('form-google-ads').addEventListener('submit', async (e) => {
  e.preventDefault();
  const { ok } = await comErro(statusGoogleAds, null, () => window.api.salvarConfig(dadosGoogleAds()));
  if (ok) mostrarStatus(statusGoogleAds, 'Dados do Google Ads salvos.');
});

$('btn-conectar-google').addEventListener('click', async () => {
  const dados = dadosGoogleAds();
  if (!dados.googleAdsClientId || !dados.googleAdsClientSecret) {
    mostrarStatus(statusGoogleAds, 'Preencha o Client ID e o Client Secret antes de conectar.', true);
    return;
  }
  await window.api.salvarConfig(dados);
  const { ok } = await comErro(statusGoogleAds, 'Abrindo o navegador... autorize e volte para o app.', () =>
    window.api.autorizarGoogleAds(dados.googleAdsClientId, dados.googleAdsClientSecret)
  );
  if (ok) {
    mostrarStatus(statusGoogleAds, 'Conectado ao Google Ads com sucesso!');
    carregarConfig();
  }
});

$('btn-testar-google-ads').addEventListener('click', async () => {
  const { ok } = await comErro(statusGoogleAds, 'Testando...', () => window.api.testarGoogleAds());
  if (ok) mostrarStatus(statusGoogleAds, 'Conexão com Google Ads funcionando!');
});

$('btn-desconectar-google').addEventListener('click', async () => {
  if (!confirm('Desconectar a conta do Google Ads?')) return;
  await comErro(statusGoogleAds, null, () => window.api.desconectarGoogleAds());
  await carregarConfig();
  mostrarStatus(statusGoogleAds, 'Desconectado.');
});

$('link-google-cloud').addEventListener('click', (e) => {
  e.preventDefault();
  window.api.abrirExterno('https://console.cloud.google.com/apis/credentials');
});

$('btn-exportar-backup').addEventListener('click', async () => {
  const { ok, resultado } = await comErro(statusConfig, 'Exportando...', () => window.api.exportarBackup());
  if (ok && resultado) mostrarStatus(statusConfig, `Backup salvo em ${resultado}`, false, 8000);
});

$('btn-abrir-pasta-dados').addEventListener('click', () => window.api.abrirPastaDados());

async function carregarInfoSistema() {
  const info = await window.api.infoSistema();
  $('info-sistema').replaceChildren(
    el('div', { text: `Versão ${info.versao}` }),
    el('div', { text: `Pasta de dados: ${info.pastaDados}` }),
    el('div', {
      text: info.criptografiaAtiva
        ? 'Tokens protegidos pelo cofre do sistema ✅'
        : '⚠️ Cofre do sistema indisponível — os tokens não estão criptografados.',
    })
  );
}

recarregadoresPorAba.config = () => {
  carregarConfig();
  carregarInfoSistema();
};

// ===============================================================
// Inicialização
// ===============================================================

// Fecha modais ao clicar fora ou apertar Esc.
document.querySelectorAll('.modal').forEach((modal) => {
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.classList.add('oculto');
  });
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') document.querySelectorAll('.modal').forEach((m) => m.classList.add('oculto'));
});

async function iniciar() {
  ETAPAS = await window.api.listarEtapasFunil();

  const filtro = $('filtro-etapa');
  for (const etapa of ETAPAS) {
    filtro.append(el('option', { value: etapa.id, text: etapa.rotulo }));
  }

  await carregarClientes();
  await carregarPrazos();
  await carregarModelos();
  await carregarConfig();
  await carregarInfoSistema();
  await carregarDashboard();
}

iniciar().catch((e) => {
  document.body.prepend(
    el('div', { class: 'aviso', text: `Erro ao iniciar o aplicativo: ${e.message}` })
  );
});
