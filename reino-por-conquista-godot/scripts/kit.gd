# ============================================================
# KIT — os componentes da interface.
#
# Por que este arquivo existe.
#
# A tela de gestão era montada com `Label` cru e `HBoxContainer` cru, e o
# resultado tinha um defeito estrutural que nenhuma cor conserta: NÃO HAVIA
# COLUNA. Uma linha do mercado era a string
#
#     "Trigo — 10 · carga: 0"
#
# jogada num Label que expandia até empurrar os botões para a direita. Medido
# na imagem renderizada: 481 pixels contíguos de vazio no meio de uma linha
# de 910 — 53% da linha era nada. E como o preço não era uma coluna, a fonte
# monoespaçada que o tema escolheu justamente para alinhar preço não tinha o
# que alinhar. O jogo tinha a tipografia certa para uma tabela que ele nunca
# desenhou.
#
# O kit desenha essa tabela. `tabela()` recebe a especificação das colunas
# uma vez, `linha()` devolve as células já medidas, e nenhuma aba volta a
# escolher larguras à mão.
#
# A outra metade do arquivo são as peças que faltavam por completo:
# MEDIDOR (moral, felicidade, cerco — um jogo de gestão sem barra de estado
# obriga a ler número para saber se algo vai mal), CHIP, DELTA (o ±n
# colorido) e as variantes de botão.
#
# Regra da casa: nada aqui inventa espaçamento. Todo número de espaço vem da
# escala `Tema.E1..E6`.
# ============================================================
extends RefCounted

const Tema = preload("res://scripts/tema.gd")
const Icones = preload("res://scripts/icones.gd")

# ---- alinhamento de coluna, na notação curta que a spec usa ----
const ESQ := "e"
const DIR := "d"
const CENTRO := "c"


# ============================================================
# TEXTO
# ============================================================

## Cabeçalho de SEÇÃO: o latão, a régua embaixo, e nada mais.
##
## A régua não é decoração. Sem ela, um título de seção no meio de uma aba
## rolada lê como mais uma linha de texto em cor diferente; com ela, o olho
## acha onde a seção anterior terminou sem precisar de 24px de vazio.
static func secao(c: Container, titulo: String, apoio: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E2)
	c.add_child(v)
	var l := Label.new()
	# O texto entra como foi escrito, em caixa mista, e sai em CAIXA ALTA E
	# VERSALETE — as minúsculas do Cinzel são versaletes de desenho. Nada de
	# `.to_upper()`: caixa alta chapada dá a todas as letras a mesma altura e
	# o cabeçalho vira uma barra; com versalete, a inicial ainda marca onde a
	# palavra começa.
	l.text = titulo
	var f := Tema.fonte_cabecalho()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l.add_theme_color_override("font_color", Tema.ACENTO)
	v.add_child(l)
	if apoio != "":
		var s := Label.new()
		s.text = apoio
		s.add_theme_font_size_override("font_size", Tema.MICRO)
		s.add_theme_color_override("font_color", Tema.TEXTO_2)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	v.add_child(regua())
	return v

## Cabeçalho de SUBSEÇÃO: caixa alta, pequeno, apagado, espacejado.
##
## Um jogo de gestão tem hierarquia demais para dois níveis. "Quartel" é
## seção; "Exércitos em marcha" dentro dela é subseção — e usar o mesmo
## latão de 22px nos dois achatava a árvore inteira, que era o estado
## anterior. Caixa alta pequena hierarquiza sem gastar tamanho.
## O espacejamento saiu do `" ".join(...)`. Aquilo inseria um ESPAÇO DE
## VERDADE entre cada caractere — o que dá quebra de linha no meio da
## palavra, quebra busca e seleção, e espaça igual entre "AV" e "II" quando
## os dois pares pedem ajustes opostos. Agora quem espaceja é a fonte
## (`spacing_glyph`), que é onde isso mora.
static func subsecao(c: Container, titulo: String) -> Label:
	var l := Label.new()
	l.text = titulo
	var f := Tema.fonte_coluna()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", Tema.MINI)
	l.add_theme_color_override("font_color", Tema.TEXTO_3)
	c.add_child(l)
	return l

