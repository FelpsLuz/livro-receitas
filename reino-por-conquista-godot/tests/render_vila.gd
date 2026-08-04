# ============================================================
# RENDERIZA A VILA PARA PNG — verificação VISUAL, não só estrutural.
# Um teste headless prova que os nós existem; só a imagem prova que a vila
# está bonita e que o Y-Sort põe o herói no lugar certo.
#   xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/render_vila.gd
# Salva em user:// (o caminho real sai impresso no fim).
# ============================================================
extends SceneTree

const VilaCena = preload("res://scripts/vila_cena.gd")

func _initialize() -> void:
	var vila = VilaCena.new()
	vila.size = Vector2(960, 540)
	root.add_child(vila)
	vila.estado = {"terra": {"nivel": 5, "nome": "Vale do Corvo"}, "mes": 6}

	# alguns quadros para a luz, o TileMap e o Y-Sort assentarem
	for i in 8:
		await process_frame

	# herói ACIMA de uma casa (casa em 560,610): o corpo some atrás do telhado,
	# só a cabeça aparece por cima — a prova clássica do Y-Sort
	vila.heroi.position = Vector2(600, 565)
	vila._rota = []                      # congela a ronda para o retrato
	for i in 4:
		await process_frame
	await _salvar(vila, "atras")

	# herói ABAIXO da mesma casa: inteiro, na frente da porta
	vila.heroi.position = Vector2(600, 660)
	for i in 4:
		await process_frame
	await _salvar(vila, "frente")

	# panorama do nível 5 com o herói na rota
	vila.heroi.position = Vector2(960, 780)
	for i in 4:
		await process_frame
	await _salvar(vila, "vila_nivel5")

	vila.estado = {"terra": null, "mes": 1}
	for i in 6:
		await process_frame
	await _salvar(vila, "acampamento")

	# ---- o que o jogador REALMENTE vê na aba ----
	# com stretch, o SubViewport assume o tamanho do container; na aba ele é
	# bem menor que o mundo, então é este render que vale como prova.
	var aba = VilaCena.new()
	aba.size = Vector2(560, 315)
	root.add_child(aba)
	aba.estado = {"terra": {"nivel": 3, "nome": "Vale do Corvo"}, "mes": 9}
	for i in 10:
		await process_frame
	await _salvar(aba, "aba_real")

	# ---- a vitrine, com os ícones novos nos slots ----
	aba.queue_free()
	vila.queue_free()
	var cena_v := load("res://cenas/vitrine_v2.tscn")
	if cena_v != null:
		var inst = cena_v.instantiate()
		root.add_child(inst)
		for i in 10:
			await process_frame
		var img_v: Image = root.get_texture().get_image()
		img_v.save_png("user://render_vitrine.png")
		print("  salvo user://render_vitrine.png  (%dx%d)" % [img_v.get_width(), img_v.get_height()])
		inst.queue_free()

	print("pronto: ", ProjectSettings.globalize_path("user://"))
	quit(0)

func _salvar(vila, nome: String) -> void:
	await process_frame
	var img: Image = vila.viewport.get_texture().get_image()
	var caminho := "user://render_%s.png" % nome
	img.save_png(caminho)
	print("  salvo %s  (%dx%d)" % [caminho, img.get_width(), img.get_height()])
