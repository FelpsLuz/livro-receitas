# PC (Steam) e Android — o mesmo jogo, sem bifurcar código

Resposta curta: **sim**. O projeto foi montado para os dois alvos desde a
base, e o que faltava de verdade para "sem quebras" foi corrigido e
travado por teste nesta rodada.

## O que garante a portabilidade (auditado)

- **Renderer `gl_compatibility` nos dois perfis** (desktop e `.mobile`) —
  o backend que o Godot recomenda para 2D e o que roda igual em GPU
  antiga, Steam Deck e celular. Todos os renders de verificação já usam
  ele.
- **Interface em `canvas_items` + `expand`**: 960×540 é sistema de
  coordenadas, não resolução fixa — a tela do Deck (1280×800) e qualquer
  celular widescreen preenchem sem tarja preta, com fonte nítida na
  resolução real do aparelho.
- **Paisagem forçada** (`handheld/orientation=1`) e **modo imersivo** no
  Android; toda a UI é `Control` (toque nativo), as abas rolam por
  `ScrollContainer` (arrasto de dedo), e a conversa tem o botão **Falar**
  além do Enter — funciona com teclado virtual.
- **Todo asset de runtime lê pelo filesystem VIRTUAL** — áudio
  (`get_file_as_bytes` → MP3/WAV) e agora também a arte hi-bit (bytes →
  `load_png_from_buffer`). Era A quebra escondida deste projeto: os
  carregadores antigos usavam caminho globalizado, que funciona no
  editor e morre dentro de PCK/APK — o build exportado perderia toda a
  arte ilustrada em silêncio. Corrigido, e o padrão antigo agora é
  **proibido por teste de higiene**.
- **Save e config em `user://`** — o Godot resolve o lugar certo em cada
  sistema (AppData no Windows, `~/.local/share` no Linux, sandbox do app
  no Android). Nenhum caminho absoluto no projeto.
- **A IA é rede pura** (`HTTPRequest` + TLS) — igual nas duas
  plataformas. No Android ela exige a permissão de INTERNET, agora
  declarada no preset (sem ela, cada fala falharia em silêncio). E sem
  internet o jogo continua de pé: o motor interno responde.

## Steam (Windows + Linux)

Presets prontos: **Windows** (`.exe` com PCK embutido, metadados
FelpsLuz, ícone) e **Linux** (`.x86_64`, novo nesta rodada — o Steam
Deck roda o build nativo, sem Proton).

1. **Steamworks**: crie o app, um *depot* para Windows e um para Linux,
   e suba com o SteamPipe (`steamcmd +run_app_build build.vdf`). Guia:
   https://partner.steamgames.com/doc/sdk/uploading
2. **DRM**: publique **sem** o DRM wrapper da Steam — ele não se dá bem
   com executáveis Godot e não protege nada que a criptografia do PCK já
   não cubra (`SEGURANCA.md`).
3. **Overlay e conquistas**: o overlay da Steam funciona no GL sem
   nenhum código. Se um dia quiser conquistas/estatísticas, o caminho é
   o **GodotSteam** (GDExtension) — opcional, zero mudança no jogo até
   lá.
4. **Steam Cloud sem código**: no Auto-Cloud, aponte a raiz para a pasta
   `user://` do jogo — Windows `%APPDATA%/Godot/app_userdata/Reino por
   Conquista`, Linux `~/.local/share/godot/app_userdata/Reino por
   Conquista` — e o save viaja entre PC e Deck sozinho.
5. **Steam Deck**: 1280×800 preenche via `expand`; a UI de mouse vira
   trackpad/toque. Marque o layout padrão de Steam Input como mouse e
   rode a verificação de compatibilidade do Deck após publicar.
6. **Assinar o `.exe`** e ligar a criptografia: passos em `SEGURANCA.md`.

## Android

Preset pronto: `arm64-v8a` (obrigatório no Play desde 2019), permissão
de INTERNET, modo imersivo, pacote `br.com.felpsluz.reinoporconquista`.

1. **Preparar o editor** (uma vez): Android SDK + JDK 17 em Editor
   Settings → Export → Android. Guia oficial:
   https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html
2. **Keystore**: para testar no seu aparelho, o *debug keystore*
   automático do Godot serve. Para publicar, gere a SUA e use a MESMA
   para sempre (perder a keystore é perder o app — `SEGURANCA.md`):
   `keytool -genkeypair -v -keystore release.keystore -alias reino -keyalg RSA -keysize 2048 -validity 10000`
3. **Sideload/itch.io**: o preset já sai um `.apk` instalável direto.
4. **Play Store**: exige `.aab` — no preset, ligue
   `gradle_build/use_gradle_build=true` e troque o formato de export
   para AAB. O alvo de SDK acompanha a versão do Godot, e o Play sobe
   essa régua todo agosto — se o console do Play reclamar do
   `targetSdk`, atualizar o Godot dentro da série 4.x resolve.
5. **32 bits (opcional)**: `architectures/armeabi-v7a=true` alcança
   aparelhos de ~2014 ao custo de quase dobrar o pacote. Padrão:
   desligado.
6. A criptografia do PCK no Android também exige templates compilados
   com a sua chave — mesmo passo a passo de `SEGURANCA.md`.

## O limite honesto

O que dava para garantir por código e teste está garantido: renderer,
toque, permissão, filesystem virtual, presets dos quatro alvos. O que só
hardware real confirma — desempenho do celular específico, teclado
virtual de cada fabricante, verificação do Deck — fica no checklist:
exportar e fazer o teste de fumaça num aparelho limpo antes de publicar.

## Checklist por release (os dois alvos)

- [ ] Suítes verdes (a higiene confere: INTERNET no Android, preset
      Linux, arm64, e zero caminho que morre no export)
- [ ] Windows: exportar release → assinar → VirusTotal (`SEGURANCA.md`)
- [ ] Linux: exportar release → rodar uma vez num Linux qualquer
- [ ] Android: exportar com a keystore de sempre → instalar num aparelho
      → abrir uma conversa com IA (prova a permissão de INTERNET viva)
- [ ] Steam: subir os dois depots · Play: subir o `.aab`