## Uma régua de 1px. É o separador mais barato que existe e o mais
## subutilizado: hairline, não borda.
static func regua(cor: Color = Tema.HAIRLINE) -> Control:
	var r := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(0)
	r.add_theme_stylebox_override("panel", sb)
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

## Parágrafo de corpo.
static func texto(c: Container, txt: String, cor: Color = Tema.TEXTO,
		tamanho: int = Tema.CORPO) -> Label:
	var l := Label.new()
	l.text = txt
	# quebrar linha numa COLUNA é o certo; numa LINHA é desastre. Num HBox o
	# label com autowrap encolhe até a largura da maior palavra e desce em
	# coluna de letras, esticando o card inteiro junto.
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if c is HBoxContainer \
		else TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	l.add_theme_font_size_override("font_size", tamanho)
	c.add_child(l)
	return l

## Texto de apoio: menor e apagado. Regra, glosa, unidade, "por mês".
static func nota(c: Container, txt: String) -> Label:
	return texto(c, txt, Tema.TEXTO_2, Tema.MICRO)

## Número. SEMPRE no algarismo tabular do Spectral — é o contrato que faz a
## coluna alinhar sem monoespaçada e sem `tnum`.
##
## `id` liga o movimento: com um identificador estável, o número CORRE do
## valor anterior até o novo em vez de trocar de golpe. Só faz sentido em
## número que muda por ação do jogador (ouro, celeiro, moral) — o preço de
## uma linha de mercado que some e volta com outro nome animaria lixo.
static func numero(c: Container, txt: String, cor: Color = Tema.TEXTO,
		tamanho: int = Tema.NUMERO, id: String = "") -> Label:
	var l := Label.new()
	l.text = txt
	var f := Tema.fonte_numero()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	if id != "" and txt.is_valid_int():
		correr(l, id, int(txt))
	return l

## O NOME DO LUGAR — o maior texto da aba, e o único que não é informação.
##
## O que ele conserta: o título da aba estava no mesmo latão de 22px que
## todo cabeçalho de seção usa, e por isso "Vale do Corvo — Burgo" lia como
## mais uma seção da tela em vez de dizer ONDE o jogador está. Aqui ele sobe
## para 30 na capitular e ganha uma régua de latão embaixo.
##
## A régua vai a 2px e em latão (a de seção tem 1px e é hairline): é o único
## traço colorido da tela e serve de linha de base para o título, que sem ela
## flutuaria sobre a ilustração.
static func titulo_tela(c: Container, txt: String, apoio: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(v)
	var l := Label.new()
	l.text = txt
	var f := Tema.fonte_titulo()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", Tema.TITULO_TELA)
	l.add_theme_color_override("font_color", Tema.ACENTO)
	# nome de lugar longo encolhe em vez de estourar a coluna: "Fortaleza do
	# Passo Alto — Cidade Murada" mede 560px em Cinzel 30 e a coluna tem 440
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	v.add_child(l)
	if apoio != "":
		var s := Label.new()
		s.text = apoio
		s.add_theme_font_size_override("font_size", Tema.MICRO)
		s.add_theme_color_override("font_color", Tema.TEXTO_2)
		v.add_child(s)
	var r := regua(Tema.ACENTO_FUNDO)
	r.custom_minimum_size = Vector2(0, 2)
	v.add_child(r)
	return v

## O GRUPO REBAIXADO. Devolve a coluna onde o conteúdo entra.
##
## É o segundo nível de profundidade que a tela não tinha: o painel sobe, o
## sulco desce, e um bloco de linhas dentro dele lê como UMA coisa em vez de
## cinco controles empilhados por acaso.
static func sulco(c: Container, margem: int = Tema.E4, sep: int = Tema.E3) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.estilo_sulco(margem))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	p.add_child(v)
	return v

