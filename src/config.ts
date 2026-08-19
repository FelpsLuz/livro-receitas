/**
 * FONTE ÚNICA DE VERDADE do projeto.
 * Todo componente consome daqui. Nenhum dado de contato ou identidade
 * pode ser hardcoded em template.
 */
export const SITE = {
  marcaPublica: "Felipe Luz",

  // [PENDENTE] Nome EXATO como consta no registro CRECI-SP.
  // Se diferente de "Felipe Luz", o uso público de "Felipe Luz" é NOME ABREVIADO
  // e exige protocolo prévio no CRECI-SP (Res. COFECI 1.065/2007, art. 6º).
  // Não bloqueia o build; bloqueia o go-live.
  nomeRegistrado: "[PENDENTE]",

  creci: "CRECI-SP 266.085-F",
  expressaoObrigatoria: "Corretor de Imóveis",

  cidade: "Sorocaba",
  uf: "SP",

  whatsappE164: "5515998106038",

  emailTemporario: "feasluz@gmail.com",                  // destino dos formulários até o routing
  emailProfissional: "felipe@felipeluzcorretor.com.br",  // criar na Fase 4 (Cloudflare Email Routing)

  instagram: "https://www.instagram.com/felipeasluz/",

  dominioCanonico: "https://felipeluzcorretor.com.br",
  redirects301: ["felipeluzbroker.com.br", "felipeluz.com.br"],
} as const;

/**
 * E-mail EXIBIDO no site e usado como destino informativo dos formulários.
 * Após ativar o Cloudflare Email Routing (Fase 4 — docs/EMAIL.md), trocar
 * para SITE.emailProfissional — é a única linha a mudar.
 */
export const EMAIL_CONTATO: string = SITE.emailTemporario;

/**
 * TRAVA DE BUILD — executa na importação deste módulo.
 * Como todas as páginas consomem SITE, qualquer build ou `astro dev`
 * falha imediatamente se o número estiver em formato errado.
 */
if (!/^55\d{2}9\d{8}$/.test(SITE.whatsappE164)) {
  throw new Error(
    "WHATSAPP INVÁLIDO: formato exigido 55 + DDD + 9 dígitos (celular BR). " +
      "Build bloqueado para impedir publicação de CTA com número errado. " +
      "Corrija SITE.whatsappE164 em src/config.ts."
  );
}
