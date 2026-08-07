# ============================================================
# ATMOSFERA — a vida por cima da arte, sem tocar num pixel dela.
#
# A arte dos nove estágios é estática: céu chapado, rio parado, janela
# apagada, chaminé sem fumaça. Este nó acrescenta o movimento que a arte
# não tem — e a regra da casa é que NADA aqui reamostra, redesenha ou
# distorce a imagem original. Cada efeito é uma camada por cima ou uma
# modulação de brilho por dentro:
#
#   · ÁGUA        shader por máscara: ondulação de BRILHO (nunca de UV —
#                 distorcer UV quebra a grade de pixel) e cintilação de sol.
#   · JANELAS     sprites de luz que ACENDEM ao anoitecer. A arte tem as
#                 janelas apagadas; a atmosfera pendura uma lamparina em
#                 cada uma quando a luminância ambiente cai.
#   · CHAMINÉS    fumaça em partículas, por posição medida na arte.
#   · NUVENS      geradas em código, parallax lento na faixa de céu.
#   · HAZE        um véu claro no horizonte — profundidade atmosférica.
#   · ESTAÇÃO     neve no inverno, folhas no outono.
#
# A COR do ambiente (hora × estação) não é deste nó: vem do
# EnvironmentManager, que já existia, já passava em teste — e não estava
# ligado em NENHUMA cena. Este nó é quem finalmente o consome, via
# `Ambiente.gerente()` (resolve em runtime; null nos testes --script).
#
# A tabela DADOS_ESTAGIO foi MEDIDA na arte, não chutada: paleta de água,
# bbox, horizonte, chaminés e janelas de cada estágio saíram de análise
# pixel a pixel dos nove PNG (ver o relatório da auditoria). As cores de
# água são verificadas contra a bbox porque azul também existe fora do rio
# (telhado, bandeira): cor SOZINHA não identifica água — cor DENTRO da
# caixa identifica.
# ============================================================
# Sem class_name, de propósito: o resto do projeto resolve dependência por
# preload (o cache de classes globais só atualiza no import do editor, e os
# testes --script rodam sem ele). Quem me usa faz preload deste arquivo.
extends Node2D

const Ambiente = preload("res://scripts/environment_manager.gd")

const NATIVO := Vector2i(400, 224)

