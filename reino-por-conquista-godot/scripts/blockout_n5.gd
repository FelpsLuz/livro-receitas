# ============================================================
# BLOCKOUT N5 — greybox antes de asset (addendum v3.3 §B).
# ColorRects cinza no tamanho previsto de cada peça, por cima da placa
# corrigida, no SubViewport real. Serve para responder às três perguntas
# da §B.2 ANTES de gastar API: colisão do castelo, leitura de povoado, e
# silhueta com a vila completa.
# `castelo_cx` é parâmetro justamente para comparar a posição ingênua
# (centro) com a medida — é a resposta visual da §B.2 pergunta 1.
# ============================================================
class_name BlockoutN5
extends Node2D

const PLACA := "res://assets_v2/cenario/base/placa_base.png"

const CINZA_CONSTRUCAO := Color(0.62, 0.62, 0.60)
const CINZA_MURALHA := Color(0.70, 0.70, 0.68)
const CINZA_CASTELO := Color(0.80, 0.80, 0.78)   # o mais claro: é o sujeito
const CINZA_NATUREZA := Color(0.42, 0.48, 0.40)
const COR_ALDEAO := Color(0.95, 0.55, 0.25)
const COR_TRILHA := Color(0.78, 0.68, 0.50)

var nivel := 5
var castelo_cx := LayoutN5.CASTELO["cx"]
var silhueta := false
var mostrar_fundo := true


func _ready() -> void:
	montar()


func montar() -> void:
	for f in get_children():
		f.queue_free()

	if silhueta:
		var branco := ColorRect.new()
		branco.size = Vector2(Bandas.CANVAS_W, Bandas.CANVAS_H)
		branco.color = Color.WHITE
		add_child(branco)
	elif mostrar_fundo:
		var placa := Sprite2D.new()
		placa.texture = load(PLACA)
		placa.centered = false
		placa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(placa)
	else:
		# modo PLANTA: fundo neutro com as bandas marcadas, para conferir
		# traçado de trilha e agrupamento sem a placa competindo
		var fundo := ColorRect.new()
		fundo.size = Vector2(Bandas.CANVAS_W, Bandas.CANVAS_H)
		fundo.color = Color(0.13, 0.14, 0.16)
		add_child(fundo)
		var claro := true
		for nome in Bandas.FATIAS:
			var f: Vector2i = Bandas.FATIAS[nome]
			var faixa := ColorRect.new()
			faixa.position = Vector2(0, f.x)
			faixa.size = Vector2(Bandas.CANVAS_W, f.y - f.x)
			faixa.color = Color(0.20, 0.22, 0.24) if claro \
					else Color(0.16, 0.18, 0.20)
			add_child(faixa)
			claro = not claro

	# ---- trilhas primeiro: ficam no chão, sob tudo ----
	for pt in LayoutN5.RAMAIS:
		_traco(pt, 3)
	_traco(LayoutN5.TRILHA, 5)
	_bloco(LayoutN5.PRACA["cx"], LayoutN5.PRACA["base"],
			LayoutN5.PRACA["w"], LayoutN5.PRACA["h"], COR_TRILHA, 0)
	_bloco(LayoutN5.PONTE["cx"], LayoutN5.PONTE["base"],
			LayoutN5.PONTE["w"], LayoutN5.PONTE["h"], COR_TRILHA, 0)

	# ---- castelo e muralha (nível 4+/5), atrás da vila ----
	if nivel >= 5:
		var c: Dictionary = LayoutN5.CASTELO
		_bloco(castelo_cx, c["base"], c["w"], c["h"], CINZA_CASTELO, 1)
	if nivel >= 4:
		var topo: int = Bandas.BANDAS["muralha"].x
		_bloco(Bandas.CANVAS_W / 2, topo + LayoutN5.MURALHA_ALTURA,
				Bandas.CANVAS_W, LayoutN5.MURALHA_ALTURA, CINZA_MURALHA, 2)
		for tx in LayoutN5.TORRES:
			_bloco(tx, topo + LayoutN5.MURALHA_ALTURA + 2, 16,
					LayoutN5.TORRE_ALTURA, CINZA_MURALHA, 3)
		var p: Dictionary = LayoutN5.PORTAO
		_bloco(castelo_cx, p["base"], p["w"], p["h"],
				CINZA_CASTELO.darkened(0.35), 3)

	# ---- peças da vila, DESENHADAS POR Y CRESCENTE (spec §5) ----
	var pecas: Array = LayoutN5.pecas_do_nivel(nivel)
	pecas.sort_custom(func(a, b): return int(a["base"]) < int(b["base"]))
	for i in pecas.size():
		var pc: Dictionary = pecas[i]
		var natureza: bool = String(pc["n"]).begins_with("arvore")
		_bloco(pc["cx"], pc["base"], pc["w"], pc["h"],
				CINZA_NATUREZA if natureza else CINZA_CONSTRUCAO, 4 + i)

	# ---- aldeões: a régua de escala (6×10) ----
	var quantos: int = LayoutN5.ALDEOES_POR_NIVEL[clampi(nivel, 0, 5)]
	for i in mini(quantos, LayoutN5.ALDEOES.size()):
		var a: Vector2i = LayoutN5.ALDEOES[i]
		_bloco(a.x, a.y, 6, 10, COR_ALDEAO, 60 + i)


func _bloco(cx: int, base: int, w: int, h: int, cor: Color, z: int) -> void:
	var r := ColorRect.new()
	r.position = Vector2(cx - w / 2.0, base - h)
	r.size = Vector2(w, h)
	r.color = Color.BLACK if silhueta else cor
	r.z_index = z
	add_child(r)


func _traco(pontos: Array, largura: int) -> void:
	var l := Line2D.new()
	for p in pontos:
		l.add_point(Vector2(p.x, p.y))
	l.width = largura
	l.default_color = Color.BLACK if silhueta else COR_TRILHA
	l.z_index = 0
	add_child(l)
