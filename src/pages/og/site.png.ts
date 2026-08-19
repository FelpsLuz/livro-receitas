import type { APIRoute } from "astro";
import { ogPadrao } from "../../lib/og";

export const GET: APIRoute = async () => {
  const png = await ogPadrao();
  return new Response(new Uint8Array(png), {
    headers: { "Content-Type": "image/png" },
  });
};
