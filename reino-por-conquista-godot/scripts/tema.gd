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
# TIPOGRAFIA — Cinzel para o LUGAR, Spectral para o que se LÊ.
#
# ---- o defeito que este bloco corrigiu ----
#
# A versão anterior escolhia DejaVu com um critério bem escrito e um erro
# fatal embaixo: ela NUNCA carregou. O `.import` das três DejaVu apontava
# para um `.fontdata` que só o editor gera, `.godot/imported/` está vazio no
# repositório, e `load()` devolvia null em silêncio. `_fonte()` retornava
# null, `criar()` pulava o `if corpo != null`, e o jogo inteiro rodou na
# fonte embutida da engine — uma grotesca neutra de sistema.
#
# Ou seja: a tela não parecia genérica apesar da escolha de tipografia. Ela
# parecia genérica porque não havia escolha de tipografia nenhuma chegando
# na tela.
#
# A correção tem duas partes, e a segunda é a que impede a recaída:
#
#   1. carregar por BYTES (`FileAccess` + `FontFile.data`), exatamente como
#      `tex_hibit` já fazia com as texturas e pela mesma razão — `load()`
#      exige o passo de importação do editor, e `res://` vira PCK/APK no
#      build exportado. Bytes funcionam em editor, headless, CI e export.
#   2. sidecar `importer="keep"` em cada .ttf, senão o exportador substitui
#      o arquivo original pelo .fontdata e os bytes somem do pacote.
#
# ---- por que estas duas, e não uma família só ----
#
#   · Cinzel     O LUGAR e o VERBO. Capitular romana lapidar — as
#                minúsculas do desenho SÃO versaletes, então "Vale do
#                Corvo" sai em caixa alta e versalete sem uma linha de
#                OpenType. É a diferença entre um título e um rótulo.
#                Aparece em quatro lugares e em nenhum outro: nome da
#                tela, cabeçalho de seção, aba, botão primário.
#   · Spectral   TUDO QUE SE LÊ. Serifada desenhada para tela (não uma
#                Garamond de papel espremida), haste firme a 15px, e —
#                medido — algarismo TABULAR de fábrica: "1111" e "8888"
#                ocupam os mesmos 35px. A coluna de preço alinha sozinha,
#                que era o único serviço que a monoespaçada prestava.
#
# A regra que separa as duas, e que vale mais que as duas: Cinzel marca
# ONDE VOCÊ ESTÁ e O QUE A TELA FAZ. Se o texto é para ser lido — prosa,
# rótulo de linha, número, glosa — é Spectral. Uma tela onde a capitular
# invade o corpo vira convite de casamento.
#
# Ambas OFL (SIL Open Font License) — uso comercial liberado, redistribuição
# com a licença junto, que é o que os dois OFL-*.txt em assets/fontes fazem.
# ============================================================
const PASTA_FONTES := "res://assets/fontes/"

## Escala tipográfica, em unidades da viewport base (960×540).
##
## O que mudou de verdade aqui não foram os números pequenos: foi o ALCANCE.
## A escala antiga ia de 11 a 22 no jogo (o 44 só existia na tela de título),
## e uma tela cujo maior texto tem o dobro do menor não tem hierarquia — tem
## variação. Agora o nome do lugar é 30 e o número que carrega a tela é 34,
## contra 15 do corpo: a razão passa de 1,5× para ~2,3×, e é isso que faz o
## olho saber onde pousar antes de começar a ler.
const MINI := 11               # cabeçalho de COLUNA, caixa alta espacejada
const MICRO := 13              # rótulo de aba, legenda, unidade
const CORPO := 15              # texto corrido e item de lista
const NUMERO := 17             # dígito em tabela
const CORPO_G := 20            # destaque dentro de um painel
const TITULO_SECAO := 16       # cabeçalho de seção — Cinzel, caixa alta
const TITULO_TELA := 30        # o nome do lugar, no topo da aba
const NUMERO_G := 34           # O número. Um por tela, no que está em jogo.
const TITULO_JOGO := 46        # tela de título, só ali

