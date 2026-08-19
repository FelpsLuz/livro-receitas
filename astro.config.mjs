// @ts-check
import { defineConfig } from "astro/config";
import { SITE } from "./src/config";

export default defineConfig({
  site: SITE.dominioCanonico,
  output: "static",
  // URLs sem barra final (/imoveis, /imovel/fl-0001) — o Cloudflare Pages
  // serve `imoveis.html` como /imoveis nativamente.
  build: { format: "file" },
  trailingSlash: "never",
});
