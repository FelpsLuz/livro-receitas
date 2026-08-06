# ============================================================
# ARTE — a fonte ÚNICA de placeholder do projeto.
#
# O jogo está em "visual strip": nenhuma imagem autoral é carregada. Toda
# textura que a cena pede nasce aqui, como um caixote cinza do tamanho que
# aquela entidade ocupava. A mecânica não muda — o que muda é que ninguém
# mais consegue confundir arte de rascunho com arte final.
#
# Por que ImageTexture cinza e não PlaceholderTexture2D
# -----------------------------------------------------
# PlaceholderTexture2D só carrega um TAMANHO: em runtime ele não desenha
# nada, então a tela ficaria vazia e seria impossível ver se um nó está no
# lugar certo. O pedido era "o jogo deve rodar apenas com os caixotes" —
# caixote precisa aparecer. Aqui a textura é cinza sólido com borda 1px mais
# escura, que é o mínimo para distinguir dois caixotes encostados.
#
# Tudo é CACHEADO por dimensão: uma vila com 200 aldeões pede 200 vezes o
# mesmo caixote de 32×32 e recebe a mesma Texture2D.
# ============================================================
class_name Arte
extends RefCounted

## O placeholder mora na paleta da INTERFACE, um degrau acima da superfície.
##
## Ele era cinza 0,62 — escolhido quando o tema era pergaminho claro, onde
## some. Sobre o slate escuro do tema novo, o mesmo cinza vira o elemento
## mais claro da tela: a ausência de arte passou a gritar mais alto que a
## arte. Placeholder tem que dizer "falta uma peça aqui", não roubar a
## leitura da tabela ao lado.
##
## Os valores espelham Tema.ELEVADO e Tema.BORDA. Não são importados de lá
## para o Arte não depender do tema — este nó também roda em teste headless,
## onde não há Theme montado.
const TOM := Color(0.185, 0.153, 0.129, 1.0)
const BORDA := Color(0.27, 0.23, 0.18, 1.0)
## Silhueta (sombra projetada, oclusor): o caixote em preto, sem borda.
const VULTO := Color(0.0, 0.0, 0.0, 1.0)

static var _cache: Dictionary = {}


## O caixote. `w`×`h` em pixels, sempre ≥ 1.
static func caixa(w: int, h: int = -1) -> Texture2D:
	if h < 0:
		h = w
	w = maxi(1, w)
	h = maxi(1, h)
	var chave := "%dx%d" % [w, h]
	if _cache.has(chave):
		return _cache[chave]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(TOM)
	# borda de 1px: sem ela, dois caixotes vizinhos viram um bloco só e some
	# a informação de quantas entidades existem ali
	if w > 2 and h > 2:
		for x in w:
			img.set_pixel(x, 0, BORDA)
			img.set_pixel(x, h - 1, BORDA)
		for y in h:
			img.set_pixel(0, y, BORDA)
			img.set_pixel(w - 1, y, BORDA)
	var tex := ImageTexture.create_from_image(img)
	_cache[chave] = tex
	return tex


## Atlas de caixotes: grade `colunas`×`linhas` de tiles de `tile` pixels, cada
## um com a sua borda. É o que substitui os atlas de terreno — o TileSet
## continua fatiando na mesma grade, com a mesma física e a mesma navegação.
static func atlas(colunas: int, linhas: int, tile: int) -> Texture2D:
	var chave := "atlas_%dx%d_%d" % [colunas, linhas, tile]
	if _cache.has(chave):
		return _cache[chave]
	var img := Image.create(colunas * tile, linhas * tile, false, Image.FORMAT_RGBA8)
	img.fill(TOM)
	for cy in linhas:
		for cx in colunas:
			var x0 := cx * tile
			var y0 := cy * tile
			for i in tile:
				img.set_pixel(x0 + i, y0, BORDA)
				img.set_pixel(x0 + i, y0 + tile - 1, BORDA)
				img.set_pixel(x0, y0 + i, BORDA)
				img.set_pixel(x0 + tile - 1, y0 + i, BORDA)
	var tex := ImageTexture.create_from_image(img)
	_cache[chave] = tex
	return tex


## Caixote opaco preto, para silhueta de sombra projetada. Sem borda: uma
## sombra com contorno mais claro não é sombra de nada.
static func vulto(w: int, h: int = -1) -> Texture2D:
	if h < 0:
		h = w
	w = maxi(1, w)
	h = maxi(1, h)
	var chave := "vulto_%dx%d" % [w, h]
	if _cache.has(chave):
		return _cache[chave]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(VULTO)
	var tex := ImageTexture.create_from_image(img)
	_cache[chave] = tex
	return tex