## A ILUSTRAÇÃO, EMOLDURADA. Devolve a moldura — quem chama põe a arte
## dentro, seja um TextureRect ou o SubViewport da vila.
##
## A arte é a melhor peça da tela e estava num retângulo de 1px encostado na
## borda esquerda. `ui_painel_madeira` — madeira com cantoneira de metal —
## já existia no acervo servindo só aos modais.
static func moldura_arte(c: Container) -> PanelContainer:
	var m := PanelContainer.new()
	m.add_theme_stylebox_override("panel", Tema.estilo_moldura_arte())
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(m)
	return m

# ============================================================
# O NÚMERO QUE CARREGA A TELA
#
# Toda aba deste jogo tem UM número que é a razão de ela existir, e até aqui
# ele aparecia com o mesmo peso dos outros. Na Terra são os homens em armas
# contra o que a terra sustenta: 182 de 200 significa que faltam dezoito
# para o recrutamento começar a recusar — e isso estava distribuído em duas
# linhas de tabela idênticas, uma na primeira posição e outra na quarta, com
# a mesma fonte e o mesmo tamanho do imposto.
#
# O jogador descobria o teto quando o botão de recrutar falhava.
#
# `destaque` é a peça que junta os dois: valor sobre teto, num tamanho que
# não se confunde com linha de tabela, com a barra logo abaixo e a folga
# escrita por extenso.
# ============================================================
static func destaque(c: Container, rotulo: String, valor: int, teto: int,
		cor: Color, glosa: String = "", id: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(v)

	var r := Label.new()
	r.text = rotulo
	var f_r := Tema.fonte_coluna()
	if f_r != null:
		r.add_theme_font_override("font", f_r)
	r.add_theme_font_size_override("font_size", Tema.MINI)
	r.add_theme_color_override("font_color", Tema.TEXTO_3)
	v.add_child(r)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E2)
	v.add_child(h)
	var grande := Label.new()
	grande.text = str(valor)
	var f_g := Tema.fonte_numero_g()
	if f_g != null:
		grande.add_theme_font_override("font", f_g)
	grande.add_theme_font_size_override("font_size", Tema.NUMERO_G)
	grande.add_theme_color_override("font_color", cor)
	h.add_child(grande)
	# o teto entra apagado e alinhado pela BASE: "182" e "/ 200" no mesmo
	# tamanho seriam dois números concorrendo, e o que está em jogo é o 182
	var t_l := Label.new()
	t_l.text = "/ %d" % teto
	var f_t := Tema.fonte_numero()
	if f_t != null:
		t_l.add_theme_font_override("font", f_t)
	t_l.add_theme_font_size_override("font_size", Tema.CORPO_G)
	t_l.add_theme_color_override("font_color", Tema.TEXTO_3)
	t_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	t_l.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(t_l)

	var barra := medidor(v, valor, maxf(1, teto), 0, 8, cor)
	if glosa != "":
		var g := Label.new()
		g.text = glosa
		g.add_theme_font_size_override("font_size", Tema.MICRO)
		g.add_theme_color_override("font_color", Tema.TEXTO_2)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(g)
	if id != "":
		correr(grande, id, valor, barra)
	return v

# ============================================================
# MOVIMENTO
#
# A tela inteira era estática, e metade do que separa "planilha" de "jogo"
# é isto: quando o dia passa e o celeiro cai de 260 para 244, o número que
# TROCA sem avisar não é lido — o jogador vê 244 e não sabe que perdeu 16.
# O número que CORRE de um valor ao outro conta a história sozinho.
#
# A dificuldade é que `atualizar()` reconstrói a aba do zero a cada refresh:
# o Label é um nó novo, sem memória do que exibia. Por isso o valor anterior
# mora aqui, num dicionário estático indexado por um `id` estável — e a
# primeira montagem, que não tem anterior, não anima nada (senão a tela
# abriria com onze números subindo de zero).
# ============================================================
const DURACAO_CORRIDA := 0.45

static var _ultimos: Dictionary = {}

## Esquece os valores anteriores. Vai no carregamento de save e no início de
## partida: sem isso, entrar num save com 3872 de ouro depois de outro com 40
## faria o número escalar a tela inteira sem nada ter acontecido.
static func esquecer_valores() -> void:
	_ultimos.clear()

