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

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