## Cinzel é variável no eixo `wght` (400..900). O peso entra por
## `FontVariation`, e a chave do dicionário é a TAG OpenType como inteiro
## big-endian — string não é aceita, e passar "wght" falha em silêncio
## devolvendo sempre o peso 400 (medido: as quatro larguras vinham iguais).
static func _tag(s: String) -> int:
	var v := 0
	for i in 4:
		v = (v << 8) | s.unicode_at(i)
	return v

## Uma fonte carregada custa parse de um .ttf inteiro, e `fonte_forte()` é
## chamada dezesseis vezes só na montagem das abas. O cache é por arquivo.
static var _fontes: Dictionary = {}

static func _fonte(arquivo: String) -> FontFile:
	if _fontes.has(arquivo):
		return _fontes[arquivo]
	var bytes := FileAccess.get_file_as_bytes(PASTA_FONTES + arquivo)
	if bytes.is_empty():
		_fontes[arquivo] = null
		return null
	var f := FontFile.new()
	f.data = bytes
	# Anti-alias LIGADO, e isto não é descuido herdado das fontes pixel: com
	# `canvas_items` o texto rasteriza na resolução do monitor, e serrilhar
	# uma serifada a 15px joga fora exatamente esse ganho.
	#
	# HINTING_LIGHT alinha à grade vertical sem engordar a haste — numa
	# serifada, hinting cheio engrossa a serifa e a linha vira negrito falso.
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.force_autohinter = false
	f.generate_mipmaps = false
	# emoji e qualquer glifo fora do Latino caem no sistema em vez de virar
	# retângulo vazio
	f.allow_system_fallback = true
	_fontes[arquivo] = f
	return f

static var _variacoes: Dictionary = {}

## Cinzel num peso, com espacejamento opcional.
##
## `tracking` existe porque caixa alta pede ar: as capitulares têm todas a
## mesma altura e sem espaço extra entre elas "RECURSOS" vira um bloco só.
## Dois pixels a 12px são +30% de largura — medido — e é a diferença entre
## um cabeçalho e uma mancha.
static func _cinzel(peso: int, tracking: int = 0) -> Font:
	var chave := "%d/%d" % [peso, tracking]
	if _variacoes.has(chave):
		return _variacoes[chave]
	var base := _fonte("Cinzel.ttf")
	if base == null:
		_variacoes[chave] = null
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {_tag("wght"): peso}
	if tracking != 0:
		fv.spacing_glyph = tracking
	_variacoes[chave] = fv
	return fv

## A fonte de NÚMERO. Spectral SemiBold: algarismo tabular de fábrica, então
## a coluna de preço alinha sem `tnum` e sem contar caractere.
##
## O peso é escolha, não sobra: o número é a informação e o rótulo ao lado
## dele é o índice. Se os dois tivessem o mesmo peso a linha leria como
## frase, e não como medida.
static func fonte_numero() -> FontFile:
	return _fonte("Spectral-SemiBold.ttf")

## O número GRANDE — o que a tela existe para dizer. Bold, e só ele.
static func fonte_numero_g() -> FontFile:
	return _fonte("Spectral-Bold.ttf")

## A fonte de TEXTO.
static func fonte_corpo() -> FontFile:
	return _fonte("Spectral-Regular.ttf")

## Rótulo, botão comum, célula que precisa pesar mais que a vizinha.
## Medium e não Bold: entre vinte linhas de tabela, negrito em cada rótulo
## devolve a mancha que a zebra tinha acabado de resolver.
static func fonte_forte() -> FontFile:
	return _fonte("Spectral-Medium.ttf")

## O nome do lugar. Cinzel 700 com um fio de tracking.
static func fonte_titulo() -> Font:
	var f := _cinzel(700, 1)
	return f if f != null else fonte_numero_g()

## Cabeçalho de seção: Cinzel 600, bem espacejado.
static func fonte_cabecalho() -> Font:
	var f := _cinzel(600, 2)
	return f if f != null else fonte_forte()

