# ============================================================
# MAPA v2 — TileSet da Godot 4 para TileMapLayer.
#
# VISUAL STRIP: o atlas de arte saiu; a GRADE ficou. Este arquivo é quase
# todo mecânica e por isso mudou pouco — o TileSet continua com camada de
# física e camada de navegação, com polígono de colisão nos tiles sólidos e
# malha de navegação nos caminháveis. Só a textura virou caixote.
#
# O layout Wang de 4×4 também fica: é ele que decide QUAL tile cada célula
# recebe, e portanto onde estão as bordas do rio, da lavoura e da rua. A
# transição some visualmente (todo tile é o mesmo caixote), mas a estrutura
# que a arte nova vai preencher continua de pé e continua testada.
# ============================================================
extends RefCounted

const Arte = preload("res://scripts/arte.gd")

## A grade dos atlas: 4×4 tiles. Antes vinha da divisão do PNG pelo tamanho
## do tile; agora é constante, porque é o layout Wang que a define.
const GRADE := 4

## ---- LAYOUT WANG DOS ATLAS DO PIXELLAB ----
## Os 16 tiles são as 16 combinações dos 4 CANTOS entre dois materiais: o
## "cheio" (grama, água) e o "vazio" (terra arada, areia). Conferido nos três
## atlas gerados — campo_terra, praia_agua e grama_pedra usam a MESMA ordem.
## Máscara: canto superior-esquerdo=1, superior-direito=2,
##          inferior-esquerdo=4, inferior-direito=8. Bit ligado = material cheio.
const WANG := {
	0: Vector2i(0, 3), 1: Vector2i(3, 3), 2: Vector2i(0, 2), 3: Vector2i(1, 2),
	4: Vector2i(0, 0), 5: Vector2i(3, 2), 6: Vector2i(2, 3), 7: Vector2i(3, 1),
	8: Vector2i(1, 3), 9: Vector2i(0, 1), 10: Vector2i(1, 0), 11: Vector2i(2, 2),
	12: Vector2i(3, 0), 13: Vector2i(2, 0), 14: Vector2i(1, 1), 15: Vector2i(2, 1),
}
const TILE_CHEIO := Vector2i(2, 1)     # 100% do material de cima (grama/água)
const TILE_VAZIO := Vector2i(0, 3)     # 100% do material de baixo (terra/areia)
## Quantas variantes espelhadas existem dos dois tiles puros (a base + 3).
const VARIANTES := 4

## Todo terreno tem caixote — o strip não deixa nenhum atlas faltar.
static func tem(_nome: String) -> bool:
	return true

## Monta o TileSet fatiando o atlas em tiles de `tile` pixels.
## `solidos`: coordenadas (Vector2i) do atlas que recebem colisão.
static func montar(_nome: String, tile: int = 32, solidos: Array = []) -> TileSet:
	var tex: Texture2D = Arte.atlas(GRADE, GRADE, tile)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	# camada de física e de navegação, para colisão e pathfinding funcionarem
	ts.add_physics_layer()
	ts.add_navigation_layer()

	var fonte := TileSetAtlasSource.new()
	fonte.texture = tex
	fonte.texture_region_size = Vector2i(tile, tile)
	# A fonte precisa entrar no TileSet ANTES de configurar os tiles: o TileData
	# só enxerga as camadas de física/navegação do TileSet ao qual pertence.
	# (Configurar antes falha silenciosamente com "p_layer_id out of bounds".)
	ts.add_source(fonte, 0)

	var colunas := GRADE
	var linhas := GRADE
	for y in linhas:
		for x in colunas:
			var coord := Vector2i(x, y)
			fonte.create_tile(coord)
			var dados: TileData = fonte.get_tile_data(coord, 0)
			if coord in solidos:
				# quadrado de colisão do tamanho do tile
				var meio := float(tile) / 2.0
				dados.add_collision_polygon(0)
				dados.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-meio, -meio), Vector2(meio, -meio),
					Vector2(meio, meio), Vector2(-meio, meio)]))
			else:
				# tile caminhável entra na malha de navegação
				var np := NavigationPolygon.new()
				var meio2 := float(tile) / 2.0
				var contorno := PackedVector2Array([
					Vector2(-meio2, -meio2), Vector2(meio2, -meio2),
					Vector2(meio2, meio2), Vector2(-meio2, meio2)])
				np.vertices = contorno
				np.add_polygon(PackedInt32Array([0, 1, 2, 3]))
				dados.set_navigation_polygon(0, np)

	# Variantes espelhadas dos DOIS tiles puros. Um campo inteiro pintado com o
	# mesmo tile vira papel de parede: as mesmas flores repetidas em grade. Três
	# espelhamentos quebram o padrão sem custar um pixel de arte nova.
	# (Só os puros: espelhar um tile de transição inverteria a borda.)
	for puro in [TILE_CHEIO, TILE_VAZIO]:
		if fonte.get_tile_data(puro, 0) == null:
			continue
		for combo in [[true, false], [false, true], [true, true]]:
			var alt: int = fonte.create_alternative_tile(puro)
			var d: TileData = fonte.get_tile_data(puro, alt)
			d.flip_h = combo[0]
			d.flip_v = combo[1]

	return ts

