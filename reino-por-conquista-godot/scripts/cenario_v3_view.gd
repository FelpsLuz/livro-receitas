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

const NATIVO := Vector2i(480, 270)
const ESCALA := 2

var viewport: SubViewport
var cena: CenarioV3Cena

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
	# NEAREST no viewport inteiro: o ×2 é fator inteiro, então cada pixel da
	# arte vira um bloco 2×2 exato. Filtro linear aqui borraria a grade toda.
	viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	cena = CenarioV3Cena.new()
	cena.scale = Vector2(ESCALA, ESCALA)
	viewport.add_child(cena)


func _ready() -> void:
	_aplicar()
	# Atmosfera Hi-Bit NESTE viewport. É esta a cena que o jogo mostra na aba
	# "Sua Terra" (ver principal.gd `_nova_cena`), então é aqui que o ciclo
	# de luz aparece para o jogador. Na raiz, o mesmo CanvasModulate deixaria
	# a interface de pergaminho azul à noite e ilegível.
	var amb := Ambiente.gerente()
	if amb != null:
		amb.registrar(cena)
		if not estado.is_empty():
			amb.definir_mes(int(estado.get("mes", 6)))


func _exit_tree() -> void:
	var amb := Ambiente.gerente()
	if amb != null and cena != null:
		amb.esquecer(cena)


func _aplicar() -> void:
	if cena == null or not cena.is_inside_tree():
		return
	# `estado` vazio é o intervalo entre construir o nó e o jogo entregar o
	# save. Sair aqui é o que mantém `_nivel_montado` negativo até haver
	# estado de verdade — sem isso, carregar um save no nível 3 disparava a
	# recompensa na abertura, como se o jogador tivesse acabado de subir.
	if estado.is_empty():
		return
	var nivel := 0
	if estado.get("terra") != null:
		nivel = int(estado["terra"].get("nivel", 0))
	nivel = clampi(nivel, 0, CenarioV3Cena.NOMES.size() - 1)
	if nivel == _nivel_montado:
		return
	# Só é recompensa quando a terra SOBE com o jogo já rodando. A primeira
	# montagem entra direto, e uma segunda subida durante o crossfade também:
	# `evoluir` RECUSA pedido em transição, e registrar como montado um
	# pedido recusado dessincroniza a vista do estado para sempre.
	if _nivel_montado >= 0 and nivel > _nivel_montado and not cena.em_transicao():
		cena.evoluir(nivel)
	else:
		cena.estagio = nivel
	_nivel_montado = nivel


## Contrato do `_nova_cena`. Não há NPC para semear: eles estão na imagem.
func semear_npcs() -> void:
	pass