## Rótulo de ABA. Mesmo desenho do cabeçalho, com um pixel a menos de
## espacejamento, e a razão é aritmética e não gosto: as onze abas somam
## 971px com tracking 2 numa faixa de 944, e a `TabBar` responde a isso
## escondendo as últimas atrás de um par de setinhas — num jogo cuja
## navegação inteira são as abas, perder "Crônica" e "Guerra" é perder duas
## telas. Com tracking 1 a soma cai para ~911 e sobra folga.
##
## Serve à hierarquia também: cabeçalho de seção é esparso porque tem a
## tela toda; aba é densa porque divide a faixa com outras dez.
static func fonte_aba() -> Font:
	var f := _cinzel(600, 1)
	return f if f != null else fonte_forte()

## Cabeçalho de COLUNA de tabela: o mesmo desenho, um grau mais leve, para
## ceder o brilho ao número que ele rotula.
static func fonte_coluna() -> Font:
	var f := _cinzel(500, 2)
	return f if f != null else fonte_forte()

# ============================================================
# ACERVO HI-BIT — as texturas de interface geradas (PixelLab)
#
# A leva hi-bit mora em assets/sprites/hibit/ e é OPCIONAL por peça: cada
# fábrica de estilo tenta a textura e cai no StyleBoxFlat de sempre quando
# ela não existe. É o mesmo contrato dos ícones — a UI nunca quebra por
# arte ausente, e a arte entra sem tocar em quem chama.
#
# Bytes do pacote + `load_png_from_buffer`, e não `load()` nem
# `Image.load_from_file`: o load() exige o .import gerado pelo editor (a
# leva chega por fora dele), e o load_from_file exige caminho REAL de
# sistema de arquivos — que deixa de existir quando o jogo é exportado e o
# res:// vira PCK/APK. Ler pelo filesystem virtual funciona em todos os
# modos: editor, headless, render de CI e build exportado.
# ============================================================
const PASTA_HIBIT := "res://assets/sprites/hibit/"

static var _tex_ui: Dictionary = {}

static func tex_hibit(nome: String) -> Texture2D:
	if _tex_ui.has(nome):
		return _tex_ui[nome]
	var bytes := FileAccess.get_file_as_bytes(PASTA_HIBIT + nome + ".png")
	var img := Image.new()
	if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
		_tex_ui[nome] = null
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex_ui[nome] = tex
	return tex

## StyleBoxTexture 9-slice de uma peça hi-bit; null se a arte não chegou.
static func _sbt(nome: String, margem: int, cont_h: int, cont_v: int) -> StyleBoxTexture:
	var tex := tex_hibit(nome)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin(SIDE_LEFT, margem)
	sb.set_texture_margin(SIDE_RIGHT, margem)
	sb.set_texture_margin(SIDE_TOP, margem)
	sb.set_texture_margin(SIDE_BOTTOM, margem)
	sb.content_margin_left = cont_h
	sb.content_margin_right = cont_h
	sb.content_margin_top = cont_v
	sb.content_margin_bottom = cont_v
	return sb

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

# ============================================================
# PROFUNDIDADE — por que um painel chapado lê como planilha
#
# O terreno já tinha quatro degraus de umbra e a tela continuava parecendo
# um documento. O motivo não é a cor: é que cada degrau era um retângulo de
# UMA cor só, e superfície de cor única não tem direção de luz. O olho lê
# profundidade por dois sinais, e a tela não dava nenhum dos dois:
#
#   1. a superfície é mais clara em cima do que embaixo (luz vem de cima);
#   2. a aresta de cima brilha e a de baixo escurece.
#
# `StyleBoxFlat` não faz nenhum dos dois: tem uma cor de fundo e UMA cor de
# borda para os quatro lados. Então o painel passa a ser uma textura gerada
# em código — oito por quarenta e oito pixels, esticada em 9-slice, com a
# rampa no meio e as duas arestas nas bordas que o 9-slice NÃO estica.
#
# É o mesmo truque de `textura_fundo()`, que o arquivo já usava para a tela
# inteira e nunca tinha aplicado ao painel. Custa 1,5 KB de imagem e é a
# diferença entre "escuro" e "dentro de alguma coisa".
# ============================================================
static func _textura_superficie(base: Color, topo_luz: float, borda: Color) -> ImageTexture:
	var larg := 8
	var alt := 48
	var img := Image.create(larg, alt, false, Image.FORMAT_RGBA8)
	# a rampa: um degrau acima em cima, um abaixo embaixo. Três por cento de
	# luminância — invisível como gradiente, legível como volume.
	var c_topo := base.lightened(topo_luz)
	var c_base := base.darkened(topo_luz * 0.7)
	for y in alt:
		var linha := c_topo.lerp(c_base, float(y) / float(alt - 1))
		for x in larg:
			img.set_pixel(x, y, linha)
	# arestas. A de cima é a borda CLAREADA e a de baixo a borda escurecida:
	# é o par que diz de onde vem a luz. As laterais ficam na borda pura,
	# senão o painel ganha um contorno brilhante fechado e vira botão.
	for x in larg:
		img.set_pixel(x, 0, borda.lightened(0.18))
		img.set_pixel(x, alt - 1, borda.darkened(0.35))
	for y in range(1, alt - 1):
		img.set_pixel(0, y, borda)
		img.set_pixel(larg - 1, y, borda)
	return ImageTexture.create_from_image(img)