static func correr(l: Label, id: String, valor: int, barra: ProgressBar = null) -> void:
	var anterior: int = int(_ultimos.get(id, valor))
	_ultimos[id] = valor
	if anterior == valor or not l.is_inside_tree():
		return
	var tw := l.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(x: float): l.text = str(roundi(x)),
		float(anterior), float(valor), DURACAO_CORRIDA)
	if barra != null:
		# a barra corre junto e no mesmo tempo: número e barra que discordam
		# por meio segundo leem como dois dados diferentes
		var tb := barra.create_tween()
		tb.set_ease(Tween.EASE_OUT)
		tb.set_trans(Tween.TRANS_CUBIC)
		tb.tween_property(barra, "value", float(valor), DURACAO_CORRIDA) \
			.from(clampf(float(anterior), 0.0, barra.max_value))

## O ±n colorido. Sálvia sobe, terracota desce, e o zero fica apagado em vez
## de verde — "não mudou" não é uma boa notícia, é ausência de notícia.
static func delta(c: Container, n: int, sufixo: String = "") -> Label:
	var txt := ("+%d" % n) if n > 0 else str(n)
	var cor := Tema.TEXTO_3
	if n > 0:
		cor = Tema.GANHO
	elif n < 0:
		cor = Tema.PERIGO
	return numero(c, txt + sufixo, cor, Tema.MICRO + 1)


# ============================================================
# TABELA
#
# `colunas` é um Array de Dictionary:
#
#   {"t": "Preço", "w": 90, "a": DIR}
#
#     t  o rótulo do cabeçalho ("" = coluna sem rótulo, p.ex. o ícone)
#     w  largura fixa em px. 0 = a coluna que ESTICA (só uma por tabela)
#     a  alinhamento: ESQ (padrão), DIR para número, CENTRO para ícone
#
# Números vão em coluna com `a: DIR`. Alinhar dígito à direita não é gosto:
# é o que põe a casa das centenas em cima da casa das centenas quando o
# jogador compara 1.240 com 980 na vertical.
# ============================================================

## O cabeçalho. Devolve o VBox onde as linhas entram — as linhas precisam ser
## irmãs do cabeçalho e coladas nele, sem separação, ou a zebra ganha frestas.
static func tabela(c: Container, colunas: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(v)

	# só desenha a faixa se ALGUMA coluna tem rótulo: uma tabela de duas
	# colunas sem nome (ícone + texto) não ganha nada com uma faixa vazia
	var tem_rotulo := false
	for col in colunas:
		if str(col.get("t", "")) != "":
			tem_rotulo = true
	if tem_rotulo:
		var cab := PanelContainer.new()
		cab.add_theme_stylebox_override("panel", Tema.estilo_cabecalho())
		v.add_child(cab)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", Tema.E3)
		cab.add_child(h)
		var f_col := Tema.fonte_coluna()
		for col in colunas:
			var l := Label.new()
			l.text = str(col.get("t", ""))
			if f_col != null:
				l.add_theme_font_override("font", f_col)
			l.add_theme_font_size_override("font_size", Tema.MINI)
			l.add_theme_color_override("font_color", Tema.TEXTO_3)
			_medir(l, col)
			h.add_child(l)
	# a spec fica pendurada no nó: `linha()` a lê de volta sem que a aba
	# precise carregar a variável de uma chamada para a outra
	v.set_meta("colunas", colunas)
	v.set_meta("n", 0)
	return v

## Uma linha da tabela. Devolve um Array de células (Control) na ordem das
## colunas — a aba preenche cada uma sem saber nada sobre larguras.
##
## `marca` pinta a barra de 3px na esquerda: é como uma linha diz "esta
## aqui" (celeiro vazio, tropa desertando) sem trocar a cor do texto inteiro.
static func linha(tab: VBoxContainer, marca: Variant = null) -> Array:
	var colunas: Array = tab.get_meta("colunas", [])
	var n: int = int(tab.get_meta("n", 0))
	tab.set_meta("n", n + 1)

	var painel := PanelContainer.new()
	var sb := Tema.estilo_linha(n % 2 == 0)
	if marca is Color:
		# `border_color` do StyleBoxFlat vale para os quatro lados: pintar só
		# a barra esquerda de latão pintava junto a hairline de baixo, e a
		# linha marcada aparecia com um contorno dourado em vez de uma barra.
		# A hairline sai; a zebra continua separando as linhas.
		sb.set_border_width_all(0)
		sb.border_width_left = 3
		sb.border_color = marca
	painel.add_theme_stylebox_override("panel", sb)
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(painel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E3)
	h.custom_minimum_size = Vector2(0, Tema.LINHA_H)
	painel.add_child(h)

	var celulas: Array = []
	for col in colunas:
		var cel := HBoxContainer.new()
		cel.add_theme_constant_override("separation", Tema.E2)
		cel.alignment = _alinhamento(str(col.get("a", ESQ)))
		_medir(cel, col)
		cel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cel)
		celulas.append(cel)
	return celulas

