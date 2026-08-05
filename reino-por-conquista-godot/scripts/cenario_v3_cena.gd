# ============================================================
# CENÁRIO v3 — a cena achatada, com vida e evolução.
#
# O cenário deixou de ser montado em nós: cada estágio é UMA imagem de
# 480×270 já pintada (assets_v3/estagios/<estacao>/). O que sobrou de
# runtime é o que a imagem não pode fazer sozinha:
#   · vida  — água ciclando e junco balançando, por cor (vida_estagio)
#   · evolução — a troca de estágio como RECOMPENSA, não como corte seco
#
# Coordenadas vêm de coordenadas.json como REGISTRO (onde estão o rio, a
# margem, as cores) — não como posicionamento: nada aqui coloca nada.
# ============================================================
class_name CenarioV3Cena
extends Node2D

const BASE := "res://assets_v3/estagios/"
const NOMES := ["e1_virgem", "e2_acampamento", "e3_assentamento",
		"e4_forte", "e5_muralha", "e6_completo"]
const NATIVO := Vector2i(480, 270)

# ---- recompensa de evolução ----
const CROSSFADE := 0.8
const FLASH := 0.18                # curto: marca o instante, não ofusca
const FLASH_ALPHA := 0.30
const POEIRA_POR_CELULA := 3
const CELULAS_MAX := 26            # as mais quentes; todas viraria névoa

var estacao := "verao"
var estagio := 5:
	set(v):
		estagio = clampi(v, 0, NOMES.size() - 1)
		if _atual:
			_atual.texture = _textura(estagio)

var _atual: Sprite2D
var _anterior: Sprite2D
var _flash: ColorRect
var _coord: Dictionary = {}
var _trans: Dictionary = {}
var _em_transicao := false

signal evolucao_terminou(de: int, para: int)


func _ready() -> void:
	_coord = _json(BASE + estacao + "/coordenadas.json")
	_trans = _json(BASE + estacao + "/transicoes.json")

	_anterior = Sprite2D.new()
	_anterior.centered = false
	_anterior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anterior.visible = false
	_anterior.z_index = 0
	add_child(_anterior)

	_atual = Sprite2D.new()
	_atual.centered = false
	_atual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_atual.texture = _textura(estagio)
	_atual.material = _material_vida()
	_atual.z_index = 1
	add_child(_atual)

	_flash = ColorRect.new()
	_flash.size = Vector2(NATIVO)
	_flash.color = Color(1, 1, 1, 0)
	_flash.z_index = 20
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _textura(i: int) -> Texture2D:
	return load(BASE + estacao + "/" + NOMES[i] + ".png")


func _json(caminho: String) -> Dictionary:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


# ---- vida: os dois shaders portam por COR, sem separar camada ----
func _material_vida() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vida_estagio.gdshader")
	var bandas: Dictionary = _coord.get("bandas", {})
	var rio: Array = bandas.get("rio", [237, 261])

	# as cores do ciclo são as CLARAS da água; as escuras ficam paradas,
	# senão o corpo d'água pulsa em vez de correr (aferido no v3.2 §D)
	var agua: Array = _coord.get("agua_cores", [])
	agua.sort_custom(func(a, b): return _lum(a["rgb"]) > _lum(b["rgb"]))
	var claras: Array = agua.slice(0, mini(3, agua.size()))
	var img := Image.create(maxi(1, claras.size()), 1, false, Image.FORMAT_RGB8)
	var alvos: Array[Vector3] = []
	for i in claras.size():
		var c: Color = _cor(claras[i]["rgb"])
		img.set_pixel(i, 0, c)
		alvos.append(Vector3(c.r, c.g, c.b))
	while alvos.size() < 4:
		alvos.append(alvos[alvos.size() - 1] if alvos.size() > 0
				else Vector3.ZERO)
	mat.set_shader_parameter("rampa", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("rampa_n", maxi(1, claras.size()))
	mat.set_shader_parameter("agua_alvo", alvos)
	mat.set_shader_parameter("agua_n", maxi(1, claras.size()))
	# porta espacial: o ciclo só vale abaixo do topo do rio (ver shader)
	mat.set_shader_parameter("agua_topo",
			float(int(rio[0]) - 2) / float(NATIVO.y))

	var junco: Array = _coord.get("junco_cores", [])
	var jalvos: Array[Vector3] = []
	for i in mini(4, junco.size()):
		var c: Color = _cor(junco[i]["rgb"])
		jalvos.append(Vector3(c.r, c.g, c.b))
	while jalvos.size() < 6:
		jalvos.append(jalvos[jalvos.size() - 1] if jalvos.size() > 0
				else Vector3.ZERO)
	mat.set_shader_parameter("junco_alvo", jalvos)
	mat.set_shader_parameter("junco_n", maxi(1, mini(4, junco.size())))
	# a faixa de junco é a borda do rio, não o rio inteiro
	mat.set_shader_parameter("junco_topo",
			float(int(rio[0]) - 8) / float(NATIVO.y))
	mat.set_shader_parameter("junco_base",
			float(int(rio[0]) + 6) / float(NATIVO.y))
	return mat


func _lum(rgb: Array) -> float:
	return 0.2126 * float(rgb[0]) + 0.7152 * float(rgb[1]) + 0.0722 * float(rgb[2])


func _cor(rgb: Array) -> Color:
	return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))


