# ============================================================
# RENDERIZA A EVOLUÇÃO DO PANORAMA — um PNG por nível de terra.
#
# O teste estrutural prova que as peças trocam de nível; só a imagem prova
# que a paliçada vira muralha SEM buraco, que o castelo não invade o céu e
# que a feira não nasce em cima do poço.
#   xvfb-run godot --rendering-driver opengl3 --script res://tests/render_evolucao.gd
# ============================================================
extends SceneTree

const PanoramaCena = preload("res://scripts/panorama_cena.gd")

func _initialize() -> void:
	if not PanoramaCena.disponivel():
		print("panorama indisponível — nada a renderizar")
		quit(1)
		return
	var cena: SubViewportContainer = PanoramaCena.new()
	root.add_child(cena)
	for nivel in 6:
		cena.estado = {"terra": {"nivel": nivel}, "mes": 6}
		for i in 10:
			await process_frame
		var img: Image = cena.viewport.get_texture().get_image()
		img.save_png("user://evolucao_n%d.png" % nivel)
		print("  ▸ evolucao_n%d.png  %dx%d" % [nivel, img.get_width(), img.get_height()])
	# e as estações no nível máximo
	for par in [[1, "inverno"], [10, "outono"]]:
		cena.estado = {"terra": {"nivel": 5}, "mes": par[0]}
		for i in 10:
			await process_frame
		var img: Image = cena.viewport.get_texture().get_image()
		img.save_png("user://evolucao_%s.png" % par[1])
		print("  ▸ evolucao_%s.png" % par[1])
	print("pronto — ", ProjectSettings.globalize_path("user://"))
	quit()