## Aplica a largura e o alinhamento de uma coluna a um Control.
static func _medir(no: Control, col: Dictionary) -> void:
	var w: int = int(col.get("w", 0))
	if w > 0:
		no.custom_minimum_size = Vector2(w, 0)
		no.size_flags_horizontal = Control.SIZE_FILL
	else:
		# a coluna que estica. Uma por tabela — duas dividem a sobra e as
		# colunas de número param de ficar no mesmo x de linha para linha.
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if no is Label:
		no.horizontal_alignment = _alinhamento_label(str(col.get("a", ESQ)))

static func _alinhamento(a: String) -> int:
	match a:
		DIR: return BoxContainer.ALIGNMENT_END
		CENTRO: return BoxContainer.ALIGNMENT_CENTER
		_: return BoxContainer.ALIGNMENT_BEGIN

static func _alinhamento_label(a: String) -> int:
	match a:
		DIR: return HORIZONTAL_ALIGNMENT_RIGHT
		CENTRO: return HORIZONTAL_ALIGNMENT_CENTER
		_: return HORIZONTAL_ALIGNMENT_LEFT


# ============================================================
# CARD — para o que NÃO é tabela
#
# Nem toda lista é tabela. Um reino no mapa tem retrato, três linhas de
# texto de comprimentos diferentes e cinco botões: forçar isso numa grade de
# colunas produziria colunas vazias. O card continua existindo para esses —
# mas agora ele é raso, e quem decide a altura é o conteúdo.
# ============================================================

## Card com moldura. `marca` pinta a barra de acento na esquerda.
static func card(c: Container, marca: Variant = null) -> VBoxContainer:
	var painel := PanelContainer.new()
	if marca is Color:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card_marcado(marca))
	else:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card())
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E2)
	painel.add_child(v)
	return v

## Card em linha: retrato à esquerda, conteúdo à direita. Devolve as duas
## metades para a aba preencher.
##
## A altura mínima de 56px que existia aqui saiu. Ela foi escrita para uma
## moldura 9-slice que não existe mais, e o que ela fazia hoje era garantir
## 56px de altura a uma linha com 15px de texto — o vazio vertical que fazia
## caber quatro itens por tela.
static func card_com_retrato(c: Container, marca: Variant = null) -> Array:
	var painel := PanelContainer.new()
	if marca is Color:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card_marcado(marca))
	else:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card())
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(painel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E4)
	painel.add_child(h)
	var esq := VBoxContainer.new()
	esq.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(esq)
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", Tema.E2)
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(dir)
	return [esq, dir]

