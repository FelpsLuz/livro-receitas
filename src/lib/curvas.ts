/**
 * Curvas de nível topográficas — textura de marca (Fase 5, seção 3.4),
 * derivada da linguagem do mapa. FONTE ÚNICA dos traçados: o data-URI usado
 * no CSS (base.css) e a camada das imagens OG saem daqui.
 *
 * Uso permitido em EXATAMENTE três lugares:
 *  1. fundo das seções --ink (stroke branco a 5%)
 *  2. cabeçalho da ficha A4 do parceiro (stroke --ink a 4%)
 *  3. barra inferior das imagens OG (stroke branco a 4%)
 */

export const CURVAS_LARGURA = 1200;
export const CURVAS_ALTURA = 640;

/** Dois "morros" aninhados + duas linhas longas — traçado à mão estabilizado. */
export const CURVAS: string[] = [
  // morro oeste
  "M 240 300 Q 260 250 320 246 Q 380 244 402 290 Q 420 332 380 362 Q 336 388 284 370 Q 240 352 240 300 Z",
  "M 180 300 Q 200 220 300 210 Q 400 202 440 272 Q 470 330 420 386 Q 360 440 270 420 Q 190 400 180 300 Z",
  "M 120 300 Q 140 180 300 168 Q 440 158 500 260 Q 540 340 470 420 Q 390 490 260 470 Q 140 452 120 300 Z",
  "M 60 300 Q 80 140 300 126 Q 490 114 560 250 Q 610 350 520 456 Q 420 552 250 522 Q 90 494 60 300 Z",
  // morro leste
  "M 850 250 Q 870 205 925 202 Q 980 200 1000 242 Q 1015 280 980 308 Q 940 332 895 316 Q 852 300 850 250 Z",
  "M 790 250 Q 812 160 920 155 Q 1020 152 1055 235 Q 1080 300 1020 358 Q 955 410 870 384 Q 795 360 790 250 Z",
  "M 730 250 Q 755 115 920 108 Q 1065 102 1110 225 Q 1145 320 1065 408 Q 975 490 855 452 Q 740 418 730 250 Z",
  // linhas de fundo do vale
  "M 0 560 Q 200 520 400 560 Q 620 600 830 540 Q 1020 490 1200 520",
  "M 0 620 Q 260 580 520 616 Q 800 652 1200 600",
];

/** SVG completo das curvas com uma cor/opacidade de traço. */
export function svgCurvas(cor: string, opacidade: number, largura = CURVAS_LARGURA, altura = CURVAS_ALTURA): string {
  const paths = CURVAS.map(
    (d) => `<path d="${d}" fill="none" stroke="${cor}" stroke-opacity="${opacidade}" stroke-width="1.5"/>`
  ).join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CURVAS_LARGURA} ${CURVAS_ALTURA}" width="${largura}" height="${altura}">${paths}</svg>`;
}

/** data-URI para uso em background-image (CSS). */
export function dataUriCurvas(cor: string, opacidade: number): string {
  return `data:image/svg+xml,${encodeURIComponent(svgCurvas(cor, opacidade))}`;
}
