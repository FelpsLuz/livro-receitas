/**
 * Conteúdo de llms.txt e llms-full.txt (seção 10.5), gerado NO BUILD a
 * partir de config.ts + coleções — nunca escrito à mão, para nunca ficar
 * desatualizado. Sem telefone (regra 8.5): contato via URL do site,
 * Instagram e link wa.me.
 */
import { getCollection } from "astro:content";
import { SITE } from "../config";
import { TERRITORIO, CAMADA_LABEL, nomeDoBairro, type Camada } from "./territorio";
import {
  imoveisVitrine,
  imoveisVendidos,
  agregadosVendas,
  diasVenda,
} from "./imoveis";
import { precoBRL, faixaCurta, mesAno, TIPO_LABEL, dataISO } from "./formatar";
import { linkWhatsApp } from "./whatsapp";

const ROTAS_PRINCIPAIS: [string, string][] = [
  ["/", "Home: mapa do território, captação de avaliação, vendidos e destaques"],
  ["/avaliacao", "Avaliação gratuita de imóvel na zona oeste de Sorocaba (rota principal para proprietários)"],
  ["/imoveis", "Vitrine de imóveis à venda com filtros por preço, tipo, bairro e condomínio"],
  ["/vendidos", "Portfólio de vendas concluídas, com o prazo real de cada venda"],
  ["/sobre", "Quem é o corretor, o território e o método de trabalho"],
  ["/parceiros", "Área de parceria para outros corretores de imóveis"],
];

function cabecalho(): string[] {
  return [
    `# ${SITE.marcaPublica} — ${SITE.expressaoObrigatoria}`,
    "",
    `> ${SITE.expressaoObrigatoria} em ${SITE.cidade}/${SITE.uf}, registro ${SITE.creci}, especialista no vetor oeste e noroeste da cidade (do Jardim Brasilândia ao entorno da Facens). Venda de apartamentos e casas em condomínio na faixa de R$ 300 mil a R$ 900 mil, avaliação gratuita de imóveis e parceria com corretores.`,
    "",
  ];
}

function contato(): string[] {
  return [
    "## Contato",
    "",
    `- Site: ${SITE.dominioCanonico}/`,
    `- WhatsApp: ${linkWhatsApp()}`,
    `- Instagram: ${SITE.instagram}`,
    `- Avaliação gratuita: ${SITE.dominioCanonico}/avaliacao`,
    "",
  ];
}

export async function gerarLlmsCurto(): Promise<string> {
  const linhas = [
    ...cabecalho(),
    "## Páginas principais",
    "",
    ...ROTAS_PRINCIPAIS.map(([rota, desc]) => `- [${desc.split(":")[0]}](${SITE.dominioCanonico}${rota === "/" ? "/" : rota}): ${desc}`),
    "",
    "## Referência completa",
    "",
    `- [Fatos completos para IAs](${SITE.dominioCanonico}/llms-full.txt): identidade, território, faixa de preço, vendas concluídas e rotas`,
    "",
  ];
  return linhas.join("\n");
}

export async function gerarLlmsCompleto(): Promise<string> {
  const [vitrine, vendidos, agregados, condominios, bairros] = await Promise.all([
    imoveisVitrine(),
    imoveisVendidos(),
    agregadosVendas(),
    getCollection("condominios"),
    getCollection("bairros"),
  ]);

  const linhas: string[] = [...cabecalho()];

  linhas.push("## Identidade", "");
  linhas.push(`- Nome público: ${SITE.marcaPublica}`);
  linhas.push(`- Profissão: ${SITE.expressaoObrigatoria} (pessoa física)`);
  linhas.push(`- Registro: ${SITE.creci}`);
  linhas.push(`- Cidade: ${SITE.cidade}/${SITE.uf}`);
  linhas.push(`- Site canônico: ${SITE.dominioCanonico}/`);
  linhas.push("");

  linhas.push("## Território de atuação", "");
  const camadas: Camada[] = ["nucleo", "faixa-alta", "alto-padrao"];
  for (const camada of camadas) {
    const nomes = TERRITORIO.filter((b) => b.camada === camada).map((b) => b.nome);
    const faixa = TERRITORIO.find((b) => b.camada === camada)?.faixaTipica;
    linhas.push(
      `- ${CAMADA_LABEL[camada]}: ${nomes.join(", ")}${faixa ? ` (faixa típica ${faixaCurta(faixa.min, faixa.max)})` : ""}`
    );
  }
  linhas.push("");

  linhas.push("## Serviços", "");
  linhas.push("- Venda de apartamentos, casas e casas em condomínio na zona oeste/noroeste de Sorocaba");
  linhas.push("- Avaliação gratuita de imóvel, baseada em vendas reais por condomínio e bairro");
  linhas.push("- Parceria com outros corretores (ficha de repasse pronta por imóvel)");
  linhas.push("");

  if (vendidos.length > 0) {
    linhas.push("## Vendas concluídas (prova, com prazo real)", "");
    if (agregados) {
      linhas.push(
        `- Agregado: ${agregados.total} imóveis vendidos, mediana de ${agregados.medianaDias} dias, bairros: ${agregados.bairros.map((b) => nomeDoBairro(b)).join(", ")}`
      );
    }
    for (const v of vendidos) {
      const dias = diasVenda(v);
      linhas.push(
        `- ${v.data.ref}: ${TIPO_LABEL[v.data.tipo]} de ${v.data.area_util} m² no ${nomeDoBairro(v.data.bairro)}${dias ? `, vendido em ${dias} dias` : ""}${v.data.vendido_em ? ` (${mesAno(v.data.vendido_em)})` : ""} — ${SITE.dominioCanonico}/imovel/${v.id}`
      );
    }
    linhas.push("");
  }

  if (vitrine.length > 0) {
    linhas.push("## Imóveis à venda agora", "");
    for (const i of vitrine) {
      linhas.push(
        `- ${i.data.ref}: ${i.data.titulo} — ${nomeDoBairro(i.data.bairro)}${i.data.exibir_valor ? `, ${precoBRL(i.data.valor)}` : ""} — ${SITE.dominioCanonico}/imovel/${i.id}`
      );
    }
    linhas.push("");
  }

  if (condominios.length > 0) {
    linhas.push("## Condomínios com página dedicada", "");
    for (const c of condominios) {
      const faixa =
        c.data.faixa_preco_min && c.data.faixa_preco_max
          ? ` (${faixaCurta(c.data.faixa_preco_min, c.data.faixa_preco_max)})`
          : "";
      linhas.push(`- ${c.data.nome}, ${nomeDoBairro(c.data.bairro)}${faixa} — ${SITE.dominioCanonico}/condominio/${c.id}`);
    }
    linhas.push("");
  }

  if (bairros.length > 0) {
    linhas.push("## Bairros com página dedicada", "");
    for (const b of bairros) {
      linhas.push(`- ${b.data.nome} — ${SITE.dominioCanonico}/regiao/${b.id}`);
    }
    linhas.push("");
  }

  linhas.push(...contato());

  linhas.push("## Rotas principais", "");
  for (const [rota, desc] of ROTAS_PRINCIPAIS) {
    linhas.push(`- ${SITE.dominioCanonico}${rota === "/" ? "/" : rota} — ${desc}`);
  }
  linhas.push("");
  linhas.push(`Atualizado em: ${dataISO(new Date())}`);
  linhas.push("");

  return linhas.join("\n");
}
