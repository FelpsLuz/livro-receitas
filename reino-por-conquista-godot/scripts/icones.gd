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

# ============================================================
# A LEVA ILUSTRADA (hi-bit, PixelLab)
#
# Os 43 ícones de silhueta continuam sendo o esqueleto — são eles que os
# testes conferem e é deles que vem o fallback. Mas quando existe a versão
# ILUSTRADA em assets/sprites/hibit/, ela vence: colorida, com luz própria,
# e por isso NUNCA tingida — tingir uma ilustração colorida a transforma
# numa mancha monocromática, que é pior que a silhueta.
#
# Bytes do pacote + `load_png_from_buffer`, não `load()`: a leva chega sem
# passar pelo editor, e caminho globalizado morre dentro de PCK/APK — o
# filesystem virtual carrega em qualquer modo (headless e export inclusos).
# ============================================================
const PASTA_HIBIT := "res://assets/sprites/hibit/"
static var _ilustrados: Dictionary = {}

static func ilustrado(nome: String) -> Texture2D:
	var chave := nome.trim_prefix("icone_")
	if _ilustrados.has(chave):
		return _ilustrados[chave]
	var bytes := FileAccess.get_file_as_bytes(
		PASTA_HIBIT + "icone_" + chave + ".png")
	var img := Image.new()
	if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
		_ilustrados[chave] = null
		return null
	var tex := ImageTexture.create_from_image(img)
	_ilustrados[chave] = tex
	return tex

## O SUBSTITUTO de um ícone que não existe.
##
## Dois dos 43 nomes de `TODOS` nunca ganharam arquivo — `pedra` e `prata` —
## e o que aparecia no lugar era `Arte.caixa`: o caixote cinza do visual
## strip. Numa coluna de tabela em que as outras oito linhas têm um símbolo
## desenhado, um retângulo cinza não lê como "falta arte", lê como DEFEITO,
## e era o pior pixel da aba do mercado.
##
## Para `pedra` e `prata` o substituto virou SILHUETA DESENHADA — uma rocha
## facetada e três barras empilhadas — no mesmo contrato dos 41 arquivos:
## branco com alfa, 192×192, cor aplicada em runtime. Qualquer OUTRO nome
## sem arquivo cai no losango genérico, que não finge ser o ícone que falta
## mas cumpre o trabalho dele na tabela: uma marca colorida que o olho acha
## antes de ler a palavra.
static var _gerados: Dictionary = {}

static func _silhueta_gerada(nome: String) -> Texture2D:
	if _gerados.has(nome):
		return _gerados[nome]
	var lado := 192
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var b := Color(1, 1, 1, 1)
	var meio := Color(1, 1, 1, 0.55)   # meio-tom: a faceta, como nos demais
	match nome:
		"pedra":
			# uma rocha: hexágono irregular cheio, com duas arestas de
			# faceta em meio-tom — o mesmo vocabulário do icone_ferro
			var pontos := PackedVector2Array([Vector2(96, 22), Vector2(164, 58),
				Vector2(172, 128), Vector2(112, 172), Vector2(38, 148),
				Vector2(24, 72)])
			for y in lado:
				for x in lado:
					if Geometry2D.is_point_in_polygon(Vector2(x, y), pontos):
						img.set_pixel(x, y, b)
			# arestas internas da faceta
			for t in 300:
				var f := t / 299.0
				var p1 := Vector2(96, 22).lerp(Vector2(112, 172), f)
				var p2 := Vector2(24, 72).lerp(Vector2(172, 128), f)
				for p in [p1, p2]:
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							var px := int(p.x) + dx
							var py := int(p.y) + dy
							if px >= 0 and py >= 0 and px < lado and py < lado \
									and img.get_pixel(px, py).a > 0.9:
								img.set_pixel(px, py, meio)
		"prata":
			# três barras trapezoidais empilhadas em pirâmide
			for barra in [[36, 128, 84], [76, 128, 84], [56, 84, 40]]:
				var bx: int = barra[0]
				var by: int = barra[2]
				for y in range(by, by + 40):
					var recuo: int = int((y - by) * 0.35)
					for x in range(bx + 14 - recuo, bx + 66 + recuo):
						if x >= 0 and x < lado:
							img.set_pixel(x, y, b)
				# topo da barra em meio-tom: o brilho do lingote
				for y in range(by, by + 8):
					var recuo2: int = int((y - by) * 0.35)
					for x in range(bx + 14 - recuo2, bx + 66 + recuo2):
						if x >= 0 and x < lado:
							img.set_pixel(x, y, meio)
		_:
			# o losango genérico de sempre
			var c := (lado - 1) * 0.5
			for y in lado:
				for x in lado:
					var d: float = absf(x - c) + absf(y - c)
					if d <= c * 0.92:
						img.set_pixel(x, y, b if d > c * 0.62 else meio)
	var tex := ImageTexture.create_from_image(img)
	_gerados[nome] = tex
	return tex


## A silhueta. Quem tinge é `imagem()` ou o chamador, via `modulate`.
static func textura(nome: String) -> Texture2D:
	var chave := nome.trim_prefix("icone_")
	if not tem(nome):
		return _silhueta_gerada(chave)
	var t = load(PASTA + _id(nome) + ".png")
	return t if t is Texture2D else _silhueta_gerada(chave)

static var _tingidas: Dictionary = {}

## A silhueta com a cor JÁ ASSADA nos pixels.
##
## `TabContainer.set_tab_icon` e `Button.icon` desenham a textura crua: não
## passam por `modulate`, então uma silhueta branca chega branca na aba. Para
## esses dois a cor tem que estar no pixel. É a mesma tabela COR — o que muda
## é só onde a tinta é aplicada.
##
## Cacheado por nome+cor: onze abas pedem onze texturas uma vez, não a cada
## `atualizar()`.
static func textura_tingida(nome: String, cor: Variant = null) -> Texture2D:
	# ilustrado NÃO se tinge: onde a aba/botão pedia a silhueta assada na
	# cor, a versão colorida entra como está
	var ilus := ilustrado(nome)
	if ilus != null:
		return ilus
	var c: Color = cor if cor is Color else cor_de(nome)
	var chave := "%s|%s" % [_id(nome), c.to_html()]
	if _tingidas.has(chave):
		return _tingidas[chave]
	var base: Texture2D
	if tem(nome):
		base = load(PASTA + _id(nome) + ".png")
	if base == null:
		# sem arquivo: a silhueta GERADA (pedra, prata, losango) entra no
		# mesmo caminho de tingimento dos PNG — um fluxo só, sem atalho
		base = _silhueta_gerada(nome.trim_prefix("icone_"))
	var img: Image = base.get_image().duplicate()
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
	# a leva ILUSTRADA vence, e entra crua: colorida, NEAREST (é pixel art
	# de 32, mostrada em 18–34 — quase sempre 1:1) e sem modulate
	var ilus := ilustrado(nome)
	if ilus != null:
		var tri := TextureRect.new()
		tri.name = "Icone_" + _id(nome)
		tri.texture = ilus
		tri.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tri.custom_minimum_size = Vector2(tamanho, tamanho)
		tri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tri.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return tri
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
