# ============================================================
# PANORAMA — a vila vista de FRENTE, em camadas, com EVOLUÇÃO.
#
# A referência do usuário é uma cena em elevação: céu, serra, floresta,
# muralha, castelo, vila viva e um rio com ponte alinhada ao portão. Esta
# cena a reproduz como PILHA de camadas — e a pilha é o que torna a evolução
# barata: subir de nível troca PEÇAS, não regenera a ilustração.
#
#   nível 0  acampamento   tendas, fogueira, árvores
#   nível 1  vila          paliçada de madeira, casas de sapê, horta, poço
#   nível 2  vila grande   moinho de MADEIRA, feira (tendas listradas),
#                          campo de treino, barraca, bichos
#   nível 3  cidade        a paliçada vira MURALHA DE PEDRA, ferraria,
#                          estábulo com cavalo
#   nível 4  cidade murada o campo de treino vira ACADEMIA de pedra, o
#                          moinho vira o de PEDRA, surge o TORREÃO e o
#                          sobrado de telhado vermelho
#   nível 5  castelo       o torreão vira o CASTELO da referência
#
# A luz é a da referência: quente, dourada, viva. Por isso estas camadas NÃO
# passam pelo requantizador de 48 cores da UI — o teto de croma de lá lavava
# a cena. A perspectiva atmosférica (longe = mais claro e menos saturado) é
# aplicada AQUI, por `modulate`, calibrável sem gastar crédito.
#
# Escala: arte de 400×180 desenhada a 2× exatos (800×360). Todo número de
# posição está em PIXELS DE ARTE. Peças com `p="pan"` são desenhadas 1:1;
# as de `p="obj"` vêm de assets_v2/objects e trazem a própria escala.
# ============================================================
extends SubViewportContainer

const PASTA := "res://assets_v2/panorama/"
const OBJETOS := "res://assets_v2/objects/"
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const Vfx = preload("res://scripts/vfx.gd")

const ARTE := Vector2i(400, 180)
const ESCALA := 2

## Linhas de apoio (base de cada faixa), derivadas da referência: o horizonte
## no terço de cima, a muralha em ~62% da altura, o rio nos últimos 26px.
const BASE_SERRA_LONGE := 104
const BASE_SERRA_PERTO := 112
const BASE_FLORESTA := 122
const BASE_MURO := 112
const Y_RIO := 154          # topo da faixa de água
const ALTURA_RIO := 26

## Perspectiva atmosférica: fração de mistura com a cor do ar, por camada.
const AR := Color("9cc0da")
const NEBLINA := {"serra_longe": 0.24, "serra_perto": 0.10, "floresta": 0.04}

## A vila, peça a peça: sprite, x (centro), y (base), escala, nível em que
## ENTRA e nível em que SAI (a peça que evolui dá lugar à sucessora).
##   p = "pan" (1:1, gerada para o panorama) ou "obj" (assets_v2/objects)
const PECAS := [
	# --- natureza, sempre ---
	{"p": "obj", "n": "arvore_carvalho", "x": 16, "y": 136, "e": 0.26, "de": 0},
	{"p": "obj", "n": "arvore_pinheiro", "x": 388, "y": 134, "e": 0.28, "de": 0},
	{"p": "obj", "n": "arvore_pinheiro", "x": 44, "y": 128, "e": 0.22, "de": 0},

	# --- nível 0: o acampamento do mercenário ---
	{"p": "obj", "n": "tenda_simples", "x": 150, "y": 142, "e": 0.26, "de": 0, "ate": 1},
	{"p": "obj", "n": "fogueira_acampamento", "x": 180, "y": 146, "e": 0.18, "de": 0, "ate": 2},
	{"p": "obj", "n": "tenda_grande", "x": 250, "y": 144, "e": 0.24, "de": 0, "ate": 0},

	# --- nível 1: a vila nasce ---
	{"p": "obj", "n": "casa_camponesa", "x": 92, "y": 140, "e": 0.26, "de": 1},
	{"p": "obj", "n": "casa_camponesa", "x": 280, "y": 142, "e": 0.24, "de": 1},
	{"p": "obj", "n": "poco_pedra", "x": 228, "y": 140, "e": 0.20, "de": 1},
	{"p": "pan", "n": "pan_horta", "x": 118, "y": 152, "e": 1.0, "de": 1},
	{"p": "pan", "n": "pan_galinha", "x": 138, "y": 150, "e": 1.0, "de": 1},

	# --- nível 2: vila grande — feira, moinho de madeira, treino ---
	{"p": "pan", "n": "pan_moinho_madeira", "x": 54, "y": 128, "e": 1.0, "de": 2, "ate": 3},
	{"p": "pan", "n": "pan_tenda_circo", "x": 162, "y": 150, "e": 1.0, "de": 2},
	{"p": "pan", "n": "pan_tenda_verde", "x": 248, "y": 152, "e": 1.0, "de": 2},
	{"p": "obj", "n": "barraca_mercado", "x": 192, "y": 142, "e": 0.22, "de": 2},
	{"p": "pan", "n": "pan_academia_treino", "x": 332, "y": 146, "e": 1.0, "de": 2, "ate": 3},
	{"p": "pan", "n": "pan_horta", "x": 306, "y": 154, "e": 1.0, "de": 2},
	{"p": "pan", "n": "pan_porco", "x": 262, "y": 148, "e": 1.0, "de": 2},
	{"p": "obj", "n": "carroca", "x": 70, "y": 148, "e": 0.20, "de": 2},

	# --- nível 3: cidade — pedra, ferro e cavalos ---
	{"p": "obj", "n": "ferraria", "x": 300, "y": 136, "e": 0.24, "de": 3},
	{"p": "pan", "n": "pan_estabulo", "x": 354, "y": 140, "e": 1.0, "de": 3},
	{"p": "pan", "n": "pan_cavalo", "x": 342, "y": 152, "e": 1.0, "de": 3},

	# --- nível 4: cidade murada — academia, moinho de pedra, sobrado ---
	{"p": "pan", "n": "pan_academia_pedra", "x": 332, "y": 144, "e": 1.0, "de": 4},
	{"p": "obj", "n": "moinho_vento", "x": 54, "y": 130, "e": 0.28, "de": 4},
	{"p": "pan", "n": "pan_casa_vermelha", "x": 120, "y": 148, "e": 1.0, "de": 4},
]

