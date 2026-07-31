# felipeluzbroker.com.br

Site-portfólio de Felipe Luz, corretor de imóveis. Substitui o site da Code 49.

O site tem **um trabalho comercial principal: captar proprietário.** A carteira
não é o produto — é a prova de que o corretor vende. Comprador vem do portal;
quem chega aqui chega por Instagram, WhatsApp, indicação ou buscando o nome.
Toda decisão de código abaixo segue disso.

## O que está aqui

```
wp-content/
  plugins/fl-imoveis/     CPT, campos, filtro, leads, schema, 301, importador XML
  themes/felipeluz/       tema-filho do GeneratePress: templates e estilos
tools/
  baixar-fotos.php        backup das fotos da carteira, direto do XML
  testes/                 testes do parser do importador (rodam sem WordPress)
docs/
  migracao-code49.md      a sequência de saída, passo a passo
```

O plugin guarda os dados; o tema guarda a aparência. Trocar de tema um dia não
apaga a carteira.

## Estrutura de páginas

| URL | Template | Função |
|---|---|---|
| `/` | `front-page.php` | Posicionamento, prova e CTA duplo |
| `/imoveis/` | `archive-imovel.php` | Vitrine da carteira ativa, com filtro |
| `/imovel/[slug]/` | `single-imovel.php` | Ficha individual |
| `/vendidos/` | `vendidos.php` | Prova social permanente |
| `/quero-vender/` | `quero-vender.php` | Captação de proprietário |
| `/sobre/` | `sobre.php` | Autoridade: CRECI, formação, números |
| `/contato/` | `contato.php` | Canais + formulário |

`/bairro/[termo]/` tem template próprio (`taxonomy-imovel_bairro.php`): é o hub
do bairro, onde o texto sobre a região mora **uma vez só**, na descrição do
termo. As fichas linkam para lá em vez de repetir o mesmo parágrafo em doze
páginas — isso seria conteúdo duplicado. `/tipo/[termo]/` e
`/finalidade/[termo]/` usam o template da vitrine.

## Instalação

Requisitos: WordPress 6.0+, PHP 7.4+, tema **GeneratePress** (gratuito) instalado
como tema-pai.

1. Copie `wp-content/plugins/fl-imoveis/` e `wp-content/themes/felipeluz/` para a
   instalação.
2. Instale e ative o GeneratePress. Ative o tema **Felipe Luz Broker**.
3. Instale e ative o **Meta Box** (gratuito) — é a interface de edição dos campos.
   Sem ele o site continua exibindo tudo, mas ninguém consegue cadastrar imóvel.
4. Ative o plugin **FL Imóveis**.
5. Crie as páginas fixas:
   ```bash
   wp fl instalar-paginas
   ```
   Isso cria `/inicio/`, `/quero-vender/`, `/vendidos/`, `/sobre/` e `/contato/`,
   aplica os templates certos e aponta a home. (Sem WP-CLI: crie as páginas à mão
   e selecione o template em *Atributos da página*.)
6. Em **Imóveis › Configurações**, preencha WhatsApp, CRECI, e-mail e cidade.
   O CRECI aparece no rodapé e em cada ficha — exigência do COFECI para
   publicidade imobiliária; confirme a resolução vigente no CRECI/SP.
7. **Configurações › Links permanentes** → Salvar. (Regrava as regras de URL.)

### Rodar local antes de mexer no site de produção

Há um `docker-compose.yml` pronto com WordPress, MariaDB e WP-CLI. As instruções
estão comentadas no topo do arquivo — sobe em `http://localhost:8080` com o tema
e o plugin já montados a partir do repositório. Use isso para testar a
importação do XML sem risco.

### Plugins recomendados além desses

`Rank Math` (SEO), `LiteSpeed Cache` ou `WP Super Cache`, `UpdraftPlus` (backup).
Formulário não precisa: a captação é nativa, e o lead é gravado no banco.

No Rank Math, configure o sitemap segmentado (imóveis / páginas) e submeta no
Search Console. Sem plugin de SEO o site usa o `wp-sitemap.xml` do core, que já
inclui o CPT — funciona, mas sem segmentação.

## Importar a carteira do XML

Ordem obrigatória — leia `docs/migracao-code49.md` antes.

```bash
# 1. Descobrir o formato do XML e o que o mapa de campos já reconhece
wp fl inspecionar-xml --file=carteira.xml

# 2. Ajustar wp-content/plugins/fl-imoveis/config/mapa-xml.php se algo faltar

# 3. Ensaiar sem gravar nada
wp fl importar-xml --file=carteira.xml --dry-run

# 4. Testar de verdade com poucos imóveis
wp fl importar-xml --file=carteira.xml --limite=3

# 5. Importar tudo (entra como rascunho; revise e publique)
wp fl importar-xml --file=carteira.xml
```

