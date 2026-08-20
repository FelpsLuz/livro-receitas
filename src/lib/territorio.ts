/**
 * O TERRITÓRIO — ativo central do posicionamento (seção 3 do briefing).
 * Bairros e condomínios são adicionados AQUI e nas coleções de conteúdo,
 * sem tocar em código de template.
 *
 * MAPA v2 (Fase 5): geografia validada contra a grade 12×12 do briefing de
 * direção de arte — origem no canto superior esquerdo, norte para cima,
 * Centro fora do quadro a leste. Mapeamento: px = 40 + 60·x · py = 35 + 40·y.
 * Polígonos simplificados de 10–12 vértices, traçado à mão estabilizado.
 * O mapa segue esquemático (sem escala), mas as POSIÇÕES RELATIVAS são reais:
 * Leocádia a LESTE da Brasilândia (perto da Vila Progresso), Alvorada a
 * SUDOESTE, Ibitis ao norte, Botânico/Facens a nordeste do miolo.
 */

export type Camada = "nucleo" | "faixa-alta" | "alto-padrao";

export interface BairroTerritorio {
  slug: string;
  nome: string;
  camada: Camada;
  /** Faixa típica da camada — números fornecidos no briefing (seção 3). */
  faixaTipica: { min: number; max: number } | null;
  /** Polígono simplificado no viewBox 800×540. */
  path: string;
  /** Âncora do rótulo (primeira linha). */
  label: { x: number; y: number };
  /** Rótulo quebrado em até 2 linhas, caixa alta. */
  labelLinhas: [string] | [string, string];
  /** Âncora da linha de pontos/contadores. */
  ancora: { x: number; y: number };
}

export const CAMADA_LABEL: Record<Camada, string> = {
  nucleo: "Núcleo — volume",
  "faixa-alta": "Faixa alta do médio",
  "alto-padrao": "Alto padrão",
};

export const CAMADA_CURTA: Record<Camada, string> = {
  nucleo: "núcleo",
  "faixa-alta": "faixa alta",
  "alto-padrao": "alto padrão",
};

export const VIEWBOX = { largura: 800, altura: 540 };

const P = (pontos: [number, number][]): string =>
  `M ${pontos.map(([x, y]) => `${x} ${y}`).join(" L ")} Z`;

