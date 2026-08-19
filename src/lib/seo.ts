import { SITE } from "../config";
import { TERRITORIO } from "./territorio";

/** URL canônica sem .html e sem barra final (home = "/"). */
export function urlCanonica(pathname: string): string {
  let caminho = pathname.replace(/\.html$/, "").replace(/\/+$/, "");
  if (caminho === "" || caminho === "/index") caminho = "";
  return `${SITE.dominioCanonico}${caminho || "/"}` === `${SITE.dominioCanonico}/`
    ? `${SITE.dominioCanonico}/`
    : `${SITE.dominioCanonico}${caminho}`;
}

export function urlAbsoluta(caminho: string): string {
  return new URL(caminho, SITE.dominioCanonico).href;
}

const ID_AGENTE = `${SITE.dominioCanonico}/#corretor`;
const ID_PESSOA = `${SITE.dominioCanonico}/#felipe-luz`;

/**
 * Grafo global: RealEstateAgent + Person consolidam a entidade "Felipe Luz"
 * para Google e grafos de conhecimento de IAs. SEM campo telephone (regra 8.5).
 */
export function grafoGlobal(): object[] {
  const areaServed = TERRITORIO.map((b) => ({
    "@type": "Place",
    name: `${b.nome}, ${SITE.cidade} - ${SITE.uf}`,
  }));
  return [
    {
      "@type": "RealEstateAgent",
      "@id": ID_AGENTE,
      name: SITE.marcaPublica,
      description: `${SITE.expressaoObrigatoria} em ${SITE.cidade}/${SITE.uf}, especialista no vetor oeste e noroeste da cidade. Venda de apartamentos e casas em condomínio e avaliação gratuita de imóveis.`,
      url: `${SITE.dominioCanonico}/`,
      identifier: {
        "@type": "PropertyValue",
        propertyID: "CRECI",
        value: SITE.creci,
      },
      areaServed,
      knowsAbout: TERRITORIO.map((b) => `Imóveis no ${b.nome}, ${SITE.cidade}`),
      sameAs: [SITE.instagram],
      employee: { "@id": ID_PESSOA },
    },
    {
      "@type": "Person",
      "@id": ID_PESSOA,
      name: SITE.marcaPublica,
      jobTitle: SITE.expressaoObrigatoria,
      identifier: {
        "@type": "PropertyValue",
        propertyID: "CRECI",
        value: SITE.creci,
      },
      worksFor: { "@id": ID_AGENTE },
      url: `${SITE.dominioCanonico}/sobre`,
      sameAs: [SITE.instagram],
    },
    {
      "@type": "WebSite",
      "@id": `${SITE.dominioCanonico}/#site`,
      url: `${SITE.dominioCanonico}/`,
      name: `${SITE.marcaPublica} · ${SITE.expressaoObrigatoria}`,
      inLanguage: "pt-BR",
      publisher: { "@id": ID_AGENTE },
    },
  ];
}

export function schemaWebPage(opcoes: {
  url: string;
  titulo: string;
  descricao: string;
  dataModificacao?: Date;
}): object {
  return {
    "@type": "WebPage",
    "@id": `${opcoes.url}#webpage`,
    url: opcoes.url,
    name: opcoes.titulo,
    description: opcoes.descricao,
    inLanguage: "pt-BR",
    isPartOf: { "@id": `${SITE.dominioCanonico}/#site` },
    about: { "@id": ID_AGENTE },
    ...(opcoes.dataModificacao ? { dateModified: opcoes.dataModificacao.toISOString().split("T")[0] } : {}),
  };
}

export function schemaBreadcrumb(trilha: { nome: string; href?: string }[]): object {
  return {
    "@type": "BreadcrumbList",
    itemListElement: trilha.map((item, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: item.nome,
      ...(item.href ? { item: urlAbsoluta(item.href) } : {}),
    })),
  };
}

export function schemaFaq(faqs: { pergunta: string; resposta: string }[]): object {
  return {
    "@type": "FAQPage",
    mainEntity: faqs.map((f) => ({
      "@type": "Question",
      name: f.pergunta,
      acceptedAnswer: { "@type": "Answer", text: f.resposta },
    })),
  };
}

export function schemaPlace(opcoes: {
  nome: string;
  descricao: string;
  url: string;
  bairroNome?: string;
}): object {
  return {
    "@type": "Place",
    name: opcoes.nome,
    description: opcoes.descricao,
    url: opcoes.url,
    address: {
      "@type": "PostalAddress",
      addressLocality: SITE.cidade,
      addressRegion: SITE.uf,
      addressCountry: "BR",
      ...(opcoes.bairroNome ? { streetAddress: opcoes.bairroNome } : {}),
    },
  };
}

export function schemaListing(opcoes: {
  url: string;
  titulo: string;
  descricao: string;
  imagem: string;
  tipo: string;
  areaUtil: number;
  dormitorios: number;
  banheiros: number;
  bairroNome: string;
  valor: number;
  exibirValor: boolean;
  vendido: boolean;
  publicadoEm: Date;
  atualizadoEm: Date;
}): object {
  const tipoSchema =
    opcoes.tipo === "apartamento" ? "Apartment" : opcoes.tipo === "terreno" ? "Place" : "House";
  return {
    "@type": "RealEstateListing",
    "@id": `${opcoes.url}#listing`,
    url: opcoes.url,
    name: opcoes.titulo,
    description: opcoes.descricao,
    image: opcoes.imagem,
    datePosted: opcoes.publicadoEm.toISOString().split("T")[0],
    dateModified: opcoes.atualizadoEm.toISOString().split("T")[0],
    provider: { "@id": ID_AGENTE },
    about: {
      "@type": tipoSchema,
      name: opcoes.titulo,
      floorSize: { "@type": "QuantitativeValue", value: opcoes.areaUtil, unitCode: "MTK" },
      numberOfRooms: opcoes.dormitorios,
      numberOfBathroomsTotal: opcoes.banheiros,
      address: {
        "@type": "PostalAddress",
        addressLocality: SITE.cidade,
        addressRegion: SITE.uf,
        addressCountry: "BR",
        streetAddress: opcoes.bairroNome,
      },
    },
    offers: {
      "@type": "Offer",
      availability: opcoes.vendido ? "https://schema.org/SoldOut" : "https://schema.org/InStock",
      priceCurrency: "BRL",
      ...(opcoes.exibirValor ? { price: opcoes.valor } : {}),
      offeredBy: { "@id": ID_AGENTE },
    },
  };
}

/** Padrão de títulos (seção 10.4). */
export const TITULOS = {
  home: () => `${SITE.marcaPublica} · ${SITE.expressaoObrigatoria} em ${SITE.cidade} · ${SITE.creci}`,
  vendidos: () => `Imóveis vendidos em ${SITE.cidade} — zona oeste · ${SITE.marcaPublica}`,
  avaliacao: () => `Quanto vale seu imóvel na zona oeste de ${SITE.cidade}? Avaliação gratuita`,
  condominio: (nome: string, bairro: string) => `Apartamentos à venda no ${nome}, ${bairro} — ${SITE.cidade}`,
  bairro: (nome: string) => `Imóveis à venda no ${nome}, ${SITE.cidade} — apartamentos e casas`,
} as const;
