# ============================================================
# PANORAMA — a vila vista de FRENTE, em camadas empilhadas.
#
# Substitui a vila em TileMapLayer vista de cima. Não é troca de gosto: uma
# vista de cima não consegue mostrar céu, serra ao fundo e muralha ao mesmo
# tempo, e é isso que faz a tela parecer um mundo em vez de um tabuleiro.
#
# A pilha, de trás para a frente:
#   0 céu        1 sol        2 serra distante   3 serra próxima
#   4 floresta   5 muralha    6 castelo          7 campo
#   8 construções da vila     9 aldeões          10 rio + ponte
#
# O que NÃO é gerado por IA
# -------------------------
# A perspectiva atmosférica — quanto mais longe, menos saturado e mais claro —
# é aplicada aqui, com `modulate` por camada. Pedir isso ao modelo daria um
# resultado diferente a cada geração; um multiplicador de cor dá o mesmo
# sempre e é calibrável sem gastar crédito.
#
# Escala
# ------
# A arte vive numa tela de 400x144 e é desenhada a 2x, exatos 800x288. Fator
# inteiro: meio pixel de escala é o que faz pixel art tremer. Todo número de
# posição neste arquivo está em PIXELS DE ARTE, não de tela.
# ============================================================
extends SubViewportContainer

const PASTA := "res://assets_v2/panorama/"
const OBJETOS := "res://assets_v2/objects/"
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const Vfx = preload("res://scripts/vfx.gd")

const ARTE := Vector2i(400, 144)
const ESCALA := 2

## Onde a base de cada faixa se apoia, em Y de arte. Estes números vêm da
## composição da referência: o horizonte fica no terço superior, a muralha
## corta a floresta, e o rio ocupa a faixa da frente.
const Y_SERRA_LONGE := 46
const Y_SERRA_PERTO := 58
const Y_FLORESTA := 78
const Y_MURALHA := 88
const Y_CASTELO := 92
const Y_CAMPO := 100
const Y_RIO := 144
## Altura da faixa de rio DESENHADA (a arte é mais alta de propósito).
const ALTURA_RIO := 30

## Perspectiva atmosférica: multiplicador de cor por distância. O céu é a cor
## para a qual tudo longe converge, então a serra distante recebe quase a cor
## do céu e o primeiro plano não recebe nada.
const AR := Color("8fb4cf")
const NEBLINA := {
	"serra_longe": 0.30, "serra_perto": 0.16, "floresta": 0.07,
	"muralha": 0.04, "castelo": 0.0, "campo": 0.0,
}

## As construções da vila, em pixels de ARTE: x, base y, escala e a partir de
## que nível da terra cada uma aparece. A vila cresce sem gerar arte nova.
const CONSTRUCOES := [
	{"n": "moinho_vento", "x": 46, "y": 118, "e": 0.30, "nivel": 2},
	{"n": "casa_camponesa", "x": 96, "y": 120, "e": 0.26, "nivel": 1},
	{"n": "tenda_simples", "x": 138, "y": 121, "e": 0.24, "nivel": 0},
	{"n": "barraca_mercado", "x": 172, "y": 121, "e": 0.24, "nivel": 2},
	{"n": "casa_camponesa", "x": 246, "y": 119, "e": 0.24, "nivel": 1},
	{"n": "ferraria", "x": 286, "y": 118, "e": 0.28, "nivel": 3},
	{"n": "barraca_mercado", "x": 226, "y": 122, "e": 0.22, "nivel": 2},
	{"n": "casa_camponesa", "x": 330, "y": 120, "e": 0.26, "nivel": 1},
	{"n": "poco_pedra", "x": 200, "y": 122, "e": 0.22, "nivel": 1},
	{"n": "carroca", "x": 66, "y": 122, "e": 0.22, "nivel": 2},
	{"n": "arvore_carvalho", "x": 20, "y": 118, "e": 0.28, "nivel": 0},
	{"n": "arvore_pinheiro", "x": 372, "y": 116, "e": 0.30, "nivel": 0},
	{"n": "fogueira_acampamento", "x": 154, "y": 123, "e": 0.20, "nivel": 0},
]

