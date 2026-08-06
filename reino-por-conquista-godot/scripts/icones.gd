# ============================================================
# ÍCONES — os símbolos da UI (mercado, inventário, HUD).
#
# VISUAL STRIP: os PNG foram removidos do projeto. A lista TODOS continua
# valendo como CONTRATO — é ela que diz quais estados a UI precisa saber
# distinguir — mas toda textura agora é um caixote cinza do tamanho pedido.
#
#   textura("trigo")            → caixote 32×32
#   slot("trigo", 48)           → moldura + caixote dentro
#   de_mercadoria("pedra")      → caixote da MERCADORIA de dados.gd
#
# `tem()` responde SEMPRE true: o caixote nunca falta. Quem chamava para
# decidir entre ícone e texto continua escolhendo o ícone, e o layout fica
# igual ao que era com arte — que é o ponto de um placeholder.
# ============================================================
extends RefCounted

const UIv2 = preload("res://scripts/ui_v2.gd")
const Arte = preload("res://scripts/arte.gd")
const Tema = preload("res://scripts/tema.gd")

const PASTA := "res://assets/sprites/"
## Os arquivos são silhueta BRANCA com alfa. A cor sai daqui, em runtime.
## Um arquivo serve a todos os estados: latão no normal, terracota no
## alarme, apagado no desabilitado — e vinte ícones nunca divergem de tom,
## porque o tom não está no arquivo.
const LADO := 192

## Tudo o que o gerador sabe fazer (espelha o CATALOGO de generate_assets_v2.py).
const TODOS := ["moedas", "trigo", "madeira", "espada", "escudo", "arco",
	"lanca", "pao", "cerveja", "pergaminho", "gema", "coroa",
	"ferro", "sal", "tecidos", "pedra", "prata",
	# ícones de MECÂNICA, não de mercadoria: são estados que a UI mostrava
	# só com emoji — neblina de guerra, moral, fila do quartel, cerco
	"espiao", "neblina", "populacao", "moral", "ampulheta", "cerco",
	# a folha que substituiu os emoji do sistema
	"renome", "calendario", "felicidade", "tropa", "alianca", "carta",
	"correntes", "caveira", "louros", "forca", "carisma", "gestao",
	"intriga", "lorde", "som", "mudo",
	# ícones de ABA (ver principal.gd ABAS): as seções que não se anunciam
	# por um ícone de recurso já existente
	"terra", "mapa", "mercado", "familia"]

## A COR DE CADA COISA.
##
## Os arquivos nascem em silhueta branca; a cor entra aqui, em runtime. Isso
## não é economia — é o que deixa a paleta ser DECIDIDA num lugar só. Trocar
## o tom do trigo é uma linha, não 38 arquivos regerados.
##
## Por que cada ícone tem a sua cor, e não todos o latão do acento: num
## painel de mercado com doze linhas, doze ícones idênticos em cor viram uma
## coluna de manchas iguais e o olho é obrigado a ler o texto para saber o
## que é cada linha. Com o trigo dourado, o ferro em aço e a madeira em
## castanho, a linha se acha pela cor antes de se ler a palavra — que é o
## trabalho que um ícone tem numa tabela.
##
## Todas as cores são DESSATURADAS de propósito e todas passam de perto do
## mesmo nível de luminância. Cor saturada pura sobre o painel escuro vibra,
## e trinta e oito hues em força total viram festa junina, não interface.
## O acento continua sendo o único latão puro — ele é da marca, não do item.
const COR := {
	# ---- metais e minérios ----
	"moedas": Color("e8b04b"), "ouro": Color("e8b04b"),
	"ferro": Color("a9b2ba"), "gema": Color("6fbfb4"),
	"correntes": Color("8d949b"),
	# ---- campo e mesa ----
	"trigo": Color("dcc067"), "pao": Color("d4a05f"),
	"cerveja": Color("d09a4a"), "sal": Color("e2ded2"),
	"madeira": Color("b07a4a"), "tecidos": Color("a382bd"),
	"pedra": Color("9b968c"), "prata": Color("aab4bd"), "terra": Color("9c7d55"),
	# ---- guerra ----
	"espada": Color("bcc4cc"), "lanca": Color("bcc4cc"),
	"escudo": Color("9fb0c2"), "arco": Color("b07a4a"),
	"tropa": Color("bcc4cc"), "cerco": Color("d0705a"),
	"forca": Color("cf8a5e"), "caveira": Color("d6d0c2"),
	# ---- corte e papel ----
	"pergaminho": Color("d8c9a8"), "carta": Color("d8c9a8"),
	"calendario": Color("d8c9a8"), "coroa": Color("f5c86b"),
	"lorde": Color("f5c86b"), "renome": Color("e8b04b"),
	"carisma": Color("e8b04b"), "gestao": Color("bcc4cc"),
	"louros": Color("8fbf6a"), "mapa": Color("cbb389"),
	"mercado": Color("c9954f"),
	# ---- gente ----
	"populacao": Color("86a9c4"), "familia": Color("86a9c4"),
	"alianca": Color("86a9c4"), "moral": Color("8fbf6a"),
	"felicidade": Color("8fbf6a"),
	# ---- sombra ----
	"espiao": Color("9b8bb5"), "intriga": Color("9b8bb5"),
	"neblina": Color("8b96a3"),
	# ---- sistema: cinza de propósito, não é conteúdo do jogo ----
	"ampulheta": Color("c2b49a"), "som": Color("b5a48c"),
	"mudo": Color("7a6b58"),
}