## O painel de conteúdo, com volume. `margem_conteudo` é o respiro interno.
static func estilo_painel(margem_conteudo: int = E5) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _textura_superficie(SUPERFICIE, 0.055, BORDA)
	# 1px em cada lado fora do esticamento: é o que mantém a aresta com
	# um pixel de espessura em qualquer tamanho de painel
	for lado in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(lado, 1)
	sb.set_content_margin_all(margem_conteudo)
	return sb

## A SUPERFÍCIE REBAIXADA — o grupo dentro do painel.
##
## É a peça que faltava para a tela ter dois níveis em vez de um. O painel
## sobe, o grupo desce: um bloco de linhas de tabela dentro de um sulco lê
## como conjunto, e é assim que "Recursos e população" deixa de ser cinco
## controles soltos e passa a ser uma coisa só.
##
## Aqui a luz INVERTE — aresta escura em cima, clara embaixo. Um sulco é um
## relevo de cabeça para baixo, e trocar as duas arestas é literalmente
## tudo o que separa os dois.
static func estilo_sulco(margem_conteudo: int = E4) -> StyleBoxTexture:
	var larg := 8
	var alt := 48
	var img := Image.create(larg, alt, false, Image.FORMAT_RGBA8)
	var base := Color("191512")
	var c_topo := base.darkened(0.20)
	var c_base := base.lightened(0.06)
	for y in alt:
		var linha := c_topo.lerp(c_base, float(y) / float(alt - 1))
		for x in larg:
			img.set_pixel(x, y, linha)
	for x in larg:
		img.set_pixel(x, 0, HAIRLINE.darkened(0.45))
		img.set_pixel(x, alt - 1, HAIRLINE.lightened(0.10))
	for y in range(1, alt - 1):
		img.set_pixel(0, y, HAIRLINE)
		img.set_pixel(larg - 1, y, HAIRLINE)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	for lado in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(lado, 1)
	sb.set_content_margin_all(margem_conteudo)
	return sb

## A MOLDURA DA ARTE.
##
## A ilustração da terra é a melhor peça da tela e estava tratada como
## célula de tabela: 400×224 encostados na borda esquerda, sem moldura, sem
## sombra. `ui_painel_madeira` já existia no acervo — madeira com cantoneira
## de metal nos quatro cantos — e estava servindo só aos modais.
##
## A margem de CONTEÚDO tem que ser >= a margem de TEXTURA, e essa é a parte
## que a primeira tentativa errou: com textura 18 e conteúdo 6, o 9-slice
## desenhava 18px de madeira e a arte era posicionada 6px para dentro — ou
## seja, a ilustração cobria doze dos dezoito pixels da moldura pelos quatro
## lados, e no render sobrava um fio escuro de 6px que não parecia moldura
## nenhuma. As duas margens andam juntas.
static func estilo_moldura_arte() -> StyleBox:
	var m := _sbt("ui_painel_madeira", 20, 20, 20)
	if m != null:
		return m
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b2118")
	sb.border_color = Color("6b512f")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(4)
	return sb

