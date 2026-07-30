# CRM Jurídico

App desktop (Electron) instalável no Windows/Mac/Linux para escritórios de advocacia.

Módulos:
- ✅ **Módulo 3 — Alertas de Prazos**
- ✅ **Módulo 2 — Gerador de Contratos**
- ✅ **Módulo 1 — CRM + Conversões Offline do Google Ads**

## Módulo 3 — Alertas de Prazos

- Cadastro de prazos: processo, cliente, ação, advogado responsável, data de vencimento.
- Painel colorido por situação: vencido, vence hoje, urgente (≤3 dias), atenção (≤7 dias), em dia.
- Rotina diária automática (horário configurável, padrão 08:00) que verifica prazos vencendo em
  **7, 3 e 0 dias** e envia:
  - Notificação nativa do sistema operacional.
  - Mensagem no Telegram (via bot próprio, grátis).
- Botão "Verificar agora" para testar sem esperar o horário agendado.

## Módulo 2 — Gerador de Contratos

- Cadastro de clientes: nome, CPF, telefone, endereço, valor dos honorários, forma de pagamento.
- Modelos de contrato são arquivos `.docx` comuns com tags como `{{NOME_CLIENTE}}`, `{{CPF}}`,
  `{{ENDERECO}}`, `{{VALOR_HONORARIOS}}`, `{{FORMA_PAGAMENTO}}` e `{{DATA_GERACAO}}` — o app já vem
  com um modelo padrão de contrato de honorários pronto para uso, e você pode importar seus
  próprios modelos (aba **Modelos de Contrato**).
- Botão "Gerar Contrato" no cadastro do cliente: preenche as tags automaticamente e salva o
  arquivo `.docx` numa pasta própria do cliente (dentro dos dados do app). Se o **LibreOffice**
  estiver instalado no computador, o app também gera o `.pdf` automaticamente; caso contrário, o
  `.docx` pode ser aberto/exportado manualmente no Word ou LibreOffice.
- Histórico de contratos gerados por cliente, com botão para abrir a pasta do arquivo.
- Botão "Enviar por WhatsApp": abre o WhatsApp Web/Desktop já com uma mensagem pronta para o
  cliente (o anexo do arquivo precisa ser feito manualmente, pois o WhatsApp não permite anexar
  arquivos automaticamente via link).

## Módulo 1 — CRM + Conversões Offline do Google Ads

Fecha o ciclo: descobre qual clique de anúncio realmente virou contrato assinado, e manda essa
informação de volta pro Google Ads para ele otimizar as campanhas por resultado real, não só por
"alguém chamou no WhatsApp".

**1. Captura do GCLID na Landing Page.** Em `landing-page/captura-gclid.js` há um script pronto:
inclua-o na sua página (veja `landing-page/exemplo.html`). Ele lê o `?gclid=...` da URL, guarda no
`localStorage` do navegador, e anexa automaticamente `GCLID:xxxxx` na mensagem dos links de
WhatsApp da página.

**2. Registro no CRM.** O estagiário atende no WhatsApp, vê o `GCLID:xxxxx` na mensagem recebida e
cola no campo **GCLID** do cadastro do cliente (aba Clientes) — aceita colar com ou sem o prefixo
`GCLID:`.

**3. Disparo da conversão offline.** Quando o estagiário clica em **"Marcar Contrato Fechado"** no
cliente, o app automaticamente:
- Marca o status do cliente como "Contrato Fechado".
- Envia para a Google Ads API: o GCLID, o valor do contrato (honorários) e o horário — usando a
  ação de conversão configurada (ex: `Contrato_Fechado`).
- Se o envio falhar (sem internet, GCLID errado, credencial expirada), mostra o erro e deixa
  disponível o botão **"Reenviar Conversão"** para tentar de novo depois.

### Como configurar (aba Configurações > Google Ads)

Diferente do Telegram, aqui você precisa de credenciais próprias do Google — não tem como pular
essa parte, é uma exigência da própria Google Ads API:

1. **Developer Token**: na sua conta Google Ads, vá em Ferramentas e Configurações > Configuração
   > API Center e solicite o token. A aprovação de acesso *Standard* costuma levar alguns dias
   (o acesso *Test* é liberado na hora, mas só funciona com contas de teste).
2. **Client ID e Client Secret (OAuth)**: no
   [Google Cloud Console](https://console.cloud.google.com/apis/credentials) (tem um atalho direto
   na tela de Configurações do app), crie um projeto, ative a **"Google Ads API"** em
   "APIs e Serviços > Biblioteca", depois crie uma credencial OAuth do tipo
   **"Aplicativo para computador" (Desktop app)**.
3. **Customer ID**: os 10 dígitos que aparecem no canto superior direito da sua conta Google Ads
   (sem os hífens, ou com — o app aceita os dois formatos).
4. **ID da Ação de Conversão**: em Google Ads > Metas > Conversões > Nova ação de conversão >
   Importar > "Outras fontes de dados ou CRM" > "Rastrear conversões a partir de cliques". Depois
   de criada, o ID numérico aparece nos detalhes/URL dessa ação.
