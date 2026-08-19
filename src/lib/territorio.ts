/**
 * O TERRITÓRIO — ativo central do posicionamento (seção 3 do briefing).
 * Bairros e condomínios são adicionados AQUI e nas coleções de conteúdo,
 * sem tocar em código de template.
 *
 * O mapa é ESQUEMÁTICO (desenhado à mão, não georreferenciado): representa
 * posições relativas do vetor oeste/noroeste de Sorocaba num viewBox 800×520.
 */

export type Camada = "nucleo" | "faixa-alta" | "alto-padrao";

export interface BairroTerritorio {
  slug: string;
  nome: string;
  camada: Camada;
  /** Faixa típica da camada — números fornecidos no briefing (seção 3). */
  faixaTipica: { min: number; max: number } | null;
  /** Path SVG do polígono esquemático no viewBox 800×520. */
  path: string;
  /** Âncora do rótulo. */
  label: { x: number; y: number };
  /** Âncora dos pontos (contagem/vendas). */
  ancora: { x: number; y: number };
}

export const CAMADA_LABEL: Record<Camada, string> = {
  nucleo: "Núcleo — volume",
  "faixa-alta": "Faixa alta do médio",
  "alto-padrao": "Alto padrão",
};

export const VIEWBOX = { largura: 800, altura: 520 };

export const TERRITORIO: BairroTerritorio[] = [
  // ——— NÚCLEO (volume — R$ 300–600 mil) ———
  {
    slug: "jardim-brasilandia",
    nome: "Jardim Brasilândia",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: "M192 214 Q214 178 268 176 Q330 172 356 202 Q372 226 362 262 Q350 300 300 306 Q240 312 210 288 Q180 262 192 214 Z",
    label: { x: 274, y: 238 },
    ancora: { x: 274, y: 262 },
  },
  {
    slug: "vila-esperanca",
    nome: "Vila Esperança",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: "M158 344 Q182 318 234 322 Q292 326 306 356 Q318 390 292 416 Q258 438 208 428 Q160 416 154 380 Q152 360 158 344 Z",
    label: { x: 232, y: 372 },
    ancora: { x: 232, y: 396 },
  },
  {
    slug: "jardim-alvorada",
    nome: "Jardim Alvorada",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: "M386 226 Q404 200 444 202 Q484 206 492 240 Q498 276 470 296 Q436 312 404 296 Q376 278 386 226 Z",
    label: { x: 438, y: 248 },
    ancora: { x: 438, y: 272 },
  },
  {
    slug: "vila-progresso",
    nome: "Vila Progresso",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: "M340 340 Q362 316 408 320 Q452 326 460 360 Q466 396 434 414 Q396 430 360 412 Q330 394 340 340 Z",
    label: { x: 398, y: 368 },
    ancora: { x: 398, y: 392 },
  },
  {
    slug: "jardim-leocadia",
    nome: "Jardim Leocádia",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: "M62 232 Q78 202 118 206 Q158 210 166 244 Q172 282 148 306 Q118 326 86 310 Q54 292 62 232 Z",
    label: { x: 113, y: 254 },
    ancora: { x: 113, y: 278 },
  },

  // ——— FAIXA ALTA DO MÉDIO (R$ 500–900 mil) ———
  {
    slug: "jardim-botanico",
    nome: "Jardim Botânico",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: "M552 140 Q576 116 616 120 Q658 126 664 162 Q668 198 638 216 Q602 232 568 214 Q542 196 552 140 Z",
    label: { x: 606, y: 166 },
    ancora: { x: 606, y: 190 },
  },
  {
    slug: "retiro-sao-joao",
    nome: "Retiro São João",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: "M578 380 Q600 356 642 362 Q684 370 686 404 Q686 438 652 452 Q614 462 590 442 Q568 422 578 380 Z",
    label: { x: 630, y: 404 },
    ancora: { x: 630, y: 428 },
  },
  {
    slug: "jardim-santa-rosalia",
    nome: "Jardim Santa Rosália",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: "M606 266 Q628 244 668 250 Q706 258 708 292 Q708 326 676 340 Q640 352 614 332 Q592 312 606 266 Z",
    label: { x: 654, y: 292 },
    ancora: { x: 654, y: 316 },
  },

  // ——— ALTO PADRÃO — listar no mapa, NÃO priorizar em conteúdo/captação ———
  {
    slug: "ibiti-royal-park",
    nome: "Ibiti Royal Park",
    camada: "alto-padrao",
    faixaTipica: null,
    path: "M312 66 Q336 42 382 44 Q430 48 438 84 Q444 118 410 134 Q372 148 338 132 Q306 116 312 66 Z",
    label: { x: 374, y: 88 },
    ancora: { x: 374, y: 112 },
  },
  {
    slug: "jardim-ibiti-do-paco",
    nome: "Jardim Ibiti do Paço",
    camada: "alto-padrao",
    faixaTipica: null,
    path: "M470 54 Q492 32 534 34 Q576 38 582 72 Q586 104 554 118 Q518 130 490 114 Q464 98 470 54 Z",
    label: { x: 526, y: 74 },
    ancora: { x: 526, y: 96 },
  },
];

/** Vias esquemáticas — só orientação visual, traço leve. */
export const VIAS = [
  "M760 295 Q640 300 540 280 Q420 258 320 250 Q200 240 70 260",
  "M755 305 Q660 360 560 400 Q460 430 350 420",
  "M745 285 Q640 200 520 150 Q430 115 380 95",
];

export const MARCO_CENTRO = { x: 758, y: 294 };

export function bairroDoTerritorio(slug: string): BairroTerritorio | undefined {
  return TERRITORIO.find((b) => b.slug === slug);
}

export function nomeDoBairro(slug: string): string {
  return bairroDoTerritorio(slug)?.nome ?? slug;
}
