# ============================================================
# TEMA — interface de gerenciamento, chapada, em código.
#
# O tema anterior era pergaminho, madeira e ouro: bonito de descrever e
# errado para o que esta tela é. Um jogo de gerenciamento passa a partida
# inteira em tabela — preço, carga, prazo, moral — e textura de madeira
# atrás de número é ruído competindo com o dado.
#
# A regra que organiza tudo aqui: TERRENO em quatro degraus de um slate
# frio, TEXTO em três pesos, e UM acento quente. A ousadia mora num lugar
# só; o resto fica quieto. Um latão sobre slate lê como moeda sem precisar
# de tábua nem de rebite.
#
# Por que escuro. Não é moda: é que os números coloridos — ganho, custo,
# alarme — precisam saltar, e sobre creme eles competem com o fundo. Sobre
# slate, o verde e o terracota carregam sozinhos.
#
# Por que canto RETO. Antes era imposição da pixel art (curva anti-aliased
# no canto de um painel gritava "isto é CSS"). A pixel art saiu, então
# agora é ESCOLHA: canto vivo e borda de 1px leem como instrumento e como
# livro-razão, que é o que o jogo é. Raio de canto puxaria para app de
# celular.
# ============================================================
extends RefCounted

# ---- terreno: quatro degraus, do fundo para a superfície ----
const FUNDO := Color("12151a")        # a tela por trás de tudo
const SUPERFICIE := Color("1b2027")   # painel, aba ativa
const ELEVADO := Color("232a33")      # linha de tabela, campo de entrada
const BORDA := Color("333c48")        # separador de 1px

# ---- texto: três pesos, e nenhum deles é branco puro ----
## Branco puro sobre escuro vibra e cansa em sessão longa. Um off-white
## levemente frio assenta com o slate e mantém 13:1 de contraste.
const TEXTO := Color("e4e9ef")
const TEXTO_2 := Color("98a3b0")      # rótulo, unidade, texto de apoio
const TEXTO_3 := Color("5f6b79")      # dica, desabilitado

# ---- acento: o ÚNICO quente da paleta ----
const ACENTO := Color("e0a93b")       # latão: ouro, título, valor de destaque
const ACENTO_FORTE := Color("f0c060") # hover

# ---- semântico: separado do acento de propósito ----
## Cor semântica não é cor de marca. Se o ganho fosse o mesmo latão do
## título, "subiu" e "isto é um cabeçalho" leriam igual.
const GANHO := Color("57b98b")
const PERIGO := Color("e0664a")

