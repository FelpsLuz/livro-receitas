/**
 * Gera as imagens de exemplo (Fase 5, seção 2): gradiente duotônico
 * --ink → --ink-2, ref em mono discreta no canto inferior esquerdo e o
 * aviso técnico reduzido a uma linha no canto — nada de texto gigante
 * central, para o placeholder não contaminar a avaliação de layout.
 * Rodar uma vez: `npm run imagens-exemplo`. Os arquivos são commitados.
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

// Variações do duotônico petróleo — sempre --ink ↔ --ink-2/--ink-line.
const GRADIENTES = [
  "linear-gradient(140deg, #0D2A33 0%, #143C48 100%)",
  "linear-gradient(160deg, #143C48 0%, #0D2A33 100%)",
  "linear-gradient(125deg, #0D2A33 10%, #1F5566 100%)",
  "linear-gradient(150deg, #143C48 0%, #1F5566 100%)",
];

async function gerar(destino, ref, ambiente, indice) {
  const svg = await satori(
    {
      type: "div",
      props: {
        style: {
          width: "100%",
          height: "100%",
          display: "flex",
          backgroundImage: GRADIENTES[indice % GRADIENTES.length],
          color: "#FFFFFF",
        },
        children: [
          {
            type: "div",
            props: {
              style: {
                position: "absolute",
                left: 96,
                bottom: 88,
                display: "flex",
                flexDirection: "column",
              },
              children: [
                {
                  type: "div",
                  props: {
                    style: {
                      fontFamily: "IBM Plex Mono",
                      fontSize: 56,
                      letterSpacing: 4,
                      color: "rgba(255,255,255,0.55)",
                    },
                    children: ref,
                  },
                },
                {
                  type: "div",
                  props: {
                    style: {
                      fontFamily: "Archivo",
                      fontSize: 34,
                      marginTop: 10,
                      textTransform: "uppercase",
                      letterSpacing: 8,
                      color: "rgba(255,255,255,0.35)",
                    },
                    children: ambiente,
                  },
                },
              ],
            },
          },
          {
            type: "div",
            props: {
              style: {
                position: "absolute",
                right: 96,
                bottom: 92,
                fontFamily: "IBM Plex Mono",
                fontSize: 26,
                letterSpacing: 2,
                color: "rgba(255,255,255,0.35)",
              },
              children: "SUBSTITUIR POR FOTO REAL · 3:2 · MÍN. 2400 PX",
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
  const jpeg = await sharp(Buffer.from(svg)).jpeg({ quality: 72, mozjpeg: true }).toBuffer();
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

let indice = 0;
for (const [ref, ambientes] of Object.entries(FOTOS_IMOVEIS)) {
  for (let i = 0; i < ambientes.length; i++) {
    const arquivo = `${ref}-${String(i + 1).padStart(2, "0")}-${ambientes[i]}.jpg`;
    await gerar(
      join(raiz, "src/content/imoveis/fotos", arquivo),
      ref.toUpperCase(),
      ambientes[i].replaceAll("-", " "),
      indice++
    );
  }
}

for (const slug of ["parque-das-andorinhas", "reserva-do-ipe"]) {
  await gerar(
    join(raiz, "src/content/condominios/fotos", `condominio-${slug}.jpg`),
    slug.replaceAll("-", " ").toUpperCase(),
    "condomínio",
    indice++
  );
}

for (const slug of ["jardim-brasilandia", "vila-esperanca", "jardim-botanico"]) {
  await gerar(
    join(raiz, "src/content/bairros/fotos", `bairro-${slug}.jpg`),
    slug.replaceAll("-", " ").toUpperCase(),
    "bairro",
    indice++
  );
}

console.log("Concluído.");
