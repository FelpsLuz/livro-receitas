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

## As 4 rotações que a arte real tem, e como as 8 direções do movimento
## caem nelas. `AgenteMovel.direcao_de` devolve 8 nomes porque o vetor tem 8
## octantes; a arte tem 4. Mapear aqui — e não lá — é o que mantém a
## mecânica ignorando quantos desenhos existem.
##
## As diagonais caem na direção HORIZONTAL, não na vertical: de frente ou de
## costas, o personagem lê como parado; de lado, lê como andando. Num
## top-down é a leitura lateral que vende o movimento.
const ROTACOES := ["south", "east", "north", "west"]
const MAPA_8_PARA_4 := {
	"south": "south", "south-east": "east", "east": "east",
	"north-east": "east", "north": "north", "north-west": "west",
	"west": "west", "south-west": "west",
}

const PASTA := "res://assets/sprites/"


static func _tex(id: String, direcao: String) -> Texture2D:
	var caminho := PASTA + id + "_" + direcao + ".png"
	if not ResourceLoader.exists(caminho):
		return null
	var t = load(caminho)
	return t if t is Texture2D else null


## O personagem tem arte de verdade nas 4 rotações?
static func tem_arte(id: String) -> bool:
	for d in ROTACOES:
		if _tex(id, d) == null:
			return false
	return true


## Quadros de um personagem.
##
## Com ARTE REAL: uma animação por rotação, mais um alias por direção
## diagonal apontando para a mesma textura — assim `virar("south-east")`
## continua funcionando sem a mecânica saber que só há 4 desenhos. A
## caminhada (`<dir>_walk`) existe com o mesmo quadro: a estrutura fica de
## pé para quando os quadros de andar chegarem, e `mover()` não muda.
##
## Sem arte: caixote, como no strip. É isso que mantém os testes de mecânica
## rodando para um id que ainda não tem desenho.
static func quadros(id: String, fps: float = 6.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	if tem_arte(id):
		for oito in MAPA_8_PARA_4:
			var quatro: String = MAPA_8_PARA_4[oito]
			var t := _tex(id, quatro)
			sf.add_animation(oito)
			sf.set_animation_speed(oito, fps)
			sf.set_animation_loop(oito, true)
			sf.add_frame(oito, t)
			var andando: String = oito + "_walk"
			sf.add_animation(andando)
			sf.set_animation_speed(andando, fps * 2.0)
			sf.set_animation_loop(andando, true)
			sf.add_frame(andando, t)
		return sf

	var anims := animacoes_de(id)
	if anims.is_empty():
		sf.add_animation("idle")
		sf.set_animation_speed("idle", fps)
		sf.set_animation_loop("idle", true)
		sf.add_frame("idle", Arte.caixa(LADO))
		return sf

	for dir in DIRECOES:
		sf.add_animation(dir)
		sf.set_animation_speed(dir, fps)
		sf.set_animation_loop(dir, true)
		sf.add_frame(dir, Arte.caixa(LADO))
	for nome_anim in anims:
		var dados: Dictionary = anims[nome_anim]
		var por_direcao = dados.get("direcoes")
		if not (por_direcao is Dictionary):
			continue
		for dir2 in por_direcao:
			var total: int = int(por_direcao[dir2])
			if total <= 0:
				continue
			var chave: String = str(dir2) + "_" + str(nome_anim)
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

## Tem as poses paradas? Arte real responde primeiro; o manifesto é a
## reserva para quem ainda está em caixote.
static func tem_rotacoes(id: String) -> bool:
	return tem_arte(id) or not animacoes_de(id).is_empty()

## O personagem tem caminhada de verdade (mais de um quadro) nessa direção?
static func tem_caminhada(id: String, direcao: String = "south",
		nome_anim: String = "walk") -> bool:
	if tem_arte(id):
		return true          # a estrutura existe, ainda com um quadro só
	var anims := animacoes_de(id)
	if not anims.has(nome_anim):
		return false
	var por_direcao = anims[nome_anim].get("direcoes")
	return por_direcao is Dictionary and int(por_direcao.get(direcao, 0)) > 1
