# ============================================================
# CENARIO V3 VIEW — o adaptador entre o jogo e a cena achatada.
#
# O jogo pede sempre a mesma coisa de quem desenha a terra: um
# SubViewportContainer com `estado` e `semear_npcs()` (ver principal.gd
# `_nova_cena`). O `CenarioV3Cena` é um Node2D — ele sabe trocar de estágio
# e animar água e junco, mas não sabe nada de estado de jogo. Este nó faz a
# ponte, e só isso: traduz `estado.terra.nivel` em índice de estágio.
#
# A tradução é direta porque as duas escalas nasceram do mesmo lugar:
# Dados.NIVEIS_TERRA tem 6 degraus (Acampamento…Castelo) e a estação de
# verão tem 6 estágios (e1_virgem…e6_completo). Nível 0 ↔ estágio 0.
#
# Subir de nível com o jogo aberto entra pela RECOMPENSA — crossfade,
# poeira na obra e flash — em vez de corte seco. Carregar um save já num
# nível alto não: ali o estágio é só o ponto de partida.
#
# `semear_npcs()` não faz nada de propósito. Os aldeões estão pintados na
# imagem; não há nó para semear. O método existe porque o contrato pede.
#
# A montagem completa (recortes, overlays, sol e nuvens) é da Fase 5. Aqui
# só se garante que o jogo continue mostrando a terra depois do expurgo do
# panorama em camadas.
# ============================================================
extends SubViewportContainer

const CenarioV3Cena = preload("res://scripts/cenario_v3_cena.gd")
const Ambiente = preload("res://scripts/environment_manager.gd")
const AtmosferaCena = preload("res://scripts/atmosfera.gd")

const NATIVO := CenarioV3Cena.NATIVO
## ESCALA 1, e não 2.
##
## A aba tem cerca de 330 unidades de canvas de altura útil. Em ×2 o cartão
## pede 448 e a rolagem corta o pé da imagem — o castelo aparecia sem a base.
## Em ×1 o panorama inteiro cabe sem rolar, que é o ponto de um cartão: ser
## visto de uma vez.
##
## Ampliar não traria nitidez de qualquer forma: o jogo roda em
## `stretch/mode = canvas_items`, então a janela já aplica um fator próprio
## (1,33 numa tela de 1280 sobre a base de 960) e nenhum inteiro sobrevive
## a ele. A grade de pixel da arte é preservada pelo filtro NEAREST, não
## pela escala.
const ESCALA := 1

var viewport: SubViewport
var cena: CenarioV3Cena
var atmosfera: Node2D

var _nivel_montado := -99

var estado: Dictionary = {}:
	set(v):
		estado = v
		_aplicar()


## Sempre disponível: no strip o cenário é um caixote, e caixote não falta.
static func disponivel() -> bool:
	return true


func _init() -> void:
	stretch = false
	custom_minimum_size = Vector2(NATIVO * ESCALA)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	viewport = SubViewport.new()
	viewport.size = NATIVO * ESCALA
	viewport.transparent_bg = false
	# NEAREST no viewport inteiro: é ele que segura a grade de pixel da arte
	# quando a janela aplica o fator do `canvas_items`. Filtro linear aqui
	# borraria a grade toda.
	viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	cena = CenarioV3Cena.new()
	cena.scale = Vector2(ESCALA, ESCALA)
	viewport.add_child(cena)


## `_aplicar` só age com a cena DENTRO da árvore — e `_aba_terra` atribui
## `estado` com este nó ainda FORA dela, porque `atualizar()` desmonta a aba
## inteira e só recoloca a vista depois de configurá-la.
##
## Sem este gancho o estágio congelava no valor da primeira montagem: com a
## terra em nível 5 a aba escrevia "Vale do Ferro — Castelo" e desenhava o
## acampamento, e nada acusava, porque as duas metades vinham de caminhos
## diferentes (o título lê `state` na hora; a vista lia um `_aplicar` que
## nunca chegou a rodar).
##
## Diferido, e não direto: durante `_enter_tree` os filhos ainda estão
## entrando, e `evoluir()` precisa de `create_tween()` num nó já assentado.
func _enter_tree() -> void:
	call_deferred("_aplicar")