## Camada pronta para a árvore de cena, já com o TileSet aplicado.
static func criar_camada(nome: String, tile: int = 32, solidos: Array = []) -> TileMapLayer:
	var ts := montar(nome, tile, solidos)
	if ts == null:
		return null
	var camada := TileMapLayer.new()
	camada.name = "Terreno_" + nome
	camada.tile_set = ts
	camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return camada

## Preenche um retângulo com um tile do atlas — útil para montar o chão base.
static func preencher(camada: TileMapLayer, area: Rect2i, tile_atlas: Vector2i) -> void:
	if camada == null:
		return
	for y in range(area.position.y, area.position.y + area.size.y):
		for x in range(area.position.x, area.position.x + area.size.x):
			camada.set_cell(Vector2i(x, y), 0, tile_atlas)

## Espalha as variantes espelhadas de um tile puro de forma determinística —
## mesma célula, mesma variante, sempre (o mapa não "pisca" ao remontar).
static func _variante(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % VARIANTES

## Pinta uma área com o Wang de 4 cantos, gerando as transições de verdade.
##
## `dentro(canto: Vector2i) -> bool` responde se aquele CANTO da grade é do
## material cheio (grama, água). Cada célula olha os seus 4 cantos e escolhe o
## tile pela máscara — é isso que dá a borda de pedra da lavoura e a espuma da
## praia sem desenhar nada à mão.
##
## `pular(celula: Vector2i) -> bool` (opcional) deixa a célula VAZIA, para a
## camada de baixo aparecer — é como o rio fica só onde deve.
static func pintar_wang(camada: TileMapLayer, area: Rect2i, dentro: Callable,
		pular: Callable = Callable()) -> void:
	if camada == null or not dentro.is_valid():
		return
	for y in range(area.position.y, area.position.y + area.size.y):
		for x in range(area.position.x, area.position.x + area.size.x):
			var celula := Vector2i(x, y)
			if pular.is_valid() and pular.call(celula):
				camada.erase_cell(celula)
				continue
			var mascara := 0
			if dentro.call(Vector2i(x, y)):         mascara |= 1
			if dentro.call(Vector2i(x + 1, y)):     mascara |= 2
			if dentro.call(Vector2i(x, y + 1)):     mascara |= 4
			if dentro.call(Vector2i(x + 1, y + 1)): mascara |= 8
			var coord: Vector2i = WANG[mascara]
			# só os tiles puros têm variante espelhada
			var alt := 0
			if coord == TILE_CHEIO or coord == TILE_VAZIO:
				alt = _variante(x, y)
			camada.set_cell(celula, 0, coord, alt)

## Os atlas que a vila usa. Era uma varredura da pasta de arte; virou lista
## explícita, porque sem arquivo não há o que varrer — e porque a lista É o
## contrato do que a próxima leva de terreno precisa entregar.
const ATLAS := ["campo_terra_atlas", "praia_agua_atlas", "grama_pedra_atlas"]

static func disponiveis() -> Array:
	return ATLAS.duplicate()
