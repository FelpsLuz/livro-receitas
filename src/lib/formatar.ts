const brl = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  maximumFractionDigits: 0,
});

export function precoBRL(valor: number): string {
  return brl.format(valor);
}

/** Faixa "R$ 380 mil – R$ 560 mil" para cards de bairro/condomínio. */
export function faixaCurta(min: number, max: number): string {
  const mil = (v: number) =>
    v >= 1_000_000 ? `${(v / 1_000_000).toLocaleString("pt-BR", { maximumFractionDigits: 1 })} mi` : `${Math.round(v / 1000)} mil`;
  return `R$ ${mil(min)} – R$ ${mil(max)}`;
}

const MESES_CURTOS = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];

/** "jun/2026" — usado no selo de vendido. */
export function mesAno(data: Date): string {
  return `${MESES_CURTOS[data.getUTCMonth()]}/${data.getUTCFullYear()}`;
}

export function dataISO(data: Date): string {
  return data.toISOString().split("T")[0];
}

export function dataLonga(data: Date): string {
  return data.toLocaleDateString("pt-BR", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
}

export function metros(area: number): string {
  return `${area.toLocaleString("pt-BR")} m²`;
}

export function plural(n: number, singular: string, pluralForma?: string): string {
  return n === 1 ? singular : (pluralForma ?? `${singular}s`);
}

/** "3 dorm. (1 suíte) · 2 vagas · 78 m²" — linha resumo dos cards. */
export function linhaResumo(dados: {
  dormitorios: number;
  suites?: number;
  vagas: number;
  area_util: number;
}): string {
  const partes: string[] = [];
  if (dados.dormitorios > 0) {
    let d = `${dados.dormitorios} dorm.`;
    if (dados.suites && dados.suites > 0) d += ` (${dados.suites} ${plural(dados.suites, "suíte")})`;
    partes.push(d);
  }
  if (dados.vagas > 0) partes.push(`${dados.vagas} ${plural(dados.vagas, "vaga")}`);
  partes.push(metros(dados.area_util));
  return partes.join(" · ");
}

export const TIPO_LABEL: Record<string, string> = {
  apartamento: "Apartamento",
  "casa-condominio": "Casa em condomínio",
  casa: "Casa",
  terreno: "Terreno",
};
