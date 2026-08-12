# ============================================================
# FERRARIA — equipamento POR UNIDADE, não um número do exército.
#
# Antes havia `jogador.equip`, de 0 a 3, aplicado a TODO o exército de uma
# vez: comprava-se "nível 2" e os duzentos camponeses viravam veteranos
# junto com a cavalaria. Nada disso é uma decisão — é um botão que sobe um
# número.
#
# Aqui o aço é por homem: dez lanceiros de nível 1, cinco de nível 2, um de
# nível 3, e o que se decide é ONDE gastar o ferro. Melhorar tira a leva da
# linha enquanto o ferreiro trabalha (tropa em melhoria não marcha), e o
# preço acompanha o que a unidade já custa — reforçar cavalaria pesada nunca
# vai ser barato.
#
# O estado mora em state["equipamento"][tipo] = [n0, n1, n2, n3]: quantos
# homens daquele tipo estão em cada nível. A soma bate com o efetivo, e o
# que não coube em nenhum nível é nível 0 por definição.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

## Três degraus acima do "sem nada": couro, malha, placas.
const NIVEIS := [
	{"nome": "sem equipamento", "bonus": 0.00},
	{"nome": "couro batido",    "bonus": 0.12},
	{"nome": "malha de ferro",  "bonus": 0.26},
	{"nome": "placas",          "bonus": 0.45},
]
const MAX_NIVEL := 3

## Minutos de forja por lote de cinco homens, por degrau.
const MINUTOS_POR_DEGRAU := [0, 30, 55, 90]
const POR_LOTE := 5

static func _tabela(state: Dictionary) -> Dictionary:
	if not (state.get("equipamento") is Dictionary):
		state["equipamento"] = {}
	return state["equipamento"]

## Quantos homens de `tipo` estão em cada nível. Sempre com MAX_NIVEL+1
## posições, e o nível 0 recalculado a partir do efetivo real — assim
## recrutar não precisa avisar a ferraria de nada.
static func distribuicao(state: Dictionary, tipo: String) -> Array:
	var tab := _tabela(state)
	var d: Array = tab.get(tipo, [])
	while d.size() < MAX_NIVEL + 1:
		d.append(0)
	var total: int = int(state["jogador"]["tropas"].get(tipo, 0))
	var equipados := 0
	for n in range(1, MAX_NIVEL + 1):
		d[n] = maxi(0, int(d[n]))
		equipados += int(d[n])
	# baixa em batalha tira dos equipados também: nunca mais homens
	# equipados do que homens vivos
	while equipados > total:
		for n in range(MAX_NIVEL, 0, -1):
			if int(d[n]) > 0:
				d[n] = int(d[n]) - 1
				equipados -= 1
				break
	d[0] = maxi(0, total - equipados)
	tab[tipo] = d
	return d

## O multiplicador de força que esta unidade dá hoje — média ponderada dos
## níveis dos homens dela. É isto que o combate lê.
static func fator(state: Dictionary, tipo: String) -> float:
	var d := distribuicao(state, tipo)
	var total := 0
	var soma := 0.0
	for n in range(0, MAX_NIVEL + 1):
		total += int(d[n])
		soma += int(d[n]) * float(NIVEIS[n]["bonus"])
	if total <= 0:
		return 1.0
	return 1.0 + soma / float(total)

## Quanto custa subir `qtd` homens de `de` para `de+1`.
static func custo(tipo: String, de: int, qtd: int) -> int:
	var base: int = int(Dados.TROPAS.get(tipo, {}).get("custo", 20))
	# cada degrau custa mais: metade do preço da unidade no primeiro,
	# quase o preço inteiro no terceiro
	var fator_degrau: float = [0.0, 0.5, 0.8, 1.2][clampi(de + 1, 0, 3)]
	return maxi(1, roundi(base * fator_degrau)) * qtd

static func minutos(tipo: String, de: int, qtd: int) -> int:
	var por_lote: int = int(MINUTOS_POR_DEGRAU[clampi(de + 1, 0, MAX_NIVEL)])
	return maxi(1, por_lote * maxi(1, ceili(float(qtd) / POR_LOTE)))

## A fila da ferraria — mesma ideia da fila do quartel: mora no state,
## atravessa save/load, e o relógio a empurra.
static func fila(state: Dictionary) -> Array:
	if not (state.get("fila_ferraria") is Array):
		state["fila_ferraria"] = []
	return state["fila_ferraria"]

## Quantos homens de um tipo estão INDISPONÍVEIS agora (na bigorna).
static func na_forja(state: Dictionary, tipo: String) -> int:
	var n := 0
	for item in fila(state):
		if str(item["tipo"]) == tipo:
			n += int(item["qtd"])
	return n

static func encomendar(state: Dictionary, tipo: String, de: int, qtd: int) -> Dictionary:
	if not Dados.TROPAS.has(tipo):
		return {"ok": false, "msg": "Tropa desconhecida."}
	if de < 0 or de >= MAX_NIVEL:
		return {"ok": false, "msg": "Já é o melhor aço que se forja."}
	var d := distribuicao(state, tipo)
	var disponiveis: int = int(d[de]) - (na_forja(state, tipo) if de == 0 else 0)
	if qtd <= 0 or disponiveis < qtd:
		return {"ok": false,
			"msg": "Você não tem %d homens de %s nesse nível prontos." % [
				qtd, str(Dados.TROPAS[tipo]["nome"]).to_lower()]}
	var preco := custo(tipo, de, qtd)
	if int(state["jogador"]["ouro"]) < preco:
		return {"ok": false, "msg": "O ferreiro pede %d de ouro." % preco}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - preco
	d[de] = int(d[de]) - qtd
	fila(state).append({"tipo": tipo, "de": de, "qtd": qtd,
		"restante": minutos(tipo, de, qtd)})
	var Relogio = load("res://scripts/relogio.gd")
	return {"ok": true, "custo": preco,
		"msg": "%d %s na bigorna — %s até saírem em %s." % [qtd,
			str(Dados.TROPAS[tipo]["nome"]).to_lower(),
			Relogio.texto_dias(minutos(tipo, de, qtd)),
			str(NIVEIS[de + 1]["nome"])]}

## O relógio empurra a forja igual empurra o quartel.
static func avancar(state: Dictionary, minutos_passados: int,
		log: Callable = Callable()) -> int:
	var f := fila(state)
	var prontos := 0
	var restante := minutos_passados
	while restante > 0 and not f.is_empty():
		var item: Dictionary = f[0]
		var falta: int = int(item["restante"])
		if restante < falta:
			item["restante"] = falta - restante
			break
		restante -= falta
		var tipo: String = str(item["tipo"])
		var destino: int = clampi(int(item["de"]) + 1, 0, MAX_NIVEL)
		var d := distribuicao(state, tipo)
		d[destino] = int(d[destino]) + int(item["qtd"])
		prontos += int(item["qtd"])
		if log.is_valid():
			log.call("A ferraria entrega %d %s em %s." % [int(item["qtd"]),
				str(Dados.TROPAS[tipo]["nome"]).to_lower(),
				str(NIVEIS[destino]["nome"])])
		f.pop_front()
	return prontos