# ---- nomes antigos, mantidos como APELIDO ----
## Doze pontos fora deste arquivo ainda os citam. Apontam para o papel
## certo no vocabulário novo, não para a cor antiga.
const MADEIRA := FUNDO
const MADEIRA_CLARA := BORDA
const PERGAMINHO := TEXTO
const PERGAMINHO_CLARO := ELEVADO
const TINTA := TEXTO
const OURO := ACENTO
const SANGUE := PERIGO
const VERDE := GANHO

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
	painel.bg_color = SUPERFICIE
	painel.border_color = BORDA
	painel.set_border_width_all(1)
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

	# ---- botão CHAPADO, estado por preenchimento ----
	# A versão anterior desenhava uma rampa de sombra: 1px claro em cima,
	# 3px escuro embaixo, invertidos ao apertar. Isso é skeuomorfismo — um
	# botão físico —, e num tema chapado ele é a peça que denuncia que o
	# resto foi só recolorido. Aqui o estado vem do PREENCHIMENTO, e o
	# apertado ainda desce 1px: o deslocamento é a única pista tátil que
	# sobrevive ao achatamento, e sem ela o clique não confirma nada.
	t.set_stylebox("normal", "Button", _botao(ELEVADO, BORDA, false))
	t.set_stylebox("hover", "Button", _botao(Color("2e3742"), ACENTO, false))
	t.set_stylebox("pressed", "Button", _botao(Color("1a1f26"), ACENTO, true))
	var foco := _botao(ELEVADO, ACENTO, false)
	t.set_stylebox("focus", "Button", foco)
	t.set_stylebox("disabled", "Button", _botao(Color("1d2229"), Color("2a323b"), false))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", ACENTO_FORTE)
	t.set_color("font_pressed_color", "Button", ACENTO)
	t.set_color("font_disabled_color", "Button", TEXTO_3)

	var entrada := StyleBoxFlat.new()
	entrada.bg_color = ELEVADO
	entrada.border_color = BORDA
	entrada.set_border_width_all(1)
	entrada.set_corner_radius_all(0)
	entrada.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", entrada)
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("caret_color", "LineEdit", ACENTO)
	t.set_color("font_placeholder_color", "LineEdit", TEXTO_3)

	t.set_color("font_color", "Label", TEXTO)
	t.set_color("default_color", "RichTextLabel", TEXTO)

	var aba_sel := StyleBoxFlat.new()
	# a aba ativa é a MESMA superfície do painel que ela abre: sem costura
	# entre a aba e o conteúdo, a barra deixa de parecer um menu solto
	aba_sel.bg_color = SUPERFICIE
	aba_sel.set_corner_radius_all(0)
	aba_sel.set_content_margin_all(8)
	aba_sel.border_color = ACENTO
	aba_sel.border_width_top = 2
	var aba_normal := StyleBoxFlat.new()
	aba_normal.bg_color = FUNDO
	aba_normal.set_corner_radius_all(0)
	aba_normal.set_content_margin_all(8)
	t.set_stylebox("tab_selected", "TabContainer", aba_sel)
	t.set_stylebox("tab_unselected", "TabContainer", aba_normal)
	t.set_stylebox("tab_hovered", "TabContainer", aba_normal)
	t.set_color("font_selected_color", "TabContainer", TEXTO)
	t.set_color("font_unselected_color", "TabContainer", TEXTO_2)
	var aba_painel := painel.duplicate()
	t.set_stylebox("panel", "TabContainer", aba_painel)

	# barra de rolagem: a padrão da engine tem cantos arredondados e cinza de
	# sistema — no meio de um pergaminho ela é a última peça de "site" na tela
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = FUNDO
	trilho.set_corner_radius_all(0)
	trilho.content_margin_left = 4
	trilho.content_margin_right = 4
	var polegar := StyleBoxFlat.new()
	polegar.bg_color = BORDA
	polegar.set_corner_radius_all(0)
	polegar.content_margin_left = 4
	polegar.content_margin_right = 4
	for classe in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", classe, trilho)
		t.set_stylebox("grabber", classe, polegar)
		var realce := polegar.duplicate()
		realce.bg_color = ACENTO
		t.set_stylebox("grabber_highlight", classe, realce)
		t.set_stylebox("grabber_pressed", classe, realce)

	return t

## Botão chapado: preenchimento e borda, sem bisel. O apertado desce 1px —
## a única pista tátil que sobrevive ao achatamento.
static func _botao(fundo: Color, borda: Color, apertado: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(8)
	if apertado:
		sb.content_margin_top = 9
		sb.content_margin_bottom = 7
	return sb

## Fundo OPACO para modal e tela de conversa. Um degrau ACIMA do painel:
## o modal precisa ler como camada nova, não como o mesmo plano.
static func estilo_modal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ELEVADO
	sb.border_color = ACENTO
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(16)
	# sem `shadow_size`: a sombra do StyleBoxFlat é um borrão gaussiano, e
	# borrão numa interface chapada é a peça que não pertence. O véu escuro
	# do modal já separa do fundo.
	return sb

## Card de linha de tabela. Um degrau acima da superfície, com borda fina —
## é a borda, e não o preenchimento, que faz vinte linhas seguidas ainda
## lerem como vinte itens.
static func estilo_card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ELEVADO
	sb.border_color = BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(10)
	return sb
