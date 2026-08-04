# ============================================================
# TESTE — integração dos sprites gerados pelo PixelLab.
# Confere que os PNG em res://assets/sprites/ são realmente usados pelos
# nós e que o jogo continua de pé quando um sprite ainda não existe.
#   godot --headless --path . --script res://tests/teste_sprites.gd
# ============================================================
extends SceneTree

const Retratos = preload("res://scripts/retratos.gd")
const SpritesPersonagens = preload("res://scripts/sprites_personagens.gd")

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
	print("=== SPRITES DO PIXELLAB ===")

	var ids := SpritesPersonagens.todos_os_ids()
	ok("elenco tem 18 personagens", ids.size() == 18, str(ids.size()))

	var com_sprite := 0
	for id in ids:
		if SpritesPersonagens.tem_sprite(id):
			com_sprite += 1
	print("  ℹ️  %d/%d com PNG gerado" % [com_sprite, ids.size()])

	# 1. toda textura resolve (sprite gerado OU retrato de reserva)
	var todas_ok := true
	for id in ids:
		var t := SpritesPersonagens.textura(id)
		if t == null or t.get_width() <= 0:
			todas_ok = false
			print("     falhou em: ", id)
	ok("toda textura do elenco resolve", todas_ok)

	# 2. o PNG gerado é MESMO o que sai (não o procedural)
	if com_sprite > 0:
		var alvo := ""
		for id in ids:
			if SpritesPersonagens.tem_sprite(id):
				alvo = id
				break
		var direto := load(SpritesPersonagens.PASTA + alvo + ".png")
		var pela_api := SpritesPersonagens.textura(alvo)
		ok("sprite gerado tem prioridade sobre o procedural",
			pela_api != null and direto != null
			and pela_api.get_width() == direto.get_width()
			and pela_api.get_height() == direto.get_height(),
			"%s %dx%d" % [alvo, direto.get_width(), direto.get_height()])
		# 3. transparência preservada (RGBA)
		var img: Image = direto.get_image()
		ok("PNG mantém canal alfa", img.get_format() == Image.FORMAT_RGBA8
			or img.detect_alpha() != Image.ALPHA_NONE, str(img.get_format()))

	# 4. id inexistente cai no retrato procedural sem quebrar
	var fantasma := SpritesPersonagens.textura("personagem_que_nao_existe")
	ok("id desconhecido cai na reserva sem erro", fantasma != null and fantasma.get_width() == 64)

	# 5. o Sprite2D sai pronto para pixel art
	var s := SpritesPersonagens.criar_sprite("rei_touros", 3)
	ok("criar_sprite devolve Sprite2D com textura", s is Sprite2D and s.texture != null)
	ok("Sprite2D usa filtro NEAREST", s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	ok("Sprite2D usa escala inteira", s.scale == Vector2(3, 3))

	# 6. aplicar_em troca a arte de um nó já existente
	var alvo_no := Sprite2D.new()
	var aplicou := SpritesPersonagens.aplicar_em(alvo_no, "rei_imperio")
	ok("aplicar_em preenche a textura do nó", alvo_no.texture != null,
		"sprite gerado" if aplicou else "reserva procedural")
	alvo_no.free()
	s.free()

	# 7. a galeria monta sem erro
	var cena := load("res://cenas/galeria_sprites.tscn")
	ok("cena da galeria carrega", cena != null)
	if cena != null:
		var inst = cena.instantiate()
		root.add_child(inst)
		# a galeria monta os nós em _ready(); espera um quadro antes de contar
		await process_frame
		var sprites := 0
		for filho in inst.get_children():
			if filho is Sprite2D:
				sprites += 1
		ok("galeria monta um Sprite2D por personagem", sprites == ids.size(), str(sprites))
		inst.queue_free()

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
