# ============================================================
# VILA EM NÓS NATIVOS — a aba "Terra" deixa de ser desenhada à mão em _draw()
# e passa a ser uma cena de verdade:
#
#   TileMapLayer (terreno Wang)  ·  Sprite2D dos objetos do PixelLab
#   AnimatedSprite2D do herói caminhando  ·  Y-Sort ordenando tudo pela base
#
# Mantém a MESMA API da CidadeCena antiga (.estado e semear_npcs()), então a
# principal.gd troca uma pela outra sem saber a diferença. Sem os assets v2,
# quem monta a aba continua sendo a CidadeCena procedural — o jogo nunca fica
# sem cenário.
# ============================================================
extends SubViewportContainer

const MapaV2 = preload("res://scripts/mapa_v2.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const LuzDoSol = preload("res://scripts/luz_do_sol.gd")

## O mundo é montado no tamanho nativo da arte (casas de 160px, herói de 124px)
## e reduzido por um fator INTEIRO de 1:2. Meio pixel de escala é o que faz
## pixel art tremer; 0.5 exato não treme.
const ESCALA_MUNDO := 0.5
const TILE := 32
## Área do mundo em pixels de arte (o dobro da viewport, pela escala 1:2).
const MUNDO := Vector2(1920, 1080)
const COLUNAS := 60      # 1920 / 32
const LINHAS := 34       # 1080 / 32, arredondado para cima
## Onde a areia começa e onde a água começa, em linhas de tile.
const LINHA_AREIA := 26
const LINHA_AGUA := 29
## Lavouras: retângulos de terra arada em volta da vila (em tiles).
const LAVOURAS := [Rect2i(2, 17, 8, 6), Rect2i(50, 16, 8, 6)]
## Rua de pedra: desce do portão e vira na altura do mercado.
const RUA_COLUNA := 30
const RUA_TOPO := 12
const RUA_BASE := 24
const RUA_LINHA := 22
const RUA_ESQ := 23
const RUA_DIR := 37

var viewport: SubViewport
var mundo: Node2D
var terreno: TileMapLayer
var rua: TileMapLayer
var agua: TileMapLayer
var heroi: AnimatedSprite2D
var luz: DirectionalLight2D
var camera: Camera2D

var _objetos: Array = []
var _aldeoes: Array = []
var _rota: Array = []
var _alvo := 0
var _nivel_montado := -99

var estado: Dictionary = {}:
	set(v):
		estado = v
		_atualizar_luz()
		_montar_vila()

## A vila só existe se o terreno e o herói animado existirem: sem isso,
## principal.gd fica com a cena procedural de antes.
static func disponivel() -> bool:
	return MapaV2.tem("campo_terra_atlas") and PersonagensV2.tem_caminhada("heroi_jogador")

func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(480, 270)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	viewport = SubViewport.new()
	viewport.size = Vector2i(MUNDO.x * ESCALA_MUNDO, MUNDO.y * ESCALA_MUNDO)
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	_montar_terreno()

	# ---- o nó que ordena tudo pela base ----
	# Com y_sort_enabled, a Godot desenha os filhos na ordem do Y GLOBAL de cada
	# um. Por isso todo sprite daqui tem a origem nos pés (ver _ancorar): assim
	# o Y comparado é o ponto onde a coisa toca o chão, e o herói passa atrás
	# da casa quando está acima dela e na frente quando está abaixo.
	mundo = Node2D.new()
	mundo.name = "Mundo"
	mundo.y_sort_enabled = true
	mundo.scale = Vector2(ESCALA_MUNDO, ESCALA_MUNDO)
	viewport.add_child(mundo)

	luz = LuzDoSol.new()
	luz.forca = 0.45          # o rio some no cinza se o sol quente vem inteiro
	viewport.add_child(luz)

	# Câmera: com stretch ligado, o SubViewport assume o TAMANHO DO CONTAINER —
	# na aba isso dá ~480px, e o mundo tem 960. Sem câmera o jogador veria só o
	# canto superior esquerdo. Ela segue o herói e os limites impedem que a
	# borda do mapa apareça.
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MUNDO.x * ESCALA_MUNDO)
	camera.limit_bottom = int(MUNDO.y * ESCALA_MUNDO)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.0
	viewport.add_child(camera)

	_criar_heroi()