var viewport: SubViewport
var mundo: Node2D
var _nivel_montado := -99
var _mes_montado := -99
var _rng := RandomNumberGenerator.new()

var estado: Dictionary = {}:
	set(v):
		estado = v
		_montar()

## Sem as camadas no disco, principal.gd continua com a vila antiga — o jogo
## nunca fica sem cenário.
static func disponivel() -> bool:
	for n in ["pan_ceu_dia", "pan_campo_verao", "pan_rio", "pan_castelo"]:
		if not ResourceLoader.exists(PASTA + n + ".png"):
			return false
	return true

static func _tex(nome: String) -> Texture2D:
	var c := PASTA + nome + ".png"
	if not ResourceLoader.exists(c):
		return null
	var t = load(c)
	return t if t is Texture2D else null

func _init() -> void:
	stretch = false
	custom_minimum_size = Vector2(ARTE.x * ESCALA, ARTE.y * ESCALA)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	viewport = SubViewport.new()
	viewport.size = ARTE * ESCALA
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	mundo = Node2D.new()
	mundo.name = "Mundo"
	mundo.scale = Vector2(ESCALA, ESCALA)
	viewport.add_child(mundo)

## Sprite ancorado pelo topo-esquerda, com recorte opcional e cor do ar.
func _sprite(nome: String, pos: Vector2, neblina: float = 0.0,
		recorte: Rect2 = Rect2()) -> Sprite2D:
	var t := _tex(nome)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.name = nome
	s.texture = t
	s.centered = false
	if recorte.size.x > 0:
		s.region_enabled = true
		s.region_rect = recorte
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if neblina > 0.0:
		s.modulate = Color(
			lerpf(1.0, AR.r + 0.22, neblina),
			lerpf(1.0, AR.g + 0.22, neblina),
			lerpf(1.0, AR.b + 0.22, neblina))
	mundo.add_child(s)
	return s

