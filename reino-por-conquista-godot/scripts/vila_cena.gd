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
const Arte = preload("res://scripts/arte.gd")
const AgenteMovel = preload("res://scripts/agente_movel.gd")
const VisualController = preload("res://scripts/visual_controller.gd")
const CameraMundo = preload("res://scripts/camera_mundo.gd")
const Ambiente = preload("res://scripts/environment_manager.gd")

## VISUAL STRIP: as dimensões que cada objeto da vila tinha na arte gerada.
## Não é decoração — `_ancorar()` põe a origem nos PÉS usando a ALTURA da
## textura, e `ESCALA_OBJ` multiplica em cima disso. Um caixote de tamanho
## errado moveria a construção de lugar e furaria o Y-Sort. A tabela é o que
## mantém a planta da vila idêntica à de antes.
const TAMANHO_OBJ := {
	"arvore_carvalho": Vector2i(128, 160),
	"arvore_pinheiro": Vector2i(112, 160),
	"barraca_mercado": Vector2i(144, 128),
	"barril_carga": Vector2i(80, 80),
	"bau_tesouro": Vector2i(96, 96),
	"carroca": Vector2i(128, 96),
	"casa_camponesa": Vector2i(160, 160),
	"ferraria": Vector2i(160, 160),
	"fogueira_acampamento": Vector2i(96, 96),
	"moinho_vento": Vector2i(160, 192),
	"muralha_pedra": Vector2i(160, 128),
	"poco_pedra": Vector2i(96, 112),
	"ponte_madeira": Vector2i(112, 160),
	"portao_fortificado": Vector2i(160, 160),
	"sacos_carga": Vector2i(80, 64),
	"tenda_grande": Vector2i(128, 112),
	"tenda_simples": Vector2i(96, 96),
	"tocha_estaca": Vector2i(48, 96),
	"torre_castelo": Vector2i(160, 192),
}

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
const LAVOURAS := [Rect2i(6, 17, 8, 6), Rect2i(48, 16, 8, 6)]
## Rua de pedra: desce do portão, cruza a vila e alcança a ponte.
const RUA_COLUNA := 30
const RUA_TOPO := 12
const RUA_BASE := 26
const RUA_LINHA := 22
const RUA_ESQ := 23
const RUA_DIR := 37

## Escala do personagem NA VILA: o cânone do gênero é o herói com ~metade da
## altura da porta de uma casa. Com as casas a 1.0 (160px), 0.55 dá isso.
const ESCALA_HEROI := 0.55
const ESCALA_ALDEAO := 0.85

## Proporção de cada objeto em relação à arte, medida CONTRA o herói:
## um barril na altura do peito, um baú até o joelho, a tenda acima da cabeça.
## Sem isto, o barril de 80px ficava com metade da casa de 160px.
const ESCALA_OBJ := {
	"barril_carga": 0.5, "bau_tesouro": 0.45, "sacos_carga": 0.6,
	"fogueira_acampamento": 0.6, "poco_pedra": 0.75, "tocha_estaca": 0.7,
	"carroca": 0.85, "tenda_simples": 0.9, "barraca_mercado": 0.9,
	"ponte_madeira": 1.35,
}

var viewport: SubViewport
var mundo: Node2D
var terreno: TileMapLayer
var rua: TileMapLayer
var agua: TileMapLayer
var floresta: TileMapLayer
var heroi: AgenteMovel
var camera: CameraMundo
var heroi_visual: VisualController

var _objetos: Array = []
var _aldeoes: Array = []      # [{no: AgenteMovel, origem, controlador}]
var _nivel_montado := -99
var _rng := RandomNumberGenerator.new()

var estado: Dictionary = {}:
	set(v):
		estado = v
		_montar_vila()
		_atualizar_ambiente()


## A atmosfera acompanha o MÊS do jogo. `transitar_para_mes` em vez de
## `definir_mes` porque passar o mês não deve dar um corte seco de cor.
## Guardado por `is_inside_tree`: principal.gd atribui `estado` antes de
## pendurar a cena, e o tween precisa do nó na árvore.
func _atualizar_ambiente() -> void:
	if not is_inside_tree() or estado.is_empty():
		return
	var amb := Ambiente.gerente()
	if amb != null:
		amb.transitar_para_mes(int(estado.get("mes", 6)))

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


	# Câmera: com stretch ligado, o SubViewport assume o TAMANHO DO CONTAINER —
	# na aba isso dá ~480px, e o mundo tem 960. Sem câmera o jogador veria só o
	# canto superior esquerdo. Ela segue o herói e os limites impedem que a
	# borda do mapa apareça.
	camera = CameraMundo.criar(MUNDO * ESCALA_MUNDO)
	viewport.add_child(camera)

	_criar_heroi()