# ---- dados por estágio, medidos na arte ----
## Preenchido a partir da análise por agente (uma passada por estágio +
## verificação adversarial de colisão de paleta). Estágio ausente na tabela
## degrada com elegância: fica sem água/luz/fumaça, mantém nuvens e estação.
const DADOS_ESTAGIO: Dictionary = {
	0: {
		"agua_presente": true,
		"agua_cores": ["#618aa0", "#63899d", "#60879d", "#638b9f", "#54727d", "#658795", "#7397a4", "#89b2c8", "#4b667b"],
		"agua_bbox": [0, 195, 399, 220],
		"y_horizonte": 80,
		"chamines": [],
		"fogueiras": [],
		"janelas": [],
	},
	1: {
		"agua_presente": true,
		"agua_cores": ["#63879a", "#66879c", "#4d687b", "#49616e", "#5d8596", "#476171", "#466478", "#4d7084", "#7ca5bc", "#83a7ba", "#86abbe"],
		"agua_bbox": [0, 195, 399, 220],
		"y_horizonte": 53,
		"chamines": [],
		"fogueiras": [[250, 174]],
		"janelas": [],
	},
	2: {
		"agua_presente": true,
		"agua_cores": ["#4b6272", "#4a6171", "#445c6c", "#3c4c5c", "#344454", "#34445c", "#546c7c", "#5c7484", "#647c8c", "#6c8494"],
		"agua_bbox": [0, 196, 399, 220],
		"y_horizonte": 85,
		"chamines": [[107, 142], [162, 131]],
		"fogueiras": [],
		"janelas": [[83, 162], [97, 162], [136, 158], [144, 158], [160, 158], [168, 158], [247, 147], [275, 148], [278, 166], [295, 167], [323, 155], [340, 155]],
	},
	3: {
		"agua_presente": true,
		"agua_cores": ["#485e6b", "#4a5d6b", "#495c69", "#4b5f6b", "#485c67", "#324350", "#303e4a", "#384854", "#586a75", "#7f92a0", "#8da1ac"],
		"agua_bbox": [0, 192, 399, 221],
		"y_horizonte": 88,
		"chamines": [[107, 143], [163, 135], [340, 168]],
		"fogueiras": [],
		"janelas": [[58, 190], [74, 190], [84, 161], [104, 161], [134, 154], [158, 154], [276, 165], [302, 165], [316, 155], [334, 155], [328, 191], [345, 191]],
	},
	4: {
		"agua_presente": true,
		"agua_cores": ["#485c67", "#495d68", "#4a5e69", "#4b5d69", "#465a65", "#324251", "#2c3c49", "#657982", "#677985", "#5e7481", "#6f777a"],
		"agua_bbox": [0, 194, 399, 220],
		"y_horizonte": 52,
		"chamines": [[108, 133], [164, 124], [64, 170], [347, 171]],
		"fogueiras": [],
		"janelas": [[84, 160], [104, 160], [138, 155], [158, 155], [51, 187], [66, 187], [275, 146], [277, 167], [293, 167], [324, 155], [339, 155], [331, 188], [348, 187], [339, 182]],
	},
	5: {
		"agua_presente": true,
		"agua_cores": ["#475a67", "#445a67", "#445663", "#435966", "#455866", "#2c3b49", "#30414e", "#405260", "#536774", "#647c8a", "#718896", "#6a8a97"],
		"agua_bbox": [0, 194, 399, 218],
		"y_horizonte": 53,
		"chamines": [[106, 148], [68, 174]],
		"fogueiras": [[181, 133], [219, 133]],
		"janelas": [[200, 61], [184, 89], [218, 89], [156, 81], [157, 91], [240, 81], [241, 92], [83, 159], [100, 159], [322, 151], [333, 151], [273, 164], [291, 165], [334, 190]],
	},
}

# ---- a luz de janela ----
## O amarelo de lamparina, quente e um degrau abaixo do branco: janela de
## sebo, não LED. O halo usa a mesma cor com alfa baixo.
const COR_LUZ := Color(1.0, 0.82, 0.45)
## Acima desta luminância ambiente as janelas ficam apagadas. O valor casa
## com a rampa do EnvironmentManager: dia pleno tem ~1.0, o "meio-dia" de
## inverno (~hora 0.345) cai perto de 0.8, crepúsculo desce de 0.7.
const LUM_ACENDE := 0.74

# ---- fumaça ----
const COR_FUMACA := Color(0.82, 0.80, 0.78, 0.55)

var _cena: Node2D          # o CenarioV3Cena (via preload de quem monta)
var _viewport: SubViewport
var _nuvens: Array[Sprite2D] = []
var _luzes: Array[Sprite2D] = []
var _glows_fogo: Array[Sprite2D] = []
var _fumacas: Array[CPUParticles2D] = []
var _neve: CPUParticles2D
var _folhas: CPUParticles2D
var _haze: Sprite2D
var _estagio := -1
var _lum := 1.0
var _cor_ambiente := Color.WHITE
var _tempo := 0.0

static var _mascaras: Dictionary = {}
static var _shader_agua: Shader

# ============================================================
# MONTAGEM
# ============================================================

## `cena` é o CenarioV3Cena cujos sprites recebem o shader de água;
## `viewport` é o SubViewport que o EnvironmentManager vai tingir.
func montar(cena: Node2D, viewport: SubViewport) -> void:
	_cena = cena
	_viewport = viewport
	z_index = 10
	_montar_haze()
	_montar_nuvens()
	_montar_estacao()
	# a atmosfera é quem LIGA o gerente à cena — o registro que faltava no
	# projeto inteiro acontece nesta linha
	var g := Ambiente.gerente()
	if g != null:
		g.registrar(viewport)
		if not g.ambiente_mudou.is_connected(_ao_mudar_ambiente):
			g.ambiente_mudou.connect(_ao_mudar_ambiente)
		_ao_mudar_ambiente(g.cor_atual())
	if _cena != null and not _cena.evolucao_terminou.is_connected(_ao_evoluir):
		_cena.evolucao_terminou.connect(_ao_evoluir)