static func criar() -> Theme:
	var t := Theme.new()

	# ---- tipografia global ----
	var corpo := fonte_corpo()
	if corpo != null:
		t.default_font = corpo
		t.default_font_size = CORPO
		var forte := fonte_forte()
		if forte != null:
			t.set_font("font", "Button", forte)
			t.set_font_size("font_size", "Button", MICRO)
		# A aba é o único rótulo de NAVEGAÇÃO da tela: ela não diz o que
		# você faz, diz onde você está. Por isso é a capitular, e por isso
		# ela é a única peça do tema que troca de família.
		var aba_fonte := fonte_aba()
		if aba_fonte != null:
			t.set_font("font", "TabContainer", aba_fonte)
			t.set_font_size("font_size", "TabContainer", MICRO)

	# CANTO RETO EM TUDO. `corner_radius` desenha uma curva anti-aliased: um
	# arco suavizado no canto de um painel é o mesmo crime que a fonte vetorial.
	# Aqui é ESCOLHA e não imposição da pixel art: canto vivo lê como
	# instrumento e como livro-razão, que é o que o jogo é.
	var painel := estilo_painel(E5)
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
	# hi-bit: o botão padrão vira PEDRA lavrada; os estados saem por
	# modulate da MESMA textura (hover clareia, apertado escurece e desce
	# 1px — a pista tátil de sempre, agora na pedra)
	var b_pedra := _sbt("ui_botao_pedra", 12, E4, 5)
	if b_pedra != null:
		t.set_stylebox("normal", "Button", b_pedra)
		var b_hover: StyleBoxTexture = b_pedra.duplicate()
		b_hover.modulate_color = Color(1.18, 1.16, 1.10)
		t.set_stylebox("hover", "Button", b_hover)
		var b_press: StyleBoxTexture = b_pedra.duplicate()
		b_press.modulate_color = Color(0.78, 0.76, 0.72)
		b_press.content_margin_top = 6
		b_press.content_margin_bottom = 4
		t.set_stylebox("pressed", "Button", b_press)
		t.set_stylebox("focus", "Button", b_hover)
		var b_off: StyleBoxTexture = b_pedra.duplicate()
		b_off.modulate_color = Color(0.55, 0.54, 0.52)
		t.set_stylebox("disabled", "Button", b_off)
	else:
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
	# hi-bit: cada aba é uma PLAQUETA de pedra; a ativa clareia (como na
	# referência, onde "Sua Terra" acende) e o texto dela escurece para
	# continuar legível sobre a pedra clara
	var placa := _sbt("ui_placa_pedra", 10, E3, 4)
	if placa != null:
		var placa_sel: StyleBoxTexture = placa.duplicate()
		placa_sel.modulate_color = Color(1.30, 1.24, 1.02)
		var placa_hover: StyleBoxTexture = placa.duplicate()
		placa_hover.modulate_color = Color(1.2, 1.18, 1.12)
		t.set_stylebox("tab_selected", "TabContainer", placa_sel)
		t.set_stylebox("tab_unselected", "TabContainer", placa)
		t.set_stylebox("tab_hovered", "TabContainer", placa_hover)
		t.set_color("font_selected_color", "TabContainer", TEXTO)
		t.set_color("font_unselected_color", "TabContainer", TEXTO_2)
		t.set_color("font_hovered_color", "TabContainer", TEXTO)
	else:
		t.set_stylebox("tab_selected", "TabContainer", aba_sel)
		t.set_stylebox("tab_unselected", "TabContainer", aba_normal)
		t.set_stylebox("tab_hovered", "TabContainer", aba_hover)
		t.set_color("font_selected_color", "TabContainer", TEXTO)
		t.set_color("font_unselected_color", "TabContainer", TEXTO_2)
		t.set_color("font_hovered_color", "TabContainer", ACENTO_FORTE)
	# o painel da aba fica CHAPADO mesmo na leva hi-bit: a moldura de
	# madeira aqui virava uma faixa clara solta entre as abas e o conteúdo
	# (só o topo dela aparecia). A madeira tem escala nos MODAIS.
	# o conteúdo da aba encosta menos: quem dá a margem interna é o card
	t.set_stylebox("panel", "TabContainer", estilo_painel(E4))

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
#             região existe para cumprir ("Passar o dia", "Nova Saga").
#   NORMAL    o padrão do tema: preenchimento elevado, borda fria.
#   FANTASMA  sem preenchimento, só texto e borda apagada. Para ação
#             secundária dentro de uma linha de tabela, onde três botões
#             sólidos por linha × dez linhas viram uma parede de caixas.
#   PERIGO    borda e texto em terracota. Guerra, exílio, independência —
#             o que não dá para desfazer.
# ============================================================
static func estilos_primario() -> Dictionary:
	# hi-bit: o primário é o BOTÃO DOURADO da referência
	var ouro := _sbt("ui_botao_dourado", 11, E4, 6)
	if ouro != null:
		var o_hover: StyleBoxTexture = ouro.duplicate()
		o_hover.modulate_color = Color(1.15, 1.13, 1.05)
		var o_press: StyleBoxTexture = ouro.duplicate()
		o_press.modulate_color = Color(0.8, 0.78, 0.72)
		o_press.content_margin_top = 6
		o_press.content_margin_bottom = 4
		var o_off: StyleBoxTexture = ouro.duplicate()
		o_off.modulate_color = Color(0.55, 0.55, 0.52)
		return {"normal": ouro, "hover": o_hover, "pressed": o_press,
			"focus": o_hover, "disabled": o_off}
	var normal := _botao(ACENTO_FUNDO, ACENTO, false)
	var hover := _botao(Color("a5792c"), ACENTO_FORTE, false)
	var press := _botao(Color("6d4f1c"), ACENTO, true)
	return {"normal": normal, "hover": hover, "pressed": press,
		"focus": hover, "disabled": _botao(Color("3a2f1c"), Color("4a3d26"), false)}

