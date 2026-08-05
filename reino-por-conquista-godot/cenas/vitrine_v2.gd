# ============================================================
# VITRINE DO OVERHAUL — prova visual de que os quatro grupos de assets Pro
# estão ligados a nós NATIVOS da Godot, todos na mesma tela:
#   TileMapLayer (terreno)  ·  Sprite2D/AnimatedSprite2D (objetos e personagens)
#   NinePatchRect (UI)      ·  Theme com StyleBoxTexture (painéis e botões)
#   godot --path reino-por-conquista-godot res://cenas/vitrine_v2.tscn
# ============================================================
extends Control

const UIv2 = preload("res://scripts/ui_v2.gd")
const MapaV2 = preload("res://scripts/mapa_v2.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const Tema = preload("res://scripts/tema.gd")
const Vfx = preload("res://scripts/vfx.gd")
const Icones = preload("res://scripts/icones.gd")

func _ready() -> void:
	theme = Tema.criar()

	# ---------- 1. TERRENO: TileMapLayer com o atlas Wang ----------
	var mundo := Node2D.new()
	add_child(mundo)
	var atlas: Array = MapaV2.disponiveis()
	if not atlas.is_empty():
		var camada: TileMapLayer = MapaV2.criar_camada(atlas[0], 32)
		if camada != null:
			camada.scale = Vector2(2, 2)
			mundo.add_child(camada)
			# o tile PURO do material de cima (grama) — carimbar um tile de
			# transição vira papel de parede de pedras
			MapaV2.preencher(camada, Rect2i(0, 0, 16, 9), MapaV2.TILE_CHEIO)

	# ---------- 2. OBJETOS: Sprite2D com os PNG de map-objects ----------
	var objetos := ["arvore_carvalho", "casa_camponesa", "torre_castelo",
		"poco_pedra", "bau_tesouro", "fogueira_acampamento", "barril_carga", "arvore_pinheiro",
		"ferraria", "moinho_vento", "muralha_pedra", "portao_fortificado", "barraca_mercado",
		"tenda_simples", "tenda_grande", "carroca", "sacos_carga", "tocha_estaca", "ponte_madeira"]
	# grade compacta na METADE ESQUERDA — a UI mora na direita, e sobrepor
	# os dois transformava a vitrine numa colagem ilegível
	var col := 0
	for nome in objetos:
		var caminho: String = "res://assets_v2/objects/" + nome + ".png"
		if not ResourceLoader.exists(caminho):
			continue
		var s := Sprite2D.new()
		s.texture = load(caminho)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(64 + (col % 7) * 66, 110 + int(col / 7) * 95)
		s.scale = Vector2(0.55, 0.55)
		s.centered = true
		# a vitrine também prova os VFX: fumaça na forja, fogo na fogueira
		if nome == "ferraria":
			var fu := Vfx.fumaca(Vector2(35, -70), true)
			if fu != null:
				s.add_child(fu)
		elif nome == "fogueira_acampamento":
			s.add_child(Vfx.fogo(Vector2(0, 6), 0.8))
		mundo.add_child(s)
		col += 1

	# ---------- 3. PERSONAGENS: AnimatedSprite2D ----------
	var elenco := ["rei_touros", "rei_imperio", "capitao", "cla_lobos", "heroi_jogador"]
	var px := 85
	for id in elenco:
		var p: AnimatedSprite2D = PersonagensV2.criar(id, 1.1)
		p.position = Vector2(px, 362)
		mundo.add_child(p)
		var eti := Label.new()
		eti.text = id.trim_prefix("rei_").trim_prefix("cla_")
		if PersonagensV2.tem_caminhada(id):
			eti.text += " "
		eti.position = Vector2(px - 40, 418)
		eti.add_theme_font_size_override("font_size", 10)
		add_child(eti)
		px += 95

	# o herói caminhando: as 8 direções em movimento, uma ao lado da outra —
	# é a prova de que os quadros do animate-character viraram animação
	var andarilhos: Array = []
	if PersonagensV2.tem_caminhada("heroi_jogador"):
		var ax := 75
		for dir in PersonagensV2.DIRECOES:
			var a: AnimatedSprite2D = PersonagensV2.criar("heroi_jogador", 1.05)
			PersonagensV2.mover(a, dir, true)
			a.position = Vector2(ax, 472)
			mundo.add_child(a)
			andarilhos.append(a)
			ax += 110
		var leg := Label.new()
		leg.text = "caminhada nas 8 direções"
		leg.position = Vector2(30, 438)
		leg.add_theme_font_size_override("font_size", 11)
		leg.add_theme_color_override("font_color", Color("c9a227"))
		add_child(leg)

	# ---------- 4. UI: NinePatchRect esticado em tamanhos diferentes ----------
	# a mesma arte de 256×256 servindo caixas de proporções distintas prova
	# que o 9-slice está com as margens certas
	var painel := UIv2.criar_painel("painel_pergaminho")
	if painel != null:
		painel.position = Vector2(560, 40)
		painel.size = Vector2(360, 180)
		add_child(painel)
		var titulo := Label.new()
		titulo.text = "Inventário"
		titulo.position = Vector2(600, 70)
		add_child(titulo)
	var moldura := UIv2.criar_painel("moldura_retrato")
	if moldura != null:
		moldura.position = Vector2(600, 100)
		moldura.size = Vector2(96, 96)
		add_child(moldura)
	# slots de inventário POPULADOS: a moldura 9-slice com os ícones gerados.
	# A grade mora DENTRO do pergaminho (interior útil: 593..887 × 73..187) —
	# antes ela cobria a tábua direita da moldura e vazava na grama
	var mostruario := ["trigo", "madeira", "ferro", "sal",
		"espada", "escudo", "cerveja", "coroa"]
	for i in mostruario.size():
		var slot := Icones.slot(mostruario[i], 44)
		slot.position = Vector2(700 + (i % 4) * 48, 100 + int(i / 4) * 48)
		add_child(slot)
	# barra de HUD esticada na largura
	var barra := UIv2.criar_painel("barra_hud")
	if barra != null:
		barra.position = Vector2(560, 240)
		barra.size = Vector2(360, 30)
		add_child(barra)
	# botões do Theme (StyleBoxTexture aplicado globalmente)
	var b1 := Button.new()
	b1.text = "Passar o mês"
	b1.position = Vector2(560, 290)
	b1.size = Vector2(170, 44)
	add_child(b1)
	var b2 := Button.new()
	b2.text = "Conversar"
	b2.position = Vector2(750, 290)
	b2.size = Vector2(170, 44)
	add_child(b2)

	# ---------- resumo no canto ----------
	var resumo := Label.new()
	resumo.text = "TileMapLayer: %d atlas · Objetos: %d · UI: %d peças · Caminhando: %d dir" % [
		atlas.size(), objetos.size(), UIv2.inventario()["tem"].size(), andarilhos.size()]
	resumo.position = Vector2(16, 16)
	resumo.add_theme_color_override("font_color", Color("c9a227"))
	add_child(resumo)
