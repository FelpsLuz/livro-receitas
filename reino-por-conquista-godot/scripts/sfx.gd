# ============================================================
# EFEITOS SONOROS (port de js/sfx.js)
# Mesmo contrato da arte hi-bit: se o WAV do pacote (RPG Essentials,
# assets/audio/sfx/<nome>.wav) existe, ele toca; se não, vale o tom
# gerado em código de sempre. Apagar a pasta de áudio não quebra nada,
# só devolve os bipes.
# Uso: Sfx.tocar(no_pai, "moeda")
# ============================================================
extends RefCounted

const TAXA := 22050
const PASTA := "res://assets/audio/sfx/"
const MUSICA_TITULO := "res://assets/audio/musica_titulo.mp3"
const PASTA_MUSICAS := "res://assets/audio/musica_jogo/"

## Ajuste de saída por nome. Os WAVs chegam normalizados no mesmo pico;
## os toques de pura interface (aba, abrir/fechar de modal) ficam um
## degrau abaixo do resto para não competirem com moeda e alerta.
const GANHO := {"aba": -8.0, "abrir": -5.0, "fechar": -5.0}

static var _cache := {}
static var mudo := false

# ---------------- pacote (assets/audio/sfx) ----------------

## Lê um WAV PCM 16-bit do pacote sem passar pelo importador do editor —
## o mesmo motivo do FileAccess nos PNGs hi-bit: os testes e o headless
## não têm .import. Qualquer surpresa no arquivo devolve null e o som
## cai no tom gerado.
static func _wav_do_pacote(nome: String) -> AudioStreamWAV:
	var caminho := PASTA + nome + ".wav"
	if not FileAccess.file_exists(caminho):
		return null
	var d := FileAccess.get_file_as_bytes(caminho)
	if d.size() < 44 or d.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or d.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var taxa := 0
	var canais := 0
	var dados := PackedByteArray()
	var i := 12
	while i + 8 <= d.size():
		var bloco := d.slice(i, i + 4).get_string_from_ascii()
		var tam := d.decode_u32(i + 4)
		if bloco == "fmt ":
			# formato 1 = PCM; só aceitamos 16 bits, que é como o pacote
			# foi convertido — qualquer outra coisa é arquivo estranho
			if d.decode_u16(i + 8) != 1 or d.decode_u16(i + 22) != 16:
				return null
			canais = d.decode_u16(i + 10)
			taxa = d.decode_u32(i + 12)
		elif bloco == "data":
			dados = d.slice(i + 8, mini(i + 8 + tam, d.size()))
		i += 8 + tam + (tam & 1)
	if taxa == 0 or dados.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = taxa
	wav.stereo = canais == 2
	wav.data = dados
	return wav

## A trilha da tela de título (mp3 em loop — acabou, recomeça). Null
## quando o arquivo não está lá; o título fica em silêncio e inteiro.
static func musica_titulo() -> AudioStreamMP3:
	if not FileAccess.file_exists(MUSICA_TITULO):
		return null
	var mp3 := AudioStreamMP3.new()
	mp3.data = FileAccess.get_file_as_bytes(MUSICA_TITULO)
	mp3.loop = true
	return mp3

## As faixas de fundo do jogo, por caminho. A PASTA é a playlist: soltar
## um MP3 novo em musica_jogo/ (a "pasta 2") entra na roda sem tocar em
## código. Ordenada para a lista ser estável; quem embaralha é a fila.
static func musicas_jogo() -> Array[String]:
	var saida: Array[String] = []
	var dir := DirAccess.open(PASTA_MUSICAS)
	if dir == null:
		return saida
	for f in dir.get_files():
		if f.ends_with(".mp3"):
			saida.append(PASTA_MUSICAS + f)
	saida.sort()
	return saida

## Uma faixa da playlist, sem cache — 4 a 7 MB por faixa ficariam na
## memória a sessão toda para poupar uma leitura de disco por música.
## loop DESLIGADO: quem dá a volta é a fila embaralhada do jogo.
static func stream_musica(caminho: String) -> AudioStreamMP3:
	if not FileAccess.file_exists(caminho):
		return null
	var mp3 := AudioStreamMP3.new()
	mp3.data = FileAccess.get_file_as_bytes(caminho)
	return mp3

# ---------------- tons gerados (reserva) ----------------

static func _tom(freq: float, dur: float, vol: float) -> PackedByteArray:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var t := float(i) / TAXA
		var envelope := 1.0 - float(i) / n
		var amostra := int(sin(TAU * freq * t) * vol * envelope * 32000.0)
		dados.encode_s16(i * 2, amostra)
	return dados

static func _ruido(dur: float, vol: float) -> PackedByteArray:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var envelope := 1.0 - float(i) / n
		dados.encode_s16(i * 2, int(rng.randf_range(-1.0, 1.0) * vol * envelope * 32000.0))
	return dados

static func _juntar(partes: Array) -> AudioStreamWAV:
	var total := PackedByteArray()
	for p in partes:
		total.append_array(p)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = TAXA
	wav.stereo = false
	wav.data = total
	return wav

static func _stream(nome: String) -> AudioStreamWAV:
	if _cache.has(nome):
		return _cache[nome]
	var wav := _wav_do_pacote(nome)
	if wav == null:
		match nome:
			"moeda":   wav = _juntar([_tom(988, 0.08, 0.25), _tom(1319, 0.12, 0.25)])
			"pagina":  wav = _juntar([_ruido(0.12, 0.15)])
			"espada":  wav = _juntar([_ruido(0.05, 0.3), _tom(2400, 0.06, 0.12)])
			"tambor":  wav = _juntar([_tom(82, 0.28, 0.5), _tom(55, 0.34, 0.4)])
			"vitoria": wav = _juntar([_tom(523, 0.2, 0.3), _tom(659, 0.2, 0.3), _tom(784, 0.2, 0.3), _tom(1047, 0.3, 0.3)])
			"derrota": wav = _juntar([_tom(392, 0.25, 0.3), _tom(330, 0.25, 0.3), _tom(262, 0.35, 0.3)])
			"alerta":  wav = _juntar([_tom(440, 0.14, 0.3), _tom(415, 0.2, 0.3)])
			_:         wav = _juntar([_tom(660, 0.05, 0.15)])
	_cache[nome] = wav
	return wav

static func tocar(pai: Node, nome: String) -> void:
	if mudo or pai == null or not pai.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = _stream(nome)
	player.volume_db = float(GANHO.get(nome, 0.0))
	pai.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
