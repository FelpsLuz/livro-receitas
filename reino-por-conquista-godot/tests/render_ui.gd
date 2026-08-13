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
const Llm = preload("res://scripts/llm.gd")
const Combate = preload("res://scripts/combate.gd")
const Contratos = preload("res://scripts/contratos.gd")
const Barbaros = preload("res://scripts/barbaros.gd")

func _initialize() -> void:
	Jogo.apagar_save()
	# a primeira saga obriga a escolher a IA; o harness escolhe "sem IA"
	# de antemão para iniciar_jogo não parar no modal
	Llm.definir({"provedor": "desligado", "url": "", "chave": "", "modelo": ""})
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

	# o modal OBRIGATÓRIO da primeira saga: sem escolha feita, iniciar abre
	# o seletor com o recomendado (Gemini) pré-selecionado
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Llm.ARQUIVO_CFG))
	jogo.iniciar_jogo("Aldric de Vau")
	await _quadro(jogo, "ia_obrigatoria")
	jogo.overlay_modal.visible = false
	Llm.definir({"provedor": "desligado", "url": "", "chave": "", "modelo": ""})

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
	await _tirar(jogo, 3, "taverna_salao", 640)
	# as duas abas que ficavam de fora deste harness — e que por isso eram as
	# duas em que ninguém tinha olhado: a ficha da casa e a crônica
	await _tirar(jogo, 8, "familia")
	await _tirar(jogo, 9, "cronica")
	await _tirar(jogo, 10, "guerras")

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
	# o relatório com o formato REAL de Combate.batalhar — um dicionário de
	# mão aqui mascarou por semanas um SCRIPT ERROR em toda batalha da UI
	jogo._modal_batalha(Combate.batalhar(st, Combate.exercito_inimigo(2),
		"Cerco a Império Central"))
	await _quadro(jogo, "modal_cerco")
	jogo.overlay_modal.visible = false

	# o seletor de IA, com o aviso de custo do provedor pago
	jogo._modal_llm()
	await _quadro(jogo, "modal_ia")
	jogo.overlay_modal.visible = false

	# a tela de conversa, com retrato e máquina de escrever
	jogo.abrir_conversa({"id": "rei_imperio", "nome": "Touro Bill",
		"personalidade": "cruel"})
	await _quadro(jogo, "conversa")
	jogo.fechar_conversa()

	# ---- os fluxos do Bloco I: viagem, contrato e fronteira ----
	# Os três modais novos que nenhum quadro cobria — e onde uma regressão
	# de layout viveria invisível até o próximo teste alfa. Ficam no FIM do
	# harness de propósito: o batedor consome um dia do relógio, e nada
	# abaixo dele pode depender da agenda.
	jogo._abrir_viagem("imperio")
	await _quadro(jogo, "viagem_popup")
	jogo.overlay_modal.visible = false

	var mural: Array = Contratos.do_local(st)
	if mural.is_empty():
		push_error("Invalid mural vazio: sem contrato para o quadro de preparação")
	else:
		jogo._modal_preparacao(mural[0])
		await _quadro(jogo, "contrato_preparacao")
		jogo.overlay_modal.visible = false

	# ---- os dois estados de tela que a integração criou ----
	# A CELA: o jogador preso via a interface como se nada tivesse
	# acontecido. Agora a aba da terra abre com o painel de ferros.
	Jogo.prender(st, 2, Jogo.log_para(st))
	await _tirar(jogo, 0, "cadeia")
	st["jogador"]["preso_ate"] = 0
	# A PRAÇA QUE NÃO EXISTE: nas Terras Bárbaras a Feira desenhava a
	# tabela com preço 0 em tudo e 14 erros de script atrás dela.
	st["local"] = "barbaros"
	await _tirar(jogo, 2, "feira_sem_praca")

	# a fronteira selvagem RECONHECIDA: batedor pago, conta dos clãs na mesa
	st["local"] = "barbaros"
	var r_esp: Dictionary = Barbaros.espiar(st, Jogo.log_para(st))
	if not bool(r_esp.get("ok", false)):
		push_error("Invalid batedor recusado no harness: %s" % str(r_esp.get("msg", "")))
	await _tirar(jogo, 1, "fronteira", 340)
	jogo._modal_invadir()
	await _quadro(jogo, "modal_invadir")
	jogo.overlay_modal.visible = false

	# A CORTE DE UMA TERRA SEM TRONO. Aqui a aba abria a corte do IMPÉRIO —
	# `_reino_local()` devolvia `reinos[0]` quando não achava o lugar — e a
	# tela dizia "Corte de Trono Verde" no meio das Terras Bárbaras, com a
	# conversa com Felippe funcionando. É o furo mais grave da auditoria, e
	# não havia um único quadro que passasse por ele.
	st["local"] = "barbaros"
	await _tirar(jogo, 4, "corte_barbaros")
	st["local"] = "sem_rei"
	await _tirar(jogo, 4, "corte_sem_rei")
	st["local"] = "imperio"

	# ---- O EIXO DO MEDO, nas duas telas onde ele aparece ----
	# Com crueldade 0 (o padrão do harness) nada disso desenha: o cartão do
	# medo some e o imposto de guerra fica apagado. Ou seja, os dois
	# controles novos do Bloco 6 não passariam por render nenhum — que é
	# exatamente como um botão nasce quebrado e ninguém vê.
	st["local"] = "imperio"
	st["jogador"]["crueldade"] = 5
	await _tirar(jogo, 8, "casa_medo")
	await _tirar(jogo, 0, "terra_imposto_guerra", 460)
	st["jogador"]["crueldade"] = 0

	# O LIVRO-RAZÃO do mês fechado. É a tela que existe para o jogador parar
	# de concluir que o jogo é aleatório: vinte e um passos rodam na virada e
	# até aqui ele via só o resultado.
	# `atualizar()` DRENA o balanço e abre o modal sozinho — é esse o
	# caminho do jogador. Chamar `_modal_balanco` depois encontraria a fila
	# já vazia, que foi o que aconteceu na primeira tentativa deste quadro.
	st["evento_pendente"] = null
	st["fim"] = null
	Jogo.passar_mes(st)
	jogo.atualizar()
	await _quadro(jogo, "balanco_mes")
	jogo.overlay_modal.visible = false

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
	# NENHUMA aba pode pedir mais largura mínima que o canvas: foi assim que
	# a Taverna empurrou a interface inteira para fora dos 960 e cortou até
	# o botão "Passar o mês" (push_error contém "Invalid" — o render acusa)
	var minw := (jogo.tela_jogo as Control).get_combined_minimum_size().x
	if minw > 960.0:
		push_error("Invalid largura minima: aba %s pede %dpx num canvas de 960" % [nome, int(minw)])
	# e a BARRA DE ABAS também não pode estourar: com 11 plaquetas a última
	# nasce escondida atrás das setas, que foi achado do teste alfa
	var barra := jogo.tabs.get_tab_bar() as TabBar
	if barra != null and barra.get_offset_buttons_visible():
		push_error("Invalid barra de abas rolando: as %d abas não cabem no canvas"
			% barra.tab_count)
	var rolagem := jogo.tabs.get_current_tab_control() as ScrollContainer
	if rolagem != null:
		rolagem.scroll_vertical = int(rolar)
		for i in 4:
			await process_frame
	var img := root.get_texture().get_image()
	img.save_png("user://ui_%s.png" % nome)
	print("  ▸ ui_%s.png  %dx%d" % [nome, img.get_width(), img.get_height()])
