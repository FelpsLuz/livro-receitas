# ============================================================
# UI v2 — as molduras e botões da interface.
#
# VISUAL STRIP: os PNG foram removidos. As molduras continuam sendo
# NinePatchRect, com as MESMAS margens 9-slice de antes, mas sobre um
# caixote cinza. Manter o 9-slice não é capricho: é ele que define quanto
# a moldura come do retângulo, e portanto o layout de toda janela. Trocar
# por um Panel liso moveria o conteúdo de lugar.
#
# MARGENS continua com os valores medidos na arte antiga porque são eles
# que a arte NOVA vai ter que respeitar para o layout não mudar de novo.
# ============================================================
extends RefCounted

const Arte = preload("res://scripts/arte.gd")

## Margens 9-slice de cada peça, medidas na imagem gerada (não chutadas):
## a moldura de madeira tem ~32px de borda numa arte de 256×256.
## Medidas na ARTE de cada peça (onde a moldura termina e o miolo começa),
## não chutadas: é isso que faz o 9-slice esticar sem deformar os rebites.
const MARGENS := {
	"painel_madeira": 32,
	"painel_pergaminho": 33,
	"moldura_retrato": 32,
	"quadro_inventario": 40,
	"botao_madeira": 18,
	"botao_madeira_apertado": 26,
	"barra_hud": 20,
}

static func tem(nome: String) -> bool:
	return MARGENS.has(nome)

## O caixote precisa ser MAIOR que a soma das margens 9-slice, senão os
## cantos se atropelam e o NinePatchRect degenera numa placa só. Três vezes
## a margem dá folga para o miolo esticar.
static func textura(nome: String) -> Texture2D:
	var m: int = MARGENS.get(nome, 24)
	return Arte.caixa(maxi(64, m * 3))

## Cria um NinePatchRect pronto: textura, margens e filtro de pixel art.
## Devolve null se o asset ainda não foi gerado (o chamador cai no tema antigo).
static func criar_painel(nome: String = "painel_madeira") -> NinePatchRect:
	var tex := textura(nome)
	if tex == null:
		return null
	var np := NinePatchRect.new()
	np.texture = tex
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m: int = MARGENS.get(nome, 24)
	np.patch_margin_left = m
	np.patch_margin_top = m
	np.patch_margin_right = m
	np.patch_margin_bottom = m
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE   # moldura não rouba clique
	return np

## Envolve um Control existente com a moldura Pro, mantendo o conteúdo por cima.
## Uso: UIv2.emoldurar(meu_painel) — devolve o nó que deve entrar na árvore.
static func emoldurar(conteudo: Control, nome: String = "painel_madeira") -> Control:
	var np := criar_painel(nome)
	if np == null:
		return conteudo               # sem asset: segue o painel de sempre
	var caixa := MarginContainer.new()
	var m: int = int(MARGENS.get(nome, 24) * 0.7)
	for lado in ["left", "top", "right", "bottom"]:
		caixa.add_theme_constant_override("margin_" + lado, m)
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(np)               # moldura ao fundo
	caixa.add_child(conteudo)         # conteúdo por cima
	return caixa

## StyleBoxTexture equivalente, para aplicar no Theme (afeta todo PanelContainer).
static func stylebox(nome: String = "painel_madeira") -> StyleBoxTexture:
	var tex := textura(nome)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m: float = float(MARGENS.get(nome, 24))
	sb.set_texture_margin(SIDE_LEFT, m)
	sb.set_texture_margin(SIDE_TOP, m)
	sb.set_texture_margin(SIDE_RIGHT, m)
	sb.set_texture_margin(SIDE_BOTTOM, m)
	# conteúdo respira dentro da moldura
	sb.set_content_margin(SIDE_LEFT, m * 0.6)
	sb.set_content_margin(SIDE_TOP, m * 0.6)
	sb.set_content_margin(SIDE_RIGHT, m * 0.6)
	sb.set_content_margin(SIDE_BOTTOM, m * 0.6)
	return sb

## StyleBox de botão nos três estados, para o Theme global.
## Cada estado tem seu PNG; sem eles, o botão do tema antigo continua.
static func estilos_botao() -> Dictionary:
	var normal := stylebox("botao_madeira")
	if normal == null:
		return {}
	var estilos := {"normal": normal}
	estilos["pressed"] = stylebox("botao_madeira_apertado")
	# Os quatro estados precisam continuar DISTINGUÍVEIS: um botão que não
	# muda ao passar o mouse ou ao desabilitar é defeito de usabilidade, não
	# de arte. Sobre o caixote cinza a diferença vira só brilho.
	var hover := stylebox("botao_madeira")
	hover.modulate_color = Color(1.25, 1.25, 1.25)
	estilos["hover"] = hover
	var desativado := stylebox("botao_madeira")
	desativado.modulate_color = Color(0.55, 0.55, 0.55)
	estilos["disabled"] = desativado
	return estilos

## Relatório para os testes. No strip nada falta — toda peça tem caixote.
static func inventario() -> Dictionary:
	return {"tem": MARGENS.keys(), "falta": []}
