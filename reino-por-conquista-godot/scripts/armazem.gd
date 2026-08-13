# ============================================================
# ARMAZÉM — onde o mercenário sem terra guarda o que sustenta a tropa.
#
# O teto de tropas vinha só da TERRA, e terra custa 5.000: até lá o
# jogador vivia com um bando de vinte homens e nenhum jeito de crescer —
# o que travava contrato grande e escalada antes do primeiro pedaço de
# chão. E o estoque não existia fora da terra: trigo comprado ficava na
# carroça, sem lugar para ser guardado.
#
# O armazém resolve as duas coisas com uma decisão de dinheiro:
#   - ALUGADO, para quem não tem terra: 5 de ouro por dia, por baia de
#     10 espaços. Cobrado todo dia que passa — parar de pagar é perder o
#     que estava dentro.
#   - PRÓPRIO, depois da terra: as baias viram construção, sem aluguel.
#
# Cada 10 espaços sustentam mais tropa (é o que o teto lê) e guardam mais
# carga. É a ponte entre "trabalhar na taverna" e "ter um exército".
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Livro = preload("res://scripts/livro.gd")

## Uma baia: dez espaços, cinco de ouro por dia enquanto for alugada.
const ESPACOS_POR_BAIA := 10
const ALUGUEL_DIA := 5
const CUSTO_ENTRADA := 40      # a caução da primeira diária + o cadeado
const MAX_BAIAS := 12

static func _dados(state: Dictionary) -> Dictionary:
	if not (state.get("armazem") is Dictionary):
		state["armazem"] = {"baias": 0, "proprio": false, "atraso": 0}
	return state["armazem"]

static func baias(state: Dictionary) -> int:
	return int(_dados(state).get("baias", 0))

static func proprio(state: Dictionary) -> bool:
	return bool(_dados(state).get("proprio", false))

## Espaços totais — é isto que o teto de tropas e a carga consultam.
static func espacos(state: Dictionary) -> int:
	return baias(state) * ESPACOS_POR_BAIA

## O que sai do bolso por DIA. Zero quando o armazém é seu.
static func aluguel_diario(state: Dictionary) -> int:
	if proprio(state):
		return 0
	return baias(state) * ALUGUEL_DIA

static func custo_proxima(state: Dictionary) -> int:
	# cada baia nova custa mais que a anterior: espaço perto da praça é
	# disputado, e o feitor sabe que você precisa
	return CUSTO_ENTRADA + baias(state) * 30

static func alugar(state: Dictionary) -> Dictionary:
	var d := _dados(state)
	if baias(state) >= MAX_BAIAS:
		return {"ok": false, "msg": "Não há mais baia livre nesta praça."}
	if proprio(state):
		return construir(state)
	var custo := custo_proxima(state)
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false, "msg": "O feitor pede %d de ouro adiantados." % custo}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	d["baias"] = baias(state) + 1
	return {"ok": true, "msg": "Baia alugada: +%d espaços, %d de ouro por dia."
		% [ESPACOS_POR_BAIA, ALUGUEL_DIA]}

## Com terra, a baia deixa de ser aluguel e vira construção: paga uma vez,
## em ouro e madeira, e nunca mais cobra diária.
static func construir(state: Dictionary) -> Dictionary:
	if state.get("terra") == null:
		return {"ok": false, "msg": "Sem terra não há onde construir."}
	var d := _dados(state)
	if baias(state) >= MAX_BAIAS:
		return {"ok": false, "msg": "O depósito já ocupa o pátio inteiro."}
	var custo := custo_proxima(state) * 2
	var madeira := 30 + baias(state) * 10
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false, "msg": "Construir custa %d de ouro." % custo}
	if int(state["terra"]["madeira"]) < madeira:
		return {"ok": false, "msg": "Faltam %d de madeira nos seus estoques." % madeira}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	state["terra"]["madeira"] = int(state["terra"]["madeira"]) - madeira
	d["baias"] = baias(state) + 1
	d["proprio"] = true
	return {"ok": true, "msg": "Depósito ampliado: +%d espaços, sem aluguel."
		% ESPACOS_POR_BAIA}

## Comprar terra converte o que era alugado em construção — o depósito
## "fica lá", como o pedido dizia: você para de pagar diária.
static func assentar(state: Dictionary) -> void:
	var d := _dados(state)
	if baias(state) > 0:
		d["proprio"] = true
	d["atraso"] = 0

## Cobrado a cada DIA que passa. Sem ouro, o feitor tranca a baia: o
## atraso cresce e, no terceiro dia, ele fica com uma delas e com o que
## havia dentro.
static func tick_dia(state: Dictionary, log: Callable = Callable()) -> void:
	var d := _dados(state)
	var custo := aluguel_diario(state)
	if custo <= 0:
		d["atraso"] = 0
		return
	if int(state["jogador"]["ouro"]) >= custo:
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
		Livro.registrar(state, "armazem", "ouro", -custo, "Aluguel do armazém")
		d["atraso"] = 0
		return
	d["atraso"] = int(d.get("atraso", 0)) + 1
	if log.is_valid():
		log.call("O feitor do armazém bateu na porta: %d de ouro de aluguel, e você não tem." % custo)
	if int(d["atraso"]) >= 3:
		d["baias"] = maxi(0, baias(state) - 1)
		d["atraso"] = 0
		# o que estava na baia perdida vai junto
		var carga: Dictionary = state.get("carga", {})
		for g_id in carga.keys():
			carga[g_id] = int(int(carga[g_id]) * 0.6)
		if log.is_valid():
			log.call("O feitor tomou uma baia e o que havia nela. Aluguel atrasado é assim.")