## O view é REMOVIDO e RECOLOCADO na árvore toda vez que a aba troca (ver
## principal.gd `atualizar`). `_exit_tree` desfaz registro e sinal — e sem o
## par `_enter_tree` refazendo os dois, a PRIMEIRA troca de aba desligava a
## atmosfera para sempre: o CanvasModulate morria com o `esquecer`, `_ready`
## não roda de novo, e a vila voltava eternamente clara. Foi exatamente o
## defeito flagrado no render: o probe isolado (uma entrada só) tinha neve e
## noite; o jogo real (dezenas de reentradas) não tinha nenhum dos dois.
func _enter_tree() -> void:
	if _viewport == null:
		return          # ainda não montado; `montar()` fará tudo
	# DIFERIDO, e a razão é do motor: durante a propagação do enter_tree o
	# viewport ainda está "montando filhos", e `add_child` nele FALHA — o
	# CanvasModulate nascia órfão (na lista do gerente, fora da árvore) e a
	# vila continuava sem luz, agora com vazamento por cima. Um frame depois
	# a árvore assentou e o registro pega.
	call_deferred("_religar")

func _religar() -> void:
	if _viewport == null or not is_inside_tree():
		return
	var g := Ambiente.gerente()
	if g != null:
		g.registrar(_viewport)
		if not g.ambiente_mudou.is_connected(_ao_mudar_ambiente):
			g.ambiente_mudou.connect(_ao_mudar_ambiente)
		_ao_mudar_ambiente(g.cor_atual())

func _exit_tree() -> void:
	var g := Ambiente.gerente()
	if g != null:
		if g.ambiente_mudou.is_connected(_ao_mudar_ambiente):
			g.ambiente_mudou.disconnect(_ao_mudar_ambiente)
		if _viewport != null:
			g.esquecer(_viewport)

## Troca o estágio: refaz máscara de água, luzes, fumaças e teto das nuvens.
func definir_estagio(i: int) -> void:
	if i == _estagio:
		return
	_estagio = i
	_vestir_agua()
	_montar_luzes()
	_montar_fumacas()
	_ajustar_nuvens()

## Durante a evolução, o sprite ANTERIOR continua na tela com o estágio
## velho: ele guarda o material velho até o crossfade terminar.
func _ao_evoluir(_de: int, _para: int) -> void:
	if _cena != null and _cena._anterior != null:
		_cena._anterior.material = null

# ============================================================
# ÁGUA — shader por máscara, gerada em runtime
# ============================================================

## A máscara nasce da PRÓPRIA arte: pixel cuja cor está na paleta de água
## do estágio E dentro da bbox vira R=1. Cor sozinha não basta — o azul do
## rio também mora em telhados e bandeiras (medido na análise) — e bbox
## sozinha pegaria a margem de grama. As duas juntas identificam água.
static func mascara_de(estagio: int) -> Texture2D:
	if _mascaras.has(estagio):
		return _mascaras[estagio]
	var dados: Dictionary = DADOS_ESTAGIO.get(estagio, {})
	if dados.is_empty() or not bool(dados.get("agua_presente", false)):
		return null
	var caminho := "res://assets/sprites/estagio_0%d.png" % (estagio + 1)
	if not ResourceLoader.exists(caminho):
		return null
	var tex = load(caminho)
	if not (tex is Texture2D):
		return null
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var bbox: Array = dados.get("agua_bbox", [0, 0, 0, 0])
	var cores: Array[Color] = []
	for c in dados.get("agua_cores", []):
		cores.append(Color(str(c)))
	var m := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	m.fill(Color(0, 0, 0, 1))
	# POR DISTÂNCIA, não por igualdade: a arte veio de um downscale (BOX ou
	# moda-por-bloco), que cria tons INTERMEDIÁRIOS entre os azuis medidos.
	# Match exato deixava a máscara furada como peneira e a ondulação
	# aparecia listrada. O limiar equivale a ~±20/255 por canal — apertado o
	# bastante para a margem de grama continuar de fora.
	const LIMIAR := 0.0055
	for y in range(int(bbox[1]), mini(int(bbox[3]) + 1, img.get_height())):
		for x in range(int(bbox[0]), mini(int(bbox[2]) + 1, img.get_width())):
			var p := img.get_pixel(x, y)
			for c in cores:
				var dr := p.r - c.r
				var dg := p.g - c.g
				var db := p.b - c.b
				if dr * dr + dg * dg + db * db < LIMIAR:
					m.set_pixel(x, y, Color(1, 0, 0, 1))
					break
	var out := ImageTexture.create_from_image(m)
	_mascaras[estagio] = out
	return out

