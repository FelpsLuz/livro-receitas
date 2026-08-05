# ============================================================
# RENDER DO CENÁRIO v2 — prova visual dos addenda v3/v3.1.
# Salva em user://:
#   cenario_v2_n{0,1}_{1x,2x}.png    composição por nível
#   cenario_v2_silhueta.png          teste de silhueta (v3.1 §D)
#   cenario_v2_vida_f{0..7}.png      frames a cada 0.4s — água ciclando,
#                                    juncos balançando, nuvens derivando
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/render_cenario_v2.gd
# ============================================================
extends SceneTree

const FRAMES_VIDA := 8
const INTERVALO := 0.4

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 200)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var cena := CenarioV2Cena.new()
	vp.add_child(cena)

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

	# ---- teste de silhueta (v3.1 §D): vila em preto sobre branco ----
	cena.nivel = 1
	cena.silhueta = true
	for i in 6:
		await process_frame
	var sil := vp.get_texture().get_image()
	sil.resize(800, 400, Image.INTERPOLATE_NEAREST)
	sil.save_png("user://cenario_v2_silhueta.png")
	print("💾 ", ProjectSettings.globalize_path("user://cenario_v2_silhueta.png"))
	cena.silhueta = false

	# ---- frames da vida (§G): tempo REAL entre capturas ----
	cena.nivel = 0
	for i in 6:
		await process_frame
	for f in FRAMES_VIDA:
		var img := vp.get_texture().get_image()
		img.save_png("user://cenario_v2_vida_f%d.png" % f)
		await create_timer(INTERVALO).timeout
	print("💾 ", ProjectSettings.globalize_path("user://cenario_v2_vida_f0.png"),
		  " … f%d" % (FRAMES_VIDA - 1))

	quit(0)
