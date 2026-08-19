import type { APIRoute } from "astro";
import { SITE } from "../config";
import { dataISO } from "../lib/formatar";

export const GET: APIRoute = () => {
  const xml = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`,
    `  <sitemap>`,
    `    <loc>${SITE.dominioCanonico}/sitemap-0.xml</loc>`,
    `    <lastmod>${dataISO(new Date())}</lastmod>`,
    `  </sitemap>`,
    `</sitemapindex>`,
    ``,
  ].join("\n");
  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