## O shader NÃO desloca UV. Ondulação aqui é de BRILHO — faixas suaves que
## atravessam a água — e a cintilação é o sol batendo em cristas, um pixel
## de cada vez, quantizado à grade nativa para não denunciar o overlay.
## `COLOR = tex * COLOR` preserva o modulate — é ele que carrega o alfa do
## crossfade de evolução e a tinta do CanvasModulate.
static func _shader() -> Shader:
	if _shader_agua != null:
		return _shader_agua
	var s := Shader.new()
	# REGRA DO MOTOR que custou uma tarde: em canvas_item, LER `COLOR` no
	# fragment já devolve `texture(TEXTURE, UV) × cor de vértice` — a base
	# pronta. A primeira versão fazia `COLOR = tex * COLOR`, multiplicando a
	# textura DE NOVO: imagem ao quadrado, céu a 80% do brilho e sombras a
	# 3%. Parecia um entardecer misterioso que nenhum CanvasModulate
	# explicava — porque não era luz, era álgebra. Aqui o shader NÃO
	# reatribui a base: só ajusta COLOR dentro da máscara d'água.
	s.code = """
shader_type canvas_item;
uniform sampler2D mascara : filter_nearest;
uniform float forca : hint_range(0.0, 1.0) = 1.0;
uniform float sol : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float agua = texture(mascara, UV).r;
	if (agua > 0.5) {
		vec2 px = floor(UV * vec2(400.0, 224.0));
		// duas ondas cruzadas, período longo: a água RESPIRA, não ferve
		float fase = sin(px.y * 0.85 + TIME * 1.5)
			* sin(px.x * 0.21 - TIME * 0.65);
		COLOR.rgb *= 1.0 + fase * 0.055 * forca;
		// cintilação: ~1,5% dos pixels da água, cada um piscando na sua
		// própria fase — o sol nas cristas, e some junto com ele à noite.
		// O alvo é multiplicado por COLOR.a para a cintilação respeitar o
		// alfa do crossfade de evolução.
		float r = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453);
		float crista = step(0.985, r)
			* max(0.0, sin(TIME * 1.8 + r * 6.2831));
		COLOR.rgb = mix(COLOR.rgb, vec3(0.95, 0.93, 0.86) * COLOR.a,
			crista * 0.7 * forca * sol);
	}
}
"""
	_shader_agua = s
	return s

func _vestir_agua() -> void:
	if _cena == null or _cena._atual == null:
		return
	var m := mascara_de(_estagio)
	if m == null:
		_cena._atual.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("mascara", m)
	mat.set_shader_parameter("forca", 1.0)
	mat.set_shader_parameter("sol", clampf(_lum, 0.0, 1.0))
	_cena._atual.material = mat

# ============================================================
# LUZES DE JANELA E FOGO
# ============================================================

## A janela: um retângulo de luz do tamanho medido na arte, com um halo de
## 1px. Gerada uma vez e compartilhada — catorze janelas, uma textura.
static var _tex_janela: Texture2D
static func _textura_janela() -> Texture2D:
	if _tex_janela != null:
		return _tex_janela
	var w := 5
	var h := 6
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var borda := x == 0 or y == 0 or x == w - 1 or y == h - 1
			img.set_pixel(x, y, Color(1, 1, 1, 0.35 if borda else 1.0))
	_tex_janela = ImageTexture.create_from_image(img)
	return _tex_janela

