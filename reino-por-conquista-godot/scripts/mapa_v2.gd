# ============================================================
# MAPA v2 — TileSet da Godot 4 a partir do atlas do PixelLab, para TileMapLayer.
#
# O create-tileset devolve um atlas contínuo (Wang/Pro) em
# assets_v2/tilesets/<nome>.png. Aqui ele vira um TileSet de verdade:
# TileSetAtlasSource fatiado no tamanho do tile, com colisão e navegação
# opcionais por tile. Sem o PNG, devolve null e a cena antiga (desenhada em
# _draw) continua valendo.
# ============================================================
extends RefCounted

const PASTA := "res://assets_v2/tilesets/"

static func tem(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + nome + ".png")

## Monta o TileSet fatiando o atlas em tiles de `tile` pixels.
## `solidos`: coordenadas (Vector2i) do atlas que recebem colisão.
static func montar(nome: String, tile: int = 32, solidos: Array = []) -> TileSet:
	if not tem(nome):
		return null
	var tex = load(PASTA + nome + ".png")
	if not (tex is Texture2D):
		return null

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	# camada de física e de navegação, para colisão e pathfinding funcionarem
	ts.add_physics_layer()
	ts.add_navigation_layer()

	var fonte := TileSetAtlasSource.new()
	fonte.texture = tex
	fonte.texture_region_size = Vector2i(tile, tile)

	var colunas := int(tex.get_width() / tile)
	var linhas := int(tex.get_height() / tile)
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
				np.add_outline(PackedVector2Array([
					Vector2(-meio2, -meio2), Vector2(meio2, -meio2),
					Vector2(meio2, meio2), Vector2(-meio2, meio2)]))
				np.make_polygons_from_outlines()
				dados.set_navigation_polygon(0, np)

	ts.add_source(fonte, 0)
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

static func disponiveis() -> Array:
	var achados := []
	var d := DirAccess.open(PASTA)
	if d == null:
		return achados
	for arq in d.get_files():
		if arq.ends_with(".png"):
			achados.append(arq.get_basename())
	return achados
