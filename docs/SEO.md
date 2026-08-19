# SEO.md — Guia de ativação (para leigo, passo a passo)

Este guia ativa as três frentes de encontrabilidade do site: **busca local**
(Google Business Profile), **cauda longa territorial** (Google/Bing) e
**citação por IAs** (GEO). Faça na ordem. Nada aqui exige saber programar.

> Pré-requisito: o site publicado na Cloudflare Pages com o domínio
> `felipeluzcorretor.com.br` apontado (o DNS do domínio fica na Cloudflare).

---

## 1. Google Search Console (GSC)

1. Acesse **search.google.com/search-console** e entre com a conta Google que
   será a "dona" do site.
2. Clique em **Adicionar propriedade** → escolha o tipo **Domínio** e digite
   `felipeluzcorretor.com.br`.
3. O Google mostra um **registro TXT** para copiar.
4. Em outra aba, abra o painel da **Cloudflare** → site
   `felipeluzcorretor.com.br` → menu **DNS** → **Add record**:
   - Type: `TXT` · Name: `@` · Content: cole o valor copiado → **Save**.
5. Volte ao Search Console e clique em **Verificar** (pode levar alguns
   minutos).
6. Com a propriedade verificada, vá em **Sitemaps** (menu lateral), digite
   `sitemap-index.xml` e clique **Enviar**. Status esperado: "Êxito".

O sitemap já sai do site com data de atualização por página — nada a manter à mão.

## 2. Google Business Profile (GBP) — a frente de resultado mais rápido (2–6 semanas)

1. Acesse **business.google.com** → **Adicionar empresa**.
2. Nome do perfil: `Felipe Luz - Corretor de Imóveis` (mesma grafia do site).
3. Categoria: **Corretor de imóveis**.
4. Na pergunta sobre local físico que os clientes visitam: responda **Não**
   (atendimento em área, sem endereço exposto).
5. **Área de atendimento**: adicione Sorocaba e, como áreas, os bairros do
   território (Jardim Brasilândia, Vila Esperança, Jardim Alvorada, Vila
   Progresso, Jardim Leocádia, Jardim Botânico, Retiro São João, Jardim Santa
   Rosália).
6. Site: `https://felipeluzcorretor.com.br` · No campo de link de agendamento
   ou "links especiais", use `https://felipeluzcorretor.com.br/avaliacao`.
7. Conclua a verificação que o Google pedir (vídeo ou código).
8. Depois de ativo: publique 1 foto real de atuação por semana e responda
   toda avaliação recebida — é o que faz o perfil subir.

## 3. Bing Webmaster Tools — alimenta ChatGPT Search e Copilot

1. Acesse **bing.com/webmasters** e entre com qualquer conta Microsoft.
2. Clique em **Importar do Google Search Console** e autorize — ele puxa a
   propriedade e o sitemap do passo 1 automaticamente.
3. Confirme em **Sitemaps** que `sitemap-index.xml` aparece como enviado.

## 4. Cloudflare — dois ajustes obrigatórios

### 4a. ARMADILHA: desligar o bloqueio de crawlers de IA

Contas novas da Cloudflare vêm com o bloqueio de crawlers de IA **ligado por
padrão**. Se ficar ligado, todo o trabalho de GEO deste site é invisível
(robots.txt liberando não adianta — a Cloudflare bloqueia antes).

1. Painel Cloudflare → site `felipeluzcorretor.com.br` → **Security** →
   **Bots** (ou **Settings**, conforme a versão do painel).
2. Localize **"AI Crawlers"** / **"Block AI training bots"** / **"AI Scrapers
   and Crawlers"**.
3. Deixe **desativado** (Do not block / Off).
4. Confirme testando: `felipeluzcorretor.com.br/llms-full.txt` deve abrir
   normalmente em uma aba anônima.

### 4b. Redirects 301 dos outros domínios

1. Painel Cloudflare → **Bulk Redirects** (menu da conta, não do site).
2. Crie uma lista `redirects-felipeluz` com:
   - `felipeluzbroker.com.br/*` → `https://felipeluzcorretor.com.br/$1`
     (301, preservar caminho)
   - `felipeluz.com.br/*` → `https://felipeluzcorretor.com.br/$1` (301) —
     quando o domínio for adquirido.
3. Ative a regra e teste digitando `felipeluzbroker.com.br` no navegador:
   deve cair no site canônico.

## 5. Consistência de identidade (leva 10 minutos, vale muito)

O mesmo nome e o mesmo registro em todo lugar, sem variação:

> **Felipe Luz — Corretor de Imóveis · CRECI-SP 266.085-F**

- [ ] Bio do Instagram (@felipeasluz) com essa linha + link para
      `felipeluzcorretor.com.br/avaliacao`
- [ ] Google Business Profile (passo 2) com a mesma grafia
- [ ] Site (já sai correto do código)

## 6. Formulários por e-mail (Web3Forms) — 5 minutos

Enquanto não há chave, os formulários abrem o WhatsApp com a mensagem
estruturada (nenhum lead se perde). Para receber também por e-mail:

1. Acesse **web3forms.com** → **Create your Access Key**.
2. Informe o e-mail de destino (hoje: `feasluz@gmail.com`; depois do
   EMAIL.md: `felipe@felipeluzcorretor.com.br`) e confirme no link que chegar.
3. Copie a Access Key.
4. Cloudflare Pages → projeto do site → **Settings → Environment variables**:
   crie `PUBLIC_WEB3FORMS_KEY` com a chave → **Save** → **Retry deployment**
   (Deployments → ⋯ → Retry) para o build pegar a variável.

## 7. Prazos realistas por frente (para calibrar expectativa)

| Frente | Prazo típico de resultado |
|---|---|
| Busca local (GBP) | 2–6 semanas |
| Cauda longa (páginas de condomínio/bairro) | 3–6 meses |
| GEO (citação por IAs) | contínuo — sem data, cresce com conteúdo |

O vão até a cauda longa render é coberto com Google Ads (ver MENSURACAO.md —
a estrutura de conversão já está pronta no site).

---

## O que o site já entrega sozinho (não precisa ativar)

- `robots.txt` com allow explícito para GPTBot, ClaudeBot, PerplexityBot,
  Google-Extended, Bingbot e demais crawlers de IA
- `llms.txt` e `llms-full.txt` gerados no build a partir dos dados reais
- Sitemap com `lastmod` por página
- JSON-LD: RealEstateAgent + Person (com CRECI), RealEstateListing por
  imóvel (`SoldOut` nos vendidos), Place, FAQPage e BreadcrumbList
- Todo o conteúdo em HTML estático (crawlers de IA não executam JS)
