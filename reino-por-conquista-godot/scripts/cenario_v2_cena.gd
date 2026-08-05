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
# Quebra de estrato (v3.2 §C): blocos de 2px, sem TIME. Muleta até o
# terreno povoar — se os estratos sumirem com o §E, reduzir a amplitude.
const CAMPO_RUIDO := 0.018   # reduzido: com o snap, 0.045 virava sal-e-pimenta
const MOD_RIO := Color(0.92, 0.92, 0.92)
const VEU_RIO := Color(115.0 / 255.0, 175.0 / 255.0, 171.0 / 255.0, 0.35)
const MOD_MARGEM := Color(0.88, 0.88, 0.88)   # v3.1 §E: −12% na banda

# ---- água (§G.1 + aferição v3.2 §D): ciclam as cores que formam FITAS
# (fluxo), não as dispersas (pipoca). Corpo escuro e traços curtos do
# azul-escuro ficam estáticos.
const AGUA_CICLO := [
	Color8(106, 195, 202), Color8(157, 237, 236), Color8(175, 233, 241),
]
const AGUA_VELOCIDADE := 1.6

# ---- juncos (§E/§G.2): touceiras 48px derivadas da própria margem,
# distribuídas irregularmente; clareiras cobrem os trechos mais densos.
# Posições recalculadas para a placa ESPELHADA (v3.2 §B).
const TOUCEIRAS_X := [60, 132, 246, 300, 350]
const TOUCEIRAS_JITTER_Y := [0, -1, 1, 0, -1]
const CLAREIRAS_X := [10, 205]
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

	# ---- recessão atmosférica do maciço (v3.2 §B): a camada extraída da
	# placa entra POR CIMA da fatia intacta, com contraste comprimido,
	# dessaturada e com bruma — a montanha volta para o fundo. As serras
	# laterais já nascem em bruma e ficam como estão. Desenhada DEPOIS das
	# nuvens: nuvem em frente ao cume passa por trás do véu, lê natural.
	var mont := Sprite2D.new()
	mont.name = "MontanhaRecessao"
	mont.texture = load(DERIVADOS + "montanha_central.png")
	mont.centered = false
	mont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat_rec := ShaderMaterial.new()
	mat_rec.shader = load("res://shaders/recessao_atmosferica.gdshader")
	mont.material = mat_rec
	add_child(mont)

	# ---- floresta em 3 tiers (spec v4 §C.1) ----
	_montar_floresta()

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

	# ---- terreno (spec v4 §C.3): trilha, cultivo, sub-bosque ----
	_montar_terreno()

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
	mat.set_shader_parameter("ruido_amplitude", CAMPO_RUIDO)
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
	veu.z_index = 4      # cobre também os 3 tiers de floresta
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	veu.material = mat
	return veu


# ---- floresta (spec v4 §C.1) --------------------------------------
# NÃO usa TileMapLayer, e o motivo é técnico: TileMapLayer alinha as
# células à grade, então o jitter de Y de ±4px que a spec exige seria
# impossível dentro dele. Sprite2D posicionado dá o mesmo resultado com o
# jitter que o critério mede, e o custo é irrelevante (~90 nós estáticos).
# As variantes vêm de fatiar_floresta.py, que já removeu a faixa de chão.
const FLORESTA_FOLHA := "res://assets_v2/cenario/tiras/floresta_arvores.png"
const FLORESTA_META := "res://assets_v2/cenario/tiras/floresta_arvores.json"
# tier: pé, faixa de ALTURA das variantes, modulate, z, passo em x.
# Escala é 1.0 em todos: escala fracionária reamostra o sprite e destrói a
# grade de pixel (0.8 de 50px dá 40, mas os pixels internos viram meio
# pixel). A profundidade vem de QUAIS variantes cada tier usa, do pé e do
# modulate — não de scale.
const TIERS := [
	{"pe": 100, "h_min": 0, "h_max": 24, "mod": Color(0.72, 0.80, 0.86), "z": 1, "passo": 15},
	{"pe": 105, "h_min": 21, "h_max": 30, "mod": Color(0.88, 0.92, 0.95), "z": 2, "passo": 19},
	{"pe": 110, "h_min": 21, "h_max": 34, "mod": Color(1, 1, 1), "z": 3, "passo": 23},
]
# As variantes de 43 e 50px não cabem numa banda de 29px: usadas na mata
# corrida, encobriam o maciço inteiro (copa em y=59 contra cume em y=52).
# Entram como EMERGENTES contados, e só FORA do vão do maciço (137..227),
# onde quebram a linha do topo sem tapar a montanha.
const EMERGENTES := [Vector2i(72, 112), Vector2i(300, 112), Vector2i(344, 111)]
# Clareiras nas faixas SEM montanha atrás (medidas na placa: x=0..62 e
# x=358..382). É onde a floresta é o horizonte e uma barra contínua
# denunciaria a arte. Elas abrem a mata PRÓXIMA e revelam a distante (a
# floresta pintada na placa): tirar aquela exigiria inpaint do que está
# atrás dela, que não existe — registrado como limite conhecido.
# A regra original mandava clareira "onde não há montanha atrás" — premissa
# de quando as laterais estavam perdidas (v3.5 §E). Com elas restauradas, o
# vão lê MELHOR sobre a montanha: abre a mata próxima e mostra o maciço.
# Nas bordas (x<45) a mata pintada na placa é a mais ALTA do quadro, então
# clareira ali não produz vão nenhum — medido.
const CLAREIRAS_FLORESTA := [Vector2i(196, 224), Vector2i(286, 312)]
const FLORESTA_SEMENTE := 20260805


