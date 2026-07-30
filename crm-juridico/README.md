# CRM Jurídico — Módulo 3: Alertas de Prazos

App desktop (Electron) instalável no Windows/Mac/Linux para controlar prazos processuais e
disparar alertas automáticos por Telegram + notificação nativa do sistema.

Este é o primeiro de 3 módulos planejados:
- ✅ **Módulo 3 — Alertas de Prazos** (este projeto)
- ⏳ Módulo 2 — Gerador de Contratos
- ⏳ Módulo 1 — CRM + Conversões Offline do Google Ads

## Funcionalidades

- Cadastro de prazos: processo, cliente, ação, advogado responsável, data de vencimento.
- Painel colorido por situação: vencido, vence hoje, urgente (≤3 dias), atenção (≤7 dias), em dia.
- Rotina diária automática (horário configurável, padrão 08:00) que verifica prazos vencendo em
  **7, 3 e 0 dias** e envia:
  - Notificação nativa do sistema operacional.
  - Mensagem no Telegram (via bot próprio, grátis).
- Botão "Verificar agora" para testar sem esperar o horário agendado.
- Todos os dados ficam salvos localmente no seu computador (nenhuma nuvem/servidor externo é
  necessário para o CRM em si).

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

## Testes

```bash
npm test
```

Roda os testes da lógica de cálculo de dias/situação/disparo de alertas (sem precisar abrir o
Electron).

## Estrutura

```
crm-juridico/
  main.js          # processo principal do Electron (janela, IPC, agendamento diário)
  preload.js        # ponte segura entre main e renderer
  src/
    store.js         # persistência local em JSON (userData)
    prazos.js         # regras de negócio: dias restantes, situação, quais alertas disparar
    telegram.js        # envio de mensagens via Telegram Bot API
  renderer/          # interface (HTML/CSS/JS)
  test/               # testes da lógica de prazos
```
