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
# TIPOGRAFIA — o erro mais barulhento que o jogo tinha.
#
# A fonte padrão da Godot é vetorial e anti-aliased: cada letra saía com
# gradiente na borda, ao lado de arte onde cada pixel foi colocado à mão. Não
# existe quantidade de arte boa que sobreviva a isso — é o primeiro frame que
# o jogador vê, e nele já dava para saber que era um protótipo web.
#
# Duas fontes, e a divisão entre elas NÃO é estética — é consequência de
# medida. `ferramentas/testar_fontes.py` comparou os 45 pares de dígitos de
# 361 candidatas, pixel a pixel. A tabela inteira está em ferramentas/FONTES.md.
#
#   · XGA-AI 12x20  — NÚMEROS e corpo denso. Melhor separação de dígitos
#                     medida no lote: IoU do pior par 61%, seis pontos abaixo
#                     da segunda colocada. Grade 20 → nítida em 20 e 40.
#   · ToshibaTxL1   — TÍTULOS e rótulos. Serifada de verdade (flare 5,0 na
#                     haste do "I", contra 1,0 de uma sem serifa) e a melhor
#                     nos pares que arruínam um título: E/C 60%, N/M 53%.
#                     Grade 16 → nítida em 16, 32, 48.
#
# Os dígitos da ToshibaTxL1 são ruins (8/9 a 92% de identidade), e é por isso
# que NÚMERO NENHUM usa esta fonte. As duas anteriores caíram exatamente aqui:
# a Pixelify Sans tinha 21 pares de dígitos acima do teto — "custo 20" lendo
# como "custo 80" não era azar, era o esperado — e a Jacquard 12 punha E/C a
# 96%, que é "REINO POR CONQUISTA" virando "RCIND PVR CVNQVISTA".
#
# Ambas cobrem os 15 acentos do português, incluindo Ç e Õ maiúsculos.
# Ultimate Oldschool PC Font Pack (VileR), CC BY-SA 4.0.
# ============================================================
const PASTA_FONTES := "res://assets/fontes/"
## Tamanhos em que cada fonte é NÍTIDA — múltiplos inteiros da grade nativa.
## Fonte pixel em tamanho intermediário vira borrão, e aí não se corrigiu
## nada: só se trocou o tipo de borrão.
const CORPO := 20              # grade 20 da XGA-AI
const CORPO_G := 40            # 2× — destaque do HUD
const TITULO_SECAO := 32       # 2× da grade 16 — título maior que o corpo
const TITULO_JOGO := 32        # 2×

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

## Corpo e — principalmente — NÚMEROS.
static func fonte_corpo() -> FontFile:
	return _fonte("PxPlus_IBM_XGA-AI_12x20.ttf")

## Títulos, rótulos e botões: a serifada. Nunca para número.
static func fonte_forte() -> FontFile:
	return _fonte("PxPlus_ToshibaTxL1_8x16.ttf")

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

	# OVERHAUL v2: se a moldura Pro do PixelLab existir, ela substitui o painel
	# chapado em TODA a interface de uma vez (StyleBoxTexture com 9-slice, então
	# os cantos não deformam). Sem o PNG, segue valendo o StyleBoxFlat acima.
	var UIv2 = load("res://scripts/ui_v2.gd")
	var moldura = UIv2.stylebox("painel_madeira")
	if moldura != null:
		t.set_stylebox("panel", "PanelContainer", moldura)
		t.set_stylebox("panel", "Panel", moldura)
	# NÃO chamamos UIv2.estilos_botao() aqui. Ele existia e era sobrescrito
	# quatro linhas abaixo — o botão de madeira do PixelLab nunca chegou a
	# aparecer uma vez sequer. E é melhor assim: `botao_madeira.png` mede 76%
	# de saturação média, o pior ativo de UI do pacote, e a moldura dele é
	# vazada. O botão desenhado abaixo é opaco, dessaturado e tem os três
	# estados de verdade.

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
