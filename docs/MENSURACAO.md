# MENSURACAO.md — GA4 e Google Ads (passo a passo para leigo)

O site já tem a camada de mensuração completa embutida e **desligada**. Ela
liga sozinha quando os dois IDs abaixo forem preenchidos — nenhum código
precisa mudar.

## Onde colar os IDs

Cloudflare Pages → projeto do site → **Settings → Environment variables**:

| Variável | Formato | Onde conseguir |
|---|---|---|
| `PUBLIC_GA4_ID` | `G-XXXXXXXXXX` | Passo 1 abaixo |
| `PUBLIC_GOOGLE_ADS_ID` | `AW-XXXXXXXXX` | Passo 3 abaixo |

Depois de salvar: **Deployments → ⋯ → Retry deployment** (o build precisa
rodar de novo para as variáveis valerem).

## 1. Criar a propriedade GA4 (10 minutos)

1. Acesse **analytics.google.com** com a conta Google do negócio.
2. **Administrador** (engrenagem) → **Criar → Propriedade**.
3. Nome: `felipeluzcorretor.com.br` · Fuso: Brasil · Moeda: BRL.
4. Setor: Imobiliário · Objetivo: Gerar leads.
5. Plataforma: **Web** → URL `felipeluzcorretor.com.br`.
6. Ao final, o GA4 mostra o **ID de métricas** no formato `G-XXXXXXXXXX`
   (em **Fluxos de dados → Web** se precisar achar de novo).
7. Cole em `PUBLIC_GA4_ID` (tabela acima) e refaça o deploy.
8. Teste: abra o site, aceite navegar por 2–3 páginas e confira em
   **Relatórios → Tempo real** se a visita aparece.

## 2. Marcar a conversão primária no GA4

1. GA4 → **Administrador → Eventos**: após o primeiro envio de formulário,
   o evento `avaliacao_enviada` aparece na lista (pode levar até 24 h).
2. **Administrador → Conversões (Principais eventos) → Novo evento de
   conversão** → digite `avaliacao_enviada`.
3. Opcional: repita para `whatsapp_click` como conversão secundária.

## 3. Google Ads: criar e vincular

1. Acesse **ads.google.com** e crie a conta (modo especialista, sem
   campanha ainda, se preferir só preparar).
2. O ID da conta aparece no topo no formato `XXX-XXX-XXXX`; para o site,
   use o **ID de tag AW** — em **Ferramentas → Gerenciador de tags/Tag do
   Google** aparece como `AW-XXXXXXXXX`. Cole em `PUBLIC_GOOGLE_ADS_ID`.
3. **Vincular GA4 ↔ Ads**: no GA4, **Administrador → Vinculações do Google
   Ads → Vincular** → escolha a conta. Aceite a personalização de anúncios.
4. **Importar a conversão**: no Ads, **Metas → Conversões → Nova ação de
   conversão → Importar → Propriedades do Google Analytics 4 → Web** →
   selecione `avaliacao_enviada`. É contra ela que as campanhas otimizam.
5. Quando criar campanhas por tipo (proprietário × comprador), a estrutura
   do site já separa os rótulos: use `avaliacao_enviada` para captação e
   `whatsapp_click` (com parâmetro `ref`) para interesse em imóvel.

## Eventos que o site já dispara

| Evento | Quando | Parâmetros |
|---|---|---|
| `avaliacao_iniciada` | primeira interação com o formulário (home ou /avaliacao) | `origem` |
| `avaliacao_enviada` | chegada em /obrigado vinda de envio real — **conversão primária** | `origem` (home/avaliacao/parceiro) |
| `whatsapp_click` | clique em qualquer botão de WhatsApp | `ref`, `status` quando houver |
| `imovel_view` | abertura de página de imóvel | `ref`, `status` |
| `vendidos_view` | abertura de /vendidos | — |
| `ficha_parceiro_impressa` | clique em "Ficha para parceiro" | `ref` |
| `filtro_aplicado` | uso do filtro na vitrine | filtros ativos + `resultados` |

Detalhes técnicos: eventos de saída usam transporte beacon
(`navigator.sendBeacon` via gtag), então o clique no WhatsApp registra mesmo
com a aba fechando. Com as variáveis vazias, nenhum script carrega e o
console fica limpo.
