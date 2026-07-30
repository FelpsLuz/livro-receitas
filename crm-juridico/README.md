# CRM Jurídico

App desktop (Windows/Mac/Linux) para escritórios de advocacia: controla prazos processuais, gera
contratos automaticamente e fecha o ciclo do Google Ads mostrando qual anúncio virou contrato
assinado.

Todos os dados ficam **no seu computador**. Nenhum servidor externo, nenhuma mensalidade — as
únicas chamadas para fora são para o Telegram (alertas) e para o Google Ads (conversões), e só se
você configurar.

---

## Dashboard de ROI

Cruza o que você **gastou** em anúncios (Google Ads API) com o que você **faturou** em contratos
(CRM), respondendo a pergunta que nenhuma das duas ferramentas responde sozinha:

- Investimento, receita, lucro, **ROI** e **ROAS** no período
- **CAC** (custo por contrato fechado), ticket médio e taxa de conversão lead → contrato
- Funil visual: quantos leads viraram qualificados, reuniões e contratos
- **Desempenho por campanha** e ranking de **palavras-chave por receita gerada** (não por cliques)
- Saúde do envio de conversões

Sem o Google Ads conectado o painel continua útil, mostrando o lado do CRM.

## Módulo 1 — CRM + Conversões Offline do Google Ads

**1. Captura do GCLID.** O script em `landing-page/captura-gclid.js` lê o `?gclid=...` da URL,
guarda no navegador e anexa `GCLID:xxxxx` na mensagem dos links de WhatsApp da página
(veja `landing-page/exemplo.html`).

**2. Registro.** O estagiário cola no campo GCLID do cliente — pode colar a mensagem inteira do
WhatsApp, o app extrai o código sozinho.

**3. Funil enviado ao Google.** Ao avançar o cliente de etapa (Lead → Qualificado → Reunião →
Contrato Fechado), o app envia a conversão correspondente. Enviar o funil inteiro dá **muito mais
sinal** ao algoritmo do que só o contrato: um escritório fecha poucos contratos por mês, mas gera
dezenas de leads qualificados — volume suficiente para o Google aprender.

O valor do contrato vai junto, então o Google passa a buscar o cliente de R$ 50 mil, não o de R$ 800.

**Confiabilidade:** o horário da conversão é o momento em que a etapa foi atingida, gravado uma
única vez. Reenviar é seguro — o Google reconhece como duplicata e ignora, em vez de contar duas
vezes e inflar seu relatório. Falhas (sem internet, token expirado) entram numa fila que tenta de
novo sozinha, com espera crescente.

## Módulo 2 — Gerador de Contratos

- Modelos são `.docx` comuns com tags: `{{NOME_CLIENTE}}`, `{{CPF}}`, `{{ENDERECO}}`,
  `{{TELEFONE}}`, `{{VALOR_HONORARIOS}}`, `{{FORMA_PAGAMENTO}}`, `{{DATA_GERACAO}}`.
- Já vem um modelo de contrato de honorários pronto; você pode importar os seus.
- Um clique preenche tudo e salva na pasta do cliente. Com o **LibreOffice** instalado, gera o PDF
  automaticamente.
- Histórico por cliente e atalho para mandar mensagem pronta no WhatsApp.

## Módulo 3 — Alertas de Prazos

- Alertas faltando **7, 3, 1 e 0 dias**, e **todo dia** depois de vencido.
- **Recuperação de alertas perdidos:** se o computador estiver desligado no dia do alerta, ele
  dispara assim que o app abrir — em vez de se perder para sempre.
- Notificação do Windows + mensagem no Telegram (bot próprio, gratuito).
- O app pode iniciar junto com o Windows, para os alertas realmente acontecerem.

## Ficha 360 do cliente

Tudo sobre um cliente em uma tela: dados, linha do tempo do funil, prazos vinculados, contratos
gerados e o status das conversões enviadas ao Google Ads.

---

## Instalação

Baixe o instalador e execute. Como o app não tem certificado de assinatura digital (que é pago), o
Windows vai mostrar "O Windows protegeu seu PC" — clique em **Mais informações** → **Executar assim
mesmo**.

