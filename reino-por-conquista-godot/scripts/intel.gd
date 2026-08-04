# ============================================================
# NEBLINA DE GUERRA — o que você NÃO sabe é o que te mata.
#
# A força de um reino inimigo não aparece na interface. Marchar sem espionar
# é marchar às cegas, e é isso que dá emprego ao espião: o relatório revela
# o exército por um tempo, e depois a informação ENVELHECE — um número de
# seis meses atrás é quase um chute.
#
# O relatório fica em state["intel"][reino] = {ate, tropas, forca, minuto}.
# Como é dicionário simples, entra no save de graça.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

## Quantos meses um relatório continua valendo.
const MESES_VALIDO := 4

static func _mapa(state: Dictionary) -> Dictionary:
	if not state.has("intel"):
		state["intel"] = {}
	return state["intel"]

static func _mes_absoluto(state: Dictionary) -> int:
	return int(state["ano"]) * 12 + int(state["mes"])

## Guarda o que o espião viu. Uma FOTOGRAFIA: se o reino recrutar depois,
## o relatório continua mostrando o número velho — e é assim que deve ser.
static func registrar(state: Dictionary, reino_id: String, tropas: Dictionary,
		forca: int) -> void:
	_mapa(state)[reino_id] = {
		"tropas": tropas.duplicate(true), "forca": forca,
		"visto_em": _mes_absoluto(state),
		"ate": _mes_absoluto(state) + MESES_VALIDO,
	}

static func tem(state: Dictionary, reino_id: String) -> bool:
	var d = _mapa(state).get(reino_id)
	return d != null and int(d["ate"]) >= _mes_absoluto(state)

## O que a UI sabe sobre um reino. `conhecido` false = mostrar "???".
static func sobre(state: Dictionary, reino_id: String) -> Dictionary:
	var d = _mapa(state).get(reino_id)
	if d == null:
		return {"conhecido": false, "texto": "???", "idade_meses": -1}
	var idade: int = _mes_absoluto(state) - int(d["visto_em"])
	if int(d["ate"]) < _mes_absoluto(state):
		# vencido: o jogador lembra que já soube, mas não confia mais
		# (mostrar o número velho como se fosse atual seria mentir para ele)
		return {"conhecido": false, "texto": "??? (relatório de %d meses atrás)" % idade,
			"idade_meses": idade, "vencido": true, "forca": int(d["forca"])}
	var homens := 0
	for tipo in d["tropas"]:
		homens += int(d["tropas"][tipo])
	return {"conhecido": true, "tropas": d["tropas"], "forca": int(d["forca"]),
		"homens": homens, "idade_meses": idade,
		"texto": "%d homens" % homens + (" (há %d meses)" % idade if idade > 0 else " (fresco)")}

## Detalhamento por tipo de tropa, para o modal do relatório de espionagem.
static func detalhar(state: Dictionary, reino_id: String) -> Array:
	var d = _mapa(state).get(reino_id)
	if d == null:
		return []
	var linhas: Array = []
	for tipo in d["tropas"]:
		var n: int = int(d["tropas"][tipo])
		if n <= 0:
			continue
		linhas.append({"tipo": tipo, "n": n,
			"nome": str(Dados.TROPAS.get(tipo, {}).get("nome", tipo))})
	linhas.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	return linhas

## Limpa relatórios muito velhos, para o save não crescer sem parar.
static func tick(state: Dictionary) -> void:
	var m := _mapa(state)
	var agora := _mes_absoluto(state)
	for reino in m.keys():
		if agora - int(m[reino]["visto_em"]) > MESES_VALIDO * 6:
			m.erase(reino)
