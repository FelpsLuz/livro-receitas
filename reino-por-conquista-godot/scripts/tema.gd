# ============================================================
# TEMA MEDIEVAL — pergaminho, madeira e ouro, criado em código.
# ============================================================
extends RefCounted

const MADEIRA := Color("2b1d12")
const MADEIRA_CLARA := Color("4a3421")
const PERGAMINHO := Color("e8d8b0")
const PERGAMINHO_CLARO := Color("f5ecd4")
const TINTA := Color("2d1f10")
const OURO := Color("c9a227")
const SANGUE := Color("8b2635")
const VERDE := Color("3e5f3e")

# ============================================================
# TIPOGRAFIA — fonte de INTERFACE, não de pixel art.
#
# As duas fontes pixel saíram. A razão não é que fossem ruins — foram
# escolhidas medindo 361 candidatas, e o critério estava certo. A razão é
# que ESTE jogo é uma planilha: dez abas de tabela, preço, carga, prazo e
# moral. Fonte pixel obriga o texto inteiro a viver na grade de 960×270 e
# a ser ampliado com o resto, e é isso que fazia a interface parecer
# protótipo por mais bonita que a arte ficasse.
#
# Com `stretch/mode = canvas_items` (ver project.godot), o texto passa a
# renderizar na resolução REAL do monitor. Aí uma fonte vetorial de
# interface não é concessão: é a única que aproveita isso.
#
# O critério antigo sobrevive, e é o que decide o par:
#
#   · DejaVu Sans        TEXTO. Altura de x generosa, e os pares que
#                        arruínam leitura vêm resolvidos de fábrica —
#                        o "1" tem base e esporão, o "l" é reto, o "I"
#                        tem serifa. Cobre os 15 acentos do português.
#   · DejaVu Sans Mono   NÚMERO E TABELA. Monoespaçada, então a coluna de
#                        preço alinha sozinha, sem tabular-figures e sem
#                        contar caractere. Num jogo em que o jogador
#                        compara 1.240 com 980 na vertical, isso não é
#                        estética — é a leitura.
#   · DejaVu Sans Bold   TÍTULO. Mesma família: hierarquia por peso, não
#                        por troca de tipo. Duas famílias numa interface
#                        de gerenciamento já são uma a mais.
#
# Licença Bitstream Vera / DejaVu — uso comercial liberado.
# ============================================================
const PASTA_FONTES := "res://assets/fontes/"

## Escala tipográfica, em unidades da viewport base (960×540).
## Razão ~1,25 entre degraus: o suficiente para hierarquia sem degrau
## intermediário que ninguém distingue.
const MICRO := 12              # rótulo de aba, legenda, unidade
const CORPO := 15              # texto corrido e item de lista
const NUMERO := 16             # dígito em tabela — mono, um degrau acima
const CORPO_G := 19            # destaque dentro de um painel
const TITULO_SECAO := 24       # cabeçalho de aba
const TITULO_JOGO := 40        # tela de título, só ali

static func _fonte(arquivo: String) -> FontFile:
	var caminho := PASTA_FONTES + arquivo
	if not ResourceLoader.exists(caminho):
		return null
	var f = load(caminho)
	if not (f is FontFile):
		return null
	# o .import já grava isto, mas repetir aqui garante o comportamento mesmo
	# se alguém reimportar o projeto com os padrões da engine
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	f.generate_mipmaps = false
	return f

## A fonte de NÚMERO. Monoespaçada: a coluna alinha sozinha.
##
## Prosa NÃO usa esta fonte: monoespaçada em parágrafo lê como terminal.
## Só dígito, tabela e HUD.
static func fonte_numero() -> FontFile:
	return _fonte("DejaVuSansMono.ttf")

## A fonte de TEXTO. Sem serifa: numa tela de gerenciamento a serifa
## disputa atenção com o número, que é quem manda.
static func fonte_corpo() -> FontFile:
	return _fonte("DejaVuSans.ttf")

## Títulos, rótulos e botões — a mesma família do corpo, em tamanho maior.
static func fonte_forte() -> FontFile:
	return _fonte("DejaVuSans-Bold.ttf")

static func fonte_titulo() -> FontFile:
	return fonte_forte()

