# ============================================================
# CONTRATOS E RENOME (port da parte de contratos de js/combat.js)
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Combate = preload("res://scripts/combate.gd")

const TIPOS := [
	{"id": "escolta", "nome": "Escoltar caravana", "forca": 1,
	 "desc": "Mercadores pagam por proteção contra bandidos.", "ouro": [60, 120], "renome": 5},
	{"id": "bandidos", "nome": "Caçar bandidos", "forca": 2,
	 "desc": "Um vilarejo sofre com saqueadores. Limpe a região.", "ouro": [100, 180], "renome": 10},
	{"id": "incursao", "nome": "Queimar vila inimiga", "forca": 2,
	 "desc": "Trabalho sujo pago por um rei rival.", "ouro": [200, 350], "renome": 12},
	{"id": "patrulha", "nome": "Guarnecer fronteira", "forca": 3,
	 "desc": "Guerra na fronteira. Reforce a linha por um mês.", "ouro": [250, 400], "renome": 18},
]

static func gerar(state: Dictionary) -> Array:
	var contratos: Array = []
	for i in Dados.ri(2, 3):
		var t: Dictionary = Dados.rnd(TIPOS)
		var contratante: Dictionary = Dados.rnd(state["reinos"])
		var alvo := ""
		if t["id"] == "incursao" or t["id"] == "patrulha":
			for g in state["guerras"]:
				if g["a"] == contratante["id"]:
					alvo = g["b"]
				elif g["b"] == contratante["id"]:
					alvo = g["a"]
			if alvo == "":
				alvo = Dados.rnd(state["reinos"].filter(
					func(r): return r["id"] != contratante["id"]))["id"]
		var c := t.duplicate()
		c["uid"] = str(randi())
		c["contratante"] = contratante["id"]
		c["alvo"] = alvo
		c["pagamento"] = Dados.ri(t["ouro"][0], t["ouro"][1])
		contratos.append(c)
	return contratos

static func executar(state: Dictionary, contrato: Dictionary, log: Callable) -> Dictionary:
	var inimigo := Combate.exercito_inimigo(int(contrato["forca"]))
	var rel := Combate.batalhar(state, inimigo, contrato["nome"])
	if rel["vitoria"]:
		state["jogador"]["ouro"] += int(contrato["pagamento"])
		state["jogador"]["renome"] += int(contrato["renome"])
		Dialogo.mudar_relacao(state, "rei_" + contrato["contratante"], 8, "contrato cumprido")
		log.call("Contrato cumprido: +%d ouro, +%d renome." % [contrato["pagamento"], contrato["renome"]])
		if contrato["id"] == "incursao" and contrato["alvo"] != "":
			Dialogo.mudar_relacao(state, "rei_" + contrato["alvo"], -25, "queimou vila")
			state["jogador"]["crueldade"] = int(state["jogador"].get("crueldade", 0)) + 1
			log.call("Você queimou uma vila de %s. O rei de lá não esquecerá." % contrato["alvo"])
	else:
		state["jogador"]["renome"] = maxi(0, state["jogador"]["renome"] - 5)
		log.call("Contrato fracassou. Renome -5.")
		# derrota esmagadora não é só perder: é ser CAPTURADO no campo
		if rel.get("esmagado", false):
			var Jogo = load("res://scripts/jogo.gd")
			Jogo.prender(state, 3, log)
	return rel

static func titulo(state: Dictionary) -> String:
	if state["jogador"]["rei_de"] != "":
		return "Rei"
	if state["terra"] != null and int(state["terra"]["nivel"]) >= 3:
		return "Conde"
	if state["terra"] != null:
		return "Senhor"
	if state["jogador"]["renome"] >= 50:
		return "Capitão Mercenário"
	return "Mercenário"