## make_current só vale com o nó já na árvore — em _init a câmera ainda não está.
func _ready() -> void:
	if camera != null:
		camera.make_current()

# ------------------------------------------------------------
# TERRENO — três camadas Wang empilhadas, todas antes do `mundo`, então
# desenham sempre atrás dos objetos e do herói.
#   1. campo_terra: grama por todo lado, com lavouras de terra arada
#   2. grama_pedra: a rua de pedra (só onde há rua; o resto fica vazio)
#   3. praia_agua:  o rio com margem de areia na parte de baixo do mapa
# ------------------------------------------------------------
## Cria as três camadas. O RIO nunca muda — ele é geografia. A grama e a rua
## são repintadas conforme a terra evolui (ver _pintar_terreno).
func _montar_terreno() -> void:
	# As três camadas se sobrepõem. A malha de navegação de uma cobriria a da
	# outra e o servidor reclama de arestas cruzadas — aqui nada faz pathfinding,
	# então o cenário é só cenário.
	terreno = MapaV2.criar_camada("campo_terra_atlas", TILE)
	if terreno != null:
		terreno.scale = Vector2(ESCALA_MUNDO, ESCALA_MUNDO)
		terreno.navigation_enabled = false
		viewport.add_child(terreno)

	rua = MapaV2.criar_camada("grama_pedra_atlas", TILE)
	if rua != null:
		rua.scale = Vector2(ESCALA_MUNDO, ESCALA_MUNDO)
		rua.navigation_enabled = false
		viewport.add_child(rua)

	# rio: areia a partir de LINHA_AREIA, água a partir de LINHA_AGUA, com a
	# margem ondulada para não virar uma régua
	agua = MapaV2.criar_camada("praia_agua_atlas", TILE)
	if agua != null:
		agua.scale = Vector2(ESCALA_MUNDO, ESCALA_MUNDO)
		agua.navigation_enabled = false
		MapaV2.pintar_wang(agua, Rect2i(0, 0, COLUNAS, LINHAS),
			func(canto: Vector2i) -> bool: return canto.y >= _margem(canto.x),
			func(celula: Vector2i) -> bool: return celula.y < LINHA_AREIA)
		viewport.add_child(agua)

	_pintar_terreno(-1)      # chão de acampamento até o estado chegar

## O chão conta a mesma história que as construções: acampamento mercenário não
## tem lavoura nem calçamento; a rua de pedra só chega quando a vila vira
## cidade murada.
func _pintar_terreno(nivel: int) -> void:
	var area := Rect2i(0, 0, COLUNAS, LINHAS)
	if terreno != null:
		var tem_lavoura := nivel >= 1
		MapaV2.pintar_wang(terreno, area, func(canto: Vector2i) -> bool:
			if not tem_lavoura:
				return true
			for lav in LAVOURAS:
				if lav.has_point(canto):
					return false          # canto de terra arada
			return true)
	if rua == null:
		return
	if nivel < 3:
		rua.clear()                       # sem calçamento: só grama e barro
		return
	MapaV2.pintar_wang(rua, area,
		func(canto: Vector2i) -> bool: return not _na_rua(canto),
		func(celula: Vector2i) -> bool:
			# célula sem nenhum canto de pedra não precisa existir
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				if _na_rua(celula + d):
					return false
			return true)

## Linha onde a água começa naquela coluna — a onda evita a margem reta.
static func _margem(x: int) -> int:
	return LINHA_AGUA + int(round(sin(x * 0.35) * 1.2))