## Uma linha horizontal de coisas, com o espaçamento da casa.
static func fila(c: Container, sep: int = Tema.E3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(h)
	return h

## Uma coluna.
static func coluna(c: Container, sep: int = Tema.E3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(v)
	return v

## DUAS COLUNAS. A tela tem 960 de largura e a interface usava ~600 dela
## numa coluna só, com o resto vazio. Onde o conteúdo permite — a aba da
## Terra, a Família — ele passa a ocupar as duas.
##
## `peso_esq` é a fração da largura que a coluna esquerda leva.
static func duas_colunas(c: Container, peso_esq: float = 0.5) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E5)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(h)
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", Tema.E3)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_stretch_ratio = peso_esq
	h.add_child(a)
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", Tema.E3)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.0 - peso_esq
	h.add_child(b)
	return [a, b]

## Espaço vertical explícito, na escala.
static func respiro(c: Container, altura: int = Tema.E4) -> Control:
	var e := Control.new()
	e.custom_minimum_size = Vector2(0, altura)
	c.add_child(e)
	return e


# ============================================================
# BOTÕES
# ============================================================

## `variante`: "" (normal), "primario", "fantasma", "perigo".
##
## `largura` em 0 deixa o botão do tamanho do texto — que é o padrão certo.
## O estado anterior tinha `SIZE_EXPAND_FILL` em botões soltos, e por isso
## "Conversar" aparecia com 830px de largura: um botão de 830px não parece
## um botão, parece uma divisória.
static func botao(c: Container, texto_botao: String, cb: Callable,
		variante: String = "", largura: int = 0) -> Button:
	var b := Button.new()
	b.text = texto_botao
	b.pressed.connect(cb)
	_pintar_botao(b, variante)
	if largura > 0:
		b.custom_minimum_size = Vector2(largura, 0)
	c.add_child(b)
	return b

## Botão pequeno, para dentro de linha de tabela.
static func botao_mini(c: Container, texto_botao: String, cb: Callable,
		variante: String = "fantasma", largura: int = 0) -> Button:
	var b := botao(c, texto_botao, cb, variante, largura)
	b.add_theme_font_size_override("font_size", Tema.MICRO)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Botão só de ícone — para a barra inferior e para ações repetidas numa
## tabela, onde a palavra caberia mas roubaria a largura da coluna de número.
static func botao_icone(c: Container, icone: String, dica: String, cb: Callable,
		variante: String = "fantasma", lado: int = 30) -> Button:
	var b := Button.new()
	b.icon = Icones.textura_tingida(icone)
	b.expand_icon = true
	b.tooltip_text = dica
	b.custom_minimum_size = Vector2(lado, lado)
	b.pressed.connect(cb)
	_pintar_botao(b, variante)
	c.add_child(b)
	return b

static func _pintar_botao(b: Button, variante: String) -> void:
	var estilos: Dictionary = {}
	match variante:
		"primario":
			estilos = Tema.estilos_primario()
			b.add_theme_color_override("font_color", Color("1c1712"))
			b.add_theme_color_override("font_hover_color", Color("14110f"))
			b.add_theme_color_override("font_pressed_color", Tema.ACENTO_FORTE)
		"fantasma":
			estilos = Tema.estilos_fantasma()
			b.add_theme_color_override("font_color", Tema.TEXTO_2)
			b.add_theme_color_override("font_hover_color", Tema.ACENTO_FORTE)
		"perigo":
			estilos = Tema.estilos_perigo()
			b.add_theme_color_override("font_color", Color("e8917a"))
			b.add_theme_color_override("font_hover_color", Color("ffb9a4"))
		_:
			return
	for estado in estilos:
		b.add_theme_stylebox_override(estado, estilos[estado])


# ============================================================
# CHIP e MEDIDOR — o que faltava por completo
# ============================================================

## Chip: ícone + valor num terreno próprio. É a unidade do HUD e do resumo
## de recursos de cada aba.
##
## `cor` tinge o NÚMERO; `fundo` tinge o terreno. Os dois separados de
## propósito: um celeiro vazio quer número terracota sobre fundo terracota
## rebaixado, e um celeiro cheio quer número creme sobre o terreno neutro —
## se a cor fosse uma só, todo chip do HUD ficaria colorido o tempo todo e
## nenhum saltaria quando importasse.
static func chip(c: Container, icone: String, valor: String,
		cor: Color = Tema.TEXTO, fundo: Color = Tema.SUPERFICIE,
		dica: String = "", id: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.estilo_chip(fundo))
	p.tooltip_text = dica
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E2 + 1)
	p.add_child(h)
	if icone != "":
		var ic := Icones.imagem(icone, 18)
		if ic != null:
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ic)
	numero(h, valor, cor, Tema.NUMERO - 1, id)
	return p

