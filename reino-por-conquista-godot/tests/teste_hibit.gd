# ============================================================
# TESTE DA INTERFACE E DO AMBIENTE
#
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/teste_hibit.gd
#
# Era o teste do pipeline Hi-Bit, em três frentes. Duas saíram com a vila
# navegável: a ponte de geração de arte, os shaders de sprite e o par
# AgenteMovel/VisualController não têm mais consumidor. O que sobrou é o
# que a tela do jogo de fato usa:
#
#   · as chaves de renderização no project.godot. São texto num .cfg, e
#     qualquer merge as apaga em silêncio — ninguém percebe até o texto
#     voltar a sair esticado na tela de alguém.
#   · a tipografia. Que a fonte de número seja MESMO monoespaçada não é
#     detalhe: é o que faz a coluna de preço alinhar sozinha.
#   · o ciclo de luz, que continua tingindo o cartão da aba "Sua Terra"
#     sem encostar na interface de pergaminho.
# ============================================================
extends SceneTree

const Ambiente = preload("res://scripts/environment_manager.gd")

var _v := 0
var _x := 0


## Luminância relativa do WCAG — não é o `v` do HSV. `v` é o canal máximo,
## e usá-lo para contraste dá razões erradas em cor saturada.
func _lum(c: Color) -> float:
	var canais := [c.r, c.g, c.b]
	var f: Array[float] = []
	for v in canais:
		f.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]


func ok(cond: bool, nome: String, obs: String = "") -> void:
	print("  %s %s%s" % ["✅" if cond else "❌", nome,
		("  —  " + obs) if obs != "" else ""])
	if cond:
		_v += 1
	else:
		_x += 1


func _initialize() -> void:
	print("\n=== RENDERIZAÇÃO E TIPOGRAFIA ===")
	_frente1()
	print("\n=== SOM DO PACOTE E HERÁLDICA ===")
	_frente_som_e_heraldica()
	print("\n=== A TERRA NA TELA ===")
	await _frente_terra()
	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)


# ------------------------------------------------------------
## A VISTA DA TERRA precisa concordar com o ESTADO.
##
## O título da aba lê `state` na hora; a imagem vem de um `_aplicar()` que
## roda noutro caminho. Quando os dois se soltaram, a aba escreveu
## "Vale do Ferro — Castelo" por cima do acampamento e nada acusou — porque
## nenhuma das duas metades estava errada sozinha.
##
## O que este teste reproduz é a sequência EXATA do `_aba_terra`: `atualizar()`
## desmonta a aba, `estado` é atribuído com a vista FORA da árvore, e só
## depois ela volta. `_aplicar` não age fora da árvore, então sem o gancho de
## `_enter_tree` a atribuição se perde inteira.
func _frente_terra() -> void:
	var Vista = load("res://scripts/cenario_v3_view.gd")
	var vista = Vista.new()
	root.add_child(vista)
	vista.estado = {"mes": 6, "terra": {"nivel": 0}}
	for i in 4:
		await process_frame
	# nível 0 (Acampamento) mostra a CENA do acampamento — que na leva de
	# seis é o estágio 1; o estágio 0 é o campo virgem de quem não tem terra
	ok(vista.cena.estagio == Vista.ESCADA_NIVEL[0],
		"a vista monta no estágio do save",
		"estágio %d para terra nível 0" % vista.cena.estagio)

	# ---- a sequência do _aba_terra, na ordem em que ela acontece ----
	root.remove_child(vista)
	vista.estado = {"mes": 6, "terra": {"nivel": 4}}
	root.add_child(vista)
	for i in 4:
		await process_frame
	# `evoluir` faz crossfade; o estágio troca na hora, o alfa é que demora
	await create_timer(1.2).timeout
	await process_frame
	ok(vista.cena.estagio == Vista.ESCADA_NIVEL[4],
		"subir de nível FORA da árvore ainda muda a imagem",
		"estágio %d para terra nível 4" % vista.cena.estagio)
	ok(not vista.cena.em_transicao(), "o crossfade termina e solta o estado")

	# a arte tem que ser a arte, não o caixote de reserva
	var tex: Texture2D = vista.cena._textura(4)
	ok(tex != null and tex.get_width() == 400 and tex.get_height() == 224,
		"o estágio carrega o PNG, não o caixote",
		"%d×%d" % [tex.get_width(), tex.get_height()])
	# todos têm que existir, senão um nível qualquer cai no cinza
	var faltam: Array[String] = []
	for i in vista.cena.NOMES.size():
		if not ResourceLoader.exists("res://assets/sprites/%s.png"
				% vista.cena.NOMES[i]):
			faltam.append(str(vista.cena.NOMES[i]))
	ok(faltam.is_empty(), "todo estágio existe em disco",
		"faltando: %s" % ("nenhum" if faltam.is_empty() else ", ".join(faltam)))

	# ---- a ESCADA nível→cena tem que ser coerente com as duas tabelas ----
	# Nove níveis dividem seis cenas, e quem traduz é ESCADA_NIVEL. O que não
	# pode acontecer, e acontecia em silêncio quando a tradução era um clamp:
	# a escada ficar mais curta que a tabela de níveis (níveis de cima caindo
	# todos no mesmo quadro sem ninguém decidir isso), a cena andar para TRÁS
	# ao subir de nível, ou o último nível não mostrar a última cena.
	var Dados = load("res://scripts/dados.gd")
	ok(Vista.ESCADA_NIVEL.size() == Dados.NIVEIS_TERRA.size(),
		"a escada cobre todos os níveis de terra",
		"%d níveis · %d degraus na escada"
		% [Dados.NIVEIS_TERRA.size(), Vista.ESCADA_NIVEL.size()])
	var monotonica := true
	for i in range(1, Vista.ESCADA_NIVEL.size()):
		if Vista.ESCADA_NIVEL[i] < Vista.ESCADA_NIVEL[i - 1]:
			monotonica = false
	ok(monotonica, "a cena nunca anda para trás ao subir de nível")
	ok(int(Vista.ESCADA_NIVEL[-1]) == vista.cena.NOMES.size() - 1,
		"o último nível mostra a última cena",
		"nível máximo → estágio %d de %d"
		% [int(Vista.ESCADA_NIVEL[-1]), vista.cena.NOMES.size() - 1])
	ok(vista.estagio_de({}) == 0 and vista.estagio_de({"terra": null}) == 0,
		"sem terra, a vista mostra o campo virgem")
	vista.queue_free()

	# ---- retratos de tropa ----
	var Retratos = load("res://scripts/retratos.gd")
	var sem_retrato: Array[String] = []
	var lados := {}
	for tipo in Dados.TROPAS:
		var t: Texture2D = Retratos.textura_tropa(str(tipo))
		if t == null or t.get_width() != 64:
			sem_retrato.append(str(tipo))
		else:
			lados[t.get_width()] = true
	ok(sem_retrato.is_empty(), "as nove tropas têm retrato de 64px",
		"sem arte: %s" % ("nenhuma" if sem_retrato.is_empty()
			else ", ".join(sem_retrato)))

	# ---- ilustrações de evento ----
	var sem_arte: Array[String] = []
	for ev in Retratos.EVENTOS:
		var t: Texture2D = Retratos.ilustracao(str(ev))
		if t == null or t.get_width() != Retratos.LADO_EVENTO:
			sem_arte.append(str(ev))
	ok(sem_arte.is_empty(), "os dez eventos têm ilustração de 128px",
		"sem arte: %s" % ("nenhum" if sem_arte.is_empty()
			else ", ".join(sem_arte)))
	# a lista FECHADA é o que faz um typo aparecer como ausência, e não como
	# ilustração errada — que é o defeito que ninguém rastreia até a causa
	ok(Retratos.ilustracao("emboscda") == null,
		"evento com typo devolve null, não arte de outro evento")


