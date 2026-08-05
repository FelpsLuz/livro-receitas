# ============================================================
# CENÁRIO v2 — composição em camadas na Godot (addendum v3).
# A placa base entra FATIADA em nós por banda (Bandas.FATIAS, gerado de
# bandas.py) para que cada banda tenha o seu modulate: é aqui que vivem as
# correções de hierarquia de valor (§F.1) e de contenção do rio (§F.2),
# sem custo de API. Objetos são sprites isolados ancorados na BASE, cada
# um com sombra de contato de nó (sombra_contato.gd, §C).
# Canvas de arte: 400×200; desenhar dentro de um SubViewport com NEAREST
# e escalar por inteiro (a arquitetura §D.1 ganha o shader de estação
# no passo 8 da §I).
# ============================================================
class_name CenarioV2Cena
extends Node2D

const PLACA := "res://assets_v2/cenario/base/placa_base.png"
const SPRITES := "res://assets_v2/cenario/sprites/"

# ---- §F.1/§F.2 — hierarquia de valor via modulate, calibrável num lugar só ----
# Floresta: escurecida/dessaturada ~15% via VÉU multiply em gradiente (as
# árvores atravessam a linha de corte fundo/floresta — modulate na fatia
# criaria uma emenda horizontal no meio das copas; o gradiente entra
# transparente no céu e chega cheio nos troncos, sem emenda).
const TINTA_FLORESTA := Color(0.82, 0.86, 0.88)
const VEU_FLORESTA_TOPO := 58      # começa no topo das copas (banda ceu/serra)
# Rio: banda inteira -8%; o specular é contido pelo véu (abaixo).
const MOD_RIO := Color(0.92, 0.92, 0.92)
# Véu do rio: ColorRect na cor média da banda (medida da placa: 115,175,171)
# por cima do specular — squash de contraste ~40% e os pontos brancos mais
# fracos somem (~metade da densidade aparente).
const VEU_RIO := Color(115.0 / 255.0, 175.0 / 255.0, 171.0 / 255.0, 0.35)
# Construções: telhado/fachada puxados para MAIS claros que o entorno.
const MOD_CONSTRUCAO := Color(1.08, 1.05, 1.0)

# Evolução: quais objetos existem em cada nível (N0..N5). Por enquanto só a
# casa do piloto; o lote do §I.6 preenche o resto da tabela.
const NIVEIS := {
	0: [],
	1: [{"sprite": "casa_sape", "pos": Vector2i(112, 155)}],
}

var nivel := 1:
	set(v):
		nivel = v
		_montar()


func _ready() -> void:
	_montar()


func _montar() -> void:
	for filho in get_children():
		filho.queue_free()

	var placa: Texture2D = load(PLACA)

	# ---- fatias da placa, uma por banda, cada uma com o seu modulate ----
	var mods := {
		"fundo": Color.WHITE,
		"floresta": Color.WHITE,      # o véu em gradiente faz o §F.1
		"campo": Color.WHITE,
		"rio": MOD_RIO,
		"margem": Color.WHITE,
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
		add_child(sp)

	# ---- véu da floresta (§F.1): multiply em gradiente vertical ----
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
	var veu_fl := Sprite2D.new()
	veu_fl.name = "VeuFloresta"
	veu_fl.texture = gtex
	veu_fl.centered = false
	veu_fl.position = Vector2(0, VEU_FLORESTA_TOPO)
	veu_fl.scale = Vector2(Bandas.CANVAS_W / 4.0, 1.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	veu_fl.material = mat
	add_child(veu_fl)

	# ---- véu do rio (§F.2): contém o specular sem regerar a placa ----
	var veu := ColorRect.new()
	veu.name = "VeuRio"
	var rio: Vector2i = Bandas.FATIAS["rio"]
	veu.position = Vector2(0, rio.x)
	veu.size = Vector2(Bandas.CANVAS_W, rio.y - rio.x)
	veu.color = VEU_RIO
	add_child(veu)

	# ---- objetos do nível, ancorados na BASE, com sombra de nó (§C) ----
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
		sp.modulate = MOD_CONSTRUCAO
		sp.z_index = 1
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sp)
		add_child(SombraContato.criar_sombra(sp))