## make_current só vale com o nó já na árvore — em _init a câmera ainda não
## está. O registro do ambiente também é aqui, pelo mesmo motivo.
func _ready() -> void:
	if camera != null:
		camera.make_current()
		if heroi != null:
			camera.seguir(heroi, ESCALA_MUNDO)
	# atmosfera Hi-Bit: o CanvasModulate entra NESTE viewport, não na raiz —
	# a interface de pergaminho fica de fora (ver environment_manager.gd)
	var amb := Ambiente.gerente()
	if amb != null:
		amb.registrar(mundo)
		if not estado.is_empty():
			amb.definir_mes(int(estado.get("mes", 6)))


func _exit_tree() -> void:
	var amb := Ambiente.gerente()
	if amb != null:
		amb.esquecer(mundo)

# ------------------------------------------------------------
# TERRENO — quatro camadas Wang, todas antes do `mundo`, então desenham
# sempre atrás dos objetos e do herói.
#   1. campo_terra:    grama por todo lado, com lavouras de terra arada
#   2. grama_pedra:    a rua de pedra (só onde há rua; o resto fica vazio)
#   3. praia_agua:     o rio com margem de areia na parte de baixo
#   4. grama_floresta: a moldura de mata fechada nas bordas do mapa —
#      o limite do mundo deixa de ser grama cortada na borda da tela
# ------------------------------------------------------------
func _montar_terreno() -> void:
	# As camadas se sobrepõem. A malha de navegação de uma cobriria a da outra
	# e o servidor reclama de arestas cruzadas — aqui nada faz pathfinding,
	# então o cenário é só cenário.
	terreno = _camada("campo_terra_atlas")
	rua = _camada("grama_pedra_atlas")

	# rio: areia a partir de LINHA_AREIA, água a partir de LINHA_AGUA, com a
	# margem ondulada para não virar uma régua
	agua = _camada("praia_agua_atlas")
	if agua != null:
		MapaV2.pintar_wang(agua, Rect2i(0, 0, COLUNAS, LINHAS),
			func(canto: Vector2i) -> bool: return canto.y >= _margem(canto.x),
			func(celula: Vector2i) -> bool: return celula.y < LINHA_AREIA)

	floresta = _camada("grama_floresta_atlas")
	if floresta != null:
		MapaV2.pintar_wang(floresta, Rect2i(0, 0, COLUNAS, LINHAS),
			func(canto: Vector2i) -> bool: return not _na_floresta(canto),
			func(celula: Vector2i) -> bool:
				# célula sem nenhum canto de mata não precisa existir
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					if _na_floresta(celula + d):
						return false
				return true)

	_pintar_terreno(-1)      # chão de acampamento até o estado chegar

func _camada(nome: String) -> TileMapLayer:
	var c := MapaV2.criar_camada(nome, TILE)
	if c == null:
		return null
	c.scale = Vector2(ESCALA_MUNDO, ESCALA_MUNDO)
	c.navigation_enabled = false
	viewport.add_child(c)
	return c

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
		# nas últimas linhas o desvio zera: a rua chega ALINHADA com a ponte
		# (coluna 30), em vez de entregar o eixo da composição meio tile torto
		var desvio := 0 if canto.y >= RUA_BASE - 3 \
			else int(round(sin(canto.y * 0.22) * 1.0))
		if absi(canto.x - (RUA_COLUNA + desvio)) <= 1:
			return true
	if canto.x >= RUA_ESQ and canto.x <= RUA_DIR:
		var onda := int(round(sin(canto.x * 0.18) * 1.0))
		return absi(canto.y - (RUA_LINHA + onda)) <= 1
	return false

## Moldura de mata: bordas esquerda, direita e topo, com a orla ondulada.
## Para na areia — árvore não cresce na praia.
static func _na_floresta(canto: Vector2i) -> bool:
	if canto.y >= LINHA_AREIA - 1:
		return false
	var onda_v := int(round(sin(canto.y * 0.55) * 1.1))
	var onda_h := int(round(sin(canto.x * 0.42) * 1.1))
	return canto.x <= 2 + onda_v or canto.x >= COLUNAS - 3 + onda_v \
		or canto.y <= 2 + onda_h

