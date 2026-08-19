import type { APIRoute } from "astro";
import { gerarLlmsCurto } from "../lib/llms";

export const GET: APIRoute = async () =>
  new Response(await gerarLlmsCurto(), {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
