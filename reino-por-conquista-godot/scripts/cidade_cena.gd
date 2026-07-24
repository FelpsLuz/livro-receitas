# ============================================================
# CENA DA CIDADE COM LUZ E ÁGUA
# Empacota a CidadeView num SubViewport próprio para que a
# DirectionalLight2D (dia/tarde/noite), os LightOccluder2D
# (sombras das construções) e o shader de água atuem SÓ no
# cenário — sem tingir a interface de pergaminho.
# Mantém a mesma API da CidadeView: .estado e semear_npcs().
# ============================================================
extends SubViewportContainer

const CidadeView = preload("res://scripts/cidade_view.gd")
const LuzDoSol = preload("res://scripts/luz_do_sol.gd")

var viewport: SubViewport
var view: Control
var luz: DirectionalLight2D
var agua: ColorRect
var _oclusores: Array = []

var estado: Dictionary = {}:
	set(v):
		estado = v
		if view != null:
			view.estado = v
		_atualizar_luz()
		_montar_oclusores()

func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(480, 270)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	view = CidadeView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(view)

	# água orgânica: retângulo com shader de distorção sobre o rio
	agua = ColorRect.new()
	agua.position = Vector2(0, 296)
	agua.size = Vector2(640, 48)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/agua.gdshader")
	var ruido := NoiseTexture2D.new()
	var fnl := FastNoiseLite.new()
	fnl.frequency = 0.02
	fnl.fractal_octaves = 3
	ruido.noise = fnl
	ruido.width = 128
	ruido.height = 128
	mat.set_shader_parameter("textura_ruido", ruido)
	agua.material = mat
	viewport.add_child(agua)

	# sol direcional com sombras
	luz = LuzDoSol.new()
	viewport.add_child(luz)

func semear_npcs() -> void:
	if view != null:
		view.semear_npcs()

func _atualizar_luz() -> void:
	if luz != null and not estado.is_empty():
		luz.definir_pelo_mes(int(estado.get("mes", 6)))

# sombras projetadas: um oclusor fino na base de cada construção
func _montar_oclusores() -> void:
	for o in _oclusores:
		if is_instance_valid(o):
			o.queue_free()
	_oclusores.clear()
	if view == null:
		return
	var nivel: int = -1
	if not estado.is_empty() and estado.get("terra") != null:
		nivel = int(estado["terra"]["nivel"])
	for r in _bases(nivel):
		var oc := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(r.position.x, r.position.y),
			Vector2(r.position.x + r.size.x, r.position.y),
			Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
			Vector2(r.position.x, r.position.y + r.size.y),
		])
		oc.occluder = poly
		viewport.add_child(oc)
		_oclusores.append(oc)

# retângulos-base das construções por nível (mesmas coordenadas do desenho)
func _bases(nivel: int) -> Array:
	var bases: Array = []
	if nivel < 0:
		bases = [Rect2(170, 250, 28, 6), Rect2(400, 264, 28, 6), Rect2(120, 286, 28, 6)]
	else:
		if nivel >= 1:
			bases.append_array([Rect2(130, 274, 52, 6), Rect2(430, 280, 48, 6), Rect2(196, 306, 46, 4)])
		if nivel >= 2:
			bases.append_array([Rect2(44, 250, 30, 6), Rect2(500, 297, 48, 6)])
		if nivel >= 4:
			bases.append(Rect2(524, 262, 48, 6))
		if nivel >= 3:
			bases.append(Rect2(0, 252, 640, 5))       # muralha
		if nivel >= 5:
			bases.append(Rect2(257, 232, 130, 6))     # castelo
	return bases
