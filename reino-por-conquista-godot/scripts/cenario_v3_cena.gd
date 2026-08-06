# ============================================================
# CENÁRIO — a terra do jogador, um quadro por estágio de evolução.
#
# VISUAL STRIP: cada estágio era UMA imagem de 480×270 já pintada. As seis
# saíram, e com elas o shader de vida (água ciclando, junco balançando) e a
# poeira de obra da transição. Sobrou o que é MECÂNICA de apresentação:
#
#   · o índice do estágio, que espelha o nível de terra
#   · `evoluir()` como transição com duração, que a vista usa para saber
#     que uma subida de nível está em curso (`em_transicao`)
#   · o sinal `evolucao_terminou`, que fecha o ciclo para quem escuta
#
# O crossfade fica porque é ele que dá a DURAÇÃO da transição — sem ela
# `em_transicao()` responderia sempre false e a vista perderia o estado que
# usa para não atropelar uma evolução com outra. Entre dois caixotes o
# efeito não aparece; o relógio dele continua valendo.
# ============================================================
class_name CenarioV3Cena
extends Node2D

const Arte = preload("res://scripts/arte.gd")

## Nomes posicionais: são a ordem narrativa dos seis estágios, e é essa
## ordem — não a arte — que casa com Dados.NIVEIS_TERRA.
const NOMES := ["estagio_01", "estagio_02", "estagio_03",
		"estagio_04", "estagio_05", "estagio_06",
		"estagio_07", "estagio_08", "estagio_09"]
## 400×224, e não os 480×270 de antes. O endpoint do gerador recusa acima de
## 400 e exige lado múltiplo de 4, então a arte NASCE em 400×224. A saída era
## gerar menor e ampliar — mas ×1,2 não é fator inteiro e borraria a grade
## inteira, que é justamente o que uma arte pixel não perdoa. A grade nativa
## desce até a arte; nada é reamostrado em lugar nenhum.
const NATIVO := Vector2i(400, 224)

# ---- transição de evolução ----
const CROSSFADE := 0.8

var estacao := "verao"
var estagio := 5:
	set(v):
		estagio = clampi(v, 0, NOMES.size() - 1)
		if _atual:
			_atual.texture = _textura(estagio)

var _atual: Sprite2D
var _anterior: Sprite2D
var _em_transicao := false

signal evolucao_terminou(de: int, para: int)


func _ready() -> void:
	_anterior = Sprite2D.new()
	_anterior.centered = false
	_anterior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anterior.texture = _textura(estagio)
	_anterior.visible = false
	_anterior.z_index = 0
	add_child(_anterior)

	_atual = Sprite2D.new()
	_atual.centered = false
	_atual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_atual.texture = _textura(estagio)
	_atual.z_index = 1
	add_child(_atual)


## O quadro do estágio. Os seis nasceram EM CADEIA (cada um usou o anterior
## como imagem de partida), então são a mesma terra em seis momentos e não
## seis vales diferentes — é isso que faz o crossfade de `evoluir()` ler como
## construção em vez de troca de cenário.
##
## Estágio sem PNG ainda cai no caixote, como antes.
func _textura(i: int) -> Texture2D:
	var caminho := "res://assets/sprites/%s.png" % NOMES[clampi(i, 0, NOMES.size() - 1)]
	if ResourceLoader.exists(caminho):
		var t = load(caminho)
		if t is Texture2D:
			return t
	return Arte.caixa(NATIVO.x, NATIVO.y)


## Uma evolução em curso RECUSA outra (ver `evoluir`). Quem chama precisa
## saber disso para não registrar como feito um pedido que foi descartado.
func em_transicao() -> bool:
	return _em_transicao


# ---- evolução: crossfade entre os dois estágios ----
func evoluir(para: int = -1) -> void:
	if _em_transicao:
		return
	var destino: int = estagio + 1 if para < 0 else para
	if destino <= estagio or destino >= NOMES.size():
		return
	_em_transicao = true
	var de := estagio

	# a imagem VELHA fica por baixo, visível; a nova entra por cima com
	# alpha 0 e sobe.
	_anterior.texture = _textura(de)
	_anterior.visible = true
	_anterior.modulate.a = 1.0
	estagio = destino
	_atual.modulate.a = 0.0

	# DOIS tweens não são mais necessários (o flash saiu), mas o crossfade
	# continua sendo o relógio da transição.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_atual, "modulate:a", 1.0, CROSSFADE)
	tw.tween_property(_anterior, "modulate:a", 0.0, CROSSFADE)

	await tw.finished
	_anterior.visible = false
	_em_transicao = false
	evolucao_terminou.emit(de, destino)
