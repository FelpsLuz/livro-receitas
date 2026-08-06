# ============================================================
# TEMA — o sistema de design da interface, em código.
#
# A regra que organiza tudo aqui não mudou: TERRENO em degraus, TEXTO em
# três pesos, e UM acento. A ousadia mora num lugar só; o resto fica quieto.
#
# Por que escuro. Não é moda: os números coloridos — ganho, custo, alarme —
# precisam saltar, e sobre creme eles competem com o fundo. Sobre um
# terreno escuro, o verde e o terracota carregam sozinhos.
#
# Por que QUENTE e não slate frio. Azul frio é o vocabulário de painel de
# controle, de SaaS, de ferramenta. Este jogo é um reino, e a tela precisa
# parecer um salão à luz de vela, não um terminal. O calor entra nos
# NEUTROS — o cinza tem viés de umbra, não de aço — e é isso que separa
# "acolhedor" de "corporativo" sem trazer de volta textura de madeira.
#
# O pergaminho não sumiu: ele virou a cor do TEXTO. É a inversão que
# permite ficar quente sem voltar ao painel bege — creme sobre umbra em vez
# de tinta sobre creme.
#
# Por que canto RETO. Canto vivo e borda de 1px leem como instrumento e
# como livro-razão, que é o que o jogo é. Raio de canto puxaria para app de
# celular.
#
# ---- o que esta revisão acrescentou, e por quê ----
#
# A paleta estava certa e a TELA continuava parecendo protótipo. O defeito
# não era de cor: era de RITMO. Havia quatro degraus de terreno e a tela
# usava dois; havia uma fonte monoespaçada escolhida para alinhar coluna de
# preço e nenhuma coluna para alinhar; havia um espaçamento diferente em
# cada chamada, escrito à mão.
#
# Então entram três coisas que um tema de jogo de gestão precisa ter e este
# não tinha:
#
#   1. ESCALA DE ESPAÇO (E1..E6). Espaço inventado por chamada é o que faz
#      uma tela parecer montada por acidente. Seis valores, todos múltiplos
#      de 4, e nada fora deles.
#   2. DEGRAUS DE ELEVAÇÃO de verdade, com uma HAIRLINE separada da BORDA.
#      Vinte linhas de tabela separadas por borda de 1px em cor de moldura
#      viram uma grade de cadeia; separadas por hairline, viram uma tabela.
#   3. VARIANTES DE BOTÃO. Uma tela onde "Comprar 5" e "Atacar SEM casus
#      belli" têm o mesmo peso visual não hierarquiza nada. Primário é
#      latão preenchido, e existe UM por região.
# ============================================================
extends RefCounted

# ---- terreno: degraus de UMBRA, do fundo para a superfície ----
## Não são marrons: são neutros com viés quente. Saturação entre 12% e 18% —
## alta o bastante para o olho ler calor, baixa o bastante para não virar
## madeira. Acima de ~25% o painel volta a parecer tábua.
##
## O FUNDO desceu de #1a1613 para #14110f. Não é escurecer por escurecer: a
## superfície precisa se destacar do fundo sem clarear (clarear a superfície
## roubaria contraste do texto). Baixar o fundo dá o degrau de graça.
const FUNDO := Color("14110f")        # a tela por trás de tudo
const SUPERFICIE := Color("1e1a16")   # painel, aba ativa
const ELEVADO := Color("272119")      # linha de tabela, campo de entrada
const SOBRE := Color("332b22")        # hover, linha sob o cursor
const BORDA := Color("453a2e")        # moldura de painel
## A hairline é o separador DENTRO de uma lista. Ela existe porque BORDA,
## que é cor de moldura, aplicada entre vinte linhas seguidas desenha uma
## grade — e grade compete com o número que a linha carrega. Hairline
## separa sem desenhar.
const HAIRLINE := Color("2f2820")

