# ============================================================
# VFX — o que faz a cena parecer VIVA em vez de uma colagem de PNGs:
#
#   sombra()  elipse radial sob cada sprite — ancora o objeto no chão
#   fumaca()  CPUParticles2D com o tufo gerado — chaminés e forja
#   fogo()    brasas subindo + PointLight2D quente — fogueira e tochas
#
# A API só entregou o "material" (um tufo de fumaça, uma brasa); o movimento
# inteiro é da Godot. Tudo com fallback: sem o PNG, devolve null e o chamador
# simplesmente não adiciona o efeito.
# ============================================================
extends RefCounted

const PASTA := "res://assets_v2/vfx/"

static var _tex_sombra: GradientTexture2D
static var _tex_luz: GradientTexture2D

## Textura compartilhada da sombra: gradiente radial preto→transparente.
## Num canvas 64×24 o radial vira ELIPSE sozinho (a distância é medida em UV).
static func _sombra_tex() -> GradientTexture2D:
	if _tex_sombra == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.34))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 24
		_tex_sombra = t
	return _tex_sombra

## Sombra elíptica para um nó ancorado nos PÉS (origem na base).
## `largura` em pixels do mundo — use ~60% da largura visual do sprite.
static func sombra(largura: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Sombra"
	s.texture = _sombra_tex()
	s.centered = true
	s.position = Vector2(0, -3)      # meio pixel acima da linha dos pés
	s.scale = Vector2(largura / 64.0, largura / 64.0 * 0.75)
	s.show_behind_parent = true       # desenha antes do pai, mas herda o Y-Sort dele
	return s

## Fumaça de chaminé. `offset` é a boca da chaminé em relação à ORIGEM do pai
## (nos pés) — ex.: casa de 160px com chaminé em (114,10) → Vector2(34, -150).
static func fumaca(offset: Vector2, forte: bool = false) -> CPUParticles2D:
	if not ResourceLoader.exists(PASTA + "fumaca_nuvem.png"):
		return null
	var p := CPUParticles2D.new()
	p.name = "Fumaca"
	p.texture = load(PASTA + "fumaca_nuvem.png")
	p.position = offset
	p.amount = 9 if forte else 5
	p.lifetime = 2.3                 # curta: o tufo morre perto da chaminé,
	p.preprocess = 2.2               # não vagando solto sobre a muralha
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector2(4.0, -14.0)  # sobe e deriva com o "vento"
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	var curva := Curve.new()          # o tufo incha enquanto sobe
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = curva
	# nasce visível, morre transparente. Os stops entram DE UMA VEZ:
	# set_color(1) depois de add_point acertaria o ponto do MEIO (o Gradient
	# reordena por offset), deixando o stop final no branco opaco padrão —
	# a fumaça terminaria a vida 100% sólida e sumiria num estalo.
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	rampa.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	p.color_ramp = rampa
	return p

## Textura de luz: radial branco→transparente, tingida pelo PointLight2D.
static func _luz_tex() -> GradientTexture2D:
	if _tex_luz == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_tex_luz = t
	return _tex_luz

## Fogo: brasas subindo + luz quente. `escala` 1.0 = fogueira; 0.5 = tocha.
## `offset` é onde a chama vive em relação à origem do pai.
static func fogo(offset: Vector2 = Vector2.ZERO, escala: float = 1.0) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "Fogo"
	raiz.position = offset

	if ResourceLoader.exists(PASTA + "brasa_fagulha.png"):
		var p := CPUParticles2D.new()
		p.name = "Brasas"
		p.texture = load(PASTA + "brasa_fagulha.png")
		p.amount = int(8 * escala) + 3
		p.lifetime = 1.1
		p.preprocess = 1.0
		p.direction = Vector2(0, -1)
		p.spread = 26.0
		p.initial_velocity_min = 20.0 * escala
		p.initial_velocity_max = 42.0 * escala
		p.gravity = Vector2(0, -30.0)
		p.scale_amount_min = 0.10 * escala
		p.scale_amount_max = 0.22 * escala
		# mesmos três stops de uma vez — ver o comentário em fumaca()
		var rampa := Gradient.new()
		rampa.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		rampa.colors = PackedColorArray([
			Color(1.0, 0.95, 0.7, 0.9), Color(1.0, 0.6, 0.25, 0.7),
			Color(0.7, 0.2, 0.1, 0.0)])
		p.color_ramp = rampa
		raiz.add_child(p)

	var luz := PointLight2D.new()
	luz.name = "Brilho"
	luz.texture = _luz_tex()
	luz.color = Color(1.0, 0.72, 0.42)
	luz.energy = 0.55 * escala      # halo discreto: calor, não holofote
	luz.texture_scale = 0.55 * escala
	luz.blend_mode = Light2D.BLEND_MODE_ADD
	raiz.add_child(luz)
	return raiz