# ------------------------------------------------------------
func _frente1() -> void:
	# ---- MODO DE INTERFACE ----
	# A asserção inverteu junto com a direção. Ela cobrava "viewport" +
	# "keep" + "integer", que é a receita para proteger uma GRADE DE PIXEL:
	# tudo renderizado em 960×540 e ampliado em múltiplo inteiro.
	#
	# Só que a tela deste jogo é onze abas de tabela, e nessa receita cada
	# letra virava um bitmap esticado. "canvas_items" mantém 960×540 como
	# sistema de coordenadas — nenhum layout se move — e manda a fonte para
	# o rasterizador na resolução real do monitor.
	#
	# A grade de pixel não sumiu: ela vive dentro do cartão da aba "Sua
	# Terra", e lá quem garante é o nó, com NEAREST e escala inteira própria.
	var modo := str(ProjectSettings.get_setting("display/window/stretch/mode"))
	ok(modo == "canvas_items", "stretch mode de interface (texto nativo)", modo)
	ok(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand",
		"aspect expand — tabela agradece largura",
		str(ProjectSettings.get_setting("display/window/stretch/aspect")))

	# ---- TIPOGRAFIA DE GERENCIAMENTO ----
	var Tema = load("res://scripts/tema.gd")
	var num: FontFile = Tema.fonte_numero()
	var corpo: FontFile = Tema.fonte_corpo()
	ok(num != null and corpo != null, "as duas fontes carregam")
	if num != null:
		# ALGARISMO TABULAR, e não monoespaçada — a asserção mudou junto com
		# a fonte, e vale registrar por quê.
		#
		# O contrato que a tabela precisa é UM: todo dígito ocupa a mesma
		# largura, para que 1.240 e 980 alinhem casa por casa na vertical.
		# Monoespaçada entrega isso, mas cobra caro — obriga a letra a ter a
		# largura do dígito, e é por isso que uma coluna de rótulos em mono
		# lê como terminal.
		#
		# Spectral tem figura tabular de fábrica: "1" e "8" medem igual, e o
		# "W" continua largo como deve. Testar `l1 == lW` seria testar a
		# monoespaçada, que é o MEIO, e não o alinhamento, que é o FIM.
		var l1 := num.get_string_size("1", 0, -1, 16).x
		var l8 := num.get_string_size("8", 0, -1, 16).x
		var l4 := num.get_string_size("4", 0, -1, 16).x
		var lw := num.get_string_size("W", 0, -1, 16).x
		ok(is_equal_approx(l1, l8) and is_equal_approx(l1, l4),
			"algarismo do número é TABULAR (a coluna alinha sozinha)",
			"1=%.1f 4=%.1f 8=%.1f" % [l1, l4, l8])
		ok(lw > l1 * 1.4, "e mesmo assim NÃO é monoespaçada (a letra respira)",
			"W=%.1f contra dígito=%.1f" % [lw, l1])
		# as duas colunas de uma tabela de dez linhas têm que fechar na mesma
		# largura, que é a prova prática do que está acima
		ok(is_equal_approx(num.get_string_size("1111", 0, -1, 16).x,
				num.get_string_size("8888", 0, -1, 16).x),
			"quatro dígitos quaisquer medem o mesmo")
	if corpo != null:
		# prosa em monoespaçada lê como terminal: o corpo TEM que ser
		# proporcional, senão a diferença entre as duas some
		var i_l := corpo.get_string_size("i", 0, -1, 16).x
		var m_l := corpo.get_string_size("M", 0, -1, 16).x
		ok(m_l > i_l * 1.8, "fonte de texto é PROPORCIONAL",
			"i=%.1f M=%.1f" % [i_l, m_l])
		ok(corpo.get_string_size("ÇÃÕáéíóúâêô", 0, -1, 16).x > 0,
			"acentuação do português coberta")
	ok(Tema.NUMERO > Tema.MICRO and Tema.TITULO_TELA > Tema.CORPO_G
		and Tema.TITULO_JOGO > Tema.TITULO_TELA,
		"escala tipográfica é monotônica",
		"%d < %d < %d < %d" % [Tema.MICRO, Tema.CORPO_G, Tema.TITULO_TELA,
			Tema.TITULO_JOGO])
	# ALCANCE, e não só ordem. A escala anterior ia de 11 a 22 dentro do
	# jogo: uma tela cujo maior texto tem o dobro do menor não hierarquiza,
	# varia. Abaixo de 2× o olho não sabe onde pousar antes de ler.
	ok(float(Tema.NUMERO_G) / float(Tema.CORPO) >= 2.0,
		"a escala tem ALCANCE de verdade (maior >= 2x o corpo)",
		"%d / %d = %.2fx" % [Tema.NUMERO_G, Tema.CORPO,
			float(Tema.NUMERO_G) / float(Tema.CORPO)])

	# ---- AS FONTES CHEGAM MESMO NA TELA ----
	#
	# Esta seção existe por causa de um defeito que ficou meses invisível: o
	# `.import` das fontes apontava para um `.fontdata` que só o editor gera,
	# `load()` devolvia null em silêncio, `criar()` pulava o `if != null` e o
	# jogo rodava na fonte embutida da engine. Nenhum teste acusava, porque
	# nenhum teste perguntava se a fonte ESCOLHIDA era a fonte USADA.
	#
	# Três asserções, e a terceira é a que importa: o Theme montado tem que
	# devolver a nossa fonte, não a da engine.
	for arq in ["Cinzel.ttf", "Spectral-Regular.ttf", "Spectral-Medium.ttf",
			"Spectral-SemiBold.ttf", "Spectral-Bold.ttf"]:
		ok(not FileAccess.get_file_as_bytes("res://assets/fontes/" + arq).is_empty(),
			"o arquivo da fonte é legível por BYTES (sobrevive ao PCK)", arq)
	ok(corpo != null and corpo.get_font_name() == "Spectral",
		"fonte_corpo() devolve Spectral de verdade",
		"veio: %s" % ("NULO" if corpo == null else corpo.get_font_name()))
	var tema_montado: Theme = Tema.criar()
	var f_padrao := tema_montado.default_font
	ok(f_padrao != null and f_padrao != ThemeDB.get_default_theme().default_font,
		"o Theme montado NÃO caiu na fonte embutida da engine",
		"default_font = %s" % ("NULO" if f_padrao == null else str(f_padrao.get_font_name())))
	# a capitular carrega e responde ao eixo de peso (a chave do
	# `variation_opentype` é a tag OpenType como INTEIRO — com string ela
	# falha em silêncio e todos os pesos saem iguais)
	var cinzel_400: Font = Tema._cinzel(400)
	var cinzel_700: Font = Tema._cinzel(700)
	ok(cinzel_400 != null and cinzel_700 != null, "a capitular carrega nos dois pesos")
	if cinzel_400 != null and cinzel_700 != null:
		ok(cinzel_700.get_string_size("REINO", 0, -1, 22).x
			> cinzel_400.get_string_size("REINO", 0, -1, 22).x,
			"o eixo de peso da capitular RESPONDE (700 mais largo que 400)",
			"400=%.0f 700=%.0f" % [cinzel_400.get_string_size("REINO", 0, -1, 22).x,
				cinzel_700.get_string_size("REINO", 0, -1, 22).x])
	# as ONZE abas cabem na faixa sem a TabBar entrar em modo de rolagem —
	# esconder "Crônica" e "Guerra" atrás de setinhas é perder duas telas
	var f_aba: Font = Tema.fonte_aba()
	if f_aba != null:
		var soma := 0.0
		for nome_aba in ["Terra", "Mapa", "Feira", "Taverna", "Corte", "Tropas",
				"Clãs", "Intriga", "Casa", "Crônica", "Guerra"]:
			# rótulo + ícone de 12 + as duas margens E3 da plaqueta
			soma += f_aba.get_string_size(nome_aba, 0, -1, Tema.MICRO).x + 12 + 2 * Tema.E3
		ok(soma <= 916.0, "as onze abas cabem sem rolagem",
			"soma %.0f de 916 úteis" % soma)
	# fonte VETORIAL com anti-alias. A herança das fontes pixel desligava
	# isto, e desligado ele devolve DejaVu serrilhada a 15px — jogando fora
	# o ganho do canvas_items sem que nada acuse.
	if corpo != null:
		ok(corpo.antialiasing == TextServer.FONT_ANTIALIASING_GRAY,
			"fonte de texto com anti-alias ligado",
			"valor %d" % corpo.antialiasing)

	# ---- PALETA ----
	# Terreno QUENTE. A primeira versão desta paleta era slate azulado, que
	# é o vocabulário de painel de controle. Um reino precisa de umbra.
	var quentes := 0
	for c in [Tema.FUNDO, Tema.SUPERFICIE, Tema.ELEVADO, Tema.BORDA]:
		if c.r > c.b:
			quentes += 1
	ok(quentes == 4, "os quatro degraus do terreno são QUENTES (r > b)",
		"%d de 4" % quentes)
	# ...mas neutros, não madeira: croma alto vira tábua de novo.
	#
	# O croma aqui é a AMPLITUDE ABSOLUTA dos canais (max − min), não a
	# saturação HSV. A saturação divide pelo canal máximo, então quanto mais
	# escura a cor, mais alto o número para a mesma diferença física: pelo
	# HSV, #010000 é "100% saturado" e é preto. Num terreno que vive entre
	# valor 0,10 e 0,27, medir por HSV mede o escuro, não o colorido.
	var croma_max := 0.0
	for c in [Tema.FUNDO, Tema.SUPERFICIE, Tema.ELEVADO, Tema.BORDA]:
		croma_max = maxf(croma_max, maxf(c.r, maxf(c.g, c.b))
			- minf(c.r, minf(c.g, c.b)))
	ok(croma_max < 0.12, "terreno é neutro quente, não madeira",
		"croma máximo %.2f (teto 0,12)" % croma_max)
	# ...e o teto acima só vale se REJEITAR tábua de verdade. Sem este
	# controle, baixar o teto até caber é indistinguível de medir certo.
	var tabuas := [Color("6b4423"), Color("8b5a2b"), Color("a0522d")]
	var reprovadas := 0
	for c in tabuas:
		if maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) >= 0.12:
			reprovadas += 1
	ok(reprovadas == tabuas.size(),
		"o teto de croma reprova madeira de verdade",
		"%d de %d tábuas reprovadas" % [reprovadas, tabuas.size()])
	# a escada precisa SUBIR: quatro degraus que não separam são um degrau
	ok(Tema.FUNDO.v < Tema.SUPERFICIE.v and Tema.SUPERFICIE.v < Tema.ELEVADO.v
		and Tema.ELEVADO.v < Tema.BORDA.v,
		"os quatro degraus sobem em valor",
		"%.2f < %.2f < %.2f < %.2f" % [Tema.FUNDO.v, Tema.SUPERFICIE.v,
			Tema.ELEVADO.v, Tema.BORDA.v])
	# contraste do texto sobre a superfície, por luminância relativa (WCAG)
	var lum_sup := _lum(Tema.SUPERFICIE)
	var razao := (_lum(Tema.TEXTO) + 0.05) / (lum_sup + 0.05)
	ok(razao >= 7.0, "texto principal em contraste AAA sobre o painel",
		"%.1f:1 (mínimo 7,0)" % razao)
	var razao2 := (_lum(Tema.TEXTO_2) + 0.05) / (lum_sup + 0.05)
	ok(razao2 >= 4.5, "texto de apoio em contraste AA",
		"%.1f:1 (mínimo 4,5)" % razao2)
	var razao_ac := (_lum(Tema.ACENTO) + 0.05) / (lum_sup + 0.05)
	ok(razao_ac >= 4.5, "acento legível como texto sobre o painel",
		"%.1f:1" % razao_ac)
	# semântico separado do acento: se o ganho tivesse o matiz do latão,
	# "subiu" e "isto é um cabeçalho" leriam igual
	ok(absf(Tema.GANHO.h - Tema.ACENTO.h) > 0.08
		and absf(Tema.PERIGO.h - Tema.ACENTO.h) > 0.02,
		"ganho e perigo têm matiz próprio, distinto do acento",
		"acento %.2f · ganho %.2f · perigo %.2f"
		% [Tema.ACENTO.h, Tema.GANHO.h, Tema.PERIGO.h])

	# ---- ÍCONES ----
	var Icones = load("res://scripts/icones.gd")
	var inv: Dictionary = Icones.inventario()
	print("      (ícones: %d gerados, %d faltando)"
		% [inv["tem"].size(), inv["falta"].size()])
	if inv["tem"].size() > 0:
		var nome: String = inv["tem"][0]
		var t = Icones.textura(nome)
		ok(t is Texture2D, "ícone carrega como textura", nome)
		# SILHUETA: o arquivo é branco com alfa, e quem dá a cor é o
		# modulate. Se o arquivo já viesse colorido, tingir para alerta
		# aplicaria tinta sobre tinta e a cor sairia errada.
		var img: Image = t.get_image()
		var coloridos := 0
		var parciais := 0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var c := img.get_pixel(x, y)
				if c.a > 0.9 and (c.r < 0.98 or c.g < 0.98 or c.b < 0.98):
					coloridos += 1
				if c.a > 0.02 and c.a < 0.98:
					parciais += 1
		ok(coloridos == 0, "ícone é silhueta BRANCA, não arte colorida",
			"%d px coloridos" % coloridos)
		ok(parciais == 0, "alfa do ícone é binário", "%d px parciais" % parciais)
		var tr: TextureRect = Icones.imagem(nome, 24)
		if Icones.ilustrado(nome) != null:
			# CONTRATO DA LEVA ILUSTRADA: o ícone hi-bit é colorido com luz
			# própria — chega CRU (sem modulate) e em NEAREST, porque é
			# pixel art de 32 mostrada quase sempre 1:1
			ok(tr != null and tr.modulate.is_equal_approx(Color.WHITE),
				"ícone ilustrado entra CRU, sem tinta", nome)
			ok(tr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"ícone ilustrado usa NEAREST",
				"pixel art de 32 em alvo de 18–34")
		else:
			ok(tr != null and tr.modulate.is_equal_approx(Icones.cor_de(nome)),
				"a interface tinge o ícone na COR DELE, o arquivo não",
				"%s → %s" % [nome, Icones.cor_de(nome).to_html(false)])
			ok(tr.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
				"ícone usa filtro LINEAR",
				"Nearest numa redução de 192→24 serrilharia a curva inteira")

	# ---- as cores dos ícones ----
	# Uma cor bonita no editor que some no painel escuro é pior que o latão
	# uniforme: some sem avisar. Todas passam pelo mesmo piso do texto de
	# apoio — um ícone é informação, não decoração.
	var fracos: Array[String] = []
	var berrantes: Array[String] = []
	for chave in Icones.COR:
		var c: Color = Icones.COR[chave]
		if (_lum(c) + 0.05) / (lum_sup + 0.05) < 3.0:
			fracos.append(str(chave))
		# ...e nenhuma pode ser mais saturada que o próprio acento de marca:
		# o latão precisa continuar sendo a coisa mais forte da tela.
		if c.s > Tema.ACENTO.s:
			berrantes.append(str(chave))
	ok(fracos.is_empty(), "toda cor de ícone se lê sobre o painel",
		"apagados: %s" % ("nenhum" if fracos.is_empty() else ", ".join(fracos)))
	ok(berrantes.is_empty(), "nenhum ícone grita mais alto que o acento",
		"acima de %.2f: %s" % [Tema.ACENTO.s,
			"nenhum" if berrantes.is_empty() else ", ".join(berrantes)])
	# a tingida tem que ser DIFERENTE da branca: se `textura_tingida`
	# devolvesse a original, a aba voltaria a ser branca sem nada acusar
	var tingida: Texture2D = Icones.textura_tingida("trigo")
	var img_t := tingida.get_image()
	var achou_cor := false
	for y in range(0, img_t.get_height(), 4):
		for x in range(0, img_t.get_width(), 4):
			var p := img_t.get_pixel(x, y)
			if p.a > 0.9 and p.b < 0.9:
				achou_cor = true
	ok(achou_cor, "textura_tingida assa a cor no pixel (aba e botão)",
		"a TabBar desenha o ícone cru — modulate não a alcança")
	# 0 = Nearest. Qualquer outro valor borra a arte inteira.
	var filtro := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"))
	ok(filtro == 0, "filtro de textura padrão = Nearest", "valor %d" % filtro)
	ok(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")),
		"snap de transform em pixel")

	# ---- EnvironmentManager ----
	var amb = Ambiente.new()
	root.add_child(amb)
	amb.intensidade = 1.0

	amb.hora = 0.5
	var meio_dia: float = amb.luminancia()
	var cor_dia: Color = amb.cor_atual()
	amb.hora = 0.0
	var meia_noite: float = amb.luminancia()
	var cor_noite: Color = amb.cor_atual()
	# LUMINÂNCIA, não Color.v — `v` é o canal máximo, e a tinta de inverno
	# tem o azul acima de 1, o que faria o inverno "mais claro" que o verão
	ok(meia_noite < meio_dia, "noite é mais escura que o meio-dia",
		"lum %.2f contra %.2f" % [meia_noite, meio_dia])
	# Purkinje: a noite não é só escura, é DESLOCADA PARA O AZUL
	ok(cor_noite.b > cor_noite.r, "noite puxa para o azul, não só escurece",
		"b %.2f > r %.2f" % [cor_noite.b, cor_noite.r])
	# meio-dia NÃO é branco puro: a tinta da estação entra por cima, e verão
	# de meio-dia é quente de propósito. A invariante que vale é que nenhuma
	# outra hora é mais clara que o meio-dia.
	var mais_claro := true
	for i in 20:
		amb.hora = float(i) / 20.0
		if amb.luminancia() > meio_dia + 0.001:
			mais_claro = false
	ok(mais_claro, "nenhuma hora é mais clara que o meio-dia",
		"meio-dia lum %.3f · cor %s" % [meio_dia, str(cor_dia)])

	amb.definir_mes(1)
	var inverno: float = amb.luminancia()
	var cor_inv: Color = amb.cor_atual()
	amb.definir_mes(7)
	var verao: float = amb.luminancia()
	var cor_ver: Color = amb.cor_atual()
	ok(inverno < verao, "inverno tem dia mais curto que o verão",
		"lum %.3f contra %.3f" % [inverno, verao])
	ok(cor_inv.b > cor_inv.r and cor_ver.r > cor_ver.b,
		"inverno esfria e verão esquenta o croma")

	# o efeito é POR VIEWPORT: um CanvasModulate na raiz tingiria a interface
	var vp := SubViewport.new()
	root.add_child(vp)
	var cm: CanvasModulate = amb.registrar(vp)
	ok(cm != null and cm.get_parent() == vp,
		"CanvasModulate entra no viewport pedido, não na raiz")
	ok(amb.registrar(vp) == cm, "registrar duas vezes não duplica o nó")
	amb.esquecer(vp)
	ok(amb.registrar(vp) != cm, "esquecer solta o viewport do ciclo")

	amb.intensidade = 0.0
	ok(amb.cor_atual().is_equal_approx(Color.WHITE),
		"intensidade 0 devolve o neutro do multiply (branco)")

	vp.free()
	amb.free()


