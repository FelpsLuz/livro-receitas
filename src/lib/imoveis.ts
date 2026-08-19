import { getCollection, type CollectionEntry } from "astro:content";

export type Imovel = CollectionEntry<"imoveis">;
export type Condominio = CollectionEntry<"condominios">;
export type Bairro = CollectionEntry<"bairros">;

const MS_POR_DIA = 86_400_000;

/** Itens `pausado` nunca renderizam — em nenhuma listagem, rota ou feed. */
export async function imoveisRenderizaveis(): Promise<Imovel[]> {
  const todos = await getCollection("imoveis");
  return todos.filter((i) => i.data.status !== "pausado");
}

/** Vitrine (/imoveis): somente disponíveis e reservados, mais recentes primeiro. */
export async function imoveisVitrine(): Promise<Imovel[]> {
  const lista = await imoveisRenderizaveis();
  return lista
    .filter((i) => i.data.status === "disponivel" || i.data.status === "reservado")
    .sort((a, b) => b.data.publicado_em.getTime() - a.data.publicado_em.getTime());
}

export async function imoveisDisponiveis(): Promise<Imovel[]> {
  const lista = await imoveisVitrine();
  return lista.filter((i) => i.data.status === "disponivel");
}

/** Vendidos, mais recentes primeiro (por data da venda). */
export async function imoveisVendidos(): Promise<Imovel[]> {
  const lista = await imoveisRenderizaveis();
  return lista
    .filter((i) => i.data.status === "vendido")
    .sort((a, b) => (b.data.vendido_em?.getTime() ?? 0) - (a.data.vendido_em?.getTime() ?? 0));
}

export async function destaquesHome(): Promise<Imovel[]> {
  const lista = await imoveisDisponiveis();
  return lista.filter((i) => i.data.destaque_home).slice(0, 6);
}

/** Dias entre publicação e venda quando `dias_para_vender` não for informado. */
export function diasVenda(imovel: Imovel): number | null {
  const d = imovel.data;
  if (d.dias_para_vender) return d.dias_para_vender;
  if (d.vendido_em) {
    const dias = Math.round((d.vendido_em.getTime() - d.publicado_em.getTime()) / MS_POR_DIA);
    return dias > 0 ? dias : null;
  }
  return null;
}

export interface AgregadosVendas {
  total: number;
  medianaDias: number | null;
  bairros: string[];
}

/**
 * Agregados de prova social — SEMPRE calculados da coleção, nunca digitados.
 * Com menos de 3 casos retorna null (omitir agregados, mostrar só os cases).
 */
export async function agregadosVendas(): Promise<AgregadosVendas | null> {
  const vendidos = await imoveisVendidos();
  if (vendidos.length < 3) return null;
  const dias = vendidos
    .map((v) => diasVenda(v))
    .filter((d): d is number => d !== null)
    .sort((a, b) => a - b);
  let mediana: number | null = null;
  if (dias.length > 0) {
    const meio = Math.floor(dias.length / 2);
    mediana = dias.length % 2 ? dias[meio] : Math.round((dias[meio - 1] + dias[meio]) / 2);
  }
  const bairros = [...new Set(vendidos.map((v) => v.data.bairro))];
  return { total: vendidos.length, medianaDias: mediana, bairros };
}

/** Imóveis semelhantes: mesmo bairro OU faixa de preço ±20%. Somente disponíveis. */
export async function imoveisSemelhantes(imovel: Imovel, limite = 3): Promise<Imovel[]> {
  const disponiveis = await imoveisDisponiveis();
  const candidatos = disponiveis.filter((i) => i.id !== imovel.id);
  const mesmoBairro = candidatos.filter((i) => i.data.bairro === imovel.data.bairro);
  const mesmaFaixa = candidatos.filter(
    (i) =>
      i.data.bairro !== imovel.data.bairro &&
      Math.abs(i.data.valor - imovel.data.valor) <= imovel.data.valor * 0.2
  );
  return [...mesmoBairro, ...mesmaFaixa].slice(0, limite);
}

export async function imoveisDoCondominio(slug: string): Promise<Imovel[]> {
  const lista = await imoveisRenderizaveis();
  return lista.filter((i) => i.data.condominio === slug);
}

export async function imoveisDoBairro(slug: string): Promise<Imovel[]> {
  const lista = await imoveisRenderizaveis();
  return lista.filter((i) => i.data.bairro === slug);
}

/** Contagem de DISPONÍVEIS por bairro — alimenta o mapa e a grade da home. */
export async function contagemPorBairro(): Promise<Map<string, number>> {
  const disponiveis = await imoveisDisponiveis();
  const mapa = new Map<string, number>();
  for (const i of disponiveis) {
    mapa.set(i.data.bairro, (mapa.get(i.data.bairro) ?? 0) + 1);
  }
  return mapa;
}

/** Vendas concluídas por bairro — o mapa também é prova de atividade. */
export async function vendasPorBairro(): Promise<Map<string, number>> {
  const vendidos = await imoveisVendidos();
  const mapa = new Map<string, number>();
  for (const i of vendidos) {
    mapa.set(i.data.bairro, (mapa.get(i.data.bairro) ?? 0) + 1);
  }
  return mapa;
}

/** Faixa de preço real praticada num bairro (a partir dos imóveis renderizáveis). */
export async function faixaDoBairro(slug: string): Promise<{ min: number; max: number } | null> {
  const lista = (await imoveisDoBairro(slug)).filter((i) => i.data.exibir_valor);
  if (lista.length === 0) return null;
  const valores = lista.map((i) => i.data.valor);
  return { min: Math.min(...valores), max: Math.max(...valores) };
}
