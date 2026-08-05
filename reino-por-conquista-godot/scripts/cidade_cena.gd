# ============================================================
# CENA DA CIDADE
# Empacota a CidadeView num SubViewport próprio, para o cenário
# ter a sua própria resolução sem afetar a interface.
# Mantém a mesma API da CidadeView: .estado e semear_npcs().
#
# VISUAL STRIP: saíram daqui o shader de água (ColorRect com ruído), a
# DirectionalLight2D de dia/tarde/noite e os LightOccluder2D que projetavam
# as sombras das construções. Os três eram só aparência: nenhum lia ou
# escrevia estado de jogo, e os oclusores só existiam por causa da luz.
# ============================================================
extends SubViewportContainer

const CidadeView = preload("res://scripts/cidade_view.gd")

var viewport: SubViewport
var view: Control

var estado: Dictionary = {}:
	set(v):
		estado = v
		if view != null:
			view.estado = v

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

func semear_npcs() -> void:
	if view != null:
		view.semear_npcs()

