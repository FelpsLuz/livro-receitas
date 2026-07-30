const fs = require('fs');
const PizZip = require('pizzip');
const Docxtemplater = require('docxtemplater');

const DELIMITADORES = { start: '{{', end: '}}' };
const REGEX_TAG = /\{\{\s*([A-Za-z0-9_]+)\s*\}\}/g;

function carregarZip(caminhoDocx) {
  const conteudo = fs.readFileSync(caminhoDocx, 'binary');
  return new PizZip(conteudo);
}

function preencherTemplate(caminhoDocx, dados) {
  const zip = carregarZip(caminhoDocx);
  const doc = new Docxtemplater(zip, {
    paragraphLoop: true,
    linebreaks: true,
    delimiters: DELIMITADORES,
  });
  doc.render(dados);
  return doc.getZip().generate({ type: 'nodebuffer' });
}

// Detecta as tags {{TAG}} presentes no documento, lendo o XML bruto diretamente
// (mais confiável para pré-visualização do que depender da API interna do
// docxtemplater, que pode variar entre versões).
function detectarTags(caminhoDocx) {
  const zip = carregarZip(caminhoDocx);
  const documentoXml = zip.file('word/document.xml');
  if (!documentoXml) return [];

  const textoSemMarcacao = documentoXml.asText().replace(/<[^>]+>/g, '');
  const tags = new Set();
  let m;
  REGEX_TAG.lastIndex = 0;
  while ((m = REGEX_TAG.exec(textoSemMarcacao))) {
    tags.add(m[1]);
  }
  return Array.from(tags);
}

module.exports = { preencherTemplate, detectarTags };
