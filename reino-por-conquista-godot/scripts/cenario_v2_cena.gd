# ============================================================
# CENÁRIO v2 — composição em camadas na Godot (addenda v3/v3.1).
# A placa base entra FATIADA em nós por banda (Bandas.FATIAS, gerado de
# bandas.py); cada correção de composição é nó ou shader, custo zero:
#   §F.1/§D  hierarquia de valor — véus multiply/shader em gradiente
#   §F.2/§E  rio e juncos contidos — modulate + véu + redistribuição
#   §G       vida — palette cycling na água, balanço de junco, deriva
#            de nuvem (derivados extraídos da placa por derivar_vida.py)
# Objetos são sprites isolados ancorados na BASE, com sombra de contato
# de nó (sombra_contato.gd, §C). Canvas de arte: 400×200 em SubViewport
# NEAREST, escala final por inteiro.
# ============================================================
class_name CenarioV2Cena
extends Node2D

const PLACA := "res://assets_v2/cenario/base/placa_base.png"
const DERIVADOS := "res://assets_v2/cenario/base/derivados/"
const SPRITES := "res://assets_v2/cenario/sprites/"

# ---- valor (§F.1 do v3 + §D do v3.1), calibrável num lugar só ----
const TINTA_FLORESTA := Color(0.82, 0.86, 0.88)
const VEU_FLORESTA_TOPO := 58      # topo das copas (banda ceu/serra)
# Campo (v3.1 §D): a massa mais clara do quadro vira meio-tom — escurece
# ~10% na média e dessatura ~8%, mais escuro no pé (próximo) que no topo
# (recuando). O gradiente também dilui os estratos retangulares da placa.
const CAMPO_MULT_TOPO := 0.97
const CAMPO_MULT_PE := 0.84
const CAMPO_SATURACAO := 0.92
const MOD_RIO := Color(0.92, 0.92, 0.92)
const VEU_RIO := Color(115.0 / 255.0, 175.0 / 255.0, 171.0 / 255.0, 0.35)
const MOD_MARGEM := Color(0.88, 0.88, 0.88)   # v3.1 §E: −12% na banda

# ---- água (§G.1): as 4 cores CLARAS da água, medidas da placa. O corpo
# escuro (27,107,151 / 20,68,99) fica de fora — ciclar tudo pulsa.
const AGUA_CICLO := [
	Color8(60, 150, 186), Color8(106, 195, 202),
	Color8(157, 237, 236), Color8(175, 233, 241),
]
const AGUA_VELOCIDADE := 1.6

# ---- juncos (§E/§G.2): touceiras 48px derivadas da própria margem,
# distribuídas irregularmente; clareiras cobrem os trechos mais densos.
const TOUCEIRAS_X := [6, 58, 204, 260, 331]
const TOUCEIRAS_JITTER_Y := [0, -1, 1, 0, -1]
const CLAREIRAS_X := [148, 352]
const MARGEM_TOPO := 180           # topos dos juncos invadem o fim do rio

# ---- nuvens (§G.3): deriva em duas velocidades = paralaxe de céu ----
const NUVENS_LENTA_PXS := 0.7
const NUVENS_RAPIDA_PXS := 1.5
const CEU_ALTURA := 47

# Evolução: quais objetos existem em cada nível (N0..N5). Por enquanto só
# a casa do piloto; o lote (v3.1 §I.11) preenche o resto da tabela.
const NIVEIS := {
	0: [],
	1: [{"sprite": "casa_sape", "pos": Vector2i(112, 155)}],
}

var nivel := 1:
	set(v):
		nivel = v
		_montar()

# Teste de silhueta (v3.1 §D): composto em preto puro sobre branco — a
# vila tem que ler como forma distinta. Liga, renderiza, desliga.
var silhueta := false:
	set(v):
		silhueta = v
		_montar()

var _nuvem_lenta: Sprite2D
var _nuvem_rapida: Sprite2D
var _deriva_lenta := 0.0
var _deriva_rapida := 0.0


func _ready() -> void:
	_montar()


func _process(delta: float) -> void:
	if _nuvem_lenta == null:
		return
	_deriva_lenta = fmod(_deriva_lenta + delta * NUVENS_LENTA_PXS, 400.0)
	_deriva_rapida = fmod(_deriva_rapida + delta * NUVENS_RAPIDA_PXS, 400.0)
	# arredonda ao aplicar: deriva acumula em float, desenha em pixel cheio
	_nuvem_lenta.region_rect.position.x = roundf(_deriva_lenta)
	_nuvem_rapida.region_rect.position.x = roundf(_deriva_rapida)


