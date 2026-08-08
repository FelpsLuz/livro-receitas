# Segurança do build — antivírus e engenharia reversa

Desenvolvedor: **FelpsLuz**. Este documento é o runbook de release: o que o
código já garante, o que fazer a cada versão, e — com honestidade — o que
cada proteção cobre e o que não cobre.

## O que o código já garante (auditado e travado por teste)

- **Nenhuma execução de comando do sistema, nenhum código dinâmico.**
  `OS.execute`, `OS.create_process` e `Expression` não existem no projeto —
  é o maior gatilho de heurística de antivírus, e um teste automatizado
  acusa se algum dia entrarem.
- **Nenhum segredo no repositório nem no binário.** As chaves de IA são do
  JOGADOR: ele digita a dele, ela fica só em `user://` na máquina dele, e
  só viaja para o provedor que ele escolheu, sempre por TLS (o
  `HTTPRequest` do Godot verifica certificado por padrão).
- **Sem telemetria, sem autoupdate, sem download de código** — as
  superfícies que costumam dar bandeira simplesmente não existem.
- **Metadados de editora preenchidos** nos presets: empresa FelpsLuz,
  produto, descrição, copyright, versão e ícone próprio. Binário anônimo
  e sem ícone é exatamente o perfil que heurística marca.

## Passar tranquilo pelo antivírus (em ordem de impacto)

1. **Assinar o `.exe` — o passo decisivo no Windows.** Sem assinatura, o
   SmartScreen mostra "editor desconhecido" até o arquivo construir
   reputação; com ela, o binário carrega o nome FelpsLuz verificado.
   - **Azure Trusted Signing** (~US$ 9,99/mês) — aceita pessoa física e é
     o caminho barato hoje; integra com `signtool`
     (https://learn.microsoft.com/azure/trusted-signing/).
   - Alternativas: certificado OV — **Certum Open Source** (~€25/ano) para
     projeto aberto, SSL.com, Sectigo. Certificado EV dá reputação
     imediata, custa mais.
   - Comando clássico (certificado próprio):
     `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 dist\ReinoPorConquista.exe`
2. **Sempre export templates oficiais do Godot** (ou os que você mesmo
   compilar — ver criptografia abaixo). Nunca binário de terceiros, e
   **nunca comprimir com UPX** — empacotador é assinatura de malware.
3. **Antes de publicar cada versão**: subir o `.exe` no VirusTotal. Se
   algum motor marcar, submeter falso positivo — resolve em dias:
   - Microsoft: https://www.microsoft.com/wdsi/filesubmission
   - Avast: https://www.avast.com/false-positive-file-form.php
   - Kaspersky: https://opentip.kaspersky.com/
   - Bitdefender: https://www.bitdefender.com/consumer/support/answer/29358/
4. **Android**: assinar sempre com a MESMA keystore (o `.keystore` está no
   `.gitignore` — guarde cópia fora do repositório; perder a keystore é
   perder a identidade do app).
5. **Distribuir sempre do mesmo lugar** (itch.io/página própria): a
   reputação do SmartScreen é por arquivo+origem e se acumula.

## Proteção contra engenharia reversa

Sem proteção, o PCK de qualquer jogo Godot abre com ferramenta pública e
os scripts voltam quase 1:1. A resposta padrão do motor é a **criptografia
AES-256 do PCK — já LIGADA nos três presets** deste projeto. Falta só a
sua chave:

1. **Gerar a chave** (64 hex): `openssl rand -hex 32`
2. **Colar no editor**: Projeto → Exportar → preset → aba **Encryption** →
   "Encryption Key". O Godot grava em `export_credentials.cfg`, que este
   repositório **ignora** (conferido por teste) — a chave nunca sobe.
3. **Compilar os export templates com a MESMA chave** (obrigatório — o
   template baixado não sabe decifrar o seu PCK):
   ```bash
   export SCRIPT_AES256_ENCRYPTION_KEY="sua_chave_de_64_hex"
   scons platform=windows target=template_release arch=x86_64 production=yes
   ```
   Guia oficial: https://docs.godotengine.org/en/4.3/contributing/development/compiling/compiling_with_script_encryption_key.html
4. **Apontar o template no preset**: "Custom Template → Release".

**O limite, dito com todas as letras:** a chave precisa viver dentro do
executável para o jogo rodar — um atacante determinado e capaz extrai ela
do binário. O que a criptografia elimina é o ataque real de 99% dos
casos: abrir o PCK com ferramenta pronta em cinco minutos e sair com
scripts e assets. Por isso a regra que este projeto já segue: **nenhum
segredo SEU embarca no cliente** — o que não está lá não vaza.

Notas:
- O GDScript 4.3 já exporta como *binary tokens* (não é texto puro) —
  ajuda, não substitui a criptografia.
- Ofuscador de identificadores (ex.: gdmaim) daria ganho marginal e risco
  real aqui: este projeto usa lookup por string em toda parte (ids de
  provedores, ofícios, eventos). Não recomendado.

## Dados do jogador

- **Chave de IA** em `user://ia_cfg.json`, texto claro — o mesmo modelo de
  launchers e apps comuns: protegida pelo perfil de usuário do sistema
  operacional, nunca sai da máquina exceto para o provedor escolhido.
- **Save** em JSON legível (`user://save.json`) — jogo single-player:
  editar o próprio save é trapacear consigo mesmo, não é superfície de
  ataque.

## Checklist de release

- [ ] Suítes verdes (inclui o teste de higiene: sem `OS.execute`/`Expression`)
- [ ] Chave de criptografia no preset + templates compilados com ela
- [ ] Exportar **release** (nunca debug) pelos presets deste repositório
- [ ] `signtool` no `.exe` (Windows) / keystore de sempre (Android)
- [ ] VirusTotal no artefato; falso positivo → formulários acima
- [ ] Smoke test numa máquina limpa (sem Godot instalado)
