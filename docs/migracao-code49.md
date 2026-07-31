# Saída da Code 49 — sequência

**Nada de cancelamento antes dos passos 1, 2 e 3 estarem confirmados.** Depois
que o contrato encerra, o XML e o CDN das fotos costumam sair do ar junto, e a
carteira volta a existir só na unha.

---

## 1. Solicitar o XML — por escrito

A própria Code 49 orienta que, ao migrar, basta pedir o banco de dados em XML à
empresa que administra o site atual. É o padrão que eles operam, e o dado é seu.

Peça por e-mail (não por telefone, não por WhatsApp), com pedido de confirmação
de recebimento. Peça explicitamente:

- **o XML completo da carteira**, com todos os imóveis — ativos, reservados e
  **vendidos/arquivados** também. Os vendidos são o que alimenta `/vendidos/`;
  se vierem de fora, você perde o histórico inteiro;
- **as URLs das fotos em resolução máxima**, não as miniaturas do site;
- **a base de contatos/leads**, se o plano incluía CRM;
- **o prazo em que o conteúdo permanecerá no ar** após o pedido de cancelamento.

Guarde a resposta. É o comprovante de que o dado foi entregue — ou de que não foi.

## 2. Baixar as fotos

Com o XML em mãos:

```bash
php tools/baixar-fotos.php carteira.xml fotos/ --listar   # confere antes
php tools/baixar-fotos.php carteira.xml fotos/            # baixa
```

Sai organizado por referência do imóvel, mais um `indice.csv` ligando arquivo →
URL de origem. Confira o número de fotos por imóvel contra o site atual antes de
seguir. Falhas ficam marcadas no CSV; rodar de novo pula o que já baixou.

Guarde essa pasta fora do servidor também (drive, HD externo). Um backup que
mora no mesmo lugar que o original não é backup.

## 3. Mapear as URLs atuais

O domínio é o mesmo (`felipeluzbroker.com.br`), então toda URL antiga que sumir
vira 404 e leva junto o pouco de indexação que existe.

Levante as URLs em três fontes:

1. **Google Search Console** → Páginas → Indexadas. É a lista que importa.
2. `site:felipeluzbroker.com.br` no Google.
3. O `sitemap.xml` do site atual — normalmente em
   `felipeluzbroker.com.br/sitemap.xml`.

Preencha `wp-content/plugins/fl-imoveis/config/redirects.php`:

```php
return array(
    '/quem-somos'   => '/sobre/',
    '/fale-conosco' => '/contato/',
);
```

As fichas de imóvel geralmente não precisam entrar à mão: o `redirects.php` do
plugin tenta casar a referência presente na URL antiga (ex.: `/imovel/AP1234`)
com o campo *Ref.* importado do XML, e redireciona sozinho. Qualquer coisa sob
`/imoveis`, `/busca`, `/comprar` ou `/alugar` que não casar cai na vitrine — 301,
nunca 404.

**Confira também:** o CNAME/A do domínio, onde está registrado, e se o e-mail
(`@felipeluzbroker.com.br`) depende da mesma hospedagem. Se depender, migre o
e-mail antes — perder o e-mail profissional no meio da mudança é pior que perder
o site.

## 4. Montar o site novo em paralelo

Suba em um domínio de teste ou subdomínio, com `noindex` ligado. Siga o
`README.md` na seção *Instalação* e importe a carteira:

```bash
wp fl inspecionar-xml --file=carteira.xml     # entender o formato
wp fl importar-xml --file=carteira.xml --dry-run
wp fl importar-xml --file=carteira.xml --limite=3
wp fl importar-xml --file=carteira.xml
```

O `inspecionar-xml` mostra todas as tags do arquivo, quais o mapa já reconhece e
quais ficaram de fora. O que ficar de fora se resolve editando um arquivo só:
`config/mapa-xml.php`.

Depois de importar, revise imóvel por imóvel:

- **descrição própria.** O texto que veio do XML é o mesmo que está no portal.
  Reescreva. É o que diferencia a ficha de mais um anúncio;
- **data de captação** nos imóveis antigos — sem ela o "vendido em X dias" usa a
  data de publicação e a média sai errada;
- **situação** correta, principalmente os vendidos;
- **fotos**: apague as ruins. Vinte fotos medianas valem menos que oito boas.

## 5. Virar

Nesta ordem, no mesmo dia:

1. Publicar os imóveis revisados.
2. Desligar o `noindex`.
3. Apontar o domínio para a nova hospedagem.
4. Testar as 301: pegue 10 URLs da lista do passo 3 e abra uma a uma.
5. Enviar o novo `sitemap.xml` no Search Console (o Rank Math gera).
6. Atualizar o link do site no Instagram, no Google Business Profile, na
   assinatura de e-mail e no cartão.

## 6. Só então: cancelar

Confirme antes que a taxa de manutenção está em dia — segundo o FAQ da Code 49
não há fidelidade nem multa nessa condição. **Confirme no seu contrato
específico, não no site institucional deles.** Cancele por escrito e guarde o
protocolo.

Deixe o site antigo no ar por mais alguns dias depois da virada, se possível. É
barato e é a sua rede de segurança.

---

## O que você perde de verdade ao sair

Vale registrar, para não virar surpresa:

- **CRM e cruzamento automático lead × imóvel.** O plugin substitui a parte que
  importa (lead gravado, status, anotação, WhatsApp direto), mas não faz o
  cruzamento automático.
- **Feed XML automático para VivaReal/OLX/ImovelWeb.** Não existe neste site.
  Quando quiser voltar a alimentar portal, será preciso escrever um endpoint que
  exporte o CPT no formato de cada um. É trabalho de dev — factível, e não está
  pronto.
- **Distribuição no portal próprio da Code 49.**

O que você não perde: um tema compartilhado com outros milhares de corretores.
Para um portfólio, isso era o defeito, não a funcionalidade.
