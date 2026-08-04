# ============================================================
# TESTE DA VILA EM NÓS NATIVOS
# Prova que a aba "Terra" virou cena de verdade: TileMapLayer no chão,
# objetos do PixelLab como Sprite2D, herói animado caminhando e — o ponto
# que mais quebra na prática — Y-Sort ordenando pela BASE de cada sprite.
#   godot --headless --path . --script res://tests/teste_vila.gd
# ============================================================
extends SceneTree

const VilaCena = preload("res://scripts/vila_cena.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const MapaV2 = preload("res://scripts/mapa_v2.gd")

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
	print("=== VILA EM NÓS NATIVOS ===")

	ok("assets da vila presentes", VilaCena.disponivel())

	# ---------- direção a partir do vetor de movimento ----------
	# o Y da tela cresce para BAIXO: descer é "south", não "north"
	var casos := {
		"east": Vector2(1, 0), "south": Vector2(0, 1),
		"west": Vector2(-1, 0), "north": Vector2(0, -1),
		"south-east": Vector2(1, 1), "north-west": Vector2(-1, -1),
		"south-west": Vector2(-1, 1), "north-east": Vector2(1, -1),
	}
	var erradas: Array = []
	for esperado in casos:
		var achou: String = VilaCena.direcao_de(casos[esperado])
		if achou != esperado:
			erradas.append("%s→%s" % [esperado, achou])
	ok("as 8 direções saem certas do vetor", erradas.is_empty(), ", ".join(erradas))
	ok("vetor parado não quebra", VilaCena.direcao_de(Vector2.ZERO) == "south")
	# toda direção gerada precisa existir no SpriteFrames, senão o herói congela
	var sf: SpriteFrames = PersonagensV2.quadros("heroi_jogador")
	var sem_anim: Array = []
	for esperado in casos:
		if not sf.has_animation(esperado + "_walk"):
			sem_anim.append(esperado)
	ok("toda direção da rota tem animação", sem_anim.is_empty(), ", ".join(sem_anim))

	# ---------- a cena monta? ----------
	var vila = VilaCena.new()
	root.add_child(vila)
	vila.estado = {"terra": {"nivel": 5, "nome": "Teste"}, "mes": 6}
	await process_frame

	ok("SubViewport criado", vila.viewport is SubViewport)
	ok("terreno é TileMapLayer com células escritas",
		vila.terreno is TileMapLayer and vila.terreno.get_used_cells().size() > 0,
		"%d células" % (vila.terreno.get_used_cells().size() if vila.terreno else -1))
	ok("faixa de água montada",
		vila.agua is TileMapLayer and vila.agua.get_used_cells().size() > 0,
		"%d células" % (vila.agua.get_used_cells().size() if vila.agua else -1))

	# ---------- Y-SORT: o ponto central desta etapa ----------
	ok("mundo com Y-Sort ligado", vila.mundo != null and vila.mundo.y_sort_enabled)
	ok("escala do mundo é razão inteira 1:2", vila.mundo.scale == Vector2(0.5, 0.5),
		str(vila.mundo.scale))
	# cada sprite precisa ter a origem nos pés, senão o Y-Sort compara o centro
	var mal_ancorados: Array = []
	for f in vila.mundo.get_children():
		var alt := 0.0
		if f is Sprite2D and f.texture != null:
			alt = f.texture.get_height()
		elif f is AnimatedSprite2D and f.sprite_frames != null:
			var t: Texture2D = f.sprite_frames.get_frame_texture(f.animation, 0)
			alt = t.get_height() if t != null else 0.0
		if alt > 0.0 and not is_equal_approx(f.offset.y, -alt / 2.0):
			mal_ancorados.append("%s off=%.1f alt=%.0f" % [f.name, f.offset.y, alt])
	ok("todo sprite ancorado nos pés", mal_ancorados.is_empty(),
		", ".join(mal_ancorados))

	var n_obj: int = vila._objetos.size()
	var n_ald: int = vila._aldeoes.size()
	print("  ℹ️  nível 5: %d objetos, %d aldeões" % [n_obj, n_ald])
	ok("objetos da vila instanciados", n_obj > 0)
	ok("aldeões instanciados", n_ald > 0)
	# a vila tem que CRESCER com a terra: o castelo é privilégio do nível 5
	var ids5: Array = []
	for p in vila._planta(5):
		ids5.append(p[0])
	var ids1: Array = []
	for p in vila._planta(1):
		ids1.append(p[0])
	ok("torre do castelo só aparece no nível 5",
		"torre_castelo" in ids5 and not ("torre_castelo" in ids1))
	ok("muralha e portão chegam no nível 3",
		"portao_fortificado" in vila._planta(3).map(func(p): return p[0])
		and not ("portao_fortificado" in ids1))

	# ---------- o herói caminha e vira ----------
	ok("herói animado na cena", vila.heroi is AnimatedSprite2D)
	if vila.heroi != null:
		var antes: Vector2 = vila.heroi.position
		for i in 20:
			vila._process(0.05)
		ok("herói se moveu ao longo da rota", vila.heroi.position != antes,
			"%.0f px" % antes.distance_to(vila.heroi.position))
		ok("herói está tocando uma animação de caminhada",
			vila.heroi.animation.ends_with("_walk"), vila.heroi.animation)
		# a rota é um laço fechado: passar do último alvo volta ao primeiro
		vila._alvo = vila._rota.size() - 1
		vila.heroi.position = vila._rota[vila._alvo]
		vila._process(0.05)
		ok("rota é um laço fechado", vila._alvo == 0, "alvo=%d" % vila._alvo)

	# ---------- a vila acompanha o nível da terra ----------
	# o chão conta a mesma história que as construções
	ok("cidade murada tem rua calçada", vila.rua.get_used_cells().size() > 0,
		"%d células" % vila.rua.get_used_cells().size())
	var no_5: int = vila._objetos.size()
	vila.estado = {"terra": {"nivel": 1, "nome": "Teste"}, "mes": 6}
	await process_frame
	ok("vila menor no nível 1 que no 5", vila._objetos.size() < no_5,
		"%d < %d" % [vila._objetos.size(), no_5])
	# sem terra nenhuma: acampamento, e nada pode quebrar
	vila.estado = {"terra": null, "mes": 1}
	await process_frame
	ok("acampamento (sem terra) monta sem quebrar", vila._objetos.size() > 0,
		"%d objetos" % vila._objetos.size())
	ok("acampamento não tem rua calçada", vila.rua.get_used_cells().is_empty(),
		"%d células" % vila.rua.get_used_cells().size())
	# sem terra não há lavoura: o chão é só grama, sem tile de terra arada
	var arada := 0
	for c in vila.terreno.get_used_cells():
		if vila.terreno.get_cell_atlas_coords(c) != MapaV2.TILE_CHEIO:
			arada += 1
	ok("acampamento não tem lavoura", arada == 0, "%d células aradas" % arada)
	# o rio é geografia: continua lá em qualquer nível
	ok("rio permanece sem terra", vila.agua.get_used_cells().size() > 0)
	# remontar duas vezes seguidas não pode duplicar objetos
	var antes_semear: int = vila._objetos.size()
	vila.semear_npcs()
	ok("semear_npcs() não duplica objetos", vila._objetos.size() == antes_semear,
		"%d = %d" % [vila._objetos.size(), antes_semear])

	vila.queue_free()
	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
