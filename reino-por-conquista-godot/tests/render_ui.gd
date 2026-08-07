# ============================================================
# RENDERIZA AS ABAS COM ARTE NOVA — verificação VISUAL.
#
# O teste headless prova que o TextureRect existe; só a imagem prova que o
# retrato da tropa não saiu esticado, que a faixa do cerco não virou um par de
# olhos gigantes e que a Corte não ficou com uma coluna de clones.
#   xvfb-run godot --rendering-driver opengl3 --script res://tests/render_ui.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Relogio = preload("res://scripts/relogio.gd")

func _initialize() -> void:
	Jogo.apagar_save()
	var cena := load("res://cenas/principal.tscn")
	var jogo: Control = cena.instantiate()
	# NÃO forçar o tamanho aqui: o canvas do projeto é 960×540 e a janela só o
	# ESCALA. Dar 1100 de largura ao Control joga 140px de interface para fora
	# da imagem — e o retrato do problema vira o retrato do harness.
	root.add_child(jogo)
	# a tela de título tem uma vila nível 5 rodando dentro dela: precisa de
	# quadros para o TileMap, o herói e as partículas assentarem
	for i in 40:
		await process_frame
	await _quadro(jogo, "titulo")

	jogo.iniciar_jogo("Aldric de Vau")
	var st: Dictionary = jogo.state

	# um reino de verdade: terra crescida, corte formada, exército em campo
	st["jogador"]["ouro"] = 4000
	st["jogador"]["renome"] = 60
	st["terra"] = {"nome": "Vale do Corvo", "nivel": 4, "populacao": 260,
		"alimento": 300, "madeira": 180, "felicidade": 62, "pressao": 0.0,
		"notaveis": [
			{"nome": "Bram Cinzas", "genero": "m", "oficio": "ferreiro",
				"riqueza": 620, "ambicao": 4, "lealdade": 82, "lorde": true},
			{"nome": "Elda do Vau", "genero": "f", "oficio": "mercador",
				"riqueza": 540, "ambicao": 7, "lealdade": 71, "lorde": true},
			{"nome": "Osric Palha", "genero": "m", "oficio": "moleiro",
				"riqueza": 310, "ambicao": 3, "lealdade": 55, "lorde": false},
			{"nome": "Mira Vento", "genero": "f", "oficio": "taverneiro",
				"riqueza": 200, "ambicao": 9, "lealdade": 34, "lorde": false},
		]}
	for tipo in st["jogador"]["tropas"]:
		st["jogador"]["tropas"][tipo] = 0
	st["jogador"]["tropas"]["lanceiro"] = 60
	st["jogador"]["tropas"]["espadachim"] = 24
	st["jogador"]["tropas"]["arqueiro"] = 30
	st["jogador"]["tropas"]["cav_pesada"] = 12

	# um exército já nos muros, para a faixa do acampamento de cerco aparecer
	var alvo: String = st["reinos"][0]["id"]
	Marchas.despachar(st, alvo, {"lanceiro": 20, "espadachim": 8}, "cerco", "senhor")
	# Relogio.avancar, não Marchas.avancar: é o relógio que move `minuto`, e a
	# marcha só chega quando o relógio passa por ela
	Relogio.avancar(st, 340, Jogo.log_para(st))

	# a vila precisa de quadros próprios depois de entrar no jogo
	await _tirar(jogo, 0, "terra", 0, 40)
	await _tirar(jogo, 1, "mapa")          # neblina de guerra + espionagem
	await _tirar(jogo, 1, "mapa_rolado", 260)
	await _tirar(jogo, 2, "mercado")       # ícones de mercadoria
	await _tirar(jogo, 6, "clas")
	await _tirar(jogo, 7, "intrigas")      # ícone de espião nas operações
	await _tirar(jogo, 5, "exercito")      # tropas, manutenção, cerco, comandante
	await _tirar(jogo, 5, "exercito_marcha", 620)
	await _tirar(jogo, 4, "corte")         # lordes gerados em partida
	await _tirar(jogo, 3, "taverna")
	await _tirar(jogo, 3, "taverna_servicos", 900)
	# as duas abas que ficavam de fora deste harness — e que por isso eram as
	# duas em que ninguém tinha olhado: a ficha da casa e a crônica
	await _tirar(jogo, 8, "familia")
	await _tirar(jogo, 9, "cronica")

	st["terra"]["alimento"] = 0            # celeiro vazio: a cena da fome
	await _tirar(jogo, 0, "terra_fome", 300)
	st["terra"]["alimento"] = 300

	# ---- a NOITE, com a aba da terra aberta ----
	# A hora é forçada direto no gerente, SEM atualizar() no meio: atualizar
	# chamaria transitar_para_mes e desfaria a noite antes do quadro. É o
	# único jeito de ver as janelas acesas e a compensação de tinta — os dois
	# efeitos que só existem com luminância baixa.
	#
	# ANTES do quadro de inverno, de propósito: flocos têm 13s de vida, e a
	# neve do inverno anterior ainda estaria no ar sobre uma noite de
	# primavera — foi flagrado no render, nevando fora de estação.
	jogo.tabs.current_tab = 0
	jogo.atualizar()
	for i in 12:
		await process_frame
	var gerente := root.get_node_or_null("EnvironmentManager")
	if gerente != null:
		gerente.hora = 0.93            # noite fechada
	for i in 30:
		await process_frame
	await _quadro(jogo, "terra_noite")
	if gerente != null:
		gerente.definir_mes(3)

	st["mes"] = 1                          # inverno: a vila coberta de neve
	await _tirar(jogo, 0, "terra_inverno", 380)
	st["mes"] = 3

	# os modais com ilustração
	st["evento_pendente"] = {"tipo": "rebeliao"}
	await _modal(jogo, "modal_rebeliao")
	st["evento_pendente"] = {"tipo": "notavel_ambicioso", "nome": "Mira Vento"}
	await _modal(jogo, "modal_ambicioso")
	st["evento_pendente"] = {"tipo": "traicao_guardas"}
	await _modal(jogo, "modal_traicao")
	st["evento_pendente"] = null
	jogo._modal_batalha({"vitoria": true, "contexto": "Cerco a Império Central",
		"rodadas": [], "debandada": "", "baixas_jogador": 14})
	await _quadro(jogo, "modal_cerco")
	jogo.overlay_modal.visible = false

	# a tela de conversa, com retrato e máquina de escrever
	jogo.abrir_conversa({"id": "rei_imperio", "nome": "Touro Bill",
		"personalidade": "cruel"})
	await _quadro(jogo, "conversa")

	print("pronto — PNGs em ", ProjectSettings.globalize_path("user://"))
	quit()

func _modal(jogo: Control, nome: String) -> void:
	jogo.atualizar()
	await _quadro(jogo, nome)

func _quadro(jogo: Control, nome: String) -> void:
	for i in 8:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("user://ui_%s.png" % nome)
	print("  ▸ ui_%s.png  %dx%d" % [nome, img.get_width(), img.get_height()])

func _tirar(jogo: Control, aba: int, nome: String, rolar: float = 0.0,
		quadros: int = 12) -> void:
	jogo.tabs.current_tab = aba
	jogo.atualizar()
	for i in quadros:
		await process_frame
	var rolagem := jogo.tabs.get_current_tab_control() as ScrollContainer
	if rolagem != null:
		rolagem.scroll_vertical = int(rolar)
		for i in 4:
			await process_frame
	var img := root.get_texture().get_image()
	img.save_png("user://ui_%s.png" % nome)
	print("  ▸ ui_%s.png  %dx%d" % [nome, img.get_width(), img.get_height()])
