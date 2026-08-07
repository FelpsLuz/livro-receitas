# Áudio — origem e mapeamento

## Música

- `musica_titulo.mp3` — "The Market Square at Night" (kaazoom, Pixabay,
  loop de 2:24). Toca na tela de título em loop e faz fade de 1.4s ao
  entrar no jogo.

### Fundo do jogo (`musica_jogo/`)

Fila embaralhada a −16 dB durante a partida; a pasta é a playlist —
qualquer MP3 solto aqui entra na roda. Todas do Pixabay:

- `delosound-medieval-background.mp3` (Delosound)
- `deuslower-medieval-ambient.mp3` (Deuslower)
- `emmraan-a-long-long-way-to-home.mp3` (Emmraan)
- `emmraan-medieval-opener.mp3` (Emmraan)
- `kaazoom-along-the-wayside-medieval-folk-music.mp3` (kaazoom)
- `music_for_creators-medieval-celtic-violin.mp3` (Music for Creators)

## Efeitos (`sfx/`)

Do pacote **RPG Essentials Free** (Leohpaz). Convertidos de 24-bit
estéreo para PCM 16-bit mono 44.1 kHz, com silêncio aparado e pico
normalizado, e gravados com o nome que `sfx.gd` usa — arquivo presente
toca, arquivo ausente devolve o tom gerado em código.

| nome do jogo | arquivo original | onde toca |
|---|---|---|
| `tique` | UI/013_Confirm_03 | confirmações leves, passar o mês, começar saga |
| `moeda` | UI/079_Buy_sell_01 | compra, venda, recrutamento — qualquer ouro |
| `alerta` | UI/033_Denied_03 | ação negada, aviso |
| `tambor` | Movement/45_Landing_01 | o baque que abre o relatório de batalha |
| `vitoria` | Buffs/30_Revive_03 (4s) | batalha vencida |
| `derrota` | Buffs/21_Debuff_01 | batalha perdida |
| `pagina` | UI/071_Unequip_01 | virada de página, resposta na conversa |
| `espada` | Battle/22_Slash_04 | reservado para combate |
| `abrir` | UI/092_Pause_04 | modal abrindo |
| `fechar` | UI/098_Unpause_04 | modal fechando (IA local) |
| `aba` | UI/001_Hover_01 | clique de aba (só clique real, não troca programática) |