## A rua serpenteia de leve. Um corredor reto de tiles vira uma faixa de
## azulejo; um desvio de um ou dois tiles já lê como caminho batido a pé.
static func _na_rua(canto: Vector2i) -> bool:
	if canto.y >= RUA_TOPO and canto.y <= RUA_BASE:
		var desvio := int(round(sin(canto.y * 0.22) * 1.0))
		if absi(canto.x - (RUA_COLUNA + desvio)) <= 1:
			return true
	if canto.x >= RUA_ESQ and canto.x <= RUA_DIR:
		var onda := int(round(sin(canto.x * 0.18) * 1.0))
		return absi(canto.y - (RUA_LINHA + onda)) <= 1
	return false

# ------------------------------------------------------------
# HERÓI
# ------------------------------------------------------------
func _criar_heroi() -> void:
	if not PersonagensV2.tem_caminhada("heroi_jogador"):
		return
	heroi = PersonagensV2.criar("heroi_jogador", 1)
	_ancorar(heroi)
	heroi.position = Vector2(MUNDO.x * 0.5, 760)
	mundo.add_child(heroi)
	_rota = [
		Vector2(360, 700), Vector2(760, 620), Vector2(1180, 640),
		Vector2(1520, 720), Vector2(1180, 820), Vector2(700, 810),
	]
	_alvo = 0

## Põe a origem do nó nos PÉS do sprite. Sem isso o Y-Sort compararia o centro
## da imagem, e um sprite alto (o moinho) pareceria estar sempre atrás.
func _ancorar(no: CanvasItem) -> void:
	var altura := 0.0
	if no is Sprite2D and no.texture != null:
		altura = no.texture.get_height()
		no.offset = Vector2(0, -altura / 2.0)
	elif no is AnimatedSprite2D and no.sprite_frames != null:
		var anim: String = no.animation
		if no.sprite_frames.has_animation(anim) and no.sprite_frames.get_frame_count(anim) > 0:
			var t: Texture2D = no.sprite_frames.get_frame_texture(anim, 0)
			if t != null:
				altura = t.get_height()
				no.offset = Vector2(0, -altura / 2.0)

## Converte um vetor de movimento no nome de direção do create-character-v3.
## Em coordenadas de tela o Y cresce para BAIXO, então +y é "south".
static func direcao_de(v: Vector2) -> String:
	if v.length() < 0.001:
		return "south"
	var passo := int(round(v.angle() / (PI / 4.0)))
	match ((passo % 8) + 8) % 8:
		0: return "east"
		1: return "south-east"
		2: return "south"
		3: return "south-west"
		4: return "west"
		5: return "north-west"
		6: return "north"
		_: return "north-east"

func _process(delta: float) -> void:
	if heroi == null:
		return
	# a câmera vive no espaço do viewport, o herói no espaço do mundo (÷2)
	if camera != null:
		camera.position = heroi.position * ESCALA_MUNDO
	if _rota.is_empty():
		return
	# ronda pela vila: sem controle do jogador, o herói percorre a rota em laço
	var destino: Vector2 = _rota[_alvo]
	var passo: Vector2 = destino - heroi.position
	if passo.length() < 6.0:
		_alvo = (_alvo + 1) % _rota.size()
		return
	var dir := passo.normalized()
	heroi.position += dir * 90.0 * delta
	PersonagensV2.mover(heroi, direcao_de(dir), true)

# ------------------------------------------------------------
# VILA — objetos por nível de terra, como no cenário antigo
# ------------------------------------------------------------
func _nivel() -> int:
	if estado.is_empty() or estado.get("terra") == null:
		return -1
	return int(estado["terra"]["nivel"])

