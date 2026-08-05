# ============================================================
# CAMERA MUNDO — a câmera padrão de cena top-down, com limites e suavização.
#
# Existia uma câmera inline na VilaCena com limites e smoothing na mão. Isto
# é a mesma coisa como COMPONENTE: qualquer cena de mundo pede uma, diz o
# tamanho do mundo e quem seguir, e ganha o comportamento inteiro.
#
#   var cam := CameraMundo.criar(Vector2(960, 540))
#   viewport.add_child(cam)
#   cam.seguir(heroi, VilaCena.ESCALA_MUNDO)
#
# Três coisas que ela resolve e que doem quando faltam:
#
# LIMITES. Sem eles a câmera mostra o vazio além da borda do mapa assim que
# o alvo chega perto do canto. Os limites entram em pixels de VIEWPORT, não
# de mundo — é um erro fácil quando a cena desenha em escala 1:2.
#
# ESPAÇO DO ALVO. O herói vive no espaço do `mundo` (escala 0,5); a câmera
# vive no espaço do viewport. Seguir a posição crua põe a câmera no dobro da
# distância. `seguir(no, escala)` guarda o fator e converte a cada quadro.
#
# ENQUADRAMENTO INTEIRO. Suavização de posição produz coordenada fracionária,
# e câmera em meio pixel desalinha a grade inteira da cena — a arte "ferve"
# enquanto anda. `arredondar` trava a posição final em pixel cheio. Fica
# ligado por padrão; é isso que separa uma câmera de pixel art de uma câmera.
# ============================================================
class_name CameraMundo
extends Camera2D

## Velocidade da suavização. 3 é lento e cinematográfico; acima de 8 a
## suavização deixa de ser perceptível e vira só custo.
const SUAVIZACAO := 3.0

var _alvo: Node2D = null
var _escala_alvo := 1.0

## Trava a posição em pixel inteiro. Ver o cabeçalho — desligue só se a cena
## não for pixel art.
var arredondar := true


static func criar(tamanho_mundo: Vector2, suavizacao: float = SUAVIZACAO) -> CameraMundo:
	var c := CameraMundo.new()
	c.name = "CameraMundo"
	c.definir_limites(tamanho_mundo)
	c.position_smoothing_enabled = suavizacao > 0.0
	c.position_smoothing_speed = suavizacao
	return c


## Limites em pixels de VIEWPORT — o retângulo que a câmera não ultrapassa.
func definir_limites(tamanho: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(tamanho.x)
	limit_bottom = int(tamanho.y)


## Passa a seguir um nó. `escala` é o fator entre o espaço do nó e o espaço
## da câmera (a VilaCena desenha o mundo a 0,5, então passa 0.5).
func seguir(no: Node2D, escala: float = 1.0) -> void:
	_alvo = no
	_escala_alvo = escala
	if no != null:
		position = _posicao_alvo()
		reset_smoothing()


func parar_de_seguir() -> void:
	_alvo = null


func _posicao_alvo() -> Vector2:
	return _alvo.position * _escala_alvo


func _process(_delta: float) -> void:
	if _alvo == null or not is_instance_valid(_alvo):
		return
	position = _posicao_alvo()


## Chamado DEPOIS que a Godot aplicou a suavização, então é aqui — e só aqui —
## que dá para arredondar sem brigar com o tween interno da câmera.
func _physics_process(_delta: float) -> void:
	if arredondar:
		var g := get_screen_center_position()
		offset = (g.round() - g)