## A cor própria do ícone. Quem não está na tabela cai no acento — assim um
## ícone novo aparece em latão, visível, em vez de sumir.
static func cor_de(nome: String) -> Color:
	var chave := nome.trim_prefix("icone_").trim_prefix("aba_")
	return COR.get(chave, Tema.ACENTO)


static func _id(nome: String) -> String:
	return nome if nome.begins_with("icone_") else "icone_" + nome

static func tem(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + _id(nome) + ".png")

## A silhueta. Quem tinge é `imagem()` ou o chamador, via `modulate`.
static func textura(nome: String) -> Texture2D:
	if not tem(nome):
		return Arte.caixa(64)
	var t = load(PASTA + _id(nome) + ".png")
	return t if t is Texture2D else Arte.caixa(64)

static var _tingidas: Dictionary = {}

## A silhueta com a cor JÁ ASSADA nos pixels.
##
## `TabContainer.set_tab_icon` e `Button.icon` desenham a textura crua: não
## passam por `modulate`, então uma silhueta branca chega branca na aba. Para
## esses dois a cor tem que estar no pixel. É a mesma tabela COR — o que muda
## é só onde a tinta é aplicada.
##
## Cacheado por nome+cor: dez abas pedem dez texturas uma vez, não a cada
## `atualizar()`.
static func textura_tingida(nome: String, cor: Variant = null) -> Texture2D:
	var c: Color = cor if cor is Color else cor_de(nome)
	var chave := "%s|%s" % [_id(nome), c.to_html()]
	if _tingidas.has(chave):
		return _tingidas[chave]
	if not tem(nome):
		return Arte.caixa(64)
	var base: Texture2D = load(PASTA + _id(nome) + ".png")
	if base == null:
		return Arte.caixa(64)
	var img := base.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, p.a))
	var tex := ImageTexture.create_from_image(img)
	_tingidas[chave] = tex
	return tex

## Ícone da mercadoria de dados.gd — os ids coincidem de propósito.
static func de_mercadoria(g_id: String) -> Texture2D:
	return textura(g_id)

## TextureRect pronto: pixel nítido, tamanho fixo, centrado.
##
## `cor` fica em `null` por padrão para o ícone usar a SUA cor (tabela COR
## acima). Quem passa uma cor explícita está dizendo um ESTADO — o trigo em
## terracota quando o celeiro está vazio — e essa cor ganha da tabela.
static func imagem(nome: String, tamanho: int = 32,
		cor: Variant = null) -> TextureRect:
	var tex := textura(nome)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.name = "Icone_" + _id(nome)
	tr.texture = tex
	# LINEAR, não NEAREST: o ícone é vetor rasterizado em 192px e a
	# interface o mostra em 20–48. Nearest numa redução de 4x serrilha a
	# curva inteira — o filtro que a pixel art exigia é o que estraga aqui.
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.modulate = cor if cor is Color else cor_de(nome)
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

## Relatório para testes e para saber o que ainda falta gerar.
static func inventario() -> Dictionary:
	var tem_: Array = []
	var falta: Array = []
	for n in TODOS:
		if tem(n):
			tem_.append(n)
		else:
			falta.append(n)
	return {"tem": tem_, "falta": falta}