# ---- evolução: crossfade + poeira na obra + flash curto ----
func evoluir(para: int = -1) -> void:
	if _em_transicao:
		return
	var destino: int = estagio + 1 if para < 0 else para
	if destino <= estagio or destino >= NOMES.size():
		return
	_em_transicao = true
	var de := estagio

	# a imagem VELHA fica por baixo, visível; a nova entra por cima com
	# alpha 0 e sobe. Crossfade de verdade, não corte.
	_anterior.texture = _textura(de)
	_anterior.visible = true
	_anterior.modulate.a = 1.0
	estagio = destino
	_atual.modulate.a = 0.0

	_poeira(de, destino)

	# DOIS tweens, não um. Com set_parallel(true), o chain() do flash
	# esperava o crossfade inteiro terminar e o clarão ficava travado no
	# pico por 0,8s — medido: luminância 158.9 constante em 7 frames.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_atual, "modulate:a", 1.0, CROSSFADE)
	tw.tween_property(_anterior, "modulate:a", 0.0, CROSSFADE)

	var tf := create_tween()
	tf.tween_property(_flash, "color:a", FLASH_ALPHA, FLASH * 0.35)
	tf.tween_property(_flash, "color:a", 0.0, FLASH * 0.65)

	await tw.finished
	_anterior.visible = false
	_em_transicao = false
	evolucao_terminou.emit(de, destino)


func _poeira(de: int, para: int) -> void:
	"""Poeira só nas CÉLULAS DE OBRA — onde o diff mediu mudança.

	A bbox global não serve: entre estágios a quantização deixa pixel
	mudado espalhado e a caixa cobre a tela toda. O mapa de densidade de
	medir_estagios.py isola os canteiros.
	"""
	var chave := "%s->%s" % [NOMES[de], NOMES[para]]
	var dados: Dictionary = _trans.get(chave, {})
	var celulas: Array = dados.get("celulas", [])
	for i in mini(CELULAS_MAX, celulas.size()):
		var cel: Dictionary = celulas[i]
		var p := CPUParticles2D.new()
		p.amount = POEIRA_POR_CELULA
		p.lifetime = CROSSFADE * 1.1
		p.one_shot = true
		p.explosiveness = 0.6
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(float(cel["w"]) / 2.0,
				float(cel["h"]) / 2.0)
		p.position = Vector2(float(cel["x"]) + float(cel["w"]) / 2.0,
				float(cel["y"]) + float(cel["h"]) / 2.0)
		p.direction = Vector2(0, -1)
		p.spread = 32.0
		p.gravity = Vector2(0, 14)
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 16.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		# poeira de obra: bege claro sumindo — a cor sai da própria cena
		p.color = Color(0.86, 0.80, 0.64, 0.75 * float(cel["peso"]) + 0.25)
		var rampa := Gradient.new()
		rampa.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		p.color_ramp = rampa       # CPUParticles2D quer Gradient, não Texture
		p.z_index = 10
		p.emitting = true
		add_child(p)
		var t := get_tree().create_timer(CROSSFADE * 1.6)
		t.timeout.connect(p.queue_free)