func _ready() -> void:
	_aplicar()
	# A ATMOSFERA — luz de hora×estação, água viva, janelas que acendem,
	# fumaça, nuvens. Ela é quem registra o viewport no EnvironmentManager
	# (um CanvasModulate SÓ, o dela: registrar aqui de novo empilharia um
	# segundo multiply e a noite escureceria em dobro). Na raiz da árvore, o
	# mesmo CanvasModulate deixaria a interface azul à noite e ilegível — é
	# por isso que a vila mora num SubViewport.
	atmosfera = AtmosferaCena.new()
	viewport.add_child(atmosfera)
	atmosfera.montar(cena, viewport)
	var amb := Ambiente.gerente()
	if amb != null and not estado.is_empty():
		amb.definir_mes(int(estado.get("mes", 6)))
	_aplicar_estagio_atmosfera()


## A ESCADA nível→cena. Nove níveis de terra (Acampamento…Castelo), seis
## cenas de referência. Os marcos visíveis ficam onde a narrativa muda:
##
##   sem terra        → 0 campo virgem (você ainda não tem nada)
##   0 Acampamento    → 1 tenda e fogueira
##   1 Paliçada       → 1 (upgrade barato; a cena pouco mudaria)
##   2 Aldeia         → 2 moinho e primeiras casas
##   3 Vila · 4 Burgo → 3 mercado, curral, paliçada
##   5–7 Pedra…Cidadela → 4 muralha de pedra e castelo em obras
##   8 Castelo        → 5 castelo pronto, estandarte no alto
const ESCADA_NIVEL := [1, 1, 2, 3, 3, 4, 4, 4, 5]

static func estagio_de(estado_jogo: Dictionary) -> int:
	if estado_jogo.get("terra") == null:
		return 0
	var nivel := clampi(int(estado_jogo["terra"].get("nivel", 0)),
		0, ESCADA_NIVEL.size() - 1)
	return ESCADA_NIVEL[nivel]


func _aplicar() -> void:
	if cena == null or not cena.is_inside_tree():
		return
	# `estado` vazio é o intervalo entre construir o nó e o jogo entregar o
	# save. Sair aqui é o que mantém `_nivel_montado` negativo até haver
	# estado de verdade — sem isso, carregar um save no nível 3 disparava a
	# recompensa na abertura, como se o jogador tivesse acabado de subir.
	if estado.is_empty():
		return
	var alvo := estagio_de(estado)
	# a luz acompanha o mês a cada mudança de estado, não só na montagem —
	# era este o fio solto que deixava o inverno com cara de verão
	var amb := Ambiente.gerente()
	if amb != null:
		amb.transitar_para_mes(int(estado.get("mes", 6)))
	if alvo == _nivel_montado:
		return
	# Só é recompensa quando a terra SOBE com o jogo já rodando. A primeira
	# montagem entra direto, e uma segunda subida durante o crossfade também:
	# `evoluir` RECUSA pedido em transição, e registrar como montado um
	# pedido recusado dessincroniza a vista do estado para sempre.
	if _nivel_montado >= 0 and alvo > _nivel_montado and not cena.em_transicao():
		cena.evoluir(alvo)
	else:
		cena.estagio = alvo
	_nivel_montado = alvo
	_aplicar_estagio_atmosfera()


func _aplicar_estagio_atmosfera() -> void:
	if atmosfera != null and _nivel_montado >= 0:
		atmosfera.definir_estagio(_nivel_montado)


## Contrato do `_nova_cena`. Não há NPC para semear: eles estão na imagem.
func semear_npcs() -> void:
	pass