var viewport: SubViewport
var mundo: Node2D
var camadas: Dictionary = {}
var _nivel_montado := -99
var _rng := RandomNumberGenerator.new()

var estado: Dictionary = {}:
	set(v):
		estado = v
		_montar()

## O panorama só existe com as camadas no disco; sem elas principal.gd
## continua com a vila de cima, e o jogo nunca fica sem cenário.
static func disponivel() -> bool:
	for n in ["pan_ceu_dia", "pan_campo_verao", "pan_castelo", "pan_rio"]:
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

## Uma camada de fundo: sprite ancorado pelo TOPO-ESQUERDA, na cor do ar.
func _faixa(nome: String, y: int, neblina: float = 0.0) -> Sprite2D:
	var t := _tex(nome)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.name = nome
	s.texture = t
	s.centered = false
	s.position = Vector2(0, y)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = _com_ar(neblina)
	mundo.add_child(s)
	camadas[nome] = s
	return s

## A cor da perspectiva atmosférica: mistura com o ar e perde contraste.
static func _com_ar(f: float) -> Color:
	if f <= 0.0:
		return Color.WHITE
	# `modulate` MULTIPLICA, então não dá para clarear com ele sozinho. O que
	# dá é puxar cada canal na direção da cor do ar sem passar de 1.0 — o
	# efeito é o mesmo que o olho lê como "mais longe": menos contraste e
	# matiz puxado para o céu.
	return Color(
		lerpf(1.0, AR.r + 0.25, f),
		lerpf(1.0, AR.g + 0.25, f),
		lerpf(1.0, AR.b + 0.25, f))

func _montar() -> void:
	var nivel: int = 0
	if estado.get("terra") != null:
		nivel = int(estado["terra"].get("nivel", 0))
	var mes: int = int(estado.get("mes", 6))
	if nivel == _nivel_montado and camadas.has("mes") and camadas["mes"] == mes:
		return
	_nivel_montado = nivel
	for f in mundo.get_children():
		f.queue_free()
	camadas.clear()
	camadas["mes"] = mes
	_rng.seed = 20260805

	var estacao := _estacao(mes)

	# 0. céu ocupa tudo por trás
	_faixa(_ceu_de(estacao), 0)

	# 1. sol no canto superior direito, como na referência
	var sol := _tex("pan_sol")
	if sol != null:
		var s := Sprite2D.new()
		s.texture = sol
		s.centered = false
		s.position = Vector2(ARTE.x - 74, 12)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mundo.add_child(s)

	# 2-4. serras e floresta, cada uma com mais ar que a seguinte
	_faixa("pan_montanha_longe", Y_SERRA_LONGE, NEBLINA["serra_longe"])
	_faixa("pan_montanha_perto", Y_SERRA_PERTO, NEBLINA["serra_perto"])
	_faixa("pan_floresta_" + estacao, Y_FLORESTA, NEBLINA["floresta"])

	# 5-6. muralha e castelo só existem quando a terra cresce: é o Progression
	#      Gate aparecendo na tela, não só na ficha
	if nivel >= 3:
		_faixa("pan_muralha", Y_MURALHA, NEBLINA["muralha"])
	if nivel >= 4:
		var cas := _tex("pan_castelo")
		if cas != null:
			var s := Sprite2D.new()
			s.texture = cas
			s.centered = false
			s.position = Vector2((ARTE.x - cas.get_width()) / 2.0,
				Y_CASTELO - cas.get_height() + 26)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.modulate = _com_ar(NEBLINA["castelo"])
			mundo.add_child(s)

	# 7. campo
	_faixa("pan_campo_" + _campo_de(estacao), Y_CAMPO)

	# 8. construções, do fundo para a frente (quem tem base mais baixa na
	#    tela está mais perto, então desenha depois)
	var lista: Array = CONSTRUCOES.filter(func(c): return nivel >= int(c["nivel"]))
	lista.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]))
	for c in lista:
		_construcao(c)

	# 9. aldeões: a vila só parece habitada com gente do tamanho certo
	_aldeoes(mini(3 + nivel * 2, 11))

	# 10. rio e ponte, na frente de tudo
	# O rio é gerado alto (64px) para o modelo ter espaço de desenhar água de
	# verdade, mas na cena ele é só a FAIXA DA FRENTE. Sem o recorte ele cobre
	# metade do quadro e afoga a vila.
	var rio := _tex("pan_rio")
	if rio != null:
		var s := Sprite2D.new()
		s.texture = rio
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0, rio.get_height() - ALTURA_RIO,
			rio.get_width(), ALTURA_RIO)
		s.position = Vector2(0, ARTE.y - ALTURA_RIO)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mundo.add_child(s)
	var ponte := _tex("pan_ponte")
	if ponte != null:
		var s := Sprite2D.new()
		s.texture = ponte
		s.centered = false
		# alinhada ao portão do castelo, como na referência
		s.position = Vector2((ARTE.x - ponte.get_width()) / 2.0,
			ARTE.y - ALTURA_RIO - ponte.get_height() + 30)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mundo.add_child(s)

