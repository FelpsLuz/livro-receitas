/**
 * Geração de imagens Open Graph NO BUILD (seções 9.4 e 10.1).
 * satori (texto → vetores, sem depender de fontes do sistema) + sharp.
 * Toda peça carrega a assinatura com CRECI (Decreto 81.871/78) e NUNCA
 * exibe telefone (regra 8.5).
 */
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import satori from "satori";
import sharp from "sharp";
import { SITE } from "../config";

// O build roda na raiz do projeto (local e Cloudflare Pages); import.meta.url
// apontaria para dist/ depois do bundle.
const dirFontes = join(process.cwd(), "node_modules");

export const OG_LARGURA = 1200;
export const OG_ALTURA = 630;

let fontes: { name: string; data: Buffer; weight: 400 | 500 | 600 | 700; style: "normal" }[] | null = null;

async function carregarFontes() {
  if (fontes) return fontes;
  const [archivo600, archivo700, mono400, mono500] = await Promise.all([
    readFile(join(dirFontes, "@fontsource/archivo/files/archivo-latin-600-normal.woff")),
    readFile(join(dirFontes, "@fontsource/archivo/files/archivo-latin-700-normal.woff")),
    readFile(join(dirFontes, "@fontsource/ibm-plex-mono/files/ibm-plex-mono-latin-400-normal.woff")),
    readFile(join(dirFontes, "@fontsource/ibm-plex-mono/files/ibm-plex-mono-latin-500-normal.woff")),
  ]);
  fontes = [
    { name: "Archivo", data: archivo600, weight: 600, style: "normal" },
    { name: "Archivo", data: archivo700, weight: 700, style: "normal" },
    { name: "IBM Plex Mono", data: mono400, weight: 400, style: "normal" },
    { name: "IBM Plex Mono", data: mono500, weight: 500, style: "normal" },
  ];
  return fontes;
}

type No = { type: string; props: Record<string, unknown> };

async function renderizarSvg(arvore: No): Promise<string> {
  return satori(arvore as any, {
    width: OG_LARGURA,
    height: OG_ALTURA,
    fonts: await carregarFontes(),
  });
}

const assinaturaOg: No = {
  type: "div",
  props: {
    style: { display: "flex", flexDirection: "column" },
    children: [
      {
        type: "div",
        props: {
          style: {
            fontFamily: "Archivo",
            fontWeight: 700,
            fontSize: 34,
            letterSpacing: 2,
            color: "#FFFFFF",
            textTransform: "uppercase",
          },
          children: SITE.marcaPublica,
        },
      },
      {
        type: "div",
        props: {
          style: {
            fontFamily: "Archivo",
            fontWeight: 600,
            fontSize: 18,
            letterSpacing: 1,
            color: "rgba(255,255,255,0.85)",
          },
          children: `${SITE.expressaoObrigatoria} · ${SITE.creci}`,
        },
      },
    ],
  },
};

/** OG padrão do site (home e páginas fixas). */
export async function ogPadrao(): Promise<Buffer> {
  const svg = await renderizarSvg({
    type: "div",
    props: {
      style: {
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: 72,
        backgroundColor: "#0D2A33",
      },
      children: [
        {
          type: "div",
          props: {
            style: { display: "flex", flexDirection: "column", gap: 18 },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "Archivo",
                    fontWeight: 700,
                    fontSize: 84,
                    color: "#FFFFFF",
                    textTransform: "uppercase",
                    letterSpacing: 3,
                  },
                  children: SITE.marcaPublica,
                },
              },
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "Archivo",
                    fontWeight: 600,
                    fontSize: 34,
                    color: "rgba(255,255,255,0.88)",
                  },
                  children: `${SITE.expressaoObrigatoria} · ${SITE.creci}`,
                },
              },
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "IBM Plex Mono",
                    fontWeight: 400,
                    fontSize: 26,
                    color: "#E8965A",
                    marginTop: 18,
                  },
                  children: `Especialista no vetor oeste e noroeste de ${SITE.cidade}`,
                },
              },
            ],
          },
        },
        {
          type: "div",
          props: {
            style: {
              fontFamily: "IBM Plex Mono",
              fontWeight: 500,
              fontSize: 26,
              color: "rgba(255,255,255,0.7)",
            },
            children: SITE.dominioCanonico.replace("https://", ""),
          },
        },
      ],
    },
  });
  return sharp(Buffer.from(svg)).png().toBuffer();
}