# ---- texto: três pesos, e nenhum deles é branco puro ----
## O creme do pergaminho antigo virou a cor do TEXTO. Branco puro sobre
## escuro vibra e cansa em sessão longa; um creme levemente quente assenta
## com a umbra e mantém 13:1 de contraste sobre a superfície.
const TEXTO := Color("f0e7d8")
const TEXTO_2 := Color("b5a48c")      # rótulo, unidade, texto de apoio
const TEXTO_3 := Color("7a6b58")      # dica, desabilitado, cabeçalho de coluna

# ---- acento ----
const ACENTO := Color("e8b04b")       # latão: ouro, título, valor de destaque
const ACENTO_FORTE := Color("f5c86b") # hover
## O latão rebaixado, para preenchimento de barra e fundo de botão primário:
## latão puro num retângulo de 200px vira placa de trânsito.
const ACENTO_FUNDO := Color("8a6524")

# ---- semântico: separado do acento de propósito ----
## Cor semântica não é cor de marca. Se o ganho fosse o mesmo latão do
## título, "subiu" e "isto é um cabeçalho" leriam igual.
##
## O verde é SÁLVIA e o alarme é TERRACOTA, não menta e vermelho de alerta:
## dentro de uma paleta quente, um verde frio salta como corpo estranho.
## Cor semântica precisa de contraste de MATIZ contra o terreno, não de
## temperatura contra a paleta.
const GANHO := Color("8fbf6a")
const PERIGO := Color("d9603f")
const ATENCAO := Color("d9a441")      # nem ganho nem perigo: "olhe para isto"
## Os fundos das mesmas três, para chip e barra. Escuros o bastante para
## texto creme continuar legível por cima.
const GANHO_FUNDO := Color("2c3d22")
const PERIGO_FUNDO := Color("40201a")
const ATENCAO_FUNDO := Color("3d2f16")

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
# ESCALA DE ESPAÇO
#
# Seis valores, todos múltiplos de 4. A regra de uso:
#
#   E1  2   entre ícone e o número que ele rotula
#   E2  4   dentro de um chip
#   E3  8   entre linhas de uma lista, padding de célula
#   E4  12  padding de card, entre um rótulo e o seu grupo
#   E5  16  padding de painel, entre grupos
#   E6  24  entre SEÇÕES — o único respiro grande da tela
#
# Ter a escala num lugar só é o que impede a interface de ganhar um
# espaçamento novo a cada função que alguém escreve.
# ============================================================
const E1 := 2
const E2 := 4
const E3 := 8
const E4 := 12
const E5 := 16
const E6 := 24

## Altura de uma linha de tabela. É a constante que decide quantos itens o
## jogador vê sem rolar, e por isso ela é do TEMA e não de cada aba.
##
## Estava em 56 de altura mínima + 10 de padding + 8 de separação = 84px por
## linha: quatro mercadorias por tela num jogo cuja tela é uma lista de
## mercadorias. Em 34 cabem nove, e nenhuma informação foi cortada — o que
## saiu foi o vazio.
const LINHA_H := 34
## Linha com retrato ou ilustração: o retrato é 64 e não encolhe.
const LINHA_H_RETRATO := 60

# ============================================================
# TIPOGRAFIA — fonte de INTERFACE, não de pixel art.
#
# As duas fontes pixel saíram. A razão não é que fossem ruins — foram
# escolhidas medindo 361 candidatas, e o critério estava certo. A razão é
# que ESTE jogo é uma planilha: dez abas de tabela, preço, carga, prazo e
# moral. Fonte pixel obriga o texto inteiro a viver na grade de 960×540 e
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
const MINI := 11               # cabeçalho de COLUNA, em caixa alta espacejada
const MICRO := 12              # rótulo de aba, legenda, unidade
const CORPO := 15              # texto corrido e item de lista
const NUMERO := 16             # dígito em tabela — mono, um degrau acima
const CORPO_G := 19            # destaque dentro de um painel
const TITULO_SECAO := 22       # cabeçalho de aba
const TITULO_JOGO := 44        # tela de título, só ali