# ------------------------------------------------------------
# HERÓI
# ------------------------------------------------------------
## O herói é um AGENTE (mecânica) com um VisualController pendurado. Nada
## aqui toca em sprite: a ronda mexe em posição, o agente emite, o
## controlador desenha. Trocar a arte não encosta nesta função.
func _criar_heroi() -> void:
	if not PersonagensV2.tem_caminhada("heroi_jogador"):
		return
	heroi = AgenteMovel.new()
	heroi.name = "Heroi"
	heroi.velocidade_max = 80.0
	heroi.position = Vector2(MUNDO.x * 0.5, 780)
	mundo.add_child(heroi)

	heroi_visual = VisualController.novo(heroi)
	heroi_visual.usar_personagem("heroi_jogador", ESCALA_HEROI)
	heroi_visual.observar(heroi)

	# ronda pela rua: portão → praça do mercado → pontas da rua transversal
	heroi.definir_rota([
		Vector2(960, 540), Vector2(960, 770), Vector2(740, 730),
		Vector2(960, 780), Vector2(1200, 740), Vector2(980, 800),
	])

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
## A conta mora no AgenteMovel — é ele quem decide direção agora. Aqui fica
## só o encaminhamento, para não haver duas cópias da mesma tabela de 8 vias
## podendo divergir.
static func direcao_de(v: Vector2) -> String:
	return AgenteMovel.direcao_de(v)

## Aldeões vagueiam devagar perto de onde nasceram: andam, param, voltam.
##
## Isto era um laço por quadro varrendo a lista inteira. Agora é o próprio
## agente que avisa quando chegou, e a cena só responde ao sinal — nenhum
## `_process` roda enquanto oito aldeões caminham. Foi a mudança que tornou
## `_process` desnecessário nesta cena, e ele saiu.
##
## Nota da rota de UM ponto: chegando ao único destino, o agente daria a
## volta e "chegaria" de novo no quadro seguinte. `esperar()` antes de
## `definir_rota()` é o que corta isso — o agente fica parado a pausa
## inteira e só então sai para o destino novo.
func _vagar(_indice: int, agente: AgenteMovel, origem: Vector2) -> void:
	if not is_instance_valid(agente):
		return
	var alvo := origem + Vector2(
		_rng.randf_range(-110.0, 110.0), _rng.randf_range(-60.0, 60.0))
	alvo.y = clampf(alvo.y, 400.0, float(LINHA_AREIA * TILE - 40))
	alvo.x = clampf(alvo.x, 140.0, MUNDO.x - 140.0)
	agente.esperar(_rng.randf_range(1.5, 4.5))
	agente.definir_rota([alvo])

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
	# bosque de primeiro plano: árvores soltas ADIANTE da moldura de floresta,
	# para a transição mata→clareira não ser uma linha de tiles
	var pecas: Array = [
		["arvore_carvalho", 210, 420], ["arvore_pinheiro", 1730, 420],
		["arvore_carvalho", 1560, 340], ["arvore_pinheiro", 350, 320],
		["arvore_carvalho", 1830, 640], ["arvore_pinheiro", 140, 620],
		["arvore_carvalho", 480, 790], ["arvore_pinheiro", 1500, 800],
	]
	# a ponte é geografia, como o rio: existe em todo nível.
	# O topo dela precisa ENCOSTAR onde a rua/grama termina (linha da areia,
	# y=832) — é o eixo portão→praça→ponte que costura a composição.
	pecas.append(["ponte_madeira", RUA_COLUNA * TILE, 1120])
	if nivel <= 0:
		# nível 0 é a terra recém-comprada (ou rebaixada por saque): ainda é
		# um acampamento — sem o <=, o jogador pagava 300 de ouro e recebia
		# uma clareira deserta
		pecas.append_array([
			["fogueira_acampamento", 940, 690],
			["tenda_grande", 800, 600], ["tenda_simples", 1080, 610],
			["tenda_simples", 860, 800], ["tenda_simples", 1120, 780],
			["carroca", 1240, 680], ["sacos_carga", 1020, 730],
			["barril_carga", 890, 730], ["tocha_estaca", 940, 590],
		])
		return pecas
	if nivel >= 1:
		pecas.append_array([
			["casa_camponesa", 560, 610], ["casa_camponesa", 1300, 640],
			["poco_pedra", 940, 700], ["sacos_carga", 640, 660],
		])
	if nivel >= 2:
		pecas.append_array([
			["moinho_vento", 330, 520], ["ferraria", 1500, 590],
			["carroca", 1390, 700],
		])
	if nivel >= 3:
		# a muralha abraça o portão pela largura VISÍVEL da arte (não do
		# canvas): o portão tem 141px e cada segmento ~134px de pedra — passo
		# de 160 abria janelas de grama e a fortificação parecia em ruínas
		pecas.append_array([
			["muralha_pedra", 686, 400], ["muralha_pedra", 824, 400],
			["portao_fortificado", 960, 410],
			["muralha_pedra", 1096, 400], ["muralha_pedra", 1234, 400],
			["barraca_mercado", 760, 740], ["barraca_mercado", 1160, 750],
			["tocha_estaca", 880, 430], ["tocha_estaca", 1040, 430],
			["barril_carga", 820, 770],
		])
	if nivel >= 4:
		pecas.append_array([["casa_camponesa", 1680, 730], ["bau_tesouro", 1010, 660]])
	if nivel >= 5:
		pecas.append_array([["torre_castelo", 850, 350], ["torre_castelo", 1070, 350]])
	return pecas

