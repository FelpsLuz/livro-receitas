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
| `/sobre/` | padrão | Autoridade: CRECI, trajetória, números |
| `/contato/` | `contato.php` | Canais + formulário |

Também respondem `/tipo/[termo]/`, `/bairro/[termo]/` e `/finalidade/[termo]/`,
usando o mesmo template da vitrine.

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
php tools/testes/teste-importador.php
```

59 verificações sobre o parser, em dois formatos de XML: feed de CRM (tags em
português, `1.250.000,00`) e feed de portal (namespace, tags em inglês, muitas
fotos e características por imóvel). Rodam sem WordPress.

Quando o XML real da Code 49 chegar, jogue uma cópia anonimizada em
`tools/testes/amostras/` e acrescente um bloco de verificações. É o que impede
um ajuste no mapa de campos de quebrar outro formato.

Lint de tudo:

```bash
find wp-content tools -name '*.php' -exec php -l {} \;
```

## O que este site deliberadamente não faz

- **Não gera feed XML para portais.** Foi decisão consciente: quando quiser
  voltar a alimentar VivaReal/OLX, será preciso escrever um endpoint que exporte
  o CPT no formato do portal. É trabalho de dev, factível, mas não está pronto.
- **Não tem SEO programático nem arquitetura de silo.** Com 20–40 imóveis não
  compensa. Se a carteira crescer muito, `/guias/[bairro]/` é o próximo passo.
- **Não tem CRM completo.** Tem o suficiente para não perder lead: registro,
  status e anotação.