## O PERGAMINHO CLARO da referência — banner de aviso com texto ESCURO.
## Quem o usa é responsável por trocar a cor do texto: pergaminho é o único
## terreno claro da interface, e creme sobre creme não se lê.
static func estilo_pergaminho() -> StyleBox:
	# margens ASSIMÉTRICAS: os rolos laterais do pergaminho têm ~22px e não
	# podem esticar; as bordas de cima e de baixo são papel e aceitam 12
	var sb := _sbt("ui_pergaminho", 22, E5 + 8, E3)
	if sb != null:
		sb.set_texture_margin(SIDE_TOP, 12)
		sb.set_texture_margin(SIDE_BOTTOM, 12)
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("e8dcc0")
	flat.border_color = Color("b8a888")
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(0)
	flat.content_margin_left = E5
	flat.content_margin_right = E5
	flat.content_margin_top = E3
	flat.content_margin_bottom = E3
	return flat

## A tinta que escreve sobre o pergaminho.
const TINTA_PERGAMINHO := Color("2e2418")
const TINTA_PERGAMINHO_2 := Color("5a4a34")

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
static func estilo_modal() -> StyleBox:
	# hi-bit: o modal é um painel de MADEIRA — a moldura que a referência
	# usa nos painéis internos, com margem generosa de decisão
	var madeira := _sbt("ui_painel_madeira", 20, E6, E5)
	if madeira != null:
		return madeira
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
##
## O respiro vertical continua em 6, e uma tentativa de subi-lo para E3 foi
## revertida: 2px por lado × duas dezenas de linhas custam duas mercadorias
## por tela na Feira, e a descendente da serifada — que era o motivo — cabe
## nos 6 sem encostar na linha seguinte. Medido no render, não estimado.
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

## Chip: o retângulo de fundo de um par ícone+número. Na leva hi-bit ele é
## a PLACA DE PEDRA da referência; sem a arte, o retângulo chapado de
## sempre. `cor` semântica entra como fundo rebaixado só no modo chapado —
## a placa de pedra alarma pelo NÚMERO terracota, não pelo terreno.
static func estilo_chip(fundo: Color = SUPERFICIE) -> StyleBox:
	var pedra := _sbt("ui_placa_pedra", 10, E3, 3)
	if pedra != null and fundo == ELEVADO:
		return pedra
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