export const TERRITORIO: BairroTerritorio[] = [
  // ——— ALTO PADRÃO — norte. Listar no mapa, NÃO priorizar (grid 3,1 · 6,1) ———
  {
    slug: "ibiti-royal-park",
    nome: "Ibiti Royal Park",
    camada: "alto-padrao",
    faixaTipica: null,
    path: P([[128,58],[150,34],[196,24],[248,28],[288,46],[296,72],[272,96],[228,108],[178,104],[140,86]]),
    label: { x: 212, y: 60 },
    labelLinhas: ["IBITI", "ROYAL PARK"],
    ancora: { x: 212, y: 88 },
  },
  {
    slug: "jardim-ibiti-do-paco",
    nome: "Jardim Ibiti do Paço",
    camada: "alto-padrao",
    faixaTipica: null,
    path: P([[330,66],[352,38],[398,26],[446,34],[472,58],[468,88],[438,106],[394,112],[352,100],[334,84]]),
    label: { x: 400, y: 62 },
    labelLinhas: ["JARDIM IBITI", "DO PAÇO"],
    ancora: { x: 400, y: 90 },
  },

  // ——— FAIXA ALTA DO MÉDIO (R$ 500–900 mil) — grid 7,3 · 9,4 · 6,9 ———
  {
    slug: "retiro-sao-joao",
    nome: "Retiro São João",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: P([[402,150],[420,124],[458,112],[500,120],[520,142],[516,172],[494,192],[452,198],[418,186],[404,168]]),
    label: { x: 460, y: 148 },
    labelLinhas: ["RETIRO", "SÃO JOÃO"],
    ancora: { x: 460, y: 176 },
  },
  {
    slug: "jardim-botanico",
    nome: "Jardim Botânico",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: P([[528,188],[548,158],[588,144],[632,150],[658,172],[660,204],[636,228],[596,240],[556,230],[532,210]]),
    label: { x: 594, y: 184 },
    labelLinhas: ["JARDIM", "BOTÂNICO"],
    ancora: { x: 594, y: 212 },
  },
  {
    slug: "jardim-santa-rosalia",
    nome: "Jardim Santa Rosália",
    camada: "faixa-alta",
    faixaTipica: { min: 500_000, max: 900_000 },
    path: P([[336,414],[354,386],[390,374],[428,380],[450,402],[446,432],[420,452],[382,456],[350,444],[336,428]]),
    label: { x: 392, y: 408 },
    labelLinhas: ["JARDIM", "SANTA ROSÁLIA"],
    ancora: { x: 392, y: 436 },
  },

  // ——— NÚCLEO (volume — R$ 300–600 mil) — grid 3,6 · 3,8 · 8,6 · 7,7 · 2,9 ———
  {
    slug: "jardim-brasilandia",
    nome: "Jardim Brasilândia",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    // 14 vértices com reentrância a sudeste — o "carro-chefe" do território.
    path: P([[128,262],[140,230],[168,210],[210,200],[252,204],[284,222],[298,248],[290,276],[266,282],[258,300],[226,312],[188,308],[150,296],[132,280]]),
    label: { x: 212, y: 250 },
    labelLinhas: ["JARDIM", "BRASILÂNDIA"],
    ancora: { x: 212, y: 286 },
  },
  {
    slug: "vila-esperanca",
    nome: "Vila Esperança",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: P([[150,336],[174,320],[210,318],[244,324],[266,340],[268,364],[250,384],[214,394],[178,390],[152,372],[144,352]]),
    label: { x: 206, y: 352 },
    labelLinhas: ["VILA", "ESPERANÇA"],
    ancora: { x: 206, y: 378 },
  },
  {
    slug: "jardim-leocadia",
    nome: "Jardim Leocádia",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: P([[478,254],[494,230],[526,218],[560,226],[578,248],[574,276],[552,294],[518,300],[490,290],[476,272]]),
    label: { x: 526, y: 254 },
    labelLinhas: ["JARDIM", "LEOCÁDIA"],
    ancora: { x: 526, y: 282 },
  },
  {
    slug: "vila-progresso",
    nome: "Vila Progresso",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: P([[400,318],[418,292],[452,280],[486,290],[500,312],[494,338],[470,354],[436,358],[408,344],[398,330]]),
    label: { x: 448, y: 312 },
    labelLinhas: ["VILA", "PROGRESSO"],
    ancora: { x: 448, y: 338 },
  },
  {
    slug: "jardim-alvorada",
    nome: "Jardim Alvorada",
    camada: "nucleo",
    faixaTipica: { min: 300_000, max: 600_000 },
    path: P([[84,436],[102,408],[138,396],[176,406],[194,428],[190,456],[164,474],[128,478],[98,466],[82,450]]),
    label: { x: 138, y: 430 },
    labelLinhas: ["JARDIM", "ALVORADA"],
    ancora: { x: 138, y: 458 },
  },
];

/** Marcos de referência — não clicáveis, dão veracidade (Fase 5, 1.2). */
export const MARCOS = {
  parqueDasAguas: {
    nome: "PQ. DAS ÁGUAS",
    path: "M 296 184 Q 306 158 336 150 Q 370 144 390 164 Q 404 184 390 204 Q 372 222 342 218 Q 310 214 296 184 Z",
    label: { x: 344, y: 240 },
  },
  avArturBernardes: {
    nome: "AV. DR. ARTUR BERNARDES",
    path: "M 468 40 Q 462 160 456 280 Q 450 400 444 520",
    label: { x: 478, y: 30 },
  },
  sp079: {
    nome: "SP-079",
    linhas: ["M 468 538 L 800 424", "M 478 526 L 796 414"],
    label: { x: 640, y: 470, rotacao: -19 },
  },
  /** Conectores urbanos em direção ao Centro — só orientação. */
  conectores: ["M 662 208 Q 722 234 792 242", "M 578 268 Q 664 282 736 278"],
  centro: { x: 792, y: 300, label: { x: 758, y: 290 } },
  norte: { x: 766, y: 32 },
} as const;

/** Compatibilidade: vias esquemáticas usadas pelo MiniMapa. */
export const VIAS: string[] = [MARCOS.avArturBernardes.path, ...MARCOS.sp079.linhas];

export const MARCO_CENTRO = { x: MARCOS.centro.x, y: MARCOS.centro.y };

export function bairroDoTerritorio(slug: string): BairroTerritorio | undefined {
  return TERRITORIO.find((b) => b.slug === slug);
}

export function nomeDoBairro(slug: string): string {
  return bairroDoTerritorio(slug)?.nome ?? slug;
}