## O que existe em cada nível: [id do objeto, x, y] no espaço da arte.
## Y é o ponto onde a construção toca o chão — é o que o Y-Sort compara.
func _planta(nivel: int) -> Array:
	# bosque de fundo: a grama vazia nas bordas é o que fazia o mapa parecer
	# um tabuleiro, então as árvores fecham o quadro
	var pecas: Array = [
		["arvore_carvalho", 150, 560], ["arvore_pinheiro", 1790, 600],
		["arvore_carvalho", 1660, 500], ["arvore_pinheiro", 90, 400],
		["arvore_carvalho", 320, 330], ["arvore_pinheiro", 1420, 330],
		["arvore_carvalho", 1880, 780], ["arvore_pinheiro", 60, 800],
		["arvore_carvalho", 430, 850], ["arvore_pinheiro", 1600, 860],
	]
	if nivel < 0:
		pecas.append_array([
			["fogueira_acampamento", 900, 700], ["barril_carga", 1010, 730],
			["barril_carga", 760, 690], ["arvore_pinheiro", 480, 520],
		])
		return pecas
	if nivel >= 1:
		pecas.append_array([
			["casa_camponesa", 520, 600], ["casa_camponesa", 1320, 640],
			["poco_pedra", 920, 700],
		])
	if nivel >= 2:
		pecas.append_array([["moinho_vento", 300, 500], ["ferraria", 1520, 580]])
	if nivel >= 3:
		pecas.append_array([
			["muralha_pedra", 620, 380], ["muralha_pedra", 780, 380],
			["portao_fortificado", 960, 390],
			["muralha_pedra", 1140, 380], ["muralha_pedra", 1300, 380],
			["barraca_mercado", 740, 720], ["barraca_mercado", 1120, 740],
		])
	if nivel >= 4:
		pecas.append_array([["casa_camponesa", 1700, 700], ["bau_tesouro", 1030, 660]])
	if nivel >= 5:
		pecas.append_array([["torre_castelo", 860, 330], ["torre_castelo", 1080, 330]])
	return pecas

func _montar_vila() -> void:
	var nivel := _nivel()
	if nivel == _nivel_montado:
		return                      # nada mudou: não remonta a cada atualizar()
	_nivel_montado = nivel
	_pintar_terreno(nivel)
	for o in _objetos:
		if is_instance_valid(o):
			o.queue_free()
	_objetos.clear()
	for peca in _planta(nivel):
		var caminho: String = "res://assets_v2/objects/%s.png" % peca[0]
		if not ResourceLoader.exists(caminho):
			continue
		var s := Sprite2D.new()
		s.texture = load(caminho)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		_ancorar(s)
		s.position = Vector2(peca[1], peca[2])
		mundo.add_child(s)
		_objetos.append(s)
	_semear()

## Aldeões parados pela vila — o mesmo papel dos NPCs desenhados de antes,
## agora como nós de verdade, entrando no mesmo Y-Sort do herói.
func _semear() -> void:
	for a in _aldeoes:
		if is_instance_valid(a):
			a.queue_free()
	_aldeoes.clear()
	var nivel := _nivel()
	var quantos: int = 8 if nivel >= 3 else (5 if nivel >= 1 else 3)
	var elenco := ["tropa_campones", "tropa_lanceiro", "taverneiro",
		"tropa_arqueiro", "capitao"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + nivel
	for i in quantos:
		var p: AnimatedSprite2D = PersonagensV2.criar(elenco[i % elenco.size()], 1)
		_ancorar(p)
		p.position = Vector2(300.0 + rng.randf() * 1300.0, 600.0 + rng.randf() * 220.0)
		mundo.add_child(p)
		_aldeoes.append(p)

## Mesma assinatura da CidadeCena: principal.gd chama isto ao comprar/evoluir.
func semear_npcs() -> void:
	_nivel_montado = -99      # força a remontagem no próximo estado
	_montar_vila()

func _atualizar_luz() -> void:
	if luz != null and not estado.is_empty():
		luz.definir_pelo_mes(int(estado.get("mes", 6)))
