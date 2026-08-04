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

	# herói ACIMA de uma casa: tem que ser desenhado ATRÁS dela
	vila.heroi.position = Vector2(520, 520)
	vila._rota = []                      # congela a ronda para o retrato
	for i in 4:
		await process_frame
	await _salvar(vila, "atras")

	# herói ABAIXO da mesma casa: tem que ser desenhado NA FRENTE
	vila.heroi.position = Vector2(520, 700)
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

	print("pronto: ", ProjectSettings.globalize_path("user://"))
	quit(0)

func _salvar(vila, nome: String) -> void:
	await process_frame
	var img: Image = vila.viewport.get_texture().get_image()
	var caminho := "user://render_%s.png" % nome
	img.save_png(caminho)
	print("  salvo %s  (%dx%d)" % [caminho, img.get_width(), img.get_height()])
