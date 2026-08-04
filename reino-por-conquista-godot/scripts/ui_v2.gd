# ============================================================
# UI v2 — liga os assets Pro do PixelLab (res://assets_v2/ui/) aos nós da Godot.
#
# A regra do overhaul: painel de textura vira NinePatchRect, que estica as
# BORDAS sem deformar os cantos — é o que permite uma moldura de pixel art
# servir a uma janela de qualquer tamanho sem borrar nem esticar os rebites.
# Quando um PNG ainda não existe, o tema procedural antigo continua valendo,
# então a interface nunca fica sem nada.
# ============================================================
extends RefCounted

const PASTA := "res://assets_v2/ui/"

## Margens 9-slice de cada peça, medidas na imagem gerada (não chutadas):
## a moldura de madeira tem ~32px de borda numa arte de 256×256.
const MARGENS := {
	"painel_madeira": 35,
	"painel_pergaminho": 35,
	"moldura_retrato": 24,
	"quadro_inventario": 20,
	"botao_madeira": 18,
	"botao_madeira_apertado": 18,
	"barra_hud": 16,
}

static func tem(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + nome + ".png")

static func textura(nome: String) -> Texture2D:
	if not tem(nome):
		return null
	var t = load(PASTA + nome + ".png")
	return t if t is Texture2D else null

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
	var apertado := stylebox("botao_madeira_apertado")
	estilos["pressed"] = apertado if apertado != null else normal
	# hover e foco: a mesma arte, um tom mais clara / com realce
	var hover := stylebox("botao_madeira")
	if hover != null:
		hover.modulate_color = Color(1.12, 1.10, 1.02)
		estilos["hover"] = hover
	var desativado := stylebox("botao_madeira")
	if desativado != null:
		desativado.modulate_color = Color(0.62, 0.60, 0.58)
		estilos["disabled"] = desativado
	return estilos

## Relatório do que já existe — usado pelos testes e pelo resumo de build.
static func inventario() -> Dictionary:
	var tem_ := []
	var falta := []
	for nome in MARGENS.keys():
		if tem(nome):
			tem_.append(nome)
		else:
			falta.append(nome)
	return {"tem": tem_, "falta": falta}