static func _fonte(arquivo: String) -> FontFile:
	var caminho := PASTA_FONTES + arquivo
	if not ResourceLoader.exists(caminho):
		return null
	var f = load(caminho)
	if not (f is FontFile):
		return null
	# Estas linhas desligavam anti-alias, hinting e posicionamento subpixel.
	# Estavam CERTAS para as fontes pixel: bitmap suavizado vira borrão, e
	# meia posição de pixel destrói a grade.
	#
	# Para uma fonte VETORIAL são exatamente o contrário. Desligar o
	# anti-alias de uma DejaVu a 15px devolve letra serrilhada — jogando
	# fora justamente o ganho do canvas_items, que existe para o texto
	# renderizar na resolução do monitor.
	#
	# HINTING_LIGHT alinha à grade vertical sem engordar a haste, que é o
	# que mantém a coluna de números regular.
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
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

# ============================================================
# FUNDO COM GRADIENTE
#
# O fundo era um ColorRect chapado, e um retângulo de 960×540 numa cor só é
# a diferença entre "escuro" e "vazio". Um gradiente vertical muito curto —
# três por cento de luminância entre o topo e a base — não é visível como
# gradiente: é visível como PROFUNDIDADE, e some assim que alguém tenta
# apontar para ele. É o truque mais barato que existe para uma tela chapada
# parar de parecer um documento e passar a parecer um espaço.
#
# Gerado como Image de 1×64 e esticado: 64 pixels de altura bastam para a
# rampa não bandear, e a textura inteira ocupa 256 bytes.
# ============================================================
static func textura_fundo() -> Texture2D:
	var alt := 64
	var img := Image.create(1, alt, false, Image.FORMAT_RGBA8)
	# o topo é um degrau ACIMA do fundo e a base um degrau abaixo: a luz
	# vem de cima, como numa sala com janela alta
	var topo := Color("1c1815")
	var base := Color("100d0b")
	for y in alt:
		img.set_pixel(0, y, topo.lerp(base, float(y) / float(alt - 1)))
	return ImageTexture.create_from_image(img)

