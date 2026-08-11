# ============================================================
# O MAPA-MÚNDI CLICÁVEL.
#
# O grafo de estradas existia desde a Fase 3, mas só como texto: "Seu
# acampamento → Ursos de Ferro → Império Central". Uma rede que ninguém
# vê não é um mapa, é uma tabela — e o jogador não tinha como sentir que
# o Império é o gargalo do continente.
#
# Aqui o MESMO grafo (dados.gd ROTAS) vira desenho: cada estrada é uma
# linha cuja cor conta o perigo dela, cada reino é um domínio na cor da
# própria casa, e clicar num deles abre a viagem.
#
# Desenhado em CÓDIGO, não gerado: uma ilustração de pergaminho custaria
# arte nova e envelheceria mal quando o mapa mudasse. Linha e disco
# acompanham o grafo sozinhos — nó novo aparece só de existir na tabela.
# ============================================================
extends Control

const Dados = preload("res://scripts/dados.gd")
const Rotas = preload("res://scripts/rotas.gd")
const Tema = preload("res://scripts/tema.gd")
const Retratos = preload("res://scripts/retratos.gd")

signal reino_clicado(id: String)

## Onde cada domínio fica, em coordenadas de 0 a 1 sobre a área do mapa.
##
## O layout não é decorativo: as doze estradas de dados.gd formam um grafo
## cúbico (oito nós, todos com três vizinhos) que fecha em DOIS anéis de
## quatro ligados por quatro raios. Desenhado assim — anel interno, anel
## externo, raios alinhados — NENHUMA estrada cruza outra.
##
## A primeira tentativa foi geográfica, seguindo a referência, e virou um
## novelo de seis cruzamentos: bonito de intenção, ilegível na prática. A
## verdade deste mundo é a rede, não a cartografia — e a rede diz que o
## Império e os Ursos são o miolo por onde tudo passa, e que o Reino sem
## Rei e as Garças são a borda onde a lei não chega.
const POSICOES := {
	# anel interno — o coração do continente
	"touros":    Vector2(0.44, 0.32),
	"imperio":   Vector2(0.68, 0.32),
	"alvorecer": Vector2(0.68, 0.68),
	"jogador":   Vector2(0.44, 0.68),
	# anel externo — cada um no raio do seu vizinho de dentro
	"rosa":      Vector2(0.25, 0.13),
	"leoes":     Vector2(0.91, 0.13),
	"aguias":    Vector2(0.91, 0.87),
	"sem_rei":   Vector2(0.25, 0.87),
	# ALÉM da borda: a fronteira selvagem só toca as duas pontas sem lei, e
	# fica FORA da linha que as une — é o que mantém o desenho sem cruzar
	"barbaros":  Vector2(0.055, 0.50),
}

const RAIO_DOMINIO := 30.0
const RAIO_NO := 7.0

var state: Dictionary = {}
var _botoes: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 340)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_posicionar)

func montar(novo_estado: Dictionary) -> void:
	state = novo_estado
	for id in POSICOES:
		if _botoes.has(id):
			continue
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", Tema.MICRO)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): reino_clicado.emit(str(id)))
		add_child(b)
		_botoes[id] = b
	_posicionar()
	queue_redraw()

func _pos_de(id: String) -> Vector2:
	var p: Vector2 = POSICOES.get(id, Vector2(0.5, 0.5))
	# margem interna: o disco do domínio não pode encostar na borda
	return Vector2(48.0 + p.x * (size.x - 96.0), 34.0 + p.y * (size.y - 68.0))