func _construcao(c: Dictionary) -> void:
	var caminho := OBJETOS + str(c["n"]) + ".png"
	if not ResourceLoader.exists(caminho):
		return
	var t = load(caminho)
	if not (t is Texture2D):
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.scale = Vector2(float(c["e"]), float(c["e"]))
	# ancorado pelos PÉS: a base do sprite encosta na linha do chão
	s.position = Vector2(float(c["x"]) - t.get_width() * float(c["e"]) * 0.5,
		float(c["y"]) - t.get_height() * float(c["e"]))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mundo.add_child(s)
	# sombra projetada, na mesma direção do resto do jogo
	var sombra := Vfx.sombra_projetada(t, 0.26)
	if sombra != null:
		sombra.offset = Vector2(0, 0)
		sombra.position = Vector2(t.get_width() / 2.0, t.get_height())
		s.add_child(sombra)

func _aldeoes(quantos: int) -> void:
	# o mesmo elenco que a vila antiga usava: os retratos de tropa e de NPC
	# servem de aldeão em escala pequena, e não custam geração nova
	var elenco := ["tropa_campones", "tropa_lanceiro", "taverneiro",
		"tropa_espadachim", "heroi_jogador", "tropa_arqueiro"]
	for i in quantos:
		var id: String = elenco[i % elenco.size()]
		var no: AnimatedSprite2D = PersonagensV2.criar(id, 0.16)
		if no == null:
			continue
		var x := 30.0 + _rng.randf() * (ARTE.x - 60.0)
		var y := 116.0 + _rng.randf() * 8.0
		no.position = Vector2(x, y)
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mundo.add_child(no)

static func _estacao(mes: int) -> String:
	var m: int = ((mes - 1) % 12 + 12) % 12 + 1
	if m in [12, 1, 2]:
		return "inverno"
	if m in [9, 10, 11]:
		return "outono"
	return "verao"

func _ceu_de(estacao: String) -> String:
	if estacao == "inverno" and _tex("pan_ceu_inverno") != null:
		return "pan_ceu_inverno"
	return "pan_ceu_dia"

func _campo_de(estacao: String) -> String:
	# floresta e campo têm variante por estação; se a variante não foi gerada,
	# cai no verão em vez de sumir da tela
	if _tex("pan_campo_" + estacao) != null:
		return estacao
	return "verao"

## Mesma API da vila antiga, para principal.gd trocar uma pela outra sem saber.
func semear_npcs() -> void:
	_nivel_montado = -99
	_montar()