## Vinheta: um escurecimento nos cantos, desenhado em 32×32 e esticado.
##
## Serve à mesma função do gradiente e pela mesma razão — cantos que caem
## puxam o olho para o centro, que é onde o conteúdo está. Fica em alfa
## baixo de propósito: vinheta que se percebe é vinheta demais.
static func textura_vinheta() -> Texture2D:
	var lado := 32
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var centro := Vector2(lado - 1, lado - 1) * 0.5
	var maxd := centro.length()
	for y in lado:
		for x in lado:
			var d := (Vector2(x, y) - centro).length() / maxd
			# começa a escurecer só depois de 55% do raio: o miolo fica limpo
			var a: float = clampf((d - 0.55) / 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.38))
	return ImageTexture.create_from_image(img)

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
			t.set_font_size("font_size", "Button", MICRO + 2)
			# abas também: são rótulos, não números
			t.set_font("font", "TabContainer", forte)
			t.set_font_size("font_size", "TabContainer", MICRO + 2)

	# CANTO RETO EM TUDO. `corner_radius` desenha uma curva anti-aliased: um
	# arco suavizado no canto de um painel é o mesmo crime que a fonte vetorial.
	# Aqui é ESCOLHA e não imposição da pixel art: canto vivo lê como
	# instrumento e como livro-razão, que é o que o jogo é.
	var painel := StyleBoxFlat.new()
	painel.bg_color = SUPERFICIE
	painel.border_color = BORDA
	painel.set_border_width_all(1)
	painel.set_corner_radius_all(0)
	painel.set_content_margin_all(E5)
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
	t.set_stylebox("hover", "Button", _botao(SOBRE, ACENTO, false))
	t.set_stylebox("pressed", "Button", _botao(Color("1c1712"), ACENTO, true))
	t.set_stylebox("focus", "Button", _botao(ELEVADO, ACENTO, false))
	t.set_stylebox("disabled", "Button", _botao(Color("201b17"), Color("2e271f"), false))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", ACENTO_FORTE)
	t.set_color("font_pressed_color", "Button", ACENTO)
	t.set_color("font_disabled_color", "Button", TEXTO_3)

	var entrada := StyleBoxFlat.new()
	entrada.bg_color = Color("18140f")
	entrada.border_color = BORDA
	entrada.set_border_width_all(1)
	entrada.set_corner_radius_all(0)
	entrada.content_margin_left = E4
	entrada.content_margin_right = E4
	entrada.content_margin_top = E3
	entrada.content_margin_bottom = E3
	t.set_stylebox("normal", "LineEdit", entrada)
	var entrada_foco := entrada.duplicate()
	entrada_foco.border_color = ACENTO
	t.set_stylebox("focus", "LineEdit", entrada_foco)
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("caret_color", "LineEdit", ACENTO)
	t.set_color("font_placeholder_color", "LineEdit", TEXTO_3)

	t.set_color("font_color", "Label", TEXTO)
	t.set_color("default_color", "RichTextLabel", TEXTO)

	# ---- abas ----
	# A aba ativa é a MESMA superfície do painel que ela abre: sem costura
	# entre a aba e o conteúdo, a barra deixa de parecer um menu solto. A
	# faixa de latão de 2px no topo é o que marca QUAL está aberta — e ela
	# fica no topo, e não embaixo, porque embaixo ela brigaria com a costura.
	#
	# A margem lateral é E3 e não E4, e isso é aritmética, não gosto: são DEZ
	# abas com ícone numa faixa de 944px. Com 12px de cada lado a soma passava
	# de 915 e a `TabBar` entrava em modo de rolagem — as duas últimas abas
	# (Família e Crônica) desapareciam atrás de um par de setinhas, e um jogo
	# de gestão cuja navegação inteira são as abas não pode esconder duas
	# delas. Com 8px sobra folga para a tradução mais longa.
	var aba_sel := StyleBoxFlat.new()
	aba_sel.bg_color = SUPERFICIE
	aba_sel.set_corner_radius_all(0)
	aba_sel.content_margin_left = E3
	aba_sel.content_margin_right = E3
	aba_sel.content_margin_top = E3
	aba_sel.content_margin_bottom = E3
	aba_sel.border_color = ACENTO
	aba_sel.border_width_top = 2
	var aba_normal := StyleBoxFlat.new()
	aba_normal.bg_color = FUNDO
	aba_normal.set_corner_radius_all(0)
	aba_normal.content_margin_left = E3
	aba_normal.content_margin_right = E3
	aba_normal.content_margin_top = E3
	aba_normal.content_margin_bottom = E3
	var aba_hover := aba_normal.duplicate()
	aba_hover.bg_color = ELEVADO
	t.set_stylebox("tab_selected", "TabContainer", aba_sel)
	t.set_stylebox("tab_unselected", "TabContainer", aba_normal)
	t.set_stylebox("tab_hovered", "TabContainer", aba_hover)
	t.set_color("font_selected_color", "TabContainer", TEXTO)
	t.set_color("font_unselected_color", "TabContainer", TEXTO_2)
	t.set_color("font_hovered_color", "TabContainer", ACENTO_FORTE)
	var aba_painel := painel.duplicate()
	# o conteúdo da aba encosta menos: quem dá a margem interna é o card
	aba_painel.set_content_margin_all(E4)
	t.set_stylebox("panel", "TabContainer", aba_painel)

	# barra de rolagem: a padrão da engine tem cantos arredondados e cinza de
	# sistema — no meio deste terreno ela é a última peça de "site" na tela.
	# Fina de propósito (4px de margem lateral num trilho de 12): a barra é
	# orientação, não controle — o jogador rola com a roda.
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color("100d0b")
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
		realce.bg_color = ACENTO_FUNDO
		t.set_stylebox("grabber_highlight", classe, realce)
		var apertado := polegar.duplicate()
		apertado.bg_color = ACENTO
		t.set_stylebox("grabber_pressed", classe, apertado)

	# SpinBox (a oferta ao clã) herda de LineEdit, mas o botão de setinha tem
	# estilo próprio e vinha cinza de sistema.
	t.set_stylebox("normal", "SpinBox", entrada)

	return t

