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

const Arte = preload("res://scripts/arte.gd")
const MANIFESTO := "res://assets_v2/characters/animacoes.json"

## Lado do caixote de personagem: 124px, o tamanho em que a arte foi gerada.
## É ele que define a silhueta que a vila usa para escalar o herói contra as
## casas, então mudar isto mexe no enquadramento da cena.
const LADO := 124

## As 8 direções que o create-character-v3 devolve.
const DIRECOES := ["south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west"]

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

## Quadros de um personagem: uma animação por direção quando ele tiver
## rotações, mais uma animação de movimento por direção quando o manifesto
## registrar quadros, senão uma única animação "idle".
##
## VISUAL STRIP: os PNG saíram, a ESTRUTURA ficou. O manifesto continua
## ditando quantos quadros tem cada caminhada e em que direções — é o que
## mantém `mover()` trocando de animação, a caminhada em laço e o passo mais
## rápido que a pose parada. O que mudou é que todo quadro é o mesmo caixote.
##
## Sem a arte, a pergunta "este personagem tem rotações?" não tem mais um PNG
## para responder. O manifesto responde: quem tem animação registrada tem as
## 8 direções. Hoje isso é exato — o único personagem com rotações geradas
## era também o único no manifesto — e daqui em diante o manifesto é a fonte
## única, o que é mais honesto do que inferir estrutura de nome de arquivo.
static func quadros(id: String, fps: float = 6.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := animacoes_de(id)

	if anims.is_empty():
		sf.add_animation("idle")
		sf.set_animation_speed("idle", fps)
		sf.set_animation_loop("idle", true)
		sf.add_frame("idle", Arte.caixa(LADO))
		return sf

	# pose parada nas 8 direções
	for dir in DIRECOES:
		sf.add_animation(dir)
		sf.set_animation_speed(dir, fps)
		sf.set_animation_loop(dir, true)
		sf.add_frame(dir, Arte.caixa(LADO))

	# ---- animações de várias imagens (caminhada e afins) ----
	# a caminhada roda mais rápido que o "parado": 12 fps para 8 quadros dá o
	# passo certo sem ficar patinando.
	for nome_anim in anims:
		var dados: Dictionary = anims[nome_anim]
		var por_direcao = dados.get("direcoes")
		if not (por_direcao is Dictionary):
			continue
		for dir in por_direcao:
			var total: int = int(por_direcao[dir])
			if total <= 0:
				continue
			var chave: String = str(dir) + "_" + str(nome_anim)
			sf.add_animation(chave)
			sf.set_animation_speed(chave, fps * 2.0)
			sf.set_animation_loop(chave, true)
			for _i in total:
				sf.add_frame(chave, Arte.caixa(LADO))
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

## Tem as 8 poses paradas? Ver a nota em `quadros()`: o manifesto responde.
static func tem_rotacoes(id: String) -> bool:
	return not animacoes_de(id).is_empty()

## O personagem tem caminhada de verdade (mais de um quadro) nessa direção?
static func tem_caminhada(id: String, direcao: String = "south",
		nome_anim: String = "walk") -> bool:
	var anims := animacoes_de(id)
	if not anims.has(nome_anim):
		return false
	var por_direcao = anims[nome_anim].get("direcoes")
	return por_direcao is Dictionary and int(por_direcao.get(direcao, 0)) > 1
