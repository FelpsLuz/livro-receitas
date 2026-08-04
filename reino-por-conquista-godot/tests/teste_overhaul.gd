# ============================================================
# TESTE DE INTEGRIDADE DO OVERHAUL v2
# Confere que os assets Pro do PixelLab estão ligados aos nós nativos da Godot:
# NinePatchRect na UI, SpriteFrames/AnimatedSprite2D nos personagens e
# TileSet/TileMapLayer no terreno — e que nada fica sem textura quando um
# asset ainda não existe.
#   godot --headless --path . --script res://tests/teste_overhaul.gd
# ============================================================
extends SceneTree

const UIv2 = preload("res://scripts/ui_v2.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const MapaV2 = preload("res://scripts/mapa_v2.gd")
const SpritesPersonagens = preload("res://scripts/sprites_personagens.gd")
const Tema = preload("res://scripts/tema.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func _initialize() -> void:
	print("=== OVERHAUL VISUAL v2 ===")

	# ---------- UI ----------
	var inv: Dictionary = UIv2.inventario()
	print("  ℹ️  UI: %d peças geradas, %d faltando" % [inv["tem"].size(), inv["falta"].size()])
	if inv["tem"].size() > 0:
		var nome: String = inv["tem"][0]
		var np: NinePatchRect = UIv2.criar_painel(nome)
		ok("NinePatchRect criado a partir do PNG", np != null and np.texture != null, nome)
		if np != null:
			ok("margens 9-slice aplicadas nos 4 lados",
				np.patch_margin_left > 0 and np.patch_margin_top > 0
				and np.patch_margin_right > 0 and np.patch_margin_bottom > 0,
				"m=%d" % np.patch_margin_left)
			ok("UI usa filtro NEAREST (pixel nítido)",
				np.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
			# a moldura não pode ser maior que a arte, senão o miolo some
			var tam: Vector2 = np.texture.get_size()
			ok("margens cabem na textura",
				np.patch_margin_left + np.patch_margin_right < tam.x
				and np.patch_margin_top + np.patch_margin_bottom < tam.y,
				"%dx%d" % [tam.x, tam.y])
			np.free()
		var sb: StyleBoxTexture = UIv2.stylebox(nome)
		ok("StyleBoxTexture pronto para o Theme", sb != null and sb.texture != null)
		# o tema global adota a moldura automaticamente
		var t: Theme = Tema.criar()
		var painel = t.get_stylebox("panel", "PanelContainer")
		ok("Theme adotou a moldura Pro nos painéis", painel is StyleBoxTexture,
			painel.get_class())
	else:
		var t2: Theme = Tema.criar()
		ok("sem asset de UI, tema procedural continua válido",
			t2.get_stylebox("panel", "PanelContainer") != null)

	# ---------- PERSONAGENS ----------
	var ids: Array = SpritesPersonagens.todos_os_ids()
	var sf: SpriteFrames = PersonagensV2.quadros("rei_touros")
	ok("SpriteFrames montado", sf != null and sf.get_animation_names().size() > 0,
		", ".join(sf.get_animation_names()))
	var anim: String = sf.get_animation_names()[0]
	ok("animação tem ao menos 1 quadro com textura",
		sf.get_frame_count(anim) > 0 and sf.get_frame_texture(anim, 0) != null)
	var no: AnimatedSprite2D = PersonagensV2.criar("rei_touros", 2)
	ok("AnimatedSprite2D pronto e tocando",
		no is AnimatedSprite2D and no.sprite_frames != null and no.is_playing())
	ok("personagem usa NEAREST e escala inteira",
		no.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and no.scale == Vector2(2, 2))
	no.free()
	# ---------- ANIMAÇÕES DE VÁRIOS QUADROS ----------
	# os quadros do animate-character só valem se virarem animação de verdade:
	# uma imagem por direção seria o mesmo que a pose parada.
	var manif: Dictionary = PersonagensV2.manifesto()
	print("  ℹ️  personagens com animação no manifesto: %d" % manif.size())
	if manif.size() > 0:
		var pers: String = manif.keys()[0]
		ok("manifesto de animações lido", not PersonagensV2.animacoes_de(pers).is_empty(), pers)
		ok("caminhada registrada com mais de um quadro",
			PersonagensV2.tem_caminhada(pers, "south"))
		var sfa: SpriteFrames = PersonagensV2.quadros(pers)
		ok("SpriteFrames ganhou a animação de caminhada",
			sfa.has_animation("south_walk"),
			", ".join(sfa.get_animation_names()))
		if sfa.has_animation("south_walk"):
			var n_q: int = sfa.get_frame_count("south_walk")
			ok("caminhada tem vários quadros com textura",
				n_q > 1 and sfa.get_frame_texture("south_walk", n_q - 1) != null,
				"%d quadros" % n_q)
			ok("caminhada roda mais rápido que a pose parada",
				sfa.get_animation_speed("south_walk") > sfa.get_animation_speed("south"))
			ok("caminhada em laço", sfa.get_animation_loop("south_walk"))
		# as 8 direções precisam estar todas lá, senão o herói "trava" virado
		var faltando_dir: Array = []
		for d in PersonagensV2.DIRECOES:
			if not sfa.has_animation(d + "_walk"):
				faltando_dir.append(d)
		ok("caminhada nas 8 direções", faltando_dir.is_empty(), ", ".join(faltando_dir))
		# mover() precisa trocar para a caminhada e voltar para a pose parada
		var andarilho: AnimatedSprite2D = PersonagensV2.criar(pers, 2)
		ok("mover() liga a caminhada",
			PersonagensV2.mover(andarilho, "east", true) and andarilho.animation == "east_walk",
			andarilho.animation)
		ok("mover(false) volta para a pose parada",
			PersonagensV2.mover(andarilho, "east", false) and andarilho.animation == "east",
			andarilho.animation)
		# direção sem caminhada não pode quebrar: cai na pose parada
		PersonagensV2.mover(andarilho, "south", true, "inexistente")
		ok("animação inexistente cai na pose parada sem quebrar",
			andarilho.animation == "south", andarilho.animation)
		andarilho.free()
	else:
		ok("sem manifesto, quadros() continua devolvendo pose parada",
			PersonagensV2.quadros("rei_touros").get_animation_names().size() > 0)

	# nenhum personagem pode ficar sem textura
	var sem_textura: Array = []
	for id in ids:
		var q: SpriteFrames = PersonagensV2.quadros(id)
		var a: String = q.get_animation_names()[0]
		if q.get_frame_count(a) == 0 or q.get_frame_texture(a, 0) == null:
			sem_textura.append(id)
	ok("nenhum dos %d personagens sem textura" % ids.size(), sem_textura.is_empty(),
		", ".join(sem_textura))

	# ---------- TERRENO ----------
	var tilesets: Array = MapaV2.disponiveis()
	print("  ℹ️  tilesets disponíveis: %d" % tilesets.size())
	if tilesets.size() > 0:
		var tnome: String = tilesets[0]
		var ts: TileSet = MapaV2.montar(tnome, 32, [Vector2i(0, 0)])
		ok("TileSet montado do atlas", ts != null and ts.get_source_count() > 0, tnome)
		if ts != null:
			ok("tile_size correto", ts.tile_size == Vector2i(32, 32), str(ts.tile_size))
			ok("camadas de física e navegação criadas",
				ts.get_physics_layers_count() > 0 and ts.get_navigation_layers_count() > 0)
			# não basta a camada existir: o polígono precisa estar NO tile
			var fonte: TileSetAtlasSource = ts.get_source(0)
			var solido: TileData = fonte.get_tile_data(Vector2i(0, 0), 0)
			ok("tile sólido recebeu polígono de colisão",
				solido != null and solido.get_collision_polygons_count(0) > 0,
				"%d polígono(s)" % (solido.get_collision_polygons_count(0) if solido else -1))
			var livre: TileData = fonte.get_tile_data(Vector2i(1, 0), 0)
			var nav: NavigationPolygon = livre.get_navigation_polygon(0) if livre else null
			ok("tile livre recebeu malha de navegação",
				nav != null and nav.get_polygon_count() > 0,
				"%d polígono(s)" % (nav.get_polygon_count() if nav else -1))
			var camada: TileMapLayer = MapaV2.criar_camada(tnome, 32)
			ok("TileMapLayer com TileSet aplicado",
				camada != null and camada.tile_set != null)
			if camada != null:
				MapaV2.preencher(camada, Rect2i(0, 0, 4, 4), Vector2i(0, 0))
				ok("preencher() escreveu células",
					camada.get_used_cells().size() == 16,
					str(camada.get_used_cells().size()))
				camada.free()
	else:
		ok("sem tileset gerado ainda, montar() devolve null sem quebrar",
			MapaV2.montar("inexistente") == null)

	# ---------- IMPORTAÇÃO ----------
	# todo PNG em assets_v2 precisa do .import, senão o Godot não o carrega no build
	var sem_import: Array = []
	for pasta in ["ui", "characters", "tilesets", "objects"]:
		var caminho: String = "res://assets_v2/" + pasta
		var d := DirAccess.open(caminho)
		if d == null:
			continue
		for arq in d.get_files():
			if arq.ends_with(".png") and not FileAccess.file_exists(caminho + "/" + arq + ".import"):
				sem_import.append(pasta + "/" + arq)
	ok("todo PNG de assets_v2 tem .import", sem_import.is_empty(), ", ".join(sem_import))

	# ---------- VITRINE: a cena de demonstração monta inteira? ----------
	var cena_v := load("res://cenas/vitrine_v2.tscn")
	ok("cena da vitrine carrega", cena_v != null)
	if cena_v != null:
		var inst = cena_v.instantiate()
		root.add_child(inst)
		await process_frame
		var n_sprites := 0
		var n_anim := 0
		var n_patch := 0
		var n_tile := 0
		var pilha: Array = [inst]
		while not pilha.is_empty():
			var atual = pilha.pop_back()
			for f in atual.get_children():
				pilha.append(f)
			if atual is AnimatedSprite2D: n_anim += 1
			elif atual is Sprite2D: n_sprites += 1
			elif atual is NinePatchRect: n_patch += 1
			elif atual is TileMapLayer: n_tile += 1
		print("  ℹ️  vitrine: %d Sprite2D, %d AnimatedSprite2D, %d NinePatchRect, %d TileMapLayer"
			% [n_sprites, n_anim, n_patch, n_tile])
		ok("vitrine tem objetos, personagens, UI e terreno",
			n_sprites > 0 and n_anim > 0 and n_patch > 0 and n_tile > 0)
		inst.queue_free()

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