static func criar() -> Theme:
	var t := Theme.new()

	# ---- tipografia global ----
	var corpo := fonte_corpo()
	if corpo != null:
		t.default_font = corpo
		t.default_font_size = CORPO
		# títulos e rótulos de botão em peso forte: hierarquia sem trocar de família
		var forte := fonte_forte()
		if forte != null:
			t.set_font("font", "Button", forte)
			t.set_font_size("font_size", "Button", 16)
			# abas também: são rótulos, não números
			t.set_font("font", "TabContainer", forte)
			t.set_font_size("font_size", "TabContainer", 16)

	# CANTO RETO EM TUDO. `corner_radius` desenha uma curva anti-aliased: um
	# arco suavizado no canto de um painel é o mesmo crime que a fonte vetorial,
	# e num jogo de pixel art é o detalhe que grita "isto é CSS".
	var painel := StyleBoxFlat.new()
	painel.bg_color = PERGAMINHO
	painel.border_color = MADEIRA_CLARA
	painel.set_border_width_all(2)
	painel.set_corner_radius_all(0)
	painel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", painel)

	# Nada de StyleBoxTexture aqui. O painel é CHAPADO, em código.
	#
	# Havia uma adoção automática da moldura de textura quando ela existisse,
	# e depois do visual strip ela passou a existir SEMPRE — como caixote
	# cinza. Resultado: todo PanelContainer do jogo virou um retângulo cinza
	# por cima do pergaminho. Painel de gerenciamento não precisa de moldura
	# ilustrada; precisa de contraste e de borda fina que separe as regiões.

	# ---- botão em três estados DESENHADOS ----
	# Mudar só a cor de fundo é o que faz botão parecer HTML. O apertado desce
	# 1px e inverte a rampa de sombra: a luz que estava em cima vai para baixo,
	# que é como um botão físico se comporta e como o olho espera ler.
	t.set_stylebox("normal", "Button", _botao(Color("5d4428"), false))
	t.set_stylebox("hover", "Button", _botao(Color("77563a"), false))
	t.set_stylebox("pressed", "Button", _botao(Color("3a2a18"), true))
	t.set_stylebox("focus", "Button", _botao(Color("5d4428"), false))
	var desativado := _botao(Color("4a4038"), false)
	desativado.border_color = Color("6b5f52")
	t.set_stylebox("disabled", "Button", desativado)
	t.set_color("font_color", "Button", PERGAMINHO)
	t.set_color("font_hover_color", "Button", Color("f5ecd4"))
	t.set_color("font_pressed_color", "Button", Color("c9a227"))
	t.set_color("font_disabled_color", "Button", Color("8a7f70"))

	var entrada := StyleBoxFlat.new()
	entrada.bg_color = PERGAMINHO_CLARO
	entrada.border_color = MADEIRA_CLARA
	entrada.set_border_width_all(2)
	entrada.set_corner_radius_all(0)
	entrada.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", entrada)
	t.set_color("font_color", "LineEdit", TINTA)
	t.set_color("caret_color", "LineEdit", TINTA)
	# o texto de dica estava em cinza claro sobre creme: praticamente invisível
	t.set_color("font_placeholder_color", "LineEdit", Color("7a6a52"))

	t.set_color("font_color", "Label", TINTA)
	t.set_color("default_color", "RichTextLabel", TINTA)

	var aba_sel := StyleBoxFlat.new()
	aba_sel.bg_color = PERGAMINHO
	aba_sel.set_corner_radius_all(0)
	aba_sel.set_content_margin_all(8)
	aba_sel.border_color = OURO
	aba_sel.border_width_top = 2
	var aba_normal := StyleBoxFlat.new()
	aba_normal.bg_color = MADEIRA_CLARA
	aba_normal.set_corner_radius_all(0)
	aba_normal.set_content_margin_all(8)
	t.set_stylebox("tab_selected", "TabContainer", aba_sel)
	t.set_stylebox("tab_unselected", "TabContainer", aba_normal)
	t.set_stylebox("tab_hovered", "TabContainer", aba_normal)
	t.set_color("font_selected_color", "TabContainer", TINTA)
	t.set_color("font_unselected_color", "TabContainer", Color("d4c090"))
	var aba_painel := painel.duplicate()
	t.set_stylebox("panel", "TabContainer", aba_painel)

	# barra de rolagem: a padrão da engine tem cantos arredondados e cinza de
	# sistema — no meio de um pergaminho ela é a última peça de "site" na tela
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color("d8c69c")
	trilho.set_corner_radius_all(0)
	trilho.content_margin_left = 4
	trilho.content_margin_right = 4
	var polegar := StyleBoxFlat.new()
	polegar.bg_color = MADEIRA_CLARA
	polegar.set_corner_radius_all(0)
	polegar.content_margin_left = 4
	polegar.content_margin_right = 4
	for classe in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", classe, trilho)
		t.set_stylebox("grabber", classe, polegar)
		var realce := polegar.duplicate()
		realce.bg_color = Color("6b4f30")
		t.set_stylebox("grabber_highlight", classe, realce)
		t.set_stylebox("grabber_pressed", classe, realce)

	return t

## Um botão de três estados com rampa de sombra desenhada, não gerada por CSS.
static func _botao(fundo: Color, apertado: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = OURO
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(8)
	# a rampa: 1px claro em cima e 1px escuro embaixo — invertidos quando aperta
	sb.border_width_top = 1
	sb.border_width_bottom = 3 if not apertado else 1
	if apertado:
		# desce 1px: o conteúdo inteiro anda junto, é o que dá o "clique"
		sb.content_margin_top = 9
		sb.content_margin_bottom = 7
		sb.border_width_top = 3
	return sb

## Fundo de um CARD de lista (tropa, lorde, reino, contrato).
##
## A moldura de madeira do PixelLab é ótima para um painel grande, mas ela tem
## listras de tábua e o 9-slice as estica: numa faixa de 56px de altura as
## listras caem exatamente em cima das linhas de texto. O card usa pergaminho
## claro sobre o pergaminho da aba — separado pela borda, e legível.
## Fundo OPACO para modal e tela de conversa.
##
## `painel_madeira` é uma moldura VAZADA — o miolo tem alpha zero. Isso serve
## para emoldurar algo que já tem fundo, mas num modal deixava a aba inteira
## aparecendo através do texto. Aqui o fundo é sólido, e a moldura de madeira
## continua livre para entrar por cima quando alguém quiser.
static func estilo_modal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PERGAMINHO
	sb.border_color = OURO
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(16)
	# sem `shadow_size`: a sombra do StyleBoxFlat é um borrão gaussiano, e
	# gradiente é justamente o que não pode existir aqui. O véu escuro do modal
	# já faz o trabalho de separar do fundo.
	return sb

static func estilo_card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PERGAMINHO_CLARO
	sb.border_color = MADEIRA_CLARA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(10)
	return sb