export interface DadosOgImovel {
  ref: string;
  titulo: string;
  local: string;
  vendido: boolean;
  prazo?: string | null; // "Vendido em 42 dias · jun/2026"
  caminhoFoto: string;   // caminho no filesystem da foto capa original
}

/** OG por imóvel: foto capa + ref + assinatura CRECI; variante vendido com selo e prazo. */
export async function ogImovel(dados: DadosOgImovel): Promise<Buffer> {
  const overlay: No = {
    type: "div",
    props: {
      style: {
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: dados.vendido ? "space-between" : "flex-end",
      },
      children: [
        ...(dados.vendido
          ? [
              {
                type: "div",
                props: {
                  style: { display: "flex", alignItems: "center", gap: 20, padding: 40 },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: {
                          display: "flex",
                          backgroundColor: "#0D2A33",
                          color: "#FFFFFF",
                          fontFamily: "Archivo",
                          fontWeight: 600,
                          fontSize: 30,
                          letterSpacing: 5,
                          textTransform: "uppercase",
                          padding: "12px 28px",
                          borderRadius: 6,
                        },
                        children: "Vendido",
                      },
                    },
                    ...(dados.prazo
                      ? [
                          {
                            type: "div",
                            props: {
                              style: {
                                display: "flex",
                                backgroundColor: "rgba(255,255,255,0.94)",
                                color: "#0D2A33",
                                fontFamily: "IBM Plex Mono",
                                fontWeight: 500,
                                fontSize: 26,
                                padding: "10px 22px",
                                borderRadius: 6,
                              },
                              children: dados.prazo,
                            },
                          },
                        ]
                      : []),
                  ],
                },
              },
            ]
          : []),
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              flexDirection: "column",
              gap: 10,
              padding: "36px 48px",
              backgroundColor: "rgba(13,42,51,0.93)",
            },
            children: [
              {
                type: "div",
                props: {
                  style: { display: "flex", alignItems: "baseline", gap: 24 },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: {
                          fontFamily: "IBM Plex Mono",
                          fontWeight: 500,
                          fontSize: 26,
                          color: "#E8965A",
                        },
                        children: dados.ref,
                      },
                    },
                    {
                      type: "div",
                      props: {
                        style: {
                          fontFamily: "Archivo",
                          fontWeight: 600,
                          fontSize: 32,
                          color: "#FFFFFF",
                        },
                        children: dados.titulo.length > 52 ? `${dados.titulo.slice(0, 52)}…` : dados.titulo,
                      },
                    },
                  ],
                },
              },
              {
                type: "div",
                props: {
                  style: { display: "flex", justifyContent: "space-between", alignItems: "flex-end" },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: {
                          fontFamily: "IBM Plex Mono",
                          fontWeight: 400,
                          fontSize: 22,
                          color: "rgba(255,255,255,0.8)",
                          maxWidth: 660,
                        },
                        children: dados.local,
                      },
                    },
                    assinaturaOg,
                  ],
                },
              },
            ],
          },
        },
      ],
    },
  };

  const [fundo, camada] = await Promise.all([
    sharp(dados.caminhoFoto)
      .resize(OG_LARGURA, OG_ALTURA, { fit: "cover" })
      .modulate(dados.vendido ? { saturation: 0.85 } : {})
      .toBuffer(),
    renderizarSvg(overlay).then((svg) => sharp(Buffer.from(svg)).png().toBuffer()),
  ]);

  return sharp(fundo)
    .composite([{ input: camada, top: 0, left: 0 }])
    .png()
    .toBuffer();
}
