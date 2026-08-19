/**
 * Gera as imagens PROCEDURAIS de exemplo (seção 12 do briefing):
 * blocos 3:2 de 2400px de largura com a ref e a instrução de substituição.
 * Rodar uma vez: `npm run imagens-exemplo`. Os arquivos são commitados;
 * o build do site não depende deste script.
 */
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import satori from "satori";
import sharp from "sharp";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");

const archivo = await readFile(
  join(raiz, "node_modules/@fontsource/archivo/files/archivo-latin-600-normal.woff")
);
const plexMono = await readFile(
  join(raiz, "node_modules/@fontsource/ibm-plex-mono/files/ibm-plex-mono-latin-500-normal.woff")
);

const LARGURA = 2400;
const ALTURA = 1600;
const TONS = ["#0D2A33", "#143C48", "#1F5566", "#28505F", "#33616F"];

async function gerar(destino, principal, secundario, indiceTom) {
  const svg = await satori(
    {
      type: "div",
      props: {
        style: {
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: TONS[indiceTom % TONS.length],
          color: "#FFFFFF",
        },
        children: [
          {
            type: "div",
            props: {
              style: {
                position: "absolute",
                top: 64,
                left: 64,
                right: 64,
                bottom: 64,
                border: "4px dashed rgba(255,255,255,0.35)",
                borderRadius: 24,
                display: "flex",
              },
            },
          },
          {
            type: "div",
            props: {
              style: { fontFamily: "IBM Plex Mono", fontSize: 200, letterSpacing: 8 },
              children: principal,
            },
          },
          {
            type: "div",
            props: {
              style: {
                fontFamily: "Archivo",
                fontSize: 88,
                marginTop: 24,
                textTransform: "uppercase",
                letterSpacing: 14,
                color: "rgba(255,255,255,0.85)",
              },
              children: secundario,
            },
          },
          {
            type: "div",
            props: {
              style: {
                fontFamily: "IBM Plex Mono",
                fontSize: 52,
                marginTop: 120,
                color: "rgba(255,255,255,0.65)",
              },
              children: "SUBSTITUIR POR FOTO REAL · 3:2 · MÍN. 2400 PX",
            },
          },
          {
            type: "div",
            props: {
              style: {
                position: "absolute",
                bottom: 96,
                fontFamily: "IBM Plex Mono",
                fontSize: 40,
                color: "rgba(255,255,255,0.45)",
              },
              children: "imagem de exemplo — não publicar",
            },
          },
        ],
      },
    },
    {
      width: LARGURA,
      height: ALTURA,
      fonts: [
        { name: "Archivo", data: archivo, weight: 600, style: "normal" },
        { name: "IBM Plex Mono", data: plexMono, weight: 500, style: "normal" },
      ],
    }
  );

  await mkdir(dirname(destino), { recursive: true });
  const jpeg = await sharp(Buffer.from(svg)).jpeg({ quality: 70, mozjpeg: true }).toBuffer();
  await writeFile(destino, jpeg);
  console.log(`✓ ${destino.replace(raiz + "/", "")} (${Math.round(jpeg.length / 1024)} KB)`);
}

const FOTOS_IMOVEIS = {
  "fl-0001": ["sala-varanda", "cozinha", "suite", "lazer-piscina", "fachada"],
  "fl-0002": ["fachada", "sala-estar", "cozinha", "quintal"],
  "fl-0003": ["sala", "varanda", "dormitorio", "area-comum"],
  "fl-0004": ["sala", "cozinha", "fachada"],
  "fl-0005": ["sala-jantar", "suite", "piscina"],
};

let tom = 0;
for (const [ref, ambientes] of Object.entries(FOTOS_IMOVEIS)) {
  for (let i = 0; i < ambientes.length; i++) {
    const arquivo = `${ref}-${String(i + 1).padStart(2, "0")}-${ambientes[i]}.jpg`;
    await gerar(
      join(raiz, "src/content/imoveis/fotos", arquivo),
      ref.toUpperCase(),
      ambientes[i].replaceAll("-", " "),
      tom++
    );
  }
}

for (const slug of ["parque-das-andorinhas", "reserva-do-ipe"]) {
  await gerar(
    join(raiz, "src/content/condominios/fotos", `condominio-${slug}.jpg`),
    "CONDOMÍNIO",
    slug.replaceAll("-", " "),
    tom++
  );
}

for (const slug of ["jardim-brasilandia", "vila-esperanca", "jardim-botanico"]) {
  await gerar(
    join(raiz, "src/content/bairros/fotos", `bairro-${slug}.jpg`),
    "BAIRRO",
    slug.replaceAll("-", " "),
    tom++
  );
}

console.log("Concluído.");
