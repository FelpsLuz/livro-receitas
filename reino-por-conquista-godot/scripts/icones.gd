# ============================================================
# ÍCONES — os símbolos da UI (mercado, inventário, HUD).
#
# VISUAL STRIP: os PNG foram removidos do projeto. A lista TODOS continua
# valendo como CONTRATO — é ela que diz quais estados a UI precisa saber
# distinguir — mas toda textura agora é um caixote cinza do tamanho pedido.
#
#   textura("trigo")            → caixote 32×32
#   slot("trigo", 48)           → moldura + caixote dentro
#   de_mercadoria("cavalos")    → caixote da MERCADORIA de dados.gd
#
# `tem()` responde SEMPRE true: o caixote nunca falta. Quem chamava para
# decidir entre ícone e texto continua escolhendo o ícone, e o layout fica
# igual ao que era com arte — que é o ponto de um placeholder.
# ============================================================
extends RefCounted

const UIv2 = preload("res://scripts/ui_v2.gd")
const Arte = preload("res://scripts/arte.gd")

## Lado do caixote: 64px, que é o tamanho em que os ícones foram gerados.
## Manter a dimensão da arte antiga é o que preserva o layout — `imagem()`
## reescala para o `tamanho` pedido pelo chamador, como sempre fez.
const LADO := 64

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
	return _id(nome) != ""

static func textura(_nome: String) -> Texture2D:
	return Arte.caixa(LADO)

## Ícone da mercadoria de dados.gd — os ids coincidem de propósito.
static func de_mercadoria(g_id: String) -> Texture2D:
	return textura(g_id)

## TextureRect pronto: pixel nítido, tamanho fixo, centrado.
static func imagem(nome: String, tamanho: int = 32) -> TextureRect:
	var tex := textura(nome)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.name = "Icone_" + _id(nome)
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

## Relatório para testes. No strip nada falta — todo ícone tem caixote.
static func inventario() -> Dictionary:
	return {"tem": TODOS.duplicate(), "falta": []}