func _montar_vila() -> void:
	var nivel := _nivel()
	if nivel == _nivel_montado:
		return                      # nada mudou: não remonta a cada atualizar()
	_nivel_montado = nivel
	_pintar_terreno(nivel)
	for o in _objetos:
		if is_instance_valid(o):
			# sair da árvore JÁ: um nó só solta o nome quando é removido, e o
			# queue_free demora um quadro — o substituto entraria renomeado
			# (Obj_x@2) e get_node("Obj_x") acharia um nó morto
			mundo.remove_child(o)
			o.queue_free()
	_objetos.clear()
	for peca in _planta(nivel):
		var s := _objeto(peca[0], Vector2(peca[1], peca[2]))
		if s != null:
			_objetos.append(s)
	_semear()

## Um objeto da vila: sprite ancorado nos pés, na escala certa, com sombra —
## e com o efeito que lhe cabe (fumaça na chaminé, fogo na fogueira e tocha).
func _objeto(nome: String, pos: Vector2) -> Sprite2D:
	if not TAMANHO_OBJ.has(nome):
		return null
	var d: Vector2i = TAMANHO_OBJ[nome]
	var s := Sprite2D.new()
	s.name = "Obj_" + nome
	s.texture = Arte.caixa(d.x, d.y)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	_ancorar(s)
	var e: float = ESCALA_OBJ.get(nome, 1.0)
	s.scale = Vector2(e, e)
	# o que queima ganha luz de ponto — iluminação 2D moderna, textura de
	# gradiente gerada, sem um arquivo de arte
	if nome == "fogueira_acampamento" or nome == "tocha_estaca":
		var vc := VisualController.novo(s)
		vc.acender(Color(1.0, 0.72, 0.42),
			110.0 if nome == "fogueira_acampamento" else 62.0,
			0.85 if nome == "fogueira_acampamento" else 0.55)
		vc.position = Vector2(0, -float(d.y) * 0.5)
	if nome == "ponte_madeira":
		# a arte veio estreita; alargar só o X estica as TÁBUAS, que são
		# horizontais — vira uma ponte de verdade, não uma escada. O Y estica
		# até o tabuleiro alcançar a linha da areia (832), onde a rua termina.
		s.scale.x = e * 1.5
		s.scale.y = (pos.y - 830.0) / s.texture.get_height()
	s.position = pos
	mundo.add_child(s)
	return s

## Aldeões passeando pela vila — o mesmo papel dos NPCs desenhados de antes,
## agora como nós de verdade, entrando no mesmo Y-Sort do herói.
func _semear() -> void:
	for a in _aldeoes:
		if is_instance_valid(a["no"]):
			mundo.remove_child(a["no"])   # solta o nome já (ver _montar_vila)
			a["no"].queue_free()
	_aldeoes.clear()
	var nivel := _nivel()
	var quantos: int = 8 if nivel >= 3 else (5 if nivel >= 1 else 3)
	var elenco := ["tropa_campones", "tropa_lanceiro", "taverneiro",
		"tropa_arqueiro", "capitao"]
	_rng.seed = 7 + nivel
	for i in quantos:
		var a := AgenteMovel.new()
		a.name = "Aldeao_%d" % i
		a.velocidade_max = 26.0
		a.raio_chegada = 4.0
		var origem := Vector2(360.0 + _rng.randf() * 1200.0, 560.0 + _rng.randf() * 240.0)
		a.position = origem
		mundo.add_child(a)
		var vc := VisualController.novo(a)
		vc.usar_personagem(elenco[i % elenco.size()], ESCALA_ALDEAO)
		vc.observar(a)
		# o passeio se conduz por SINAL: chegou → escolhe o próximo destino
		a.chegou.connect(_vagar.bind(a, origem))
		_vagar(0, a, origem)
		_aldeoes.append({"no": a, "origem": origem, "controlador": vc})

## Mesma assinatura da CidadeCena: principal.gd chama isto ao comprar/evoluir.
func semear_npcs() -> void:
	_nivel_montado = -99      # força a remontagem no próximo estado
	_montar_vila()

