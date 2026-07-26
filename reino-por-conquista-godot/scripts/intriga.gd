# ============================================================
# INTRIGAS, CASUS BELLI E DINASTIA (port de js/intrigue.js)
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Combate = preload("res://scripts/combate.gd")

static func espionar(state: Dictionary, reino_id: String) -> Dictionary:
	if state["jogador"]["ouro"] < 80:
		return {"ok": false, "msg": "Espiões custam 80 de ouro."}
	state["jogador"]["ouro"] -= 80
	var chance: float = 0.4 + state["jogador"]["atributos"]["intriga"] * 0.05
	if randf() > chance:
		if randf() < 0.3:
			Dialogo.mudar_relacao(state, "rei_" + reino_id, -15, "espião capturado")
			return {"ok": true, "msg": "Espião CAPTURADO! Relação -15."}
		return {"ok": true, "msg": "Espião voltou de mãos vazias."}
	state["segredos"].append({"reino": reino_id, "usado": false})
	return {"ok": true, "msg": "SEGREDO descoberto sobre o rei de %s." % reino_id}

static func forjar_documento(state: Dictionary, reino_id: String) -> Dictionary:
	if state["jogador"]["ouro"] < 150:
		return {"ok": false, "msg": "Falsários custam 150."}
	if state["casus_belli"].has(reino_id):
		return {"ok": false, "msg": "Já há reivindicação."}
	state["jogador"]["ouro"] -= 150
	if randf() < 0.35 + state["jogador"]["atributos"]["intriga"] * 0.06:
		state["casus_belli"].append(reino_id)
		return {"ok": true, "msg": "Reivindicação forjada com sucesso!", "sucesso": true}
	Dialogo.mudar_relacao(state, "rei_" + reino_id, -30, "falsificação exposta")
	return {"ok": true, "msg": "Falsificação EXPOSTA! Relação -30.", "sucesso": false}

static func chantagear(state: Dictionary, npc: Dictionary) -> Dictionary:
	if not (npc["id"] as String).begins_with("rei_"):
		return {"resposta": "Minha vida é um livro aberto. Procure gente importante.", "efeitos": []}
	var reino_id: String = (npc["id"] as String).replace("rei_", "")
	var idx := -1
	for i in state["segredos"].size():
		var s: Dictionary = state["segredos"][i]
		if s["reino"] == reino_id and not s["usado"]:
			idx = i
			break
	if idx < 0:
		return {"resposta": "Seus olhos dizem que não sabe de nada. Patético.", "efeitos": ["[Blefe falhou]"]}
	state["segredos"][idx]["usado"] = true
	var efeitos: Array = [Dialogo.mudar_relacao(state, npc["id"], -20, "chantagem")]
	state["chantagem_pendente"] = {"reino": reino_id}
	return {"resposta": "*o sangue foge do rosto* ...O que você quer? Fale logo.", "efeitos": efeitos}

static func resolver_chantagem(state: Dictionary, escolha: String) -> void:
	var ch = state.get("chantagem_pendente")
	if ch == null:
		return
	match escolha:
		"ouro":
			state["jogador"]["ouro"] += Dados.ri(300, 500)
		"casamento":
			realizar_casamento(state, ch["reino"], true)
		"casusbelli":
			if not state["casus_belli"].has(ch["reino"]):
				state["casus_belli"].append(ch["reino"])
	state["chantagem_pendente"] = null

static func realizar_casamento(state: Dictionary, reino_id: String, forcado: bool) -> void:
	var reino: Dictionary = {}
	for r in state["reinos"]:
		if r["id"] == reino_id:
			reino = r
			break
	var genero := "m" if reino["rei"]["genero"] == "f" else "f"
	state["familia"]["conjuge"] = {
		"nome": (Dados.rnd(Dados.NOMES_F) if genero == "f" else Dados.rnd(Dados.NOMES_M)) + " de " + reino["capital"],
		"genero": genero, "reino": reino_id, "forcado": forcado,
		"atributos": {"forca": Dados.ri(3, 8), "carisma": Dados.ri(3, 8),
			"gestao": Dados.ri(3, 8), "intriga": Dados.ri(3, 8)},
	}
	if not state["casus_belli"].has(reino_id):
		state["casus_belli"].append(reino_id)
	if not forcado:
		Dialogo.mudar_relacao(state, "rei_" + reino_id, 20, "aliança de casamento")

static func tick_familia(state: Dictionary, log: Callable) -> void:
	var f: Dictionary = state["familia"]
	if f["conjuge"] != null and f["filhos"].size() < 4 and randf() < 0.06:
		var genero := "m" if randf() < 0.5 else "f"
		var j: Dictionary = state["jogador"]["atributos"]
		var c: Dictionary = f["conjuge"]["atributos"]
		var filho := {
			"nome": Dados.rnd(Dados.NOMES_M) if genero == "m" else Dados.rnd(Dados.NOMES_F),
			"genero": genero, "idade": 0, "educacao": "",
			"atributos": {
				"forca": clampi(roundi((j["forca"] + c["forca"]) / 2.0) + Dados.ri(-2, 2), 1, 10),
				"carisma": clampi(roundi((j["carisma"] + c["carisma"]) / 2.0) + Dados.ri(-2, 2), 1, 10),
				"gestao": clampi(roundi((j["gestao"] + c["gestao"]) / 2.0) + Dados.ri(-2, 2), 1, 10),
				"intriga": clampi(roundi((j["intriga"] + c["intriga"]) / 2.0) + Dados.ri(-2, 2), 1, 10),
			},
			"mimado": int(state["jogador"].get("crueldade", 0)) >= 3 and randf() < 0.5,
		}
		f["filhos"].append(filho)
		log.call("Nasce %s! A dinastia continua." % filho["nome"])

static func declarar_guerra(state: Dictionary, reino_id: String, log: Callable) -> Dictionary:
	var tem_cb: bool = state["casus_belli"].has(reino_id)
	if not tem_cb:
		log.call("Ataque SEM casus belli: os 6 reinos condenam sua agressão!")
		for r in state["reinos"]:
			Dialogo.mudar_relacao(state, "rei_" + r["id"],
				-60 if r["id"] == reino_id else -35, "agressão")
	var inimigo := Combate.exercito_inimigo(3 if tem_cb else 4)
	var rel := Combate.batalhar(state, inimigo, "Conquista de " + reino_id)
	if rel["vitoria"]:
		for r in state["reinos"]:
			if r["id"] == reino_id:
				r["dominado_por"] = "jogador"
		if state["jogador"]["rei_de"] == "":
			state["jogador"]["rei_de"] = reino_id
		state["jogador"]["renome"] += 50
		log.call("VITÓRIA! Você toma o trono de %s!" % reino_id)
	else:
		state["jogador"]["renome"] = maxi(0, state["jogador"]["renome"] - 20)
		log.call("Derrota diante dos muros de %s." % reino_id)
	return rel