## FATO: ícone e número em cima, rótulo embaixo. Dois ou três lado a lado.
##
## Existe para o caso em que uma tabela é desperdício. Uma tabela de DUAS
## linhas gasta 84px de altura, cabeçalho, zebra e hairline para dizer dois
## números — e numa tela de 540 essa é a altura que decide se o resto cabe.
## Em fila, os mesmos dois números ocupam 26px e continuam comparáveis,
## porque ficam lado a lado em vez de um sobre o outro.
##
## A regra de quando usar cada um: TABELA quando as linhas são uma lista que
## cresce (mercadorias, tropas, contratos); FATO quando são dois ou três
## números fixos que a tela sempre mostra.
static func fato(c: Container, icone: String, valor: String, rotulo: String,
		cor: Color = Tema.TEXTO, dica: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.tooltip_text = dica
	c.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E2 + 1)
	v.add_child(h)
	var ic := Icones.imagem(icone, 20)
	if ic != null:
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	numero(h, valor, cor, Tema.NUMERO)
	var l := Label.new()
	l.text = rotulo
	l.add_theme_font_size_override("font_size", Tema.MINI)
	l.add_theme_color_override("font_color", Tema.TEXTO_3)
	v.add_child(l)
	return v

## Ícone + número soltos, sem terreno — para dentro de uma célula de tabela,
## onde o chip acrescentaria uma caixa em cima da linha que já é uma caixa.
static func icone_valor(c: Container, icone: String, valor: String,
		cor: Color = Tema.TEXTO, lado: int = 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E2 + 1)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(h)
	var ic := Icones.imagem(icone, lado)
	if ic != null:
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	numero(h, valor, cor, Tema.NUMERO - 1)
	return h

## MEDIDOR — a barra de estado que o jogo não tinha.
##
## Moral 34/100 escrito por extenso obriga a leitura, a divisão e a
## comparação com o limiar de deserção. A mesma informação como barra
## terracota de um terço é lida em 200ms sem nenhuma das três operações.
## Isto não é enfeite: num jogo de gestão é a diferença entre um número que
## o jogador confere e um estado que ele PERCEBE.
##
## A cor vem de `Tema.cor_de_saude`, que muda nos limiares da mecânica.
static func medidor(c: Container, valor: float, maximo: float,
		largura: int = 0, altura: int = 6, cor: Variant = null) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(1.0, maximo)
	b.value = clampf(valor, 0.0, maxf(1.0, maximo))
	b.show_percentage = false
	b.custom_minimum_size = Vector2(largura, altura)
	if largura <= 0:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f: float = valor / maxf(1.0, maximo)
	b.add_theme_stylebox_override("background", Tema.estilo_medidor_trilho())
	b.add_theme_stylebox_override("fill",
		Tema.estilo_medidor_cheio(cor if cor is Color else Tema.cor_de_saude(f)))
	c.add_child(b)
	return b