## O glow de fogueira: um disco radial suave, para o BLEND ADD.
static var _tex_glow: Texture2D
static func _textura_glow() -> Texture2D:
	if _tex_glow != null:
		return _tex_glow
	var lado := 24
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var c := (lado - 1) * 0.5
	for y in lado:
		for x in lado:
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * 0.5))
	_tex_glow = ImageTexture.create_from_image(img)
	return _tex_glow

func _montar_luzes() -> void:
	for s in _luzes:
		s.queue_free()
	_luzes.clear()
	for s in _glows_fogo:
		s.queue_free()
	_glows_fogo.clear()
	var dados: Dictionary = DADOS_ESTAGIO.get(_estagio, {})
	for p in dados.get("janelas", []):
		var s := Sprite2D.new()
		s.texture = _textura_janela()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(p[0], p[1])
		s.z_index = 12
		# fase própria: catorze janelas piscando em uníssono seriam um
		# letreiro; cada lamparina tremula sozinha
		s.set_meta("fase", randf() * TAU)
		s.modulate = Color(COR_LUZ, 0.0)
		add_child(s)
		_luzes.append(s)
	# fogueira acesa tem glow SEMPRE (o fogo pintado já está lá de dia);
	# o blend add faz o clarão somar sobre a arte
	for p in dados.get("fogueiras", []):
		var s := Sprite2D.new()
		s.texture = _textura_glow()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(p[0], p[1])
		s.z_index = 12
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
		s.set_meta("fase", randf() * TAU)
		s.modulate = Color(1.0, 0.62, 0.28, 0.5)
		add_child(s)
		_glows_fogo.append(s)

# ============================================================
# FUMAÇA
# ============================================================

static var _tex_fumo: Texture2D
static func _textura_fumo() -> Texture2D:
	if _tex_fumo != null:
		return _tex_fumo
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.9))
	# cantos vazados: o quadrado vira um "quase-círculo" de 3px, que na
	# grade nativa lê como floco de fumaça e não como pixel morto
	for p in [[0, 0], [2, 0], [0, 2], [2, 2]]:
		img.set_pixel(p[0], p[1], Color(1, 1, 1, 0.35))
	_tex_fumo = ImageTexture.create_from_image(img)
	return _tex_fumo

func _montar_fumacas() -> void:
	for f in _fumacas:
		f.queue_free()
	_fumacas.clear()
	var dados: Dictionary = DADOS_ESTAGIO.get(_estagio, {})
	var pontos: Array = []
	pontos.append_array(dados.get("chamines", []))
	pontos.append_array(dados.get("fogueiras", []))
	for p in pontos:
		var f := CPUParticles2D.new()
		f.position = Vector2(p[0], p[1])
		f.z_index = 13
		f.amount = 7
		f.lifetime = 3.2
		f.preprocess = 3.2      # a fumaça já está no ar quando a cena abre
		f.texture = _textura_fumo()
		f.direction = Vector2(0, -1)
		f.spread = 12.0
		f.initial_velocity_min = 5.0
		f.initial_velocity_max = 9.0
		f.gravity = Vector2(2.5, -6.0)   # sobe desacelerando e deriva com o vento
		f.scale_amount_min = 0.8
		f.scale_amount_max = 1.6
		var rampa := Gradient.new()
		rampa.set_color(0, Color(COR_FUMACA, 0.0))
		rampa.add_point(0.25, COR_FUMACA)
		rampa.set_color(rampa.get_point_count() - 1, Color(COR_FUMACA, 0.0))
		f.color_ramp = rampa
		add_child(f)
		_fumacas.append(f)

# ============================================================
# NUVENS E HAZE
# ============================================================

## As nuvens geradas ficam DESLIGADAS enquanto a arte dos estágios já traz
## céu completo — e a leva atual traz: nuvens volumosas pintadas e sol com
## halo em todas as seis cenas. Medido no render: o blob procedural de dois
## tons ao lado de uma nuvem pintada lê como adesivo, e movimento não
## compensa vocabulário. A flag fica para arte futura que venha sem céu.
const NUVENS_GERADAS := false

