# CRM Jurídico

App desktop (Electron) instalável no Windows/Mac/Linux para escritórios de advocacia.

Módulos:
- ✅ **Módulo 3 — Alertas de Prazos**
- ✅ **Módulo 2 — Gerador de Contratos**
- ⏳ Módulo 1 — CRM + Conversões Offline do Google Ads

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

Todos os dados (prazos, clientes, modelos, contratos gerados) ficam salvos localmente no seu
computador — nenhuma nuvem/servidor externo é necessária.

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

Roda os testes da lógica de prazos/alertas e do gerador de contratos (formatação, slugify,
substituição de tags, fluxo completo de geração) sem precisar abrir o Electron.

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
    store.js              # persistência local em JSON (userData): prazos, clientes, modelos, contratos
    prazos.js              # regras de negócio: dias restantes, situação, quais alertas disparar
    telegram.js             # envio de mensagens via Telegram Bot API
    docxTemplate.js          # preenchimento de tags {{...}} em .docx e detecção de tags
    geradorContratos.js       # formatação de dados, geração do contrato e conversão para PDF
  assets/templates/        # modelo padrão de contrato (.docx) incluído no app
  scripts/                 # script para (re)gerar o modelo padrão
  renderer/                # interface (HTML/CSS/JS)
  test/                    # testes automatizados
```
