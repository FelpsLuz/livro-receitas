const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { preencherTemplate } = require('./docxTemplate');

function formatarMoeda(valor) {
  const numero = Number(valor) || 0;
  return numero.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function formatarDataHoje(hoje = new Date()) {
  return hoje.toLocaleDateString('pt-BR');
}

function slugify(texto) {
  const limpo = (texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .toLowerCase()
    .replace(/(^-+|-+$)/g, '');
  return limpo || 'cliente';
}

function dadosParaTemplate(cliente, hoje = new Date()) {
  return {
    NOME_CLIENTE: cliente.nome || '',
    CPF: cliente.cpf || '',
    ENDERECO: cliente.endereco || '',
    TELEFONE: cliente.telefone || '',
    VALOR_HONORARIOS: formatarMoeda(cliente.valorHonorarios),
    FORMA_PAGAMENTO: cliente.formaPagamento || '',
    DATA_GERACAO: formatarDataHoje(hoje),
  };
}

function candidatosLibreOffice() {
  if (process.platform === 'win32') {
    return [
      'soffice.exe',
      'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
      'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
    ];
  }
  if (process.platform === 'darwin') {
    return ['soffice', '/Applications/LibreOffice.app/Contents/MacOS/soffice'];
  }
  return ['soffice', 'libreoffice'];
}

function converterParaPdf(caminhoDocx, pastaSaida) {
  return new Promise((resolve) => {
    const candidatos = candidatosLibreOffice();

    const tentar = (indice) => {
      if (indice >= candidatos.length) {
        resolve(null);
        return;
      }
      execFile(
        candidatos[indice],
        ['--headless', '--convert-to', 'pdf', '--outdir', pastaSaida, caminhoDocx],
        { timeout: 60000 },
        (erro) => {
          if (erro) {
            tentar(indice + 1);
            return;
          }
          const caminhoPdf = path.join(
            pastaSaida,
            `${path.basename(caminhoDocx, '.docx')}.pdf`
          );
          resolve(fs.existsSync(caminhoPdf) ? caminhoPdf : null);
        }
      );
    };

    tentar(0);
  });
}

async function gerarContrato({ cliente, template, pastaBaseContratos, timestamp = new Date() }) {
  const dados = dadosParaTemplate(cliente, timestamp);
  const bufferDocx = preencherTemplate(template.caminhoAbsoluto, dados);

  const pastaCliente = path.join(pastaBaseContratos, slugify(cliente.nome));
  fs.mkdirSync(pastaCliente, { recursive: true });

  const carimbo = timestamp.toISOString().replace(/[:.]/g, '-');
  const nomeArquivo = `${carimbo}__${slugify(template.nome)}.docx`;
  const caminhoDocx = path.join(pastaCliente, nomeArquivo);
  fs.writeFileSync(caminhoDocx, bufferDocx);

  const caminhoPdf = await converterParaPdf(caminhoDocx, pastaCliente);

  return { caminhoDocx, caminhoPdf, pastaCliente };
}

module.exports = {
  formatarMoeda,
  formatarDataHoje,
  slugify,
  dadosParaTemplate,
  converterParaPdf,
  gerarContrato,
};