## Uma nuvem pixel-art: três elipses achatadas com base reta e dois tons.
## Cada uma nasce de uma semente própria — quatro nuvens iguais em fila
## denunciariam o gerador na hora.
static func _textura_nuvem(semente: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var w := rng.randi_range(34, 58)
	var h := rng.randi_range(9, 13)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var claro := Color(0.97, 0.98, 0.98, 0.92)
	var sombra := Color(0.82, 0.87, 0.90, 0.92)
	var lobos: Array = []
	for i in 3:
		lobos.append([rng.randf_range(0.2, 0.8) * w,
			rng.randf_range(0.35, 0.55) * h,
			rng.randf_range(0.22, 0.4) * w, rng.randf_range(0.5, 0.75) * h])
	var base := int(h * 0.78)
	for y in h:
		for x in w:
			var dentro := false
			for l in lobos:
				var dx := (x - float(l[0])) / float(l[2])
				var dy := (y - float(l[1])) / float(l[3])
				if dx * dx + dy * dy <= 1.0:
					dentro = true
			if dentro and y <= base:
				img.set_pixel(x, y, sombra if y > base - 3 else claro)
	return ImageTexture.create_from_image(img)

func _montar_nuvens() -> void:
	if not NUVENS_GERADAS:
		return
	for i in 4:
		var s := Sprite2D.new()
		s.texture = _textura_nuvem(1000 + i * 271)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.z_index = 11
		# parallax: a nuvem mais alta é a mais distante — anda mais devagar
		# e é um pouco menor no alfa, como a arte já faz com as montanhas
		s.set_meta("vel", 2.2 + i * 1.3)
		s.position = Vector2(randf() * NATIVO.x, 0)
		add_child(s)
		_nuvens.append(s)
	_ajustar_nuvens()

func _ajustar_nuvens() -> void:
	var dados: Dictionary = DADOS_ESTAGIO.get(_estagio, {})
	var horizonte: int = int(dados.get("y_horizonte", 60))
	for i in _nuvens.size():
		var s := _nuvens[i]
		# empilha as faixas de altura: a mais lenta em cima
		var alt := 4 + i * maxi(6, (horizonte - 26) / 4)
		s.position.y = clampf(alt, 2, maxf(2, horizonte - 14))
		s.modulate.a = 0.85 - 0.1 * i
	# o haze ANCORA NO HORIZONTE do estágio — nasceu pendurado em y=0, um
	# véu no topo do céu, onde profundidade atmosférica não existe. O pico
	# do gradiente (base da textura de 40px) assenta 8px DENTRO das
	# montanhas; o resto esvanece céu acima.
	if _haze != null:
		_haze.position.y = maxf(0.0, float(horizonte) - 32.0)

## O haze: um véu da cor do céu que engrossa perto do horizonte — é a
## profundidade atmosférica que separa a montanha distante da próxima.
## Por FAIXA vertical, não por cor: caçar o azul da montanha colidiria com
## o azul dos pinheiros, e a análise mostrou isso.
func _montar_haze() -> void:
	var alt := 40
	var img := Image.create(1, alt, false, Image.FORMAT_RGBA8)
	var cor := Color(0.86, 0.92, 0.94)
	for y in alt:
		# pico no horizonte (base da imagem), zero no topo
		var t := float(y) / float(alt - 1)
		img.set_pixel(0, y, Color(cor, t * t * 0.22))
	_haze = Sprite2D.new()
	_haze.texture = ImageTexture.create_from_image(img)
	_haze.centered = false
	_haze.scale = Vector2(NATIVO.x, 1)
	_haze.z_index = 10
	add_child(_haze)

# ============================================================
# ESTAÇÃO — neve e folhas
# ============================================================

static var _tex_floco: Texture2D
static func _textura_floco() -> Texture2D:
	if _tex_floco != null:
		return _tex_floco
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.95))
	_tex_floco = ImageTexture.create_from_image(img)
	return _tex_floco