# ------------------------------------------------------------
## O CONTRATO DO ÁUDIO é o da arte hi-bit: arquivo do pacote presente
## toca o arquivo, ausente devolve o tom gerado — e nunca um crash.
## E a PLAQUETA nova tem a borda lisa POR CONSTRUÇÃO: as quatro faixas
## esticáveis do 9-slice são uniformes ao longo do eixo de estico. Era a
## serrilha das abas — pedra segmentada esticada — e se alguém regenerar
## a arte com segmentos, isto acusa antes de qualquer olho.
func _frente_som_e_heraldica() -> void:
	var Sfx = load("res://scripts/sfx.gd")
	var Retratos = load("res://scripts/retratos.gd")
	var Tema = load("res://scripts/tema.gd")

	# os onze nomes servidos pelo pacote: o stream tem que vir do WAV de
	# 44.1 kHz mono — sair a 22050 seria o tom gerado, ou seja, parse falhou
	var nomes := ["tique", "moeda", "alerta", "tambor", "vitoria", "derrota",
		"pagina", "espada", "abrir", "fechar", "aba"]
	var pacote_ok := true
	var falha := ""
	for nome in nomes:
		var s: AudioStreamWAV = Sfx._stream(nome)
		if s == null or s.mix_rate != 44100 or s.stereo or s.data.is_empty():
			pacote_ok = false
			falha = str(nome)
	ok(pacote_ok, "os 11 sons vêm do pacote (44.1 kHz mono, com dados)",
		"falhou em '%s'" % falha if not pacote_ok else "")
	var generico: AudioStreamWAV = Sfx._stream("nome_que_nao_existe")
	ok(generico != null and generico.mix_rate == 22050,
		"nome desconhecido cai no tom gerado (22 kHz)")

	var trilha: AudioStreamMP3 = Sfx.musica_titulo()
	ok(trilha != null and trilha.loop and trilha.data.size() > 1_000_000,
		"a trilha do título existe e está em loop",
		"" if trilha == null else "%d bytes" % trilha.data.size())

	# ---- playlist de fundo do jogo ----
	# a pasta É a playlist: cada faixa carrega SEM loop próprio (quem dá a
	# volta é a fila embaralhada do principal, senão a primeira faixa
	# tocaria para sempre e as outras nunca)
	var faixas: Array[String] = Sfx.musicas_jogo()
	ok(faixas.size() >= 6, "a playlist do jogo tem as faixas da pasta",
		"%d faixas" % faixas.size())
	var todas_ok := true
	var faixa_ruim := ""
	for c in faixas:
		var st: AudioStreamMP3 = Sfx.stream_musica(str(c))
		if st == null or st.loop or st.data.size() < 100_000:
			todas_ok = false
			faixa_ruim = str(c)
	ok(todas_ok, "toda faixa carrega, com dados e sem loop próprio",
		"falhou em '%s'" % faixa_ruim if not todas_ok else "")

	# ---- plaqueta: faixas esticáveis uniformes ----
	var placa: Texture2D = Tema.tex_hibit("ui_placa_pedra")
	ok(placa != null, "ui_placa_pedra carrega")
	if placa != null:
		var img: Image = placa.get_image()
		var w := img.get_width()
		var h := img.get_height()
		var lisa := true
		for x in range(11, w - 11):
			for y in [1, 3, h - 4, h - 2]:
				if img.get_pixel(x, int(y)) != img.get_pixel(11, int(y)):
					lisa = false
		for y in range(11, h - 11):
			for x in [1, 3, w - 4, w - 2]:
				if img.get_pixel(int(x), y) != img.get_pixel(int(x), 11):
					lisa = false
		ok(lisa, "faixas esticáveis da plaqueta são uniformes (borda lisa)",
			"%dx%d" % [w, h])

	# ---- heráldica da casa ----
	ok(Retratos.fundo_da_casa({}) == "5e4420",
		"casa sem coroa usa o latão-úmbria próprio")
	ok(Retratos.fundo_da_casa({"jogador": {"rei_de": "imperio"}}) == "1a4a2a",
		"casa coroada herda o fundo do reino tomado")
	var ficha := {"nome": "Teobaldo de Teste", "oficio": "senhor",
		"riqueza": 400, "genero": "m", "lealdade": 60, "lorde": true}
	var neutro: Texture2D = Retratos.textura_cidadao(ficha)
	var com_casa: Texture2D = Retratos.textura_cidadao(ficha, false, "5e4420")
	var pn: Color = neutro.get_image().get_pixel(2, 2)
	var pc: Color = com_casa.get_image().get_pixel(2, 2)
	ok(not pn.is_equal_approx(pc),
		"o fundo de facção muda de fato o retrato do lorde",
		"%s → %s" % [pn.to_html(false), pc.to_html(false)])

	# ---- elenco ilustrado dos cidadãos ----
	# POOL_CIDADAO é um CONTRATO: cada contagem promete arquivos no disco.
	# Contagem maior que a leva = lordes sorteando um busto que não existe
	# e caindo no gerador só para alguns nomes — o elenco vira loteria.
	var faltam_bustos: Array[String] = []
	for arq in Retratos.POOL_CIDADAO:
		for i in int(Retratos.POOL_CIDADAO[arq]):
			var f := "cidadao_%s%d.png" % [arq, i + 1]
			if Retratos._busto_cidadao(f) == null:
				faltam_bustos.append(f)
	ok(faltam_bustos.is_empty(), "o pool de bustos dos cidadãos está completo",
		"faltando: %s" % ("nenhum" if faltam_bustos.is_empty()
			else ", ".join(faltam_bustos)))
	# capturado muda o busto ILUSTRADO (a ferros: dessatura e escurece) — o
	# ramo procedural sempre prometeu isso e o pool completo o desligava
	var n_ferros := {"nome": "Preso Teste", "genero": "m", "oficio": "mercador",
		"lorde": true, "lealdade": 80}
	var img_livre: Image = (Retratos.textura_cidadao(n_ferros) as Texture2D).get_image()
	var n_ferros2: Dictionary = n_ferros.duplicate()
	n_ferros2["capturado"] = true
	var img_presa: Image = (Retratos.textura_cidadao(n_ferros2) as Texture2D).get_image()
	var dif_ferros := 0
	for y_f in img_livre.get_height():
		for x_f in img_livre.get_width():
			if img_livre.get_pixel(x_f, y_f) != img_presa.get_pixel(x_f, y_f):
				dif_ferros += 1
	ok(dif_ferros > 300, "capturado muda o busto ilustrado de verdade (a ferros)",
		"%d px diferentes" % dif_ferros)
	ok(Retratos._arquetipo_de({"genero": "f", "lorde": true}) == "lorde_f"
		and Retratos._arquetipo_de({"oficio": "senhor", "genero": "f"}) == "senhor_m"
		and Retratos._arquetipo_de({"oficio": "alquimista"}) == "mercador_m",
		"o arquétipo resolve gênero, senhor e ofício desconhecido")

	# ---- IA multi-provedor ----
	# O catálogo é um CONTRATO com a interface: todo provedor pago exige
	# chave (senão o aviso de cobrança protegeria ninguém), e o protocolo
	# é um dos três que gerar() sabe falar.
	var Llm = load("res://scripts/llm.gd")
	var cat_ok := true
	for id in Llm.PROVEDORES:
		var p: Dictionary = Llm.PROVEDORES[id]
		if str(p["custo"]) == "pago" and not bool(p["chave"]):
			cat_ok = false
		if not str(p["protocolo"]) in ["", "llama", "openai", "anthropic", "gemini"]:
			cat_ok = false
	ok(cat_ok, "catálogo de provedores: pago exige chave, protocolo conhecido")
	# o RECOMENDADO da primeira saga tem que existir, ser de faixa grátis
	# e ter nota — é ele que o jogador vê pré-selecionado
	var rec: Dictionary = Llm.PROVEDORES.get(Llm.RECOMENDADO, {})
	ok(not rec.is_empty() and str(rec["custo"]) == "gratis_conta"
		and str(rec.get("nota", "")) != "",
		"o provedor recomendado existe, é de faixa grátis e explica por quê")
	ok(Llm._ler_gemini({"candidates": [{"content": {"parts":
		[{"text": "Salve, "}, {"text": "mercenário."}]}}]}) == "Salve, mercenário.",
		"resposta do Gemini concatena as partes de texto")
	ok(Llm._ler_gemini({"candidates": [{"finishReason": "SAFETY", "content": null}]}) == ""
		and Llm._ler_gemini({"promptFeedback": {"blockReason": "SAFETY"}}) == "",
		"resposta bloqueada do Gemini devolve vazio (motor interno assume)")

	# ---- o prompt do turno (bugs de campo dos prints) ----
	# a FALA do jogador chegava vazia ao modelo e não havia memória de
	# conversa: o personagem improvisava no vácuo e repetia a mesma frase
	var Jogo_p = load("res://scripts/jogo.gd")
	var Dialogo_p = load("res://scripts/dialogo.gd")
	var st_p: Dictionary = Jogo_p.novo_jogo("Prompt")
	var npc_p := {"id": "rei_touros", "nome": "Bjorne", "personalidade": "orgulhoso",
		"papel": "rei"}
	var prompt_p: String = Dialogo_p.montar_prompt_llm(st_p, npc_p, "onde consigo trabalho?",
		{"resposta": "Ele mede você com os olhos."},
		[{"quem": "Jogador", "fala": "salve"}, {"quem": "npc", "fala": "Fale logo."}])
	ok(prompt_p.contains("onde consigo trabalho?"),
		"a fala do JOGADOR entra no prompt da IA")
	ok(prompt_p.contains("Fale logo.") and prompt_p.contains("A conversa até agora"),
		"o histórico da conversa entra no prompt (fim do papo em loop)")
	ok(not prompt_p.contains("REGRAS ABSOLUTAS"),
		"as regras do mundo NÃO vão no prompt do turno — vão como sistema")
	var Llm_p = load("res://scripts/llm.gd")
	ok(int(Llm_p.TETO_SAIDA) >= 400,
		"teto de saída generoso: resposta cortada no meio era o defeito antigo")

	# ---- higiene de segurança do build (ver SEGURANCA.md) ----
	# execução de comando e código dinâmico são O gatilho de heurística de
	# antivírus — este jogo não usa nenhum, e este teste tranca a porta.
	# Os dois últimos padrões são de PORTABILIDADE: caminho globalizado de
	# res:// e load_from_file funcionam no editor mas morrem dentro de
	# PCK/APK exportado — a arte sumiria em silêncio no build final.
	var proibidos := ["OS.execute(", "OS.create_process(", "Expression.new(",
		"Image.load_from_file(", "globalize_path(\"res:"]
	var infratores: Array[String] = []
	for pasta in ["res://scripts", "res://cenas"]:
		for arq in DirAccess.get_files_at(pasta):
			if not arq.ends_with(".gd"):
				continue
			var texto := FileAccess.get_file_as_string(pasta + "/" + arq)
			for p in proibidos:
				if texto.contains(str(p)):
					infratores.append(arq + " usa " + str(p))
	ok(infratores.is_empty(),
		"nenhum script usa comando de sistema, código dinâmico ou caminho que morre no export",
		"; ".join(infratores) if not infratores.is_empty() else "")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(presets.contains("company_name=\"FelpsLuz\"")
		and presets.count("encrypt_pck=true") == 4,
		"presets levam a editora FelpsLuz e criptografia de PCK nos 4 alvos")
	ok(presets.contains("permissions/internet=true"),
		"Android declara a permissão de INTERNET — sem ela a IA morre calada no celular")
	ok(presets.contains("platform=\"Linux/X11\"")
		and presets.contains("architectures/arm64-v8a=true"),
		"preset Linux (Steam Deck nativo) existe e o Android mira arm64")
	var gi := FileAccess.get_file_as_string("res://.gitignore")
	ok(gi.contains("export_credentials.cfg"),
		"a chave de criptografia (export_credentials.cfg) nunca sobe no git")
	ok(FileAccess.file_exists("res://icone_jogo.ico")
		and FileAccess.file_exists("res://icone_jogo.png"),
		"o ícone próprio do jogo existe (.ico multi-tamanho e .png)")
	# todo asset lido CRU em runtime precisa do sidecar importer="keep":
	# sem ele o editor importa o arquivo e o exportador empacota SÓ a
	# versão importada — o APK/PCK final ficaria sem música, sem SFX e sem
	# a arte hi-bit (descoberto num export Android real; include_filter
	# NÃO vence o sidecar)
	var sem_keep: Array[String] = []
	for par: Array in [["res://assets/audio", "mp3"],
			["res://assets/audio/musica_jogo", "mp3"],
			["res://assets/audio/sfx", "wav"],
			["res://assets/sprites/hibit", "png"]]:
		for arq in DirAccess.get_files_at(str(par[0])):
			if not arq.ends_with("." + str(par[1])):
				continue
			var side := FileAccess.get_file_as_string(str(par[0]) + "/" + arq + ".import")
			if not side.contains("importer=\"keep\""):
				sem_keep.append(arq)
	ok(sem_keep.is_empty(),
		"todo asset cru de runtime leva importer=\"keep\" — senão o export perde ele",
		"; ".join(sem_keep) if not sem_keep.is_empty() else "")
	ok(bool(ProjectSettings.get_setting(
		"rendering/textures/vram_compression/import_etc2_astc", false)),
		"ETC2/ASTC declarado no projeto — o exportador Android exige")
	Llm._cfg = {"provedor": "desligado", "url": "", "chave": "", "modelo": ""}
	ok(not Llm.ativa(), "provedor desligado nunca ativa")
	Llm._cfg = {"provedor": "anthropic", "url": "https://api.anthropic.com/v1",
		"chave": "", "modelo": ""}
	ok(not Llm.ativa(), "provedor pago SEM chave não ativa — sem cobrança surpresa")
	Llm._cfg["chave"] = "chave-de-teste"
	ok(Llm.ativa() and Llm.url() != "",
		"com chave ativa, e o gate antigo (url) continua enxergando")
	Llm._cfg = {"provedor": "local", "url": "http://localhost:8080",
		"chave": "", "modelo": ""}
	ok(Llm.ativa(), "IA local ativa sem chave — grátis é grátis")
	ok(Llm._ler_anthropic({"stop_reason": "refusal",
		"content": [{"type": "text", "text": "x"}]}) == "",
		"recusa de segurança devolve vazio (motor interno assume a fala)")
	ok(Llm._ler_anthropic({"stop_reason": "end_turn",
		"content": [{"type": "text", "text": "Salve, mercenário."}]}) == "Salve, mercenário.",
		"resposta da Anthropic lê os blocos de texto")
	ok(Llm._ler_openai({"choices": [{"message": {"content": "Oi."}}]}) == "Oi.",
		"resposta compatível-OpenAI lê choices[0].message")
	Llm._cfg = {}
