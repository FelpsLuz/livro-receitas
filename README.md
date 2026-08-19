# felipeluzcorretor.com.br

Site profissional de **Felipe Luz — Corretor de Imóveis · CRECI-SP 266.085-F**
(Sorocaba/SP, vetor oeste/noroeste). Astro estático, CSS puro, conteúdo em
Markdown com validação Zod, zero JavaScript para renderizar conteúdo.

Três funções comerciais: **captar proprietário** (avaliação), **converter
comprador / servir parceiro** (página por imóvel + ficha A4) e **ser
encontrável** (SEO local + cauda longa por condomínio + GEO para IAs).

## Comandos

| Comando | O que faz |
|---|---|
| `npm install` | instala dependências |
| `npm run dev` | servidor de desenvolvimento em `localhost:4321` |
| `npm run build` | build de produção em `dist/` (roda todas as travas) |
| `npm run preview` | serve o `dist/` localmente |
| `npm run check` | checagem de tipos dos templates |
| `npm run imagens-exemplo` | regenera as imagens procedurais de exemplo |

## Fonte única de verdade

`src/config.ts` concentra marca, CRECI, WhatsApp, e-mails, Instagram e
domínio. **Nenhum dado de contato é hardcoded em template.** A constante
`EMAIL_CONTATO` define o e-mail exibido no site (trocar para o profissional
após ativar o Email Routing — ver `docs/EMAIL.md`).

## Travas de build (o build FALHA se…)

1. …um imóvel publicável (`status` ≠ `pausado`) estiver sem
   `autorizacao_escrita: true` — trava legal (Decreto 81.871/78, art. 5º).
2. …`SITE.whatsappE164` não casar com `55 + DDD + 9 dígitos` — trava de
   conversão (roda em toda importação do config).
3. …um imóvel `vendido` estiver sem `vendido_em` — case sem data não é
   prova.

As mensagens de erro dizem exatamente qual arquivo/campo corrigir.

## Como adicionar conteúdo (sem tocar em código)

- **Imóvel**: criar `src/content/imoveis/fl-00XX.md` (copie um existente) e
  as fotos em `src/content/imoveis/fotos/` com nome descritivo
  (`fl-00xx-01-sala.jpg`, 3:2, mínimo 2400 px de largura). `alt` é
  obrigatório. A foto `[0]` é capa e imagem de OG.
- **Condomínio**: `src/content/condominios/slug.md`. `mapa_x`/`mapa_y`
  (0–100) posicionam o ponto no mapa do território.
- **Bairro**: `src/content/bairros/slug.md`. Para aparecer no mapa, o slug
  precisa existir também em `src/lib/territorio.ts` (polígono + rótulo).
- **Vendido**: mude `status: vendido` e preencha `vendido_em` (e
  `dias_para_vender`, senão é calculado de `publicado_em`). O valor final
  fica oculto por padrão (`exibir_valor: false` em vendidos — dado privado
  das partes).
- **Tirar do ar sem apagar**: `status: pausado` (nunca renderiza).

Agregados de vendas (contadores, mediana de dias) são **sempre calculados
das coleções** — nunca digite números de prova social à mão.

## Deploy — Cloudflare Pages

1. Painel Cloudflare → **Workers & Pages → Create → Pages → Connect to
   Git** → selecione este repositório.
2. Build command: `npm run build` · Output directory: `dist`.
3. Em **Custom domains**, aponte `felipeluzcorretor.com.br` (e `www`, se
   quiser, com redirect para o apex).
4. Variáveis de ambiente (podem ficar vazias no início): `PUBLIC_GA4_ID`,
   `PUBLIC_GOOGLE_ADS_ID`, `PUBLIC_WEB3FORMS_KEY` — ver `.env.example`.
5. Cada push na branch principal publica sozinho.

## Checklist de GO-LIVE (nesta ordem)

- [ ] **[PENDENTE — BLOQUEIA O GO-LIVE]** Confirmar o nome EXATO registrado
      no CRECI-SP e preencher `SITE.nomeRegistrado` em `src/config.ts`. Se
      for diferente de "Felipe Luz", o uso público de "Felipe Luz" é NOME
      ABREVIADO e exige protocolo prévio no CRECI-SP (Res. COFECI
      1.065/2007, art. 6º) **antes** de publicar.
- [ ] Substituir os 5 imóveis de exemplo (`placeholder: true`) por imóveis
      reais com autorização escrita — ou pausá-los (`status: pausado`).
- [ ] Substituir os 2 condomínios fictícios (Parque das Andorinhas, Reserva
      do Ipê) por condomínios reais do território e revisar os FAQs
      (números plausíveis foram usados como exemplo).
- [ ] Revisar os textos dos 3 bairros (faixas de preço e pontos de
      interesse foram preenchidos de forma plausível, marcados p/ revisão).
- [ ] Trocar as imagens procedurais por fotos reais (3:2, mín. 2400 px).
- [ ] Deploy na Cloudflare Pages (acima) + domínio canônico.
- [ ] `docs/SEO.md` — GSC, GBP, Bing, **desligar o bloqueio de AI crawlers
      da Cloudflare (ligado por padrão!)**, redirects 301 e Web3Forms.
- [ ] `docs/EMAIL.md` — ativar felipe@felipeluzcorretor.com.br e trocar
      `EMAIL_CONTATO` no config.
- [ ] `docs/MENSURACAO.md` — criar GA4 e Ads, preencher os dois IDs.

## Estrutura

```
src/
  config.ts              ← fonte única (dados + trava do WhatsApp)
  content.config.ts      ← schemas Zod + travas legais
  content/{imoveis,condominios,bairros}/  ← conteúdo em Markdown + fotos
  lib/                   ← domínio (imoveis, território, seo, og, llms…)
  components/            ← AssinaturaLegal, CardImovel, MapaTerritorio…
  layouts/Base.astro     ← head, JSON-LD, fontes, mensuração condicional
  pages/                 ← rotas (inclui og/*.png, llms*.txt, sitemap, robots)
docs/                    ← SEO.md, EMAIL.md, MENSURACAO.md
scripts/                 ← gerador das imagens de exemplo
```

## Compliance embutido (não remover)

- Assinatura legal (nome + "Corretor de Imóveis" + CRECI) no cabeçalho e no
  rodapé de todas as páginas, com proporção travada em CSS (≥ 25%).
- CRECI em toda peça: páginas, imagens OG geradas no build e ficha A4.
- **Telefone nunca renderizado como texto** — o número existe apenas dentro
  do link `wa.me` (`src/lib/whatsapp.ts`).
- Vendidos: valor oculto por padrão, localização só em nível de
  bairro/condomínio, fotos da própria captação, sem dados do comprador;
  depoimento de vendedor só via campo `depoimento_vendedor` (exige
  autorização expressa).
- LGPD: consentimento não pré-marcado em todo formulário, finalidade
  declarada, sem CPF/dado sensível, política de privacidade dedicada.