## Configuração dos alertas (Telegram, grátis)

1. No Telegram, fale com **@BotFather**, envie `/newbot` e guarde o token.
2. Mande qualquer mensagem para o bot criado.
3. Pegue seu **chat_id** com o bot **@userinfobot**.
4. Em **Configurações**, cole os dois, defina o horário e clique em "Testar conexão".

## Configuração do Google Ads

Essas credenciais são suas e exigidas pela própria Google — não tem como o app pular essa parte:

1. **Developer Token**: conta Google Ads → Ferramentas → Configuração → API Center.
   A aprovação de acesso *Standard* leva alguns dias.
2. **Client ID e Secret**: [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   → crie um projeto → ative a "Google Ads API" → credencial OAuth do tipo **Desktop app**.
3. **Customer ID**: os 10 dígitos no topo da conta Google Ads.
4. **Ações de conversão**: Google Ads → Metas → Conversões → Nova ação → Importar →
   "Outras fontes de dados ou CRM" → "Rastrear conversões a partir de cliques".
   Crie uma por etapa que quiser medir e cole os IDs no app.
5. Clique em **Conectar com Google** — o navegador abre para você autorizar, e o app guarda o
   acesso sozinho (não precisa de ferramenta externa).
6. **Testar conexão** valida tudo sem enviar nenhum dado.

> Se as chamadas passarem a falhar com erro de versão, troque a **Versão da API** em Configurações.
> O Google descontinua versões antigas a cada ~1 ano, e o campo evita ter que reinstalar o app.

## Segurança e dados

- Tokens do Google Ads e do Telegram são criptografados com o **cofre do sistema operacional**
  (DPAPI no Windows). A tela de Configurações mostra se a proteção está ativa.
- Os dados usam **escrita atômica com backup**: uma queda de energia no meio de uma gravação não
  corrompe nem apaga o arquivo. Se um arquivo for danificado, o app restaura do backup
  automaticamente e preserva o arquivo problemático para análise.
- **Exporte um backup** periodicamente (Configurações → Exportar backup) e guarde fora do
  computador. É o que salva o escritório se o HD falhar. O backup não inclui tokens, por segurança.

---

## Para desenvolvedores

```bash
npm install
npm start          # roda em modo desenvolvimento
npm test           # 43 testes de lógica (sem abrir o Electron)
npm run test:app   # teste ponta a ponta operando a interface real
npm run dist:win   # instalador .exe (precisa de Windows, ou Linux com Wine)
npm run dist:linux # AppImage
```

O repositório inclui um workflow do GitHub Actions que gera os instaladores das três plataformas
automaticamente (aba Actions → "Build CRM Juridico").

### Estrutura

```
crm-juridico/
  main.js                  processo principal: janela, IPC, agendamentos, criptografia
  preload.js               ponte segura entre o main e a interface
  src/
    store.js               persistência local com escrita atômica, backup e migrações
    prazos.js              regras de alerta (limiares, catch-up, vencidos)
    funil.js               definição das etapas do funil de vendas
    servicoConversoes.js   fila de conversões: idempotência e retry com backoff
    googleAds.js           cliente da Google Ads API (conversões + métricas de custo)
    googleOAuth.js         autorização OAuth via servidor local temporário
    relatorios.js          cálculos do dashboard (ROI, CAC, funil, atribuição)
    docxTemplate.js        substituição de tags em .docx
    geradorContratos.js    geração do contrato e conversão para PDF
    telegram.js            envio de alertas
    log.js                 log em arquivo para diagnóstico
  renderer/                interface (HTML/CSS/JS, sem framework)
  landing-page/            script de captura de GCLID para o site
  assets/                  ícone e modelo de contrato padrão
  test/                    testes de lógica e teste ponta a ponta
```

### Onde ficam os dados

Windows: `%APPDATA%\crm-juridico`. Use **Configurações → Abrir pasta de dados** para chegar lá.
O arquivo `crm-juridico.log` registra o que o app fez, útil para diagnosticar problemas.
