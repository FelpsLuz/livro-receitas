# ============================================================
# RENDER DO CENÁRIO v2 — prova visual do §I.5 (addendum v3).
# Renderiza o N pedido num SubViewport 400×200 NEAREST e salva 1× e 2×
# (o 2× é upscale por inteiro, nunca fracionário).
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/render_cenario_v2.gd
# ============================================================
extends SceneTree

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 200)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var cena := CenarioV2Cena.new()
	vp.add_child(vp_preparar(cena))

	for nivel in [1, 0]:
		cena.nivel = nivel
		for i in 6:
			await process_frame
		var img := vp.get_texture().get_image()
		var base := "user://cenario_v2_n%d" % nivel
		img.save_png(base + "_1x.png")
		var dobro := img.duplicate()
		dobro.resize(800, 400, Image.INTERPOLATE_NEAREST)
		dobro.save_png(base + "_2x.png")
		print("💾 ", ProjectSettings.globalize_path(base + "_2x.png"))

	quit(0)

func vp_preparar(cena: Node) -> Node:
	return cena
