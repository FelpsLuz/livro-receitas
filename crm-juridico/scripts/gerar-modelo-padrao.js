// Gera o modelo padrao de contrato (assets/templates/modelo-padrao.docx) usado
// como semente na primeira execucao do app. Rodar com: npm run gerar-modelo-padrao
const fs = require('fs');
const path = require('path');
const { Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType } = require('docx');

const paragrafo = (texto, opcoes = {}) =>
  new Paragraph({ children: [new TextRun(texto)], spacing: { after: 200 }, ...opcoes });

const doc = new Document({
  sections: [
    {
      children: [
        new Paragraph({
          text: 'CONTRATO DE PRESTAÇÃO DE SERVIÇOS ADVOCATÍCIOS',
          heading: HeadingLevel.HEADING_1,
          alignment: AlignmentType.CENTER,
          spacing: { after: 400 },
        }),
        paragrafo(
          'Pelo presente instrumento particular de contrato de prestação de serviços advocatícios, de um lado:'
        ),
        paragrafo(
          'CONTRATANTE: {{NOME_CLIENTE}}, portador(a) do CPF nº {{CPF}}, residente e domiciliado(a) em {{ENDERECO}}, telefone de contato {{TELEFONE}}.'
        ),
        paragrafo(
          'CONTRATADO(A): [NOME DO ESCRITÓRIO / ADVOGADO(A)], inscrito(a) na OAB sob o nº [NÚMERO OAB].'
        ),
        paragrafo(
          'As partes acima identificadas têm, entre si, justo e acordado o presente contrato de prestação de serviços advocatícios, que se regerá pelas cláusulas seguintes:'
        ),
        new Paragraph({
          text: 'CLÁUSULA 1ª - DO OBJETO',
          heading: HeadingLevel.HEADING_2,
          spacing: { before: 300, after: 200 },
        }),
        paragrafo(
          'O(A) CONTRATADO(A) prestará serviços de assessoria e representação jurídica ao CONTRATANTE, conforme detalhado nos autos e documentos apresentados.'
        ),
        new Paragraph({
          text: 'CLÁUSULA 2ª - DOS HONORÁRIOS',
          heading: HeadingLevel.HEADING_2,
          spacing: { before: 300, after: 200 },
        }),
        paragrafo(
          'Pelos serviços prestados, o CONTRATANTE pagará ao(à) CONTRATADO(A) honorários no valor de {{VALOR_HONORARIOS}}, na seguinte forma de pagamento: {{FORMA_PAGAMENTO}}.'
        ),
        new Paragraph({
          text: 'CLÁUSULA 3ª - DAS DISPOSIÇÕES GERAIS',
          heading: HeadingLevel.HEADING_2,
          spacing: { before: 300, after: 200 },
        }),
        paragrafo(
          'O presente contrato entra em vigor na data de sua assinatura, obrigando as partes e seus sucessores a qualquer título.'
        ),
        paragrafo('E, por estarem assim justos e contratados, firmam o presente instrumento.'),
        new Paragraph({ text: '', spacing: { before: 400 } }),
        paragrafo('Data: {{DATA_GERACAO}}', { alignment: AlignmentType.CENTER }),
        new Paragraph({ text: '', spacing: { before: 600 } }),
        paragrafo('_______________________________________', { alignment: AlignmentType.CENTER }),
        paragrafo('{{NOME_CLIENTE}} (CONTRATANTE)', { alignment: AlignmentType.CENTER }),
        new Paragraph({ text: '', spacing: { before: 400 } }),
        paragrafo('_______________________________________', { alignment: AlignmentType.CENTER }),
        paragrafo('CONTRATADO(A)', { alignment: AlignmentType.CENTER }),
      ],
    },
  ],
});

const destino = path.join(__dirname, '..', 'assets', 'templates', 'modelo-padrao.docx');
fs.mkdirSync(path.dirname(destino), { recursive: true });

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(destino, buffer);
  console.log(`Modelo padrão gerado em: ${destino}`);
});
