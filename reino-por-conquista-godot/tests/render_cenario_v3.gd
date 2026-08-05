# ============================================================
# PROVA VISUAL DO CENÁRIO v3 — vida e evolução.
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/render_cenario_v3.gd
# Salva em user://:
#   v3_e{1..6}.png            cada estágio com o shader de vida
#   v3_vida_f{0..7}.png       8 frames de um mesmo estágio (água e junco)
#   v3_evolucao_f{0..9}.png   a transição E5→E6 amostrada no tempo
# ============================================================
extends SceneTree

const FRAMES_VIDA := 8
const FRAMES_EVOL := 16


func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	var cena := CenarioV3Cena.new()
	vp.add_child(cena)
	for i in 6:
		await process_frame

	# cada estágio com o shader de vida ligado
	for i in CenarioV3Cena.NOMES.size():
		cena.estagio = i
		for j in 4:
			await process_frame
		vp.get_texture().get_image().save_png("user://v3_e%d.png" % (i + 1))
	print("💾 6 estágios")

	# vida: mesmo estágio, tempo correndo
	cena.estagio = 5
	for j in 4:
		await process_frame
	for f in FRAMES_VIDA:
		vp.get_texture().get_image().save_png("user://v3_vida_f%d.png" % f)
		await create_timer(0.22).timeout
	print("💾 %d frames de vida" % FRAMES_VIDA)

	# evolução E5→E6 amostrada durante o crossfade
	cena.estagio = 4
	for j in 4:
		await process_frame
	# amostragem por RELÓGIO REAL. create_timer neste laço voltava quase
	# de imediato (o save_png bloqueia e o timer já venceu), e a transição
	# aparecia completa em 3 frames. Medido à parte, o crossfade leva
	# 806ms para um alvo de 800 — o defeito era do teste, não do tween.
	cena.evoluir(5)
	var t0 := Time.get_ticks_msec()
	var passo := int(CenarioV3Cena.CROSSFADE * 1300.0) / FRAMES_EVOL
	for f in FRAMES_EVOL:
		while Time.get_ticks_msec() - t0 < passo * f:
			await process_frame
		vp.get_texture().get_image().save_png("user://v3_evolucao_f%d.png" % f)
	print("💾 %d frames de evolução" % FRAMES_EVOL)

	quit(0)
