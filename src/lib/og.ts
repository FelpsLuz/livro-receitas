/**
 * Imagens Open Graph geradas NO BUILD (seções 9.4/10.1 + Fase 5, 2.1).
 * Composição 60/40: foto no topo (1200×500) e barra --ink de 130px com
 * pill da ref, título, local e assinatura legal — sobre a textura de
 * curvas de nível (uso 3 de 3). Toda peça carrega o CRECI e NUNCA exibe
 * telefone (regra 8.5). satori (texto → vetores) + sharp.
 */
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import satori from "satori";
import sharp from "sharp";
import { SITE } from "../config";
import { svgCurvas, CURVAS_ALTURA } from "./curvas";

export const OG_LARGURA = 1200;
export const OG_ALTURA = 630;
const BARRA_ALTURA = 130;
const FOTO_ALTURA = OG_ALTURA - BARRA_ALTURA; // 500

// O build roda na raiz do projeto (local e Cloudflare Pages).
const dirFontes = join(process.cwd(), "node_modules");

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

async function renderizarPng(arvore: No): Promise<Buffer> {
  const svg = await satori(arvore as any, {
    width: OG_LARGURA,
    height: OG_ALTURA,
    fonts: await carregarFontes(),
  });
  return sharp(Buffer.from(svg)).png().toBuffer();
}

/** Faixa de curvas de nível para a barra inferior (fatia central, sem esticar). */
async function faixaCurvas(): Promise<Buffer> {
  const cheia = await sharp(Buffer.from(svgCurvas("#FFFFFF", 0.04))).png().toBuffer();
  const topo = Math.round((CURVAS_ALTURA - BARRA_ALTURA) / 2);
  return sharp(cheia).extract({ left: 0, top: topo, width: OG_LARGURA, height: BARRA_ALTURA }).toBuffer();
}

const assinaturaOg: No = {
  type: "div",
  props: {
    style: { display: "flex", flexDirection: "column", alignItems: "flex-end", flexShrink: 0 },
    children: [
      {
        type: "div",
        props: {
          style: {
            fontFamily: "Archivo",
            fontWeight: 700,
            fontSize: 26,
            letterSpacing: 1.5,
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
            fontSize: 14.5,
            letterSpacing: 0.5,
            color: "rgba(255,255,255,0.85)",
            marginTop: 3,
          },
          children: `${SITE.expressaoObrigatoria} · ${SITE.creci}`,
        },
      },
    ],
  },
};

function pillMono(texto: string, opcoes?: { forte?: boolean }): No {
  return {
    type: "div",
    props: {
      style: {
        display: "flex",
        alignItems: "center",
        fontFamily: "IBM Plex Mono",
        fontWeight: 500,
        fontSize: 20,
        letterSpacing: 1,
        color: opcoes?.forte ? "#0D2A33" : "#E8965A",
        backgroundColor: opcoes?.forte ? "rgba(255,255,255,0.94)" : "rgba(255,255,255,0.08)",
        border: opcoes?.forte ? "none" : "1px solid rgba(255,255,255,0.22)",
        borderRadius: 999,
        padding: "5px 16px",
      },
      children: texto,
    },
  };
}

/** Barra inferior --ink: pill da ref + título + local à esquerda, assinatura à direita. */
function barraInferior(esquerda: No[]): No {
  return {
    type: "div",
    props: {
      style: {
        position: "absolute",
        left: 0,
        right: 0,
        bottom: 0,
        height: BARRA_ALTURA,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 32,
        padding: "0 44px",
      },
      children: [
        {
          type: "div",
          props: {
            style: { display: "flex", flexDirection: "column", gap: 9, minWidth: 0 },
            children: esquerda,
          },
        },
        assinaturaOg,
      ],
    },
  };
}

export interface DadosOgImovel {
  ref: string;
  titulo: string;
  local: string;
  vendido: boolean;
  prazo?: string | null; // "Vendido em 42 dias · jun/2026"
  caminhoFoto: string;   // caminho da foto capa original no filesystem
}