O importador é idempotente: casa pelo campo *Ref.*, atualiza em vez de duplicar,
e não rebaixa fotos de imóvel que já tem galeria.

Opções: `--status=publish`, `--sem-imagens`, `--max-imagens=N`, `--limite=N`.

### Backup das fotos, independente do site

```bash
php tools/baixar-fotos.php carteira.xml fotos/
```

Salva tudo em `fotos/[REF]/01.jpg` mais um `indice.csv` com as URLs de origem.
Rode isso **antes** de cancelar: quando o contrato encerra, o CDN das fotos
costuma cair junto.

## Regras que valem para sempre

- **Imóvel vendido nunca é deletado.** Muda `situacao` para `vendido`, a URL
  segue viva, a ficha ganha faixa "Vendido em X dias" e um link para
  `/quero-vender/`. Cada venda vira prova permanente — é o principal ativo que
  a Code 49 não entrega.
- Descrição própria em cada ficha. Nunca copiada do portal.
- Fotografia é o fator número um. Portfólio com foto ruim é pior que portfólio
  nenhum.
- Endereço exato fica em campo interno e não aparece no site. Bairro e cidade,
  sim.

## Números da home e da LP

`vendidos`, `dias médios entre captação e venda` e `ticket médio` são calculados
dos imóveis reais, com cache de 1 hora, invalidado a cada alteração. Não há
número digitado à mão em lugar nenhum: se não houver venda registrada, o bloco
simplesmente não aparece.

O "dias para venda" usa `data_captacao → data_venda`. Sem data de captação, cai
para a data de publicação do post — então preencha a captação ao importar
imóveis antigos, senão a média sai inflada.

## Leads

Formulários nativos, com honeypot e armadilha de tempo. Cada envio vira um post
do tipo `Lead` com status (`novo → contatado → reunião → captado/perdido`),
anotações e link direto de WhatsApp na listagem. Cópia por e-mail para o
endereço configurado. Exportação CSV em *Imóveis › Configurações*.

## Testes

```bash
php tools/testes/teste-importador.php   # 59 verificações do parser de XML
php tools/testes/teste-conteudo.php     # 47 verificações dos textos gerados
```

Rodam sem WordPress, com stubs mínimos.

O primeiro cobre dois formatos de XML: feed de CRM (tags em português,
`1.250.000,00`) e feed de portal (namespace, tags em inglês, muitas fotos e
características por imóvel). Quando o XML real da Code 49 chegar, jogue uma
cópia anonimizada em `tools/testes/amostras/` e acrescente um bloco de
verificações — é o que impede um ajuste no mapa de campos de quebrar outro
formato.

O segundo cobre a resposta direta, a tabela de especificações e o FAQ. São
textos gerados: um erro ali não quebra nada, só publica uma frase errada em
toda ficha do site — o pior tipo de bug, porque ninguém percebe.

Lint de tudo:

```bash
find wp-content tools -name '*.php' -exec php -l {} \;
```

## A jornada mobile

O caminho é o mesmo para todo visitante, e cada etapa tem um requisito técnico
que a sustenta:

| Momento | O que acontece | O que garante |
|---|---|---|
| 0–3s, chegada | Rosto, nome, CRECI, posicionamento e dois botões | Sem carrossel e sem popup. Imagem do topo em WebP, `fetchpriority="high"`, com `preload` e proporção reservada |
| 3–15s, confiança | Números reais, CRECI e avaliações do Google | Nada digitado à mão: os números saem da carteira |
| Exploração | Cards em coluna única, foto 4:3, preço em destaque, três dados | Filtro abre fechado, como bottom sheet. Paginação rastreável, nunca scroll infinito |
| A ficha | Ver abaixo | — |
| Contato | CTA fixo no rodapé com o preço ao lado | `inputmode`, `font-size:16px`, alvo de toque de 44px, honeypot no lugar de CAPTCHA |

O CTA fixo aparece só até 900px de largura — no desktop a caixa lateral já
cumpre o papel. Ele sozinho costuma dobrar a taxa de contato em mobile.

Sobre fontes: o tema usa system stack e Georgia. Sem webfont, `font-display` não
tem o que resolver — e o LCP não espera por download nenhum.

## Anatomia da ficha

A ordem dos blocos não é estética, é funcional:

1. **Galeria** — swipe com `scroll-snap` puro em CSS. A primeira foto é `eager`
   com `fetchpriority="high"`, o resto é `lazy`. O alt sai de `fl_alt_foto()`:
   usa o alt do anexo se alguém escreveu um, senão monta *"Apartamento no
   Campolim, Sorocaba — foto 2 de 12"*. Nunca "foto-1".
2. **Resposta direta** — 2 a 3 frases com tipo, bairro, cidade, área,
   dormitórios, vagas e o preço numérico. É o parágrafo que a IA extrai. Sai
   pronto dos campos; o campo *Resposta direta* só existe para sobrescrever.
