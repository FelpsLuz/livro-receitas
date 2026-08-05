# ============================================================
# ÍCONES — os itens gerados pelo PixelLab (assets_v2/icons/) para a UI Pro.
#
# Dois usos:
#   textura("trigo")            → Texture2D do ícone (ou null)
#   slot("trigo", 48)           → quadro_inventario 9-slice com o ícone dentro
#   de_mercadoria("cavalos")    → ícone da MERCADORIA de dados.gd
#
# O mercado, o inventário de trocas e a vitrine passam por aqui. Sem o PNG,
# devolve null e a UI continua só com texto — nunca quebra.
# ============================================================
extends RefCounted

const UIv2 = preload("res://scripts/ui_v2.gd")

const PASTA := "res://assets_v2/icons/"

## Tudo o que o gerador sabe fazer (espelha o CATALOGO de generate_assets_v2.py).
const TODOS := ["moedas", "trigo", "madeira", "espada", "escudo", "arco",
	"lanca", "pao", "cerveja", "pergaminho", "gema", "coroa",
	"ferro", "sal", "tecidos", "cavalos",
	# ícones de MECÂNICA, não de mercadoria: são estados que a UI mostrava
	# só com emoji — neblina de guerra, moral, fila do quartel, cerco
	"espiao", "neblina", "populacao", "moral", "ampulheta", "cerco",
	# a folha que substituiu os emoji do sistema
	"renome", "calendario", "felicidade", "tropa", "alianca", "carta",
	"correntes", "caveira", "louros", "forca", "carisma", "gestao",
	"intriga", "lorde", "som", "mudo"]

static func _id(nome: String) -> String:
	return nome if nome.begins_with("icone_") else "icone_" + nome

static func tem(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + _id(nome) + ".png")

static func textura(nome: String) -> Texture2D:
	if not tem(nome):
		return null
	var t = load(PASTA + _id(nome) + ".png")
	return t if t is Texture2D else null

## Ícone da mercadoria de dados.gd — os ids coincidem de propósito.
static func de_mercadoria(g_id: String) -> Texture2D:
	return textura(g_id)

## TextureRect pronto: pixel nítido, tamanho fixo, centrado.
static func imagem(nome: String, tamanho: int = 32) -> TextureRect:
	var tex := textura(nome)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = Vector2(tamanho, tamanho)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr

## Slot de inventário completo: a moldura Pro (quadro_inventario) com o ícone
## dentro. Sem a moldura, devolve só o ícone; sem nada, um quadrado vazio.
static func slot(nome: String, tamanho: int = 48) -> Control:
	var base: Control = UIv2.criar_painel("quadro_inventario")
	if base == null:
		base = Panel.new()
	elif base is NinePatchRect:
		# a arte do quadro tem margem de 40px num canvas de 128 (~31%); num
		# slot de 44px as margens somariam 80 > 44 e o 9-slice degenera —
		# os cantos se atropelam e os slots "se fundem" numa placa só
		var m := int(tamanho * 0.31)
		base.patch_margin_left = m
		base.patch_margin_top = m
		base.patch_margin_right = m
		base.patch_margin_bottom = m
	base.custom_minimum_size = Vector2(tamanho, tamanho)
	base.size = Vector2(tamanho, tamanho)
	var icone := imagem(nome, int(tamanho * 0.62))
	if icone != null:
		# posição e tamanho EXPLÍCITOS: âncora central com size zero deixava o
		# TextureRect invisível dentro do NinePatchRect
		var lado := int(tamanho * 0.62)
		icone.size = Vector2(lado, lado)
		icone.position = Vector2((tamanho - lado) / 2.0, (tamanho - lado) / 2.0)
		base.add_child(icone)
	return base

## Relatório para testes e resumo de build.
static func inventario() -> Dictionary:
	var tem_: Array = []
	var falta: Array = []
	for n in TODOS:
		if tem(n):
			tem_.append(n)
		else:
			falta.append(n)
	return {"tem": tem_, "falta": falta}
