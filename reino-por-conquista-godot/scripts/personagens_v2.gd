# ============================================================
# PERSONAGENS v2 — AnimatedSprite2D + SpriteFrames a partir dos assets gerados.
#
# Dois formatos convivem:
#   1) sprite único      assets/sprites/<id>.png            (já gerado, 18 peças)
#   2) 8 rotações v3     assets_v2/characters/<id>_<dir>.png (create-character-v3)
#
# Em ambos os casos o resultado é um SpriteFrames pronto, com uma animação por
# direção, para o nó AnimatedSprite2D. Sem arquivo nenhum, cai no retrato
# procedural — o jogo nunca fica sem textura.
# ============================================================
extends RefCounted

const Retratos = preload("res://scripts/retratos.gd")
const PASTA_V2 := "res://assets_v2/characters/"
const PASTA_V1 := "res://assets/sprites/"

## As 8 direções que o create-character-v3 devolve.
const DIRECOES := ["south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west"]

static func _tex(caminho: String) -> Texture2D:
	if not ResourceLoader.exists(caminho):
		return null
	var t = load(caminho)
	return t if t is Texture2D else null

## Quadros de um personagem: uma animação por direção quando houver rotações,
## senão uma única animação "idle" com o sprite frontal.
static func quadros(id: String, fps: float = 6.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var achou := false

	for dir in DIRECOES:
		var t := _tex(PASTA_V2 + id + "_" + dir + ".png")
		if t == null:
			continue
		sf.add_animation(dir)
		sf.set_animation_speed(dir, fps)
		sf.set_animation_loop(dir, true)
		sf.add_frame(dir, t)
		achou = true

	if not achou:
		# sem rotações: usa o sprite único (ou o retrato procedural)
		var t := _tex(PASTA_V2 + id + ".png")
		if t == null:
			t = _tex(PASTA_V1 + id + ".png")
		if t == null:
			t = Retratos.textura(id)
		sf.add_animation("idle")
		sf.set_animation_speed("idle", fps)
		sf.set_animation_loop("idle", true)
		sf.add_frame("idle", t)
	return sf

## Nó pronto para a cena: AnimatedSprite2D configurado para pixel art.
static func criar(id: String, escala: int = 2) -> AnimatedSprite2D:
	var no := AnimatedSprite2D.new()
	no.name = "Personagem_" + id
	no.sprite_frames = quadros(id)
	no.animation = ("south" if no.sprite_frames.has_animation("south") else "idle")
	no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	no.scale = Vector2(escala, escala)
	no.centered = true
	no.play()
	return no

## Vira o personagem para uma direção, se ele tiver as rotações.
static func virar(no: AnimatedSprite2D, direcao: String) -> bool:
	if no == null or no.sprite_frames == null:
		return false
	if not no.sprite_frames.has_animation(direcao):
		return false
	no.animation = direcao
	no.play()
	return true

static func tem_rotacoes(id: String) -> bool:
	return ResourceLoader.exists(PASTA_V2 + id + "_south.png")
