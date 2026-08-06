# ============================================================
# EFEITOS SONOROS (port de js/sfx.js)
# Tons gerados em código como AudioStreamWAV — zero assets.
# Uso: Sfx.tocar(no_pai, "moeda")
# ============================================================
extends RefCounted

const TAXA := 22050

static var _cache := {}
static var mudo := false

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
	var wav: AudioStreamWAV
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
	pai.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
