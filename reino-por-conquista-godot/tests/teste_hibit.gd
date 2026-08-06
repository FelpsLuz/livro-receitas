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
	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)


# ------------------------------------------------------------
func _frente1() -> void:
	# ---- MODO DE INTERFACE ----
	# A asserção inverteu junto com a direção. Ela cobrava "viewport" +
	# "keep" + "integer", que é a receita para proteger uma GRADE DE PIXEL:
	# tudo renderizado em 960×540 e ampliado em múltiplo inteiro.
	#
	# Só que a tela deste jogo é dez abas de tabela, e nessa receita cada
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
		# monoespaçada: a coluna de preço alinha sozinha. Se o "1" e o "8"
		# tiverem larguras diferentes, a tabela desalinha e ninguém compara
		# 1.240 com 980 na vertical.
		var l1 := num.get_string_size("1", 0, -1, 16).x
		var l8 := num.get_string_size("8", 0, -1, 16).x
		var lw := num.get_string_size("W", 0, -1, 16).x
		ok(is_equal_approx(l1, l8) and is_equal_approx(l1, lw),
			"fonte de número é MONOESPAÇADA",
			"1=%.1f 8=%.1f W=%.1f" % [l1, l8, lw])
	if corpo != null:
		# prosa em monoespaçada lê como terminal: o corpo TEM que ser
		# proporcional, senão a diferença entre as duas some
		var i_l := corpo.get_string_size("i", 0, -1, 16).x
		var m_l := corpo.get_string_size("M", 0, -1, 16).x
		ok(m_l > i_l * 1.8, "fonte de texto é PROPORCIONAL",
			"i=%.1f M=%.1f" % [i_l, m_l])
		ok(corpo.get_string_size("ÇÃÕáéíóúâêô", 0, -1, 16).x > 0,
			"acentuação do português coberta")
	ok(Tema.NUMERO > Tema.MICRO and Tema.TITULO_SECAO > Tema.CORPO
		and Tema.TITULO_JOGO > Tema.TITULO_SECAO,
		"escala tipográfica é monotônica",
		"%d < %d < %d < %d" % [Tema.MICRO, Tema.CORPO, Tema.TITULO_SECAO,
			Tema.TITULO_JOGO])
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
