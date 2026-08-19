/**
 * Sitemap com <lastmod> real, alimentado por `atualizado_em` das coleções
 * (seção 10.1). /obrigado e /404 ficam de fora (noindex/erro).
 */
import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { SITE } from "../config";
import { imoveisRenderizaveis, imoveisVitrine, imoveisVendidos } from "../lib/imoveis";
import { dataISO } from "../lib/formatar";

function maxData(datas: Date[], reserva: Date): Date {
  return datas.length ? new Date(Math.max(...datas.map((d) => d.getTime()))) : reserva;
}

export const GET: APIRoute = async () => {
  const agora = new Date();
  const [imoveis, vitrine, vendidos, condominios, bairros] = await Promise.all([
    imoveisRenderizaveis(),
    imoveisVitrine(),
    imoveisVendidos(),
    getCollection("condominios"),
    getCollection("bairros"),
  ]);

  const tudoAtualizado = maxData(
    [
      ...imoveis.map((i) => i.data.atualizado_em),
      ...condominios.map((c) => c.data.atualizado_em),
      ...bairros.map((b) => b.data.atualizado_em),
    ],
    agora
  );

  const urls: { caminho: string; lastmod: Date }[] = [
    { caminho: "/", lastmod: tudoAtualizado },
    { caminho: "/imoveis", lastmod: maxData(vitrine.map((i) => i.data.atualizado_em), agora) },
    { caminho: "/vendidos", lastmod: maxData(vendidos.map((i) => i.data.atualizado_em), agora) },
    { caminho: "/avaliacao", lastmod: tudoAtualizado },
    { caminho: "/sobre", lastmod: agora },
    { caminho: "/parceiros", lastmod: maxData(vitrine.map((i) => i.data.atualizado_em), agora) },
    { caminho: "/politica-de-privacidade", lastmod: agora },
    ...imoveis.map((i) => ({ caminho: `/imovel/${i.id}`, lastmod: i.data.atualizado_em })),
    ...condominios.map((c) => ({ caminho: `/condominio/${c.id}`, lastmod: c.data.atualizado_em })),
    ...bairros.map((b) => ({ caminho: `/regiao/${b.id}`, lastmod: b.data.atualizado_em })),
  ];

  const xml = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`,
    ...urls.map((u) =>
      [
        `  <url>`,
        `    <loc>${SITE.dominioCanonico}${u.caminho === "/" ? "/" : u.caminho}</loc>`,
        `    <lastmod>${dataISO(u.lastmod)}</lastmod>`,
        `  </url>`,
      ].join("\n")
    ),
    `</urlset>`,
    ``,
  ].join("\n");

  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