func _montar_floresta() -> void:
	var meta_arq := FileAccess.open(FLORESTA_META, FileAccess.READ)
	if meta_arq == null:
		return
	var meta: Dictionary = JSON.parse_string(meta_arq.get_as_text())
	var variantes: Array = meta["variantes"]
	var folha: Texture2D = load(FLORESTA_FOLHA)
	var rng := RandomNumberGenerator.new()
	rng.seed = FLORESTA_SEMENTE

	for t in TIERS.size():
		var tier: Dictionary = TIERS[t]
		var elegiveis: Array[int] = []
		for i in variantes.size():
			var hv: int = int(variantes[i]["h"])
			if hv >= int(tier["h_min"]) and hv <= int(tier["h_max"]):
				elegiveis.append(i)
		var anterior := -1
		var x: int = -6
		while x < Bandas.CANVAS_W + 6:
			var em_clareira := false
			for cl in CLAREIRAS_FLORESTA:
				if x >= cl.x and x <= cl.y:
					em_clareira = true
			if not em_clareira and not elegiveis.is_empty():
				# nenhuma silhueta idêntica em células adjacentes
				var v: int = elegiveis[rng.randi_range(0, elegiveis.size() - 1)]
				if v == anterior and elegiveis.size() > 1:
					v = elegiveis[(elegiveis.find(v) + 1) % elegiveis.size()]
				anterior = v
				var d: Dictionary = variantes[v]
				var at := AtlasTexture.new()
				at.atlas = folha
				at.region = Rect2(d["x"], d["y"], d["w"], d["h"])
				var sp := Sprite2D.new()
				sp.texture = at
				sp.centered = false
				sp.offset = Vector2(-float(d["w"]) / 2.0, -float(d["h"]))
				# jitter de Y: é ele que faz a linha do topo ondular
				sp.position = Vector2(x, int(tier["pe"]) + rng.randi_range(-4, 4))
				sp.modulate = tier["mod"]
				sp.z_index = int(tier["z"])
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				if t == 0:
					# tier de fundo com a MESMA recessão do maciço, para o
					# fundo inteiro concordar (v3.2 §B / v4 §C.1)
					var mr := ShaderMaterial.new()
					mr.shader = load("res://shaders/recessao_atmosferica.gdshader")
					mr.set_shader_parameter("bruma", 0.22)
					sp.material = mr
				add_child(sp)
			x += int(tier["passo"]) + rng.randi_range(-2, 3)

	for e in EMERGENTES:
		var alto := -1
		for i in variantes.size():
			if int(variantes[i]["h"]) >= 38:
				alto = i if alto < 0 or rng.randf() < 0.5 else alto
		if alto < 0:
			continue
		var da: Dictionary = variantes[alto]
		var ata := AtlasTexture.new()
		ata.atlas = folha
		ata.region = Rect2(da["x"], da["y"], da["w"], da["h"])
		var spa := Sprite2D.new()
		spa.texture = ata
		spa.centered = false
		spa.offset = Vector2(-float(da["w"]) / 2.0, -float(da["h"]))
		spa.position = Vector2(e.x, e.y)
		spa.z_index = 3
		spa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spa)