## Botão chapado: preenchimento e borda, sem bisel. O apertado desce 1px —
## a única pista tátil que sobrevive ao achatamento.
static func _botao(fundo: Color, borda: Color, apertado: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = E4
	sb.content_margin_right = E4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if apertado:
		sb.content_margin_top = 7
		sb.content_margin_bottom = 5
	return sb

# ============================================================
# VARIANTES DE BOTÃO
#
# Uma tela em que "Comprar 5" e "Atacar SEM casus belli" têm exatamente o
# mesmo peso visual não hierarquiza coisa nenhuma — e era esse o estado.
# Três variantes, e a regra de uso é a parte que importa:
#
#   PRIMÁRIO  latão preenchido. UM por região da tela, no verbo que a
#             região existe para cumprir ("Passar o mês", "Nova Saga").
#   NORMAL    o padrão do tema: preenchimento elevado, borda fria.
#   FANTASMA  sem preenchimento, só texto e borda apagada. Para ação
#             secundária dentro de uma linha de tabela, onde três botões
#             sólidos por linha × dez linhas viram uma parede de caixas.
#   PERIGO    borda e texto em terracota. Guerra, exílio, independência —
#             o que não dá para desfazer.
# ============================================================
static func estilos_primario() -> Dictionary:
	var normal := _botao(ACENTO_FUNDO, ACENTO, false)
	var hover := _botao(Color("a5792c"), ACENTO_FORTE, false)
	var press := _botao(Color("6d4f1c"), ACENTO, true)
	return {"normal": normal, "hover": hover, "pressed": press,
		"focus": hover, "disabled": _botao(Color("3a2f1c"), Color("4a3d26"), false)}

static func estilos_fantasma() -> Dictionary:
	var normal := _botao(Color(0, 0, 0, 0), HAIRLINE, false)
	var hover := _botao(SOBRE, ACENTO, false)
	var press := _botao(Color("1c1712"), ACENTO, true)
	return {"normal": normal, "hover": hover, "pressed": press,
		"focus": hover, "disabled": _botao(Color(0, 0, 0, 0), Color("241f1a"), false)}

static func estilos_perigo() -> Dictionary:
	var normal := _botao(PERIGO_FUNDO, Color("6b3527"), false)
	var hover := _botao(Color("55291f"), PERIGO, false)
	var press := _botao(Color("2e1712"), PERIGO, true)
	return {"normal": normal, "hover": hover, "pressed": press,
		"focus": hover, "disabled": _botao(Color("2a1c18"), Color("38251f"), false)}

## Fundo OPACO para modal e tela de conversa. Um degrau ACIMA do painel:
## o modal precisa ler como camada nova, não como o mesmo plano.
static func estilo_modal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUPERFICIE
	# Moldura de latão de 1px, nos quatro lados. É a única coisa da interface
	# inteira contornada em latão, e é isso que a torna informação: quando
	# ela aparece, a decisão é ali e o resto da tela não responde.
	#
	# (Uma tentativa anterior punha 2px só no topo e 1px nos outros lados,
	# achando que só o topo ficaria dourado. `StyleBoxFlat` tem UMA cor de
	# borda para os quatro lados — o resultado era a mesma moldura dourada,
	# com o topo desigual sem motivo.)
	sb.border_color = ACENTO
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(E6)
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
	sb.border_color = HAIRLINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = E4
	sb.content_margin_right = E4
	sb.content_margin_top = E3
	sb.content_margin_bottom = E3
	return sb

## Card com uma barra de acento na esquerda: o item que exige atenção
## (celeiro vazio, moral em queda, cerco em curso). A barra tem 3px e mora
## na borda esquerda — nenhum outro elemento da tela usa esse lugar, então
## ela nunca é confundida com decoração.
##
## Os outros três lados vão a ZERO, e isso não é economia de traço: o
## `StyleBoxFlat` tem UMA cor de borda para os quatro lados, então pintar a
## barra esquerda de latão pintava também a moldura de 1px em volta do card
## inteiro. O resultado era um retângulo dourado fechado — que grita bem
## mais alto que a barra e some com a diferença entre "este item merece
## atenção" e "este item está selecionado". Sem os três lados, o card ainda
## se separa do painel pelo próprio preenchimento, que é um degrau acima.
static func estilo_card_marcado(cor: Color) -> StyleBoxFlat:
	var sb := estilo_card()
	sb.set_border_width_all(0)
	sb.border_width_left = 3
	sb.border_color = cor
	sb.bg_color = ELEVADO
	return sb

## A LINHA de tabela, sem card por baixo: fundo zebrado e hairline embaixo.
##
## Por que zebra e não card por item. Card por item desenha quatro bordas
## por linha; vinte linhas viram oitenta arestas, e o olho passa a contar
## caixas em vez de ler números. A zebra separa com meio por cento de
## luminância e some assim que a leitura começa — que é exatamente o que um
## separador de tabela deve fazer.
static func estilo_linha(par: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ELEVADO if par else SUPERFICIE
	sb.set_corner_radius_all(0)
	sb.border_color = HAIRLINE
	sb.border_width_bottom = 1
	sb.content_margin_left = E4
	sb.content_margin_right = E4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## Faixa de cabeçalho de tabela: mais escura que as duas cores de zebra, com
## uma hairline embaixo. Escura, e não clara, porque cabeçalho de coluna é
## RÓTULO — ele tem que ceder o brilho para o número que rotula.
static func estilo_cabecalho() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("18140f")
	sb.set_corner_radius_all(0)
	sb.border_color = BORDA
	sb.border_width_bottom = 1
	sb.content_margin_left = E4
	sb.content_margin_right = E4
	sb.content_margin_top = E2
	sb.content_margin_bottom = E2
	return sb

## A barra do HUD. Ela era nada — os números flutuavam direto sobre o fundo
## da janela, e por isso liam como legenda de debug em vez de painel de
## instrumentos. Um terreno próprio e uma borda embaixo bastam.
static func estilo_barra_hud() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUPERFICIE
	sb.set_corner_radius_all(0)
	sb.border_color = BORDA
	sb.border_width_bottom = 1
	sb.content_margin_left = E4
	sb.content_margin_right = E4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## Chip: o retângulo de fundo de um par ícone+número. `cor` é a cor
## SEMÂNTICA do chip (null = neutro) e entra como fundo rebaixado, não como
## preenchimento cheio — chip cheio de terracota no HUD grita alarme antes
## de o jogador ler o que é.
static func estilo_chip(fundo: Color = SUPERFICIE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.set_corner_radius_all(0)
	sb.content_margin_left = E3
	sb.content_margin_right = E3
	sb.content_margin_top = E2
	sb.content_margin_bottom = E2
	return sb

## O trilho de um medidor (moral, felicidade, fase de cerco).
static func estilo_medidor_trilho() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("18140f")
	sb.set_corner_radius_all(0)
	sb.border_color = HAIRLINE
	sb.set_border_width_all(1)
	return sb

## O preenchimento de um medidor, na cor que o valor merece.
static func estilo_medidor_cheio(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(0)
	return sb

## A cor de um valor 0..1 lido como SAÚDE de alguma coisa: moral, felicidade,
## celeiro. Terracota embaixo, latão no meio, sálvia em cima.
##
## Os cortes (0,35 e 0,60) não são estéticos: 35 é onde `Economia` começa a
## desertar tropa e 60 é onde o povo para de murmurar. A cor muda onde a
## MECÂNICA muda, senão ela estaria mentindo.
static func cor_de_saude(fracao: float) -> Color:
	if fracao <= 0.35:
		return PERIGO
	if fracao <= 0.60:
		return ATENCAO
	return GANHO
