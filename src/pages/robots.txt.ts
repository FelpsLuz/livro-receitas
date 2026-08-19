/**
 * robots.txt com allow explícito para crawlers de IA (seção 10.5 — GEO),
 * além do allow geral. Gerado no build a partir do config.
 */
import type { APIRoute } from "astro";
import { SITE } from "../config";

const BOTS_IA = [
  "GPTBot",
  "OAI-SearchBot",
  "ChatGPT-User",
  "ClaudeBot",
  "Claude-User",
  "Claude-SearchBot",
  "PerplexityBot",
  "Perplexity-User",
  "Google-Extended",
  "Applebot",
  "Applebot-Extended",
  "Amazonbot",
  "meta-externalagent",
  "CCBot",
  "Bingbot",
];

export const GET: APIRoute = () => {
  const corpo = [
    ...BOTS_IA.map((bot) => `User-agent: ${bot}`),
    "Allow: /",
    "",
    "User-agent: *",
    "Allow: /",
    `Sitemap: ${SITE.dominioCanonico}/sitemap-index.xml`,
    "",
  ].join("\n");

  return new Response(corpo, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