5. No app, preencha os 5 campos acima e clique em **"Conectar com Google"** — uma aba do navegador
   abre pedindo login e permissão; depois de autorizar, o app recebe e guarda o token de acesso
   automaticamente (não precisa copiar nada manualmente, nem usar ferramentas externas tipo OAuth
   Playground).
6. Clique em **"Testar conexão"** para confirmar que tudo está certo (essa chamada é somente
   leitura — não envia nenhum dado de conversão, só verifica o acesso).

Sem essas credenciais preenchidas, o app continua funcionando normalmente para prazos e contratos —
só não envia a conversão offline (o botão "Marcar Contrato Fechado" ainda marca o status, mas avisa
que a conversão não foi enviada).

Todos os dados (prazos, clientes, modelos, contratos gerados, histórico de conversões) ficam salvos
localmente no seu computador — nenhuma nuvem/servidor externo é necessária, exceto as chamadas
diretas à API do Google quando você usa este módulo.

## Botões de atualizar (sincronizar dados)

Cada aba (Prazos, Clientes, Modelos) tem um botão **🔄 Atualizar**, que recarrega os dados salvos
em disco (útil se os arquivos de dados forem alterados por fora do app, ou só para conferir que
tudo foi salvo). Salvar um formulário (Novo Prazo, Novo Cliente, Importar Modelo, etc.) já grava os
dados imediatamente — o botão Atualizar serve para "puxar" o estado mais recente do disco para a
tela a qualquer momento.

## Como rodar em modo desenvolvimento

```bash
cd crm-juridico
npm install
npm start
```

## Como gerar o instalador

```bash
npm run dist:win     # gera instalador .exe (Windows) — precisa rodar em Windows ou Linux/Mac com Wine
npm run dist:linux   # gera .AppImage (Linux)
npm run dist         # gera para a plataforma atual
```

O instalador fica em `crm-juridico/dist/`.

> Se você não tem Windows disponível para gerar o `.exe`, o repositório já inclui um workflow do
> GitHub Actions (`.github/workflows/build-crm-juridico.yml`) que builda automaticamente os
> instaladores para Windows, Mac e Linux e disponibiliza como artefatos do Actions — sem precisar
> instalar nada localmente. Basta rodar o workflow manualmente (aba Actions > "Build CRM Juridico
> (instaladores)" > Run workflow) ou fazer um push na branch principal.

## Como configurar os alertas por Telegram (grátis)

1. No Telegram, converse com **@BotFather** e envie `/newbot`. Siga as instruções e guarde o
   **token** gerado.
2. Envie qualquer mensagem para o bot recém-criado (procure pelo nome de usuário dele).
3. Descubra seu **chat_id**: abra no navegador
   `https://api.telegram.org/bot<SEU_TOKEN>/getUpdates` (substituindo `<SEU_TOKEN>`) e procure o
   campo `"chat":{"id": ...}` — ou converse com o bot **@userinfobot**.
4. No app, aba **Configurações**, cole o token e o chat_id, defina o horário e clique em
   "Testar conexão".

## Como gerar PDF automaticamente (opcional)

Instale o [LibreOffice](https://www.libreoffice.org/download/download/) (gratuito) no computador
onde o app roda. O gerador de contratos detecta automaticamente o `soffice`/`libreoffice`
instalado e converte o `.docx` gerado para `.pdf`. Sem o LibreOffice, o app ainda funciona
normalmente — só não gera o PDF automático.

## Testes

```bash
npm test
```

Roda os testes da lógica de prazos/alertas, do gerador de contratos (formatação, slugify,
substituição de tags, fluxo completo de geração) e do cliente da Google Ads API (com `fetch`
mockado — não faz nenhuma chamada de rede real nem precisa de credenciais) sem precisar abrir o
Electron.

Para regenerar o modelo padrão de contrato (caso queira editar `scripts/gerar-modelo-padrao.js`):

```bash
npm run gerar-modelo-padrao
```

## Estrutura

```
crm-juridico/
  main.js               # processo principal do Electron (janela, IPC, agendamento diário)
  preload.js             # ponte segura entre main e renderer
  src/
    store.js              # persistência local em JSON (userData): prazos, clientes, modelos, contratos, conversões
    prazos.js              # regras de negócio: dias restantes, situação, quais alertas disparar
    telegram.js             # envio de mensagens via Telegram Bot API
    docxTemplate.js          # preenchimento de tags {{...}} em .docx e detecção de tags
    geradorContratos.js       # formatação de dados, geração do contrato e conversão para PDF
    googleAds.js              # cliente HTTP da Google Ads API (access token, testar conexão, enviar conversão)
    googleOAuth.js             # fluxo OAuth com servidor local temporário (gera o refresh token)
  assets/templates/        # modelo padrão de contrato (.docx) incluído no app
  scripts/                 # script para (re)gerar o modelo padrão
  landing-page/             # script de captura de GCLID para a landing page (fora do app Electron)
  renderer/                # interface (HTML/CSS/JS)
  test/                    # testes automatizados
```