# ---- terreno (spec v4 §C.3) ----------------------------------------
# A tira de trilha veio como FAIXA UNIFORME de terra batida, não como
# estrada desenhada. Melhor assim: ela entra como TEXTURA e a forma vem de
# LayoutN5 — a estrada passa a ligar ponte→praça→portão por construção, com
# a largura que o critério exige, em vez de depender do que o modelo pintou.
const TIRAS := "res://assets_v2/cenario/tiras/"
const TRILHA_LARGURA := 12       # tronco: o critério pede ≥10
const RAMAL_LARGURA := 5         # ramais: 4–6
const MANCHA_ALTURA := 4         # terra sob o pé de cada construção


func _montar_terreno() -> void:
	var terra: Texture2D = load(TIRAS + "terreno_trilhas.png")

	# manchas sob CADA peça do layout: nenhuma construção assenta em grama
	# virgem (v4 §C.3). Entram antes da estrada, que passa por cima.
	for p in LayoutN5.PECAS:
		if String(p["n"]).begins_with("arvore"):
			continue
		var largura: int = int(round(float(p["w"]) * 0.55))
		_mancha(terra, int(p["cx"]), int(p["base"]), largura, MANCHA_ALTURA, 5)

	# praça: mancha aberta no encontro dos caminhos
	var pr: Dictionary = LayoutN5.PRACA
	_mancha(terra, int(pr["cx"]), int(pr["base"]), int(pr["w"]),
			int(pr["h"]), 6)

	for pontos in LayoutN5.RAMAIS:
		_estrada(terra, pontos, RAMAL_LARGURA, 6)
	_estrada(terra, LayoutN5.TRILHA, TRILHA_LARGURA, 7)

	# cultivo: canteiros cercados onde o layout põe horta
	var cultivo: Texture2D = load(TIRAS + "terreno_cultivo.png")
	var i := 0
	for p in LayoutN5.PECAS:
		if not String(p["n"]).begins_with("pan_horta"):
			continue
		var at := AtlasTexture.new()
		at.atlas = cultivo
		at.region = Rect2(40 + i * 96, 26, 54, 26)
		var sp := Sprite2D.new()
		sp.texture = at
		sp.centered = false
		sp.offset = Vector2(-27, -24)
		sp.position = Vector2(int(p["cx"]), int(p["base"]) + 2)
		sp.z_index = int(p["base"])
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sp)
		i += 1

	# sub-bosque POR ÚLTIMO, contra a floresta já em 3 tiers: é ele que
	# quebra a linha reta da junção floresta/campo, com jitter de Y.
	var sub: Texture2D = load(TIRAS + "terreno_sub_bosque.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = FLORESTA_SEMENTE + 7
	var x := -8
	while x < Bandas.CANVAS_W + 8:
		var larg: int = rng.randi_range(34, 56)
		var at2 := AtlasTexture.new()
		at2.atlas = sub
		at2.region = Rect2(rng.randi_range(0, 340), 0, larg, 24)
		var sp2 := Sprite2D.new()
		sp2.texture = at2
		sp2.centered = false
		sp2.position = Vector2(x, Bandas.FATIAS["campo"].x - 18
				+ rng.randi_range(-3, 3))
		sp2.z_index = 5
		sp2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sp2)
		x += larg - rng.randi_range(2, 8)


func _mancha(tex: Texture2D, cx: int, base: int, w: int, h: int,
		z: int) -> void:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((cx * 7) % maxi(1, 400 - w), 24, w, h)
	var sp := Sprite2D.new()
	sp.texture = at
	sp.centered = false
	sp.offset = Vector2(-float(w) / 2.0, -float(h))
	sp.position = Vector2(cx, base)
	sp.z_index = z
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)


func _estrada(tex: Texture2D, pontos: Array, largura: int, z: int) -> void:
	var l := Line2D.new()
	for p in pontos:
		l.add_point(Vector2(p.x, p.y))
	l.width = largura
	l.texture = tex
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.z_index = z
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)


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
