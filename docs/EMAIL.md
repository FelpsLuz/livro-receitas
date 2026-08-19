# EMAIL.md — E-mail profissional com Cloudflare Email Routing (custo zero)

Objetivo: criar `felipe@felipeluzcorretor.com.br` encaminhando para
`feasluz@gmail.com`. O Gmail continua sendo a caixa de entrada; o cliente vê
o domínio próprio.

## Ativação (10 minutos)

1. Painel **Cloudflare** → site `felipeluzcorretor.com.br` → menu
   **Email** → **Email Routing** → **Get started / Enable Email Routing**.
2. Em **Custom addresses** → **Create address**:
   - Custom address: `felipe`
   - Action: **Send to an email** → Destination: `feasluz@gmail.com`
3. A Cloudflare envia um e-mail de confirmação para `feasluz@gmail.com` —
   abra e clique em **Verify email address**.
4. Volte à aba **Email Routing**: a Cloudflare oferece **Add records and
   enable** para criar os registros DNS automaticamente. Aceite.
5. Confira em **DNS → Records** que existem (criados automaticamente):

   | Tipo | Nome | Conteúdo | Prioridade |
   |---|---|---|---|
   | MX | @ | `route1.mx.cloudflare.net` | 5 |
   | MX | @ | `route2.mx.cloudflare.net` | 12 |
   | MX | @ | `route3.mx.cloudflare.net` | 89 |
   | TXT | @ | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — |

6. Status esperado na tela do Email Routing: **Enabled**, endereço
   `felipe@felipeluzcorretor.com.br` como **Active**.
7. Teste: envie um e-mail de qualquer conta para
   `felipe@felipeluzcorretor.com.br` e confirme que caiu no Gmail.

## Para RESPONDER como felipe@ (opcional, recomendado)

No Gmail: **Configurações → Contas e importação → Enviar e-mail como →
Adicionar outro endereço**. Informe `felipe@felipeluzcorretor.com.br`.
Para o envio autenticado, o caminho simples é usar o próprio SMTP do Gmail
com "Tratar como um alias" marcado; o cliente verá o remetente felipe@.

## Depois de ativo — trocar no site (1 linha)

Em `src/config.ts`, a constante `EMAIL_CONTATO` define o e-mail exibido no
site e a referência de destino dos formulários:

```ts
export const EMAIL_CONTATO: string = SITE.emailTemporario;
// trocar para:
export const EMAIL_CONTATO: string = SITE.emailProfissional;
```

E no **Web3Forms** (ver SEO.md, passo 6): crie uma **nova Access Key** com o
e-mail `felipe@felipeluzcorretor.com.br` como destino e atualize a variável
`PUBLIC_WEB3FORMS_KEY` na Cloudflare Pages. Faça um novo deploy.

Pronto: um único lugar no código + uma variável de ambiente.