func _montar() -> void:
	var nivel: int = 0
	if estado.get("terra") != null:
		nivel = int(estado["terra"].get("nivel", 0))
	var mes: int = int(estado.get("mes", 6))
	if nivel == _nivel_montado and mes == _mes_montado:
		return
	_nivel_montado = nivel
	_mes_montado = mes
	for f in mundo.get_children():
		f.queue_free()
	_rng.seed = 20260805

	var estacao := _estacao(mes)

	# ---- fundo ----
	_sprite(_variante("pan_ceu", estacao, "dia"), Vector2.ZERO)
	var sol := _tex("pan_sol")
	if sol != null and estacao != "inverno":
		_sprite("pan_sol", Vector2(ARTE.x - 70, 10))
	_sprite("pan_montanha_longe",
		Vector2(0, BASE_SERRA_LONGE - 60), NEBLINA["serra_longe"])
	_sprite("pan_montanha_perto",
		Vector2(0, BASE_SERRA_PERTO - 60), NEBLINA["serra_perto"])
	var flor := _variante("pan_floresta", estacao, "verao")
	_sprite(flor, Vector2(0, BASE_FLORESTA - 44), NEBLINA["floresta"])

	# ---- a defesa evolui: paliçada → muralha ----
	if nivel >= 3:
		_sprite("pan_muralha", Vector2(0, BASE_MURO - 44 + 12))
	elif nivel >= 1:
		_sprite("pan_palicada", Vector2(0, BASE_MURO - 32 + 8))

	# ---- a sede evolui: nada → torreão → castelo ----
	if nivel >= 5:
		var cas := _tex("pan_castelo")
		if cas != null:
			_sprite("pan_castelo", Vector2(
				(ARTE.x - cas.get_width()) / 2.0, BASE_MURO + 2 - cas.get_height()))
	elif nivel == 4:
		var tor := _tex("pan_torreao")
		if tor != null:
			_sprite("pan_torreao", Vector2(
				(ARTE.x - tor.get_width()) / 2.0, BASE_MURO + 2 - tor.get_height()))

	# ---- campo ----
	# o topo da arte do campo tem copas de árvore: o recorte pula essa parte
	var campo := _variante("pan_campo", estacao, "verao")
	_sprite(campo, Vector2(0, BASE_MURO - 4), 0.0, Rect2(0, 14, 400, 50))

	# ---- caminho do portão à ponte ----
	# recorte do miolo da arte (o topo dela veio com cenário); as bordas de
	# grama do recorte se fundem no campo
	_sprite("pan_caminho", Vector2(ARTE.x / 2.0 - 22, BASE_MURO + 2),
		0.0, Rect2(0, 30, 44, 22))

	# ---- a vila, peça a peça, na ordem de profundidade ----
	var lista: Array = PECAS.filter(func(c):
		return nivel >= int(c["de"]) and nivel <= int(c.get("ate", 99)))
	lista.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]))
	for c in lista:
		_peca(c)

	# ---- aldeões ----
	_aldeoes(mini(2 + nivel * 2, 10))

	# ---- rio na frente, ponte alinhada ao portão ----
	_sprite("pan_rio", Vector2(0, Y_RIO), 0.0,
		Rect2(0, 4, 400, ALTURA_RIO + 8))
	var ponte := _tex("pan_ponte")
	if ponte != null:
		_sprite("pan_ponte", Vector2(
			(ARTE.x - ponte.get_width()) / 2.0, ARTE.y - ponte.get_height() + 4))

func _peca(c: Dictionary) -> void:
	var t: Texture2D = null
	var e := float(c["e"])
	if str(c["p"]) == "pan":
		t = _tex(str(c["n"]))
	else:
		var caminho := OBJETOS + str(c["n"]) + ".png"
		if ResourceLoader.exists(caminho):
			var carr = load(caminho)
			if carr is Texture2D:
				t = carr
	if t == null:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.scale = Vector2(e, e)
	s.position = Vector2(float(c["x"]) - t.get_width() * e * 0.5,
		float(c["y"]) - t.get_height() * e)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mundo.add_child(s)
	# sombra projetada na mesma direção do resto do jogo
	var sombra := Vfx.sombra_projetada(t, 0.20)
	if sombra != null:
		sombra.offset = Vector2(0, 0)
		sombra.position = Vector2(t.get_width() / 2.0, t.get_height())
		s.add_child(sombra)

func _aldeoes(quantos: int) -> void:
	var elenco := ["tropa_campones", "tropa_lanceiro", "taverneiro",
		"tropa_espadachim", "heroi_jogador", "tropa_arqueiro"]
	for i in quantos:
		var no: AnimatedSprite2D = PersonagensV2.criar(elenco[i % elenco.size()], 0.14)
		if no == null:
			continue
		no.position = Vector2(30.0 + _rng.randf() * (ARTE.x - 60.0),
			136.0 + _rng.randf() * 16.0)
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mundo.add_child(no)

## "pan_campo" + "inverno" → o PNG da estação, com o verão de reserva.
func _variante(base: String, estacao: String, padrao: String) -> String:
	if _tex(base + "_" + estacao) != null:
		return base + "_" + estacao
	return base + "_" + padrao

static func _estacao(mes: int) -> String:
	var m: int = ((mes - 1) % 12 + 12) % 12 + 1
	if m in [12, 1, 2]:
		return "inverno"
	if m in [9, 10, 11]:
		return "outono"
	if m in [3, 4, 5]:
		return "verao"      # primavera usa a arte de verão até ter a própria
	return "verao"

## Mesma API da vila antiga, para principal.gd trocar uma pela outra sem saber.
func semear_npcs() -> void:
	_nivel_montado = -99
	_montar()
