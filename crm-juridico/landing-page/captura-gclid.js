// Script de captura do GCLID (Google Click ID) para a Landing Page.
//
// Como usar: inclua este arquivo antes do fechamento de </body> na sua página
// (ou use uma tag <script src="captura-gclid.js"></script>).
//
// O que ele faz:
// 1. Quando alguem chega na pagina vindo de um anuncio do Google Ads, a URL
//    tem o parametro ?gclid=XXXXX. Este script le esse parametro e guarda no
//    localStorage do navegador (assim ele "sobrevive" mesmo que o visitante
//    navegue para outras paginas do site antes de clicar no WhatsApp).
// 2. Ele encontra automaticamente os links de WhatsApp da pagina (wa.me ou
//    api.whatsapp.com/send) e adiciona "GCLID:XXXXX" no final da mensagem
//    pre-preenchida, para o estagiario ver o GCLID na conversa e colar no
//    campo "GCLID" do cadastro do cliente no CRM Juridico.

(function () {
  function obterParametroUrl(nome) {
    const parametros = new URLSearchParams(window.location.search);
    return parametros.get(nome);
  }

  function capturarGclid() {
    const gclidDaUrl = obterParametroUrl('gclid');
    if (gclidDaUrl) {
      localStorage.setItem('gclid', gclidDaUrl);
      localStorage.setItem('gclid_capturado_em', new Date().toISOString());
    }
    return localStorage.getItem('gclid');
  }

  function anexarGclidNosLinksWhatsapp(gclid) {
    if (!gclid) return;

    const seletor = 'a[href*="wa.me/"], a[href*="api.whatsapp.com/send"]';
    document.querySelectorAll(seletor).forEach((link) => {
      try {
        const url = new URL(link.href, window.location.origin);
        const textoAtual = url.searchParams.get('text') || '';
        if (textoAtual.includes('GCLID:')) return;

        const novoTexto = textoAtual ? `${textoAtual} (GCLID:${gclid})` : `GCLID:${gclid}`;
        url.searchParams.set('text', novoTexto);
        link.href = url.toString();
      } catch (erro) {
        console.warn('captura-gclid: nao foi possivel processar o link', link.href, erro);
      }
    });
  }

  function iniciar() {
    const gclid = capturarGclid();
    anexarGclidNosLinksWhatsapp(gclid);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
  } else {
    iniciar();
  }
})();