func _montar() -> void:
	for filho in get_children():
		filho.queue_free()
	_nuvem_lenta = null
	_nuvem_rapida = null

	if silhueta:
		var branco := ColorRect.new()
		branco.size = Vector2(Bandas.CANVAS_W, Bandas.CANVAS_H)
		branco.color = Color.WHITE
		add_child(branco)
		_montar_objetos(true)
		return

	var placa: Texture2D = load(PLACA)

	# ---- fatias da placa, uma por banda ----
	var mods := {
		"fundo": Color.WHITE,
		"floresta": Color.WHITE,      # o véu em gradiente faz o §F.1
		"campo": Color.WHITE,
		"rio": MOD_RIO,
		"margem": MOD_MARGEM,
	}
	for fatia in Bandas.FATIAS:
		var faixa: Vector2i = Bandas.FATIAS[fatia]
		var at := AtlasTexture.new()
		at.atlas = placa
		at.region = Rect2(0, faixa.x, Bandas.CANVAS_W, faixa.y - faixa.x)
		var sp := Sprite2D.new()
		sp.name = "Fatia_" + fatia
		sp.texture = at
		sp.centered = false
		sp.position = Vector2(0, faixa.x)
		sp.modulate = mods[fatia]
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		match fatia:
			"campo":
				sp.material = _material_valor(faixa)
			"rio":
				sp.material = _material_agua()
		add_child(sp)

	# ---- céu vivo (§G.3): céu limpo estático + 2 camadas de nuvem ----
	var ceu := Sprite2D.new()
	ceu.name = "CeuLimpo"
	ceu.texture = load(DERIVADOS + "ceu_limpo.png")
	ceu.centered = false
	ceu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ceu)
	_nuvem_lenta = _camada_nuvem("nuvens_lenta")
	_nuvem_rapida = _camada_nuvem("nuvens_rapida")

	# ---- véu da floresta (§F.1): multiply em gradiente vertical ----
	add_child(_veu_floresta())

	# ---- véu do rio (§F.2): contém o specular sem regerar a placa ----
	var veu := ColorRect.new()
	veu.name = "VeuRio"
	var rio: Vector2i = Bandas.FATIAS["rio"]
	veu.position = Vector2(0, rio.x)
	veu.size = Vector2(Bandas.CANVAS_W, rio.y - rio.x)
	veu.color = VEU_RIO
	add_child(veu)

	# ---- juncos (§E): clareiras + touceiras irregulares com balanço ----
	_montar_margem()

	_montar_objetos(false)


func _material_valor(faixa: Vector2i) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/valor_banda.gdshader")
	# UV do shader é do ATLAS (placa inteira): passa os limites da região
	mat.set_shader_parameter("uv_topo", float(faixa.x) / Bandas.CANVAS_H)
	mat.set_shader_parameter("uv_pe", float(faixa.y) / Bandas.CANVAS_H)
	mat.set_shader_parameter("mult_topo", CAMPO_MULT_TOPO)
	mat.set_shader_parameter("mult_pe", CAMPO_MULT_PE)
	mat.set_shader_parameter("saturacao", CAMPO_SATURACAO)
	return mat


func _material_agua() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/agua_ciclo.gdshader")
	var img := Image.create(4, 1, false, Image.FORMAT_RGB8)
	var alvos: Array[Vector3] = []
	for i in AGUA_CICLO.size():
		var c: Color = AGUA_CICLO[i]
		img.set_pixel(i, 0, c)
		alvos.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("rampa", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("alvos", alvos)
	mat.set_shader_parameter("velocidade", AGUA_VELOCIDADE)
	return mat


func _camada_nuvem(nome: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = nome
	sp.texture = load(DERIVADOS + nome + ".png")
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, Bandas.CANVAS_W, CEU_ALTURA)
	add_child(sp)
	return sp


func _veu_floresta() -> Sprite2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, TINTA_FLORESTA, TINTA_FLORESTA])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var fim_floresta: int = Bandas.FATIAS["floresta"].y
	gtex.width = 4
	gtex.height = fim_floresta - VEU_FLORESTA_TOPO
	var veu := Sprite2D.new()
	veu.name = "VeuFloresta"
	veu.texture = gtex
	veu.centered = false
	veu.position = Vector2(0, VEU_FLORESTA_TOPO)
	veu.scale = Vector2(Bandas.CANVAS_W / 4.0, 1.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	veu.material = mat
	return veu


func _montar_margem() -> void:
	var variantes: Texture2D = load(DERIVADOS + "margem_variantes.png")
	var clareira: Texture2D = load(DERIVADOS + "margem_clareira.png")

	# clareiras: trecho esparso cobre os pontos mais densos da base — a
	# margem deixa de ser 400px de junco uniforme (v3.1 §E.2)
	for cx in CLAREIRAS_X:
		var cl := Sprite2D.new()
		cl.name = "Clareira_%d" % cx
		cl.texture = clareira
		cl.centered = false
		cl.position = Vector2(cx, MARGEM_TOPO)
		cl.modulate = MOD_MARGEM
		cl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(cl)

	# touceiras RGBA (água removida) com balanço por fase própria (§G.2)
	for i in TOUCEIRAS_X.size():
		var at := AtlasTexture.new()
		at.atlas = variantes
		at.region = Rect2(i * 48, 0, 48, 20)
		var tc := Sprite2D.new()
		tc.name = "Touceira_%d" % i
		tc.texture = at
		tc.centered = false
		tc.position = Vector2(TOUCEIRAS_X[i], MARGEM_TOPO + TOUCEIRAS_JITTER_Y[i])
		tc.modulate = MOD_MARGEM
		tc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/juncos_balanco.gdshader")
		mat.set_shader_parameter("fase", float(i) * 1.7)
		tc.material = mat
		add_child(tc)


func _montar_objetos(preto: bool) -> void:
	var objetos: Array = []
	for n in NIVEIS:
		if n <= nivel:
			objetos.append_array(NIVEIS[n])
	for obj in objetos:
		var tex: Texture2D = load(SPRITES + obj["sprite"] + ".png")
		var sp := Sprite2D.new()
		sp.name = obj["sprite"]
		sp.texture = tex
		sp.centered = false
		# origem na BASE (meio-embaixo): a sombra espelha a partir dela e o
		# Y da posição é a linha de chão nas bandas.
		sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		sp.position = Vector2(obj["pos"])
		sp.z_index = 1
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if preto:
			sp.self_modulate = Color.BLACK
			add_child(sp)
		else:
			add_child(sp)
			add_child(SombraContato.criar_sombra(sp))
