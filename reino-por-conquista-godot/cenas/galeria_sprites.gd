# ============================================================
# GALERIA DE SPRITES — confere de olho o que o PixelLab gerou.
# Monta um Sprite2D REAL por personagem, na grade, com o nome embaixo
# e um aviso de quem ainda está usando o retrato procedural de reserva.
#   godot --path reino-por-conquista-godot res://cenas/galeria_sprites.tscn
# ============================================================
extends Control

const SpritesPersonagens = preload("res://scripts/sprites_personagens.gd")

const COLUNAS := 6
const CELULA := Vector2(150, 168)
const MARGEM := Vector2(96, 92)

func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("1d1309")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var ids := SpritesPersonagens.todos_os_ids()
	var falta := SpritesPersonagens.faltando()

	var titulo := Label.new()
	titulo.text = "Galeria de personagens — %d de %d com sprite gerado" % [ids.size() - falta.size(), ids.size()]
	titulo.position = Vector2(28, 26)
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("c9a227"))
	add_child(titulo)

	if not falta.is_empty():
		var aviso := Label.new()
		aviso.text = "Ainda no retrato de reserva: " + ", ".join(falta)
		aviso.position = Vector2(28, 54)
		aviso.add_theme_color_override("font_color", Color("8b6a45"))
		add_child(aviso)

	for i in ids.size():
		var id: String = ids[i]
		var pos := MARGEM + Vector2(
			(i % COLUNAS) * CELULA.x,
			floor(float(i) / COLUNAS) * CELULA.y)

		# moldura da célula
		var moldura := ColorRect.new()
		moldura.color = Color(0, 0, 0, 0.28)
		moldura.position = pos - Vector2(64, 62)
		moldura.size = Vector2(128, 140)
		add_child(moldura)

		# O NÓ QUE INTERESSA: Sprite2D usando a imagem baixada do PixelLab
		var sprite := SpritesPersonagens.criar_sprite(id, 2)
		sprite.position = pos
		add_child(sprite)

		var nome := Label.new()
		nome.text = id
		nome.position = pos + Vector2(-62, 50)
		nome.size = Vector2(124, 20)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_font_size_override("font_size", 12)
		nome.add_theme_color_override("font_color",
			Color("e8d8b0") if SpritesPersonagens.tem_sprite(id) else Color("7a6a55"))
		add_child(nome)
