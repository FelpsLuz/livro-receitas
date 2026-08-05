# ============================================================
# VISUAL CONTROLLER — o lado VISUAL, e só ele.
#
# Componente que se pendura numa entidade e observa o estado dela por SINAL.
# Ele lê da mecânica; a mecânica nunca lê dele. A seta aponta num sentido só,
# e é isso que permite trocar toda a arte sem tocar em uma linha de regra.
#
#   var vc := VisualController.novo(agente)
#   vc.usar_personagem("heroi_jogador", 0.55)
#   vc.observar(agente)
#
# O que ele faz quando o estado muda:
#   moveu(v)          → animação de caminhada na direção da velocidade
#   parou()           → pose parada, mesma direção
#   direcao_mudou(d)  → vira, andando ou parado
#
# Sobre AnimationPlayer
# ---------------------
# O pedido falava em acionar um AnimationPlayer. Este projeto não tem
# nenhum: a animação de personagem é `SpriteFrames` num AnimatedSprite2D,
# montada por PersonagensV2 a partir do manifesto (8 direções, 9 quadros por
# caminhada, laço, passo mais rápido que a pose). Um AnimationPlayer por
# cima disso seria uma segunda máquina de estados controlando a mesma coisa,
# com as duas podendo discordar. `aplicar_em(AnimationPlayer)` existe abaixo
# para o dia em que houver animação de propriedade (ataque, dano, morte) —
# aí o player entra e este controlador dispara nele pelo mesmo caminho.
#
# Sobre CharacterBody2D
# ---------------------
# `observar()` prefere SINAL e aceita qualquer fonte que os tenha. Um
# CharacterBody2D nativo não emite nada sobre a própria velocidade, então
# para ele há o caminho de leitura em `_physics_process` — que continua sendo
# dependência de uma via só (o visual lê o corpo; o corpo ignora o visual).
# Preferir sinal não é preciosismo: com leitura, este nó roda todo quadro
# mesmo parado; com sinal, ele só acorda quando algo muda.
# ============================================================
class_name VisualController
extends Node2D

const Arte = preload("res://scripts/arte.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")

## Sufixo da animação de caminhada no SpriteFrames (ver PersonagensV2).
const ANIM_ANDANDO := "walk"

var visual: Node2D = null
var luz: PointLight2D = null

var _fonte: Object = null
var _corpo_lido: Node = null       # só no caminho sem sinal
var _direcao := "south"
var _andando := false
var _id := ""


static func novo(pai: Node2D) -> VisualController:
	var vc := VisualController.new()
	vc.name = "VisualController"
	pai.add_child(vc)
	return vc


# ------------------------------------------------------------
# O QUE ELE DESENHA
# ------------------------------------------------------------
## Personagem animado: SpriteFrames com as 8 direções e as caminhadas.
func usar_personagem(id: String, escala: float = 1.0) -> AnimatedSprite2D:
	_id = id
	var no := PersonagensV2.criar(id, escala)
	_adotar(no)
	return no


## Objeto parado: um Sprite2D de tamanho fixo.
func usar_sprite(largura: int, altura: int, escala: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Visual"
	s.texture = Arte.caixa(largura, altura)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(escala, escala)
	s.centered = true
	_adotar(s)
	return s


func _adotar(no: Node2D) -> void:
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	visual = no
	add_child(no)
	_ancorar()


## Origem nos PÉS. Sem isto o Y-Sort compara o CENTRO da imagem, e um sprite
## alto (o moinho, a torre) parece estar sempre atrás de quem passa ao lado.
func _ancorar() -> void:
	if visual == null:
		return
	# variáveis LOCAIS tipadas, não `visual.texture` direto: a Godot só
	# estreita o tipo de local dentro do `is`, nunca o de um membro. Com
	# `visual` declarado Node2D, ler `.texture` dele é erro de compilação.
	var altura := 0.0
	if visual is Sprite2D:
		var sp: Sprite2D = visual
		if sp.texture != null:
			altura = sp.texture.get_height()
	elif visual is AnimatedSprite2D:
		var an: AnimatedSprite2D = visual
		if an.sprite_frames != null:
			var a: String = an.animation
			if an.sprite_frames.has_animation(a) \
					and an.sprite_frames.get_frame_count(a) > 0:
				var t: Texture2D = an.sprite_frames.get_frame_texture(a, 0)
				if t != null:
					altura = t.get_height()
	if altura > 0.0:
		visual.offset = Vector2(0, -altura / 2.0)


## Luz de ponto com gradiente radial suave — a iluminação 2D moderna que o
## Hi-Bit usa para tocha, fogueira e janela acesa. A textura é gerada, não
## carregada: um gradiente é matemática, não arte.
func acender(cor: Color = Color(1.0, 0.72, 0.42), raio: float = 96.0,
		energia: float = 0.8) -> PointLight2D:
	if luz == null:
		luz = PointLight2D.new()
		luz.name = "Luz"
		var g := Gradient.new()
		# três paradas, não duas: o miolo cheio dá o núcleo quente, e a queda
		# só começa depois. Com duas, a luz vira um borrão sem centro.
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55),
			Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		luz.texture = gt
		luz.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(luz)
	luz.color = cor
	luz.energy = energia
	luz.texture_scale = raio / 128.0
	return luz