func _posicionar() -> void:
	if state.is_empty():
		return
	for id in _botoes:
		var b: Button = _botoes[id]
		b.text = Rotas.nome_do(state, str(id))
		var aqui: bool = str(state.get("local", "")) == str(id)
		b.add_theme_color_override("font_color",
			Tema.ACENTO if aqui else Tema.TEXTO_2)
		b.tooltip_text = "Clique para viajar até %s" % b.text
		if str(id) == "jogador":
			b.tooltip_text = "Suas terras"
		b.size = Vector2(150, 22)
		var p := _pos_de(str(id))
		# rótulo ACIMA nos nós da metade de cima e abaixo nos de baixo: no
		# meio do caminho ele encostava no domínio vizinho
		var acima: bool = POSICOES[id].y < 0.5
		b.position = Vector2(p.x - 75.0,
			p.y - RAIO_DOMINIO - 22.0 if acima else p.y + RAIO_DOMINIO + 4.0)
	queue_redraw()

## Cor da casa — a mesma heráldica dos retratos, para o mapa e a corte
## falarem a mesma língua. Sem rei conhecido, cinza de terra de ninguém.
func _cor_do_dominio(id: String) -> Color:
	var ficha = Retratos.REIS.get("rei_" + id)
	if ficha is Dictionary and str(ficha.get("fundo", "")) != "":
		return Color(str(ficha["fundo"]))
	if id == "jogador":
		return Tema.ACENTO
	return Color("4a4640")

func _draw() -> void:
	if state.is_empty():
		return
	# ---- o chão do mapa ----
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Tema.ELEVADO, true)
	draw_rect(r, Tema.BORDA, false, 2.0)

	# ---- as estradas, ANTES dos domínios: linha passa por baixo ----
	# a cor conta o perigo do trecho, que é a informação que o jogador
	# usa para decidir se vale a volta mais longa
	for chave in Dados.ROTAS:
		var partes: PackedStringArray = _partes(str(chave))
		if partes.size() != 2:
			continue
		if not POSICOES.has(partes[0]) or not POSICOES.has(partes[1]):
			continue
		var trecho: Dictionary = Dados.ROTAS[chave]
		var perigo: float = float(trecho.get("perigo", 0.1))
		var cor := Color("6b5b3e").lerp(Color("a8503a"), clampf(perigo / 0.28, 0.0, 1.0))
		draw_line(_pos_de(partes[0]), _pos_de(partes[1]), cor, 2.0, true)

	# ---- os domínios ----
	for id in POSICOES:
		var p := _pos_de(str(id))
		var cor := _cor_do_dominio(str(id))
		draw_circle(p, RAIO_DOMINIO, Color(cor.r, cor.g, cor.b, 0.30))
		var dominado := false
		for reino in state.get("reinos", []):
			if str(reino["id"]) == str(id) and str(reino.get("dominado_por", "")) != "":
				dominado = true
		# o nó: disco cheio na cor da casa, anel escuro por fora
		draw_circle(p, RAIO_NO, cor)
		draw_arc(p, RAIO_NO + 1.5, 0.0, TAU, 20, Tema.FUNDO, 2.0, true)
		if dominado:
			# corrente do conquistador: o domínio some do jogo político
			draw_line(p - Vector2(RAIO_NO, RAIO_NO), p + Vector2(RAIO_NO, RAIO_NO),
				Tema.PERIGO, 2.0, true)
			draw_line(p - Vector2(-RAIO_NO, RAIO_NO), p + Vector2(-RAIO_NO, RAIO_NO),
				Tema.PERIGO, 2.0, true)

	# ---- ONDE VOCÊ ESTÁ: o anel que responde à pergunta de sempre ----
	var aqui: String = str(state.get("local", ""))
	if POSICOES.has(aqui):
		draw_arc(_pos_de(aqui), RAIO_DOMINIO - 4.0, 0.0, TAU, 36, Tema.ACENTO, 2.0, true)

func _partes(chave: String) -> PackedStringArray:
	# as chaves são "a_b" e os ids podem ter underscore ("sem_rei"): o
	# corte certo é o que produz DOIS nós conhecidos
	for i in chave.length():
		if chave[i] != "_":
			continue
		var a := chave.substr(0, i)
		var b := chave.substr(i + 1)
		if POSICOES.has(a) and POSICOES.has(b):
			return PackedStringArray([a, b])
	return PackedStringArray()
