# ============================================================
# AGENTE MÓVEL — o lado MECÂNICO de qualquer coisa que anda.
#
# Ele tem posição, velocidade e destino. Ele NÃO tem sprite, não conhece
# animação, não sabe o que é uma direção em nome de arquivo. Quando alguma
# coisa muda, ele EMITE — e quem quiser desenhar que escute.
#
# Era assim que estava antes, dentro da VilaCena:
#
#     heroi.position += dir * 80.0 * delta
#     PersonagensV2.mover(heroi, direcao_de(dir), true)
#
# `heroi` ali era o AnimatedSprite2D. A regra de movimento estava escrevendo
# no nó de arte, e trocar a arte significava mexer no laço de movimento. É
# exatamente esse acoplamento que este par desfaz: agora o laço mexe só em
# posição e velocidade, e o VisualController traduz isso em animação.
#
# Por que Node2D e não RefCounted
# -------------------------------
# Posição no espaço da cena é o que o Y-Sort do pai ordena e o que a câmera
# segue. Um agente fora da árvore precisaria de um espelho, e espelho de
# posição desatualiza. O agente é o nó da entidade; o visual é filho dele.
#
# O que NÃO entra aqui
# --------------------
# Nada de física. Este projeto não tem CharacterBody2D nem colisão em lugar
# nenhum, e inventar um corpo cinemático para mover um aldeão numa praça
# seria peso sem ganho. Se um dia houver colisão, um CharacterBody2D emite
# estes mesmos três sinais e o VisualController não muda uma linha.
# ============================================================
class_name AgenteMovel
extends Node2D

## Velocidade abaixo disto conta como parado. Não é zero porque a chegada ao
## destino deixa um resto minúsculo, e oscilar entre andar e parar no último
## pixel faz a animação piscar.
const LIMIAR_PARADO := 1.0

signal moveu(velocidade: Vector2)
signal parou()
signal direcao_mudou(direcao: String)
signal chegou(indice: int)

@export var velocidade_max := 80.0
## Distância do destino que já conta como chegada.
@export var raio_chegada := 6.0

var velocidade := Vector2.ZERO
var direcao := "south"

var _rota: Array[Vector2] = []
var _alvo := 0
var _espera := 0.0
var _andando := false


## Converte um vetor de movimento no nome de direção de 8 vias.
## Em coordenadas de tela o Y cresce para BAIXO, então +y é "south".
static func direcao_de(v: Vector2) -> String:
	if v.length() < 0.001:
		return "south"
	var passo := int(round(v.angle() / (PI / 4.0)))
	match ((passo % 8) + 8) % 8:
		0: return "east"
		1: return "south-east"
		2: return "south"
		3: return "south-west"
		4: return "west"
		5: return "north-west"
		6: return "north"
		_: return "north-east"


## Ronda em laço pelos pontos dados.
func definir_rota(pontos: Array) -> void:
	_rota.clear()
	for p in pontos:
		_rota.append(p as Vector2)
	_alvo = 0


## Faz o agente esperar parado por N segundos antes de seguir.
func esperar(segundos: float) -> void:
	_espera = maxf(0.0, segundos)
	_parar()


func _physics_process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		return
	if _rota.is_empty():
		return

	var destino: Vector2 = _rota[_alvo]
	var passo: Vector2 = destino - position
	if passo.length() < raio_chegada:
		var i := _alvo
		_alvo = (_alvo + 1) % _rota.size()
		_parar()
		chegou.emit(i)
		return

	var dir := passo.normalized()
	velocidade = dir * velocidade_max
	position += velocidade * delta

	var d := direcao_de(dir)
	if d != direcao:
		direcao = d
		direcao_mudou.emit(d)
	if not _andando:
		_andando = true
	moveu.emit(velocidade)


func _parar() -> void:
	velocidade = Vector2.ZERO
	if _andando:
		_andando = false
		parou.emit()


func esta_andando() -> bool:
	return _andando
