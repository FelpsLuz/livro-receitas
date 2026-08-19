/**
 * Envio de formulários SEM backend próprio (seção 9.2), roda no navegador.
 *
 * Caminho principal: Web3Forms (a access key define o e-mail de destino —
 * hoje SITE.emailTemporario; ver .env.example e docs/SEO.md).
 * Sem chave configurada, o lead NÃO se perde: abre o WhatsApp com a mensagem
 * estruturada — o canal real de atendimento do corretor.
 */
import { SITE } from "../../config";

const CHAVE_WEB3FORMS: string = import.meta.env.PUBLIC_WEB3FORMS_KEY || "";

export interface Lead {
  assunto: string;
  /** Pares rótulo → valor, na ordem de exibição. */
  campos: [string, string][];
  nomeRemetente?: string;
  emailRemetente?: string;
}

function mensagemEstruturada(lead: Lead): string {
  const linhas = lead.campos
    .filter(([, valor]) => valor && valor.trim() !== "")
    .map(([rotulo, valor]) => `${rotulo}: ${valor.trim()}`);
  return `${lead.assunto}\n\n${linhas.join("\n")}`;
}

export type ResultadoEnvio = "email" | "whatsapp";

export async function enviarLead(lead: Lead): Promise<ResultadoEnvio> {
  if (CHAVE_WEB3FORMS) {
    try {
      const corpo: Record<string, string> = {
        access_key: CHAVE_WEB3FORMS,
        subject: lead.assunto,
        from_name: lead.nomeRemetente || SITE.marcaPublica,
        botcheck: "",
      };
      if (lead.emailRemetente) corpo.replyto = lead.emailRemetente;
      for (const [rotulo, valor] of lead.campos) {
        if (valor && valor.trim() !== "") corpo[rotulo] = valor.trim();
      }
      const resposta = await fetch("https://api.web3forms.com/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(corpo),
      });
      if (resposta.ok) return "email";
    } catch {
      // cai no WhatsApp
    }
  }

  const url = `https://wa.me/${SITE.whatsappE164}?text=${encodeURIComponent(mensagemEstruturada(lead))}`;
  window.open(url, "_blank", "noopener");
  return "whatsapp";
}

/** Marca a conversão para a página /obrigado disparar `avaliacao_enviada` uma única vez. */
export function marcarConversao(tipo: string): void {
  try {
    sessionStorage.setItem("conversao", tipo);
  } catch {
    // storage indisponível não impede o fluxo
  }
}