func _montar_estacao() -> void:
	_neve = CPUParticles2D.new()
	_neve.position = Vector2(NATIVO.x * 0.5, -6)
	_neve.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_neve.emission_rect_extents = Vector2(NATIVO.x * 0.55, 4)
	_neve.amount = 46
	_neve.lifetime = 13.0
	_neve.preprocess = 13.0
	_neve.texture = _textura_floco()
	_neve.direction = Vector2(0, 1)
	_neve.spread = 8.0
	_neve.initial_velocity_min = 12.0
	_neve.initial_velocity_max = 20.0
	_neve.gravity = Vector2(-4.0, 3.0)   # deriva de vento leve
	_neve.z_index = 14
	_neve.emitting = false
	add_child(_neve)

	_folhas = CPUParticles2D.new()
	_folhas.position = Vector2(NATIVO.x * 0.5, -6)
	_folhas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_folhas.emission_rect_extents = Vector2(NATIVO.x * 0.55, 4)
	_folhas.amount = 10
	_folhas.lifetime = 11.0
	_folhas.preprocess = 11.0
	_folhas.texture = _textura_floco()
	_folhas.direction = Vector2(0.3, 1)
	_folhas.spread = 20.0
	_folhas.initial_velocity_min = 14.0
	_folhas.initial_velocity_max = 24.0
	_folhas.gravity = Vector2(6.0, 4.0)
	_folhas.angular_velocity_min = -180.0
	_folhas.angular_velocity_max = 180.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color("c9793a"))
	rampa.add_point(0.5, Color("b0562f"))
	rampa.set_color(rampa.get_point_count() - 1, Color("8a6524"))
	_folhas.color_ramp = rampa
	_folhas.z_index = 14
	_folhas.emitting = false
	add_child(_folhas)

# ============================================================
# O CICLO — reação ao ambiente
# ============================================================

func _ao_mudar_ambiente(cor: Color) -> void:
	_cor_ambiente = cor
	_lum = 0.2126 * cor.r + 0.7152 * cor.g + 0.0722 * cor.b
	# o sol sai da água junto com o dia
	if _cena != null and _cena._atual != null and _cena._atual.material is ShaderMaterial:
		_cena._atual.material.set_shader_parameter("sol", clampf(_lum, 0.0, 1.0))
	var g := Ambiente.gerente()
	var estacao: String = "verao" if g == null else str(g.estacao)
	if _neve != null:
		_neve.emitting = estacao == "inverno"
	if _folhas != null:
		_folhas.emitting = estacao == "outono"
	# no frio a lareira trabalha: mais fumaça no inverno
	for f in _fumacas:
		f.amount = 10 if estacao == "inverno" else 7

func _process(delta: float) -> void:
	_tempo += delta
	# ---- nuvens: deriva com wrap ----
	for s in _nuvens:
		s.position.x += float(s.get_meta("vel", 3.0)) * delta
		var w := s.texture.get_width()
		if s.position.x > NATIVO.x:
			s.position.x = -w
	# ---- janelas: acendem com a noite, cada uma tremulando na sua fase ----
	#
	# A COMPENSAÇÃO: o CanvasModulate multiplica tudo no viewport, inclusive
	# a luz — à noite a lamparina sairia azul-escura, que é o contrário do
	# que uma janela acesa faz. Dividir a cor da luz pela cor do ambiente
	# cancela a tinta SÓ nas janelas: depois do multiply, o amarelo chega
	# inteiro. É o que faz a luz parecer EMITIR em vez de refletir.
	var forca := clampf((LUM_ACENDE - _lum) / 0.35, 0.0, 1.0)
	for s in _luzes:
		var fase := float(s.get_meta("fase", 0.0))
		var tremula := 0.92 + 0.08 * sin(_tempo * 5.0 + fase)
		var c := _compensada(COR_LUZ)
		s.modulate = Color(c.r, c.g, c.b, forca * tremula)
	for s in _glows_fogo:
		var fase_g := float(s.get_meta("fase", 0.0))
		var pulso := 0.42 + 0.14 * sin(_tempo * 6.3 + fase_g) \
			+ 0.05 * sin(_tempo * 17.0 + fase_g * 2.0)
		var cf := _compensada(Color(1.0, 0.62, 0.28))
		s.modulate = Color(cf.r, cf.g, cf.b, pulso)

func _compensada(cor: Color) -> Color:
	return Color(
		cor.r / maxf(_cor_ambiente.r, 0.25),
		cor.g / maxf(_cor_ambiente.g, 0.25),
		cor.b / maxf(_cor_ambiente.b, 0.25))