/** OG por imóvel — variantes disponível e VENDIDO (selo + prazo sobre a foto). */
export async function ogImovel(dados: DadosOgImovel): Promise<Buffer> {
  const titulo = dados.titulo.length > 46 ? `${dados.titulo.slice(0, 46)}…` : dados.titulo;

  const overlay: No = {
    type: "div",
    props: {
      style: { width: "100%", height: "100%", display: "flex", position: "relative" },
      children: [
        ...(dados.vendido
          ? [
              {
                type: "div",
                props: {
                  style: { position: "absolute", top: 36, left: 44, display: "flex", gap: 14 },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: {
                          display: "flex",
                          backgroundColor: "rgba(13,42,51,0.85)",
                          color: "#FFFFFF",
                          fontFamily: "Archivo",
                          fontWeight: 600,
                          fontSize: 26,
                          letterSpacing: 5,
                          textTransform: "uppercase",
                          padding: "10px 24px",
                          borderRadius: 8,
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
                                alignItems: "center",
                                backgroundColor: "rgba(13,42,51,0.85)",
                                color: "#FFFFFF",
                                fontFamily: "IBM Plex Mono",
                                fontWeight: 500,
                                fontSize: 22,
                                padding: "10px 20px",
                                borderRadius: 999,
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
        barraInferior([
          {
            type: "div",
            props: {
              style: { display: "flex", alignItems: "center", gap: 16 },
              children: [
                pillMono(dados.ref),
                {
                  type: "div",
                  props: {
                    style: {
                      fontFamily: "Archivo",
                      fontWeight: 600,
                      fontSize: 34,
                      color: "#FFFFFF",
                    },
                    children: titulo,
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
                fontWeight: 400,
                fontSize: 20,
                color: "rgba(255,255,255,0.75)",
              },
              children: dados.local,
            },
          },
        ]),
      ],
    },
  };

  const [foto, curvas, camadaTexto] = await Promise.all([
    sharp(dados.caminhoFoto)
      .resize(OG_LARGURA, FOTO_ALTURA, { fit: "cover" })
      .modulate(dados.vendido ? { saturation: 0.85 } : {})
      .toBuffer(),
    faixaCurvas(),
    renderizarPng(overlay),
  ]);

  return sharp({
    create: { width: OG_LARGURA, height: OG_ALTURA, channels: 4, background: "#0D2A33" },
  })
    .composite([
      { input: foto, top: 0, left: 0 },
      ...(dados.vendido
        ? [
            {
              input: await sharp({
                create: {
                  width: OG_LARGURA,
                  height: FOTO_ALTURA,
                  channels: 4,
                  background: { r: 13, g: 42, b: 51, alpha: 0.1 },
                },
              })
                .png()
                .toBuffer(),
              top: 0,
              left: 0,
            },
          ]
        : []),
      { input: curvas, top: FOTO_ALTURA, left: 0 },
      { input: camadaTexto, top: 0, left: 0 },
    ])
    .png()
    .toBuffer();
}

/** OG padrão do site (home e páginas fixas) — mesma linguagem, sem foto. */
export async function ogPadrao(): Promise<Buffer> {
  const overlay: No = {
    type: "div",
    props: {
      style: { width: "100%", height: "100%", display: "flex", position: "relative" },
      children: [
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              top: 0,
              left: 0,
              right: 0,
              height: FOTO_ALTURA,
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              padding: "0 72px",
              gap: 18,
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "Archivo",
                    fontWeight: 700,
                    fontSize: 88,
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
                    fontSize: 36,
                    color: "rgba(255,255,255,0.9)",
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
                    fontSize: 25,
                    color: "#E8965A",
                    marginTop: 14,
                  },
                  children: `Especialista no vetor oeste e noroeste de ${SITE.cidade}`,
                },
              },
            ],
          },
        },
        barraInferior([
          {
            type: "div",
            props: {
              style: {
                fontFamily: "IBM Plex Mono",
                fontWeight: 500,
                fontSize: 24,
                color: "rgba(255,255,255,0.8)",
              },
              children: SITE.dominioCanonico.replace("https://", ""),
            },
          },
        ]),
      ],
    },
  };

  const [curvas, camadaTexto] = await Promise.all([faixaCurvas(), renderizarPng(overlay)]);

  return sharp({
    create: { width: OG_LARGURA, height: OG_ALTURA, channels: 4, background: "#0D2A33" },
  })
    .composite([
      { input: curvas, top: FOTO_ALTURA, left: 0 },
      { input: camadaTexto, top: 0, left: 0 },
    ])
    .png()
    .toBuffer();
}