# ------------------------------------------------------------
# O QUE ELE OBSERVA
# ------------------------------------------------------------
## Liga-se a uma fonte de estado. Prefere sinal; cai na leitura só quando a
## fonte não tem nenhum (ver o cabeçalho).
func observar(fonte: Object) -> bool:
	_fonte = fonte
	_corpo_lido = null
	if fonte == null:
		return false
	var por_sinal := false
	for par in [["moveu", _ao_mover], ["parou", _ao_parar],
			["direcao_mudou", _ao_virar]]:
		var nome: String = par[0]
		if fonte.has_signal(nome):
			if not fonte.is_connected(nome, par[1]):
				fonte.connect(nome, par[1])
			por_sinal = true
	if por_sinal:
		set_physics_process(false)
		return true
	# sem sinal: só um CharacterBody2D justifica leitura por quadro
	if fonte is Node and fonte.get("velocity") != null:
		_corpo_lido = fonte as Node
		set_physics_process(true)
		return true
	return false


func _physics_process(_delta: float) -> void:
	if _corpo_lido == null or not is_instance_valid(_corpo_lido):
		return
	var v: Vector2 = _corpo_lido.velocity
	if v.length() < AgenteMovel.LIMIAR_PARADO:
		_ao_parar()
	else:
		_ao_mover(v)


func _ao_mover(velocidade: Vector2) -> void:
	if velocidade.length() < AgenteMovel.LIMIAR_PARADO:
		_ao_parar()
		return
	_direcao = AgenteMovel.direcao_de(velocidade)
	_andando = true
	_aplicar()


func _ao_parar() -> void:
	if not _andando:
		return
	_andando = false
	_aplicar()


func _ao_virar(direcao: String) -> void:
	_direcao = direcao
	_aplicar()


func _aplicar() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual is AnimatedSprite2D:
		var an: AnimatedSprite2D = visual
		PersonagensV2.mover(an, _direcao, _andando, ANIM_ANDANDO)
		# quem não tem as 8 direções (aldeão sem rotação gerada) ainda lê a
		# lateralidade pelo espelho — é o mínimo que vende movimento
		if an.sprite_frames != null and not an.sprite_frames.has_animation(_direcao):
			an.flip_h = _direcao.ends_with("west")
	elif visual is Sprite2D:
		var sp: Sprite2D = visual
		sp.flip_h = _direcao.ends_with("west")


## Ponte para o dia em que houver animação de propriedade (ataque, dano).
## Dispara no AnimationPlayer sem que a mecânica precise conhecê-lo: quem
## chama é este controlador, a partir do estado que já observa.
func aplicar_em(player: AnimationPlayer, acao: String) -> bool:
	if player == null or not player.has_animation(acao):
		return false
	player.play(acao)
	return true


## Estado atual, para depuração e teste.
func estado() -> Dictionary:
	return {"id": _id, "direcao": _direcao, "andando": _andando,
		"por_sinal": _corpo_lido == null and _fonte != null,
		"tem_visual": visual != null, "tem_luz": luz != null}
