# ============================================================
# PERSONAGENS v2 — AnimatedSprite2D + SpriteFrames a partir dos assets gerados.
#
# Três formatos convivem:
#   1) sprite único      assets/sprites/<id>.png             (já gerado, 18 peças)
#   2) 8 rotações v3     assets_v2/characters/<id>_<dir>.png (create-character-v3)
#   3) animações         assets_v2/characters/<prefixo>_<dir>_<NN>.png
#                        (animate-character; o manifesto animacoes.json diz
#                         qual prefixo pertence a qual personagem)
#
# Em todos os casos o resultado é um SpriteFrames pronto para AnimatedSprite2D:
# uma animação parada por direção ("south") e, quando houver quadros, a versão
# em movimento ("south_walk"). Sem arquivo nenhum, cai no retrato procedural —
# o jogo nunca fica sem textura.
# ============================================================
extends RefCounted

const Retratos = preload("res://scripts/retratos.gd")
const PASTA_V2 := "res://assets_v2/characters/"
const PASTA_V1 := "res://assets/sprites/"
const MANIFESTO := "res://assets_v2/characters/animacoes.json"

## As 8 direções que o create-character-v3 devolve.
const DIRECOES := ["south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west"]

static func _tex(caminho: String) -> Texture2D:
	if not ResourceLoader.exists(caminho):
		return null
	var t = load(caminho)
	return t if t is Texture2D else null

## Manifesto das animações geradas: {personagem: {nome: {prefixo, direcoes}}}.
## Escrito por generate_assets_v2.py --indexar; ausente = só sprites parados.
static func manifesto() -> Dictionary:
	if not FileAccess.file_exists(MANIFESTO):
		return {}
	var f := FileAccess.open(MANIFESTO, FileAccess.READ)
	if f == null:
		return {}
	var dados = JSON.parse_string(f.get_as_text())
	return dados if dados is Dictionary else {}

## As animações de um personagem, já validadas contra o manifesto.
static func animacoes_de(id: String) -> Dictionary:
	var m := manifesto()
	var d = m.get(id)
	return d if d is Dictionary else {}

## Quadros de um personagem: uma animação por direção quando houver rotações,
## mais uma animação de movimento por direção quando houver quadros gerados;
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

	# ---- animações de várias imagens (caminhada e afins) ----
	# a caminhada roda mais rápido que o "parado": 12 fps para 8 quadros dá o
	# passo certo sem ficar patinando.
	for nome_anim in animacoes_de(id):
		var dados: Dictionary = animacoes_de(id)[nome_anim]
		var prefixo: String = str(dados.get("prefixo", ""))
		var por_direcao = dados.get("direcoes")
		if prefixo == "" or not (por_direcao is Dictionary):
			continue
		for dir in por_direcao:
			var total: int = int(por_direcao[dir])
			var faixa := []
			for i in total:
				var t2 := _tex(PASTA_V2 + "%s_%s_%02d.png" % [prefixo, dir, i])
				if t2 != null:
					faixa.append(t2)
			if faixa.is_empty():
				continue
			var chave: String = str(dir) + "_" + str(nome_anim)
			sf.add_animation(chave)
			sf.set_animation_speed(chave, fps * 2.0)
			sf.set_animation_loop(chave, true)
			for t3 in faixa:
				sf.add_frame(chave, t3)
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
## `escala` aceita fração: a vila desenha o herói a 0.55 para as casas
## parecerem CASAS (o cânone do gênero é o personagem com ~metade da porta).
static func criar(id: String, escala: float = 2.0) -> AnimatedSprite2D:
	var no := AnimatedSprite2D.new()
	no.name = "Personagem_" + id
	no.sprite_frames = quadros(id)
	# começa parado de frente; se o personagem só tiver caminhada, usa o que houver
	var inicial := "idle"
	for candidato in ["south", "south_walk"]:
		if no.sprite_frames.has_animation(candidato):
			inicial = candidato
			break
	if not no.sprite_frames.has_animation(inicial):
		var nomes := no.sprite_frames.get_animation_names()
		if nomes.size() > 0:
			inicial = nomes[0]
	no.animation = inicial
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

## Põe o personagem a caminhar numa direção (ou a parar, se `andando` for false).
## Cai na pose parada quando a caminhada daquela direção não foi gerada.
static func mover(no: AnimatedSprite2D, direcao: String, andando: bool = true,
		nome_anim: String = "walk") -> bool:
	if no == null or no.sprite_frames == null:
		return false
	var alvo: String = direcao + "_" + nome_anim
	if andando and no.sprite_frames.has_animation(alvo):
		if no.animation != alvo:
			no.animation = alvo
		no.play()
		return true
	return virar(no, direcao)

static func tem_rotacoes(id: String) -> bool:
	return ResourceLoader.exists(PASTA_V2 + id + "_south.png")

## O personagem tem caminhada de verdade (mais de um quadro) nessa direção?
static func tem_caminhada(id: String, direcao: String = "south",
		nome_anim: String = "walk") -> bool:
	var anims := animacoes_de(id)
	if not anims.has(nome_anim):
		return false
	var por_direcao = anims[nome_anim].get("direcoes")
	return por_direcao is Dictionary and int(por_direcao.get(direcao, 0)) > 1
