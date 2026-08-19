import { SITE } from "../config";

/**
 * REGRA ABSOLUTA (seção 8.5 do briefing): o número de telefone existe
 * apenas dentro do href — nunca renderizado como texto visível em
 * nenhuma peça (interface, ficha imprimível, imagem OG).
 */
export function linkWhatsApp(mensagem?: string): string {
  const base = `https://wa.me/${SITE.whatsappE164}`;
  return mensagem ? `${base}?text=${encodeURIComponent(mensagem)}` : base;
}

export function mensagemImovel(ref: string, titulo: string): string {
  return `Olá, Felipe. Vi o imóvel ${ref} (${titulo}) no seu site e quero saber mais.`;
}

export function mensagemVisita(ref: string): string {
  return `Olá, Felipe. Quero agendar uma visita ao imóvel ${ref}.`;
}

export function mensagemAvaliacao(): string {
  return "Olá, Felipe. Tenho um imóvel na região e quero saber quanto vale hoje.";
}