## Medidor com rótulo em cima e valor à direita — o bloco completo, que é
## como ele aparece nove em cada dez vezes.
static func medidor_rotulado(c: Container, rotulo: String, valor: float,
		maximo: float, sufixo: String = "", cor: Variant = null,
		id: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var l := Label.new()
	l.text = rotulo
	l.add_theme_font_size_override("font_size", Tema.MICRO)
	l.add_theme_color_override("font_color", Tema.TEXTO_2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(l)
	var f: float = valor / maxf(1.0, maximo)
	var n := numero(topo, "%d%s" % [int(valor), sufixo],
		cor if cor is Color else Tema.cor_de_saude(f), Tema.MICRO + 1)
	var b := medidor(v, valor, maximo, 0, 6, cor)
	# com sufixo o texto não é um inteiro puro, então `numero()` não anima
	# sozinho: o movimento entra aqui, reescrevendo o rótulo inteiro a cada
	# quadro para o sufixo ("/100", " de 260") acompanhar o dígito
	if id != "":
		var anterior: int = int(_ultimos.get(id, int(valor)))
		_ultimos[id] = int(valor)
		if anterior != int(valor) and n.is_inside_tree():
			var tw := n.create_tween()
			tw.set_ease(Tween.EASE_OUT)
			tw.set_trans(Tween.TRANS_CUBIC)
			tw.tween_method(func(x: float): n.text = "%d%s" % [roundi(x), sufixo],
				float(anterior), valor, DURACAO_CORRIDA)
			var tb := b.create_tween()
			tb.set_ease(Tween.EASE_OUT)
			tb.set_trans(Tween.TRANS_CUBIC)
			tb.tween_property(b, "value", valor, DURACAO_CORRIDA) \
				.from(clampf(float(anterior), 0.0, b.max_value))
	return v

## A ESCALA INTEIRA mais próxima do tamanho pedido.
##
## Toda a arte do jogo é potência de dois — retrato 64, tropa 64, evento 128
## — e é desenhada com filtro NEAREST. Exibir uma textura de 64 num quadro
## de 150 é ampliar 2,34×: com NEAREST isso significa que uma linha de pixel
## em cada três vira duas linhas, e a grade sai visivelmente irregular. Era
## o que acontecia no retrato do modal e na ilustração de evento.
##
## Aqui o tamanho pedido é tratado como INTENÇÃO e não como medida: a função
## devolve o múltiplo (ou submúltiplo, em potências de dois) mais próximo.
## Pedir 150 de um evento de 128 devolve 128; pedir 150 de um retrato de 64
## devolve 128; pedir 72 de um evento de 128 devolve 64.
static func escala_inteira(nativo: int, alvo: int) -> int:
	if nativo <= 0:
		return alvo
	if alvo >= nativo:
		return nativo * maxi(1, int(round(float(alvo) / float(nativo))))
	# redução: só por metades, que é a única que preserva a grade
	var lado := nativo
	while lado > alvo and lado > 8:
		@warning_ignore("integer_division")
		lado = lado / 2
	# entre o degrau de baixo e o de cima, o mais próximo do que se pediu
	if absi(lado * 2 - alvo) < absi(lado - alvo):
		return lado * 2
	return lado

## Uma ILUSTRAÇÃO grande, centrada e com moldura.
##
## As cenas saem quadradas (128×128); esticá-las numa faixa larga cortava
## três quartos do desenho. Aqui a arte aparece inteira, ampliada, centrada,
## e com uma moldura de 1px que a separa do painel — sem a moldura, uma
## ilustração escura encostava no terreno e parecia um buraco.
static func ilustracao(c: Container, tex: Texture2D, altura: int = 120) -> Control:
	if tex == null:
		return null
	var moldura := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("100d0b")
	sb.border_color = Tema.BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(1)
	moldura.add_theme_stylebox_override("panel", sb)
	moldura.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moldura.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(moldura)
	var lado := escala_inteira(tex.get_width(), altura)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(lado, lado)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moldura.add_child(tr)
	return moldura

## Retrato com moldura fina. O retrato é 64×64 e a moldura é 1px: qualquer
## coisa mais grossa e a moldura vira o assunto.
static func retrato(c: Container, tex: Texture2D, lado: int = 44) -> Control:
	if tex == null:
		return null
	var moldura := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("100d0b")
	sb.border_color = Tema.BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	moldura.add_theme_stylebox_override("panel", sb)
	moldura.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moldura.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(moldura)
	var real := escala_inteira(tex.get_width(), lado)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(real, real)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moldura.add_child(tr)
	return moldura

## Selo: uma palavra curta em caixa alta sobre terreno colorido. "CASUS
## BELLI", "SEU TRONO", "VASSALO", "A FERROS". São ESTADOS, e estado escrito
## no meio de uma frase corrida — que era como apareciam — não é lido.
static func selo(c: Container, txt: String, cor: Color = Tema.ACENTO,
		fundo: Color = Tema.ACENTO_FUNDO) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.set_corner_radius_all(0)
	sb.content_margin_left = Tema.E2 + 1
	sb.content_margin_right = Tema.E2 + 1
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.add_child(p)
	var l := Label.new()
	l.text = txt.to_upper()
	l.add_theme_font_size_override("font_size", Tema.MINI)
	l.add_theme_color_override("font_color", cor)
	var f := Tema.fonte_forte()
	if f != null:
		l.add_theme_font_override("font", f)
	p.add_child(l)
	return p
