# ============================================================
# COMBATE TÁTICO (port GDScript de js/combat.js)
# Formações pedra-papel-tesoura, moral, baixas permanentes.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

static func poder(tropas: Dictionary, equip: int) -> Dictionary:
	var atq := 0.0
	var def := 0.0
	var homens := 0
	for tipo in tropas:
		var n: int = int(tropas[tipo])
		if n <= 0:
			continue
		atq += Dados.TROPAS[tipo]["atq"] * n
		def += Dados.TROPAS[tipo]["def"] * n
		homens += n
	var mult := 1.0 + equip * 0.15
	return {"atq": atq * mult, "def": def * mult, "homens": homens}

static func exercito_inimigo(forca: int) -> Dictionary:
	var e := {"tropas": {}, "equip": 1 if forca > 2 else 0,
		"formacao": Dados.rnd(Dados.FORMACOES.keys())}
	match forca:
		1: e["tropas"] = {"campones": Dados.ri(8, 14), "lanceiro": Dados.ri(2, 5)}
		2: e["tropas"] = {"lanceiro": Dados.ri(8, 14), "arqueiro": Dados.ri(4, 8)}
		3: e["tropas"] = {"lanceiro": Dados.ri(12, 18), "arqueiro": Dados.ri(8, 12), "cavaleiro": Dados.ri(2, 4)}
		_: e["tropas"] = {"lanceiro": Dados.ri(20, 30), "arqueiro": Dados.ri(12, 18), "cavaleiro": Dados.ri(5, 9)}
	return e

static func batalhar(state: Dictionary, inimigo: Dictionary, contexto: String) -> Dictionary:
	var j: Dictionary = state["jogador"]
	var rel := {"rodadas": [], "vitoria": false, "contexto": contexto, "debandada": "",
		"baixas_jogador": 0, "baixas_inimigo": 0}
	var form_j: String = j.get("formacao", "linha")
	var moral_j: float = 1.0 + (float(j["atributos"]["forca"]) - 5.0) * 0.04
	var moral_i: float = 1.0

	for rodada in range(1, 4):
		var pj := poder(j["tropas"], j["equip"])
		var pi := poder(inimigo["tropas"], inimigo["equip"])
		if pj["homens"] == 0 or pi["homens"] == 0:
			break
		var vent_j := 1.0
		var vent_i := 1.0
		if Dados.FORMACOES[form_j]["vence_de"] == inimigo["formacao"]:
			vent_j = 1.35
		elif Dados.FORMACOES[inimigo["formacao"]]["vence_de"] == form_j:
			vent_i = 1.35
		var dano_i: float = pj["atq"] * vent_j * moral_j * randf_range(0.8, 1.2)
		var dano_j: float = pi["atq"] * vent_i * moral_i * randf_range(0.8, 1.2)
		var baixas_i := _aplicar_baixas(inimigo["tropas"], dano_i / maxf(1.0, pi["def"]) * 0.25)
		var baixas_j := _aplicar_baixas(j["tropas"], dano_j / maxf(1.0, pj["def"]) * 0.25)
		rel["baixas_inimigo"] += baixas_i
		rel["baixas_jogador"] += baixas_j
		moral_i -= baixas_i / maxf(1.0, float(pi["homens"])) * 0.8
		moral_j -= baixas_j / maxf(1.0, float(pj["homens"])) * 0.8
		rel["rodadas"].append({"rodada": rodada, "baixas_j": baixas_j, "baixas_i": baixas_i,
			"formacao_inimiga": inimigo["formacao"]})
		if moral_i <= 0.3:
			rel["debandada"] = "inimigo"
			break
		if moral_j <= 0.3:
			rel["debandada"] = "jogador"
			break

	var resto_j: int = poder(j["tropas"], 0)["homens"]
	var resto_i: int = poder(inimigo["tropas"], 0)["homens"]
	rel["vitoria"] = rel["debandada"] == "inimigo" \
		or (rel["debandada"] != "jogador" and resto_j > resto_i)
	return rel

static func _aplicar_baixas(tropas: Dictionary, taxa: float) -> int:
	var total := 0
	for tipo in tropas:
		var n: int = int(tropas[tipo])
		if n <= 0:
			continue
		var resist: float = Dados.TROPAS[tipo]["def"] / 4.0
		var mortos: int = mini(n, roundi(n * clampf(taxa / resist, 0.0, 0.6)))
		tropas[tipo] = n - mortos
		total += mortos
	return total

static func total_homens(tropas: Dictionary) -> int:
	var t := 0
	for tipo in tropas:
		t += int(tropas[tipo])
	return t
