/**
 * Imagem de Open Graph POR IMÓVEL, gerada no build (seção 9.4):
 * foto capa + ref + assinatura CRECI. Variante vendido: selo + prazo.
 * É o que aparece no preview do WhatsApp — diferencial competitivo direto.
 */
import type { APIRoute } from "astro";
import { getEntry } from "astro:content";
import { imoveisRenderizaveis, diasVenda, type Imovel } from "../../lib/imoveis";
import { nomeDoBairro } from "../../lib/territorio";
import { mesAno } from "../../lib/formatar";
import { ogImovel } from "../../lib/og";

export async function getStaticPaths() {
  const imoveis = await imoveisRenderizaveis();
  return imoveis.map((imovel) => ({ params: { ref: imovel.id }, props: { imovel } }));
}

export const GET: APIRoute = async ({ props }) => {
  const imovel = (props as { imovel: Imovel }).imovel;
  const d = imovel.data;
  const vendido = d.status === "vendido";
  const dias = vendido ? diasVenda(imovel) : null;
  const quando = d.vendido_em ? mesAno(d.vendido_em) : null;
  const condominio = d.condominio ? await getEntry("condominios", d.condominio) : undefined;
  const localCompleto = [condominio?.data.nome, nomeDoBairro(d.bairro), "Sorocaba"]
    .filter(Boolean)
    .join(" · ");
  const local = localCompleto.length > 56 ? `${localCompleto.slice(0, 56)}…` : localCompleto;

  // Caminho original da foto no filesystem, exposto pelo astro:assets no build.
  const caminhoFoto = (d.fotos[0].src as unknown as { fsPath?: string }).fsPath;
  if (!caminhoFoto) {
    throw new Error(
      `OG do imóvel ${d.ref}: não foi possível resolver o arquivo da foto capa (fsPath ausente).`
    );
  }

  const png = await ogImovel({
    ref: d.ref,
    titulo: d.titulo,
    local,
    vendido,
    prazo: vendido ? [dias ? `Vendido em ${dias} dias` : "Vendido", quando].filter(Boolean).join(" · ") : null,
    caminhoFoto,
  });

  return new Response(new Uint8Array(png), {
    headers: { "Content-Type": "image/png" },
  });
};