3. **Preço, condomínio e IPTU** explícitos. "Consulte-nos" é sabotagem tripla:
   destrói conversão, esvazia o `offers.price` do schema e torna o imóvel
   invisível para qualquer sistema que precise do número.
4. **Tabela de especificações** em `<table>` — o formato que LLM extrai melhor.
5. **Descrição própria**, 250 a 400 palavras, escritas à mão.
6. **Diferenciais em lista**, nunca em parágrafo corrido.
7. **Localização** — link para o hub do bairro. O mapa só carrega sob clique
   (iframe de mapa é o segundo maior vilão de performance depois de imagem), com
   a altura reservada por CSS para o CLS não estourar.
8. **FAQ** — o corretor responde cinco perguntinhas no painel (financiamento,
   permuta, ocupação, o que o condomínio inclui, distância até o centro) e o
   bloco sai montado, junto com o `FAQPage`. Perguntas extras em
   `Pergunta :: Resposta`, uma por linha.
9. **Relacionados** — mesmo bairro, alimenta link interno.
10. **CTA fixo.**

## SEO técnico e camada de IA

- **HTML no servidor.** Nada essencial injetado por JavaScript — crawler de LLM
  em geral não executa JS. É uma vantagem real do WordPress sobre SPA.
- **Uma URL canônica por listagem.** Vistas filtradas (`?tipo=casa&ordem=…`)
  recebem canonical para a versão limpa e `noindex,follow`.
- **Schema JSON-LD**: `RealEstateAgent` com `sameAs` (Google Business Profile,
  Instagram, LinkedIn) na home; `RealEstateListing` + `Offer` + `Residence` na
  ficha; `FAQPage`; e `BreadcrumbList`, que continua gerando rich result — o de
  FAQ o Google aposentou em 2023 para a maioria dos sites, então o markup vale
  como leitura por máquina, não como estrela no resultado.
- **robots.txt** libera GPTBot, OAI-SearchBot, ChatGPT-User, PerplexityBot,
  ClaudeBot, Claude-SearchBot, Applebot-Extended e Google-Extended. Bloquear
  Google-Extended não tiraria o site das AI Overviews (aquilo usa o índice do
  Googlebot) — não há ganho em bloquear nada aqui. Só funciona se não houver um
  `robots.txt` físico na raiz.
- **WebP** nos tamanhos gerados, via `image_editor_output_format`. O original
  enviado fica intacto.
- **`/llms.txt`** existe. Custou dez minutos e não há evidência de que algum
  provedor relevante consuma o arquivo hoje. Não conte com ele.

**Consistência de entidade (NAP).** Nome, cidade e contato precisam ser
idênticos — mesma grafia, mesma ordem — no site, no Google Business Profile, no
Instagram e no LinkedIn. É o que a tela de Configurações centraliza. Divergência
fragmenta a entidade e é o erro que mais custa em SEO local.

O que move o ponteiro na IA está **fora** do site: volume de avaliações no
Google, menções da marca em sites locais de Sorocaba, e conteúdo com dado
proprietário que ninguém mais tem — seu levantamento de preço por bairro. Isso é
o que faz outro site te citar, e citação externa é a moeda. O lugar desse dado é
a descrição do termo em *Imóveis › Bairros*, com fonte e data: *"R$ 8.400/m² em
média no Campolim (levantamento próprio, jul/2026)"*. Dado datado é citável;
adjetivo não é.

## O que medir

| Métrica | Meta | Onde |
|---|---|---|
| LCP mobile | < 2,5s | Search Console, dados de campo — não o PageSpeed |
| INP | < 200ms | Search Console |
| CLS | < 0,1 | Search Console |
| Taxa de contato na ficha | > 3% | GA4, evento `contato_whatsapp` |
| Páginas indexadas | > 90% das enviadas | Search Console |
| Leads de `/quero-vender/` | **métrica principal** | GA4, evento `generate_lead` com `origem=quero-vender` |

Os eventos vão para o `dataLayer` e para o `gtag`, se houver. Basta instalar o
GA4 ou o GTM — nenhum código a mais: `generate_lead` (com a origem),
`contato_whatsapp`, `cta_captacao`, `cta_vitrine` e `cta_formulario`, todos com
o `local` de onde foram clicados.

## O que este site deliberadamente não faz

- **Não gera feed XML para portais.** Foi decisão consciente: quando quiser
  voltar a alimentar VivaReal/OLX, será preciso escrever um endpoint que exporte
  o CPT no formato do portal. É trabalho de dev, factível, mas não está pronto.
- **Não tem SEO programático nem arquitetura de silo.** Com 20–40 imóveis não
  compensa. Se a carteira crescer muito, `/guias/[bairro]/` é o próximo passo.
- **Não tem CRM completo.** Tem o suficiente para não perder lead: registro,
  status e anotação.
