import type { APIRoute } from "astro";
import { gerarLlmsCompleto } from "../lib/llms";

export const GET: APIRoute = async () =>
  new Response(await gerarLlmsCompleto(), {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
