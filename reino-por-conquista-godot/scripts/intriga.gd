# ============================================================
# INTRIGAS, CASUS BELLI E DINASTIA (port de js/intrigue.js)
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Combate = preload("res://scripts/combate.gd")
const Economia = preload("res://scripts/economia.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Intel = preload("res://scripts/intel.gd")

## Espionagem com MEMÓRIA: 30% de falha fixa, aliviada pelo atributo intriga.
## Quando o espião é pego, o reino LEMBRA — e na terceira vez eles não vêm
## atrás do espião, vêm atrás de você.
static func espionar(state: Dictionary, reino_id: String) -> Dictionary:
	if state["jogador"]["ouro"] < 80:
		return {"ok": false, "msg": "Espiões custam 80 de ouro."}
	state["jogador"]["ouro"] -= 80
	var falha: float = maxf(0.10, 0.30 - int(state["jogador"]["atributos"]["intriga"]) * 0.02)
	if randf() >= falha:
		state["segredos"].append({"reino": reino_id, "usado": false})
		# O relatório do espião é a ÚNICA forma de furar a neblina de guerra:
		# sem isto, o jogador marcha contra um "???" e descobre o tamanho do
		# exército inimigo quando já é tarde.
		Geopolitica.inicializar(state)
		var alvo: Dictionary = Geopolitica.reino_por_id(state, reino_id)
		var contagem := 0
		if not alvo.is_empty():
			Intel.registrar(state, reino_id, alvo.get("tropas", {}),
				int(alvo.get("forca", 0)))
			for tipo in alvo.get("tropas", {}):
				contagem += int(alvo["tropas"][tipo])
		return {"ok": true, "revelou": contagem,
			"msg": "SEGREDO descoberto sobre o rei de %s. Seu espião contou %d homens sob as bandeiras dele."
				% [reino_id, contagem]}

	if not state.has("flagras"):
		state["flagras"] = {}
	state["flagras"][reino_id] = int(state["flagras"].get(reino_id, 0)) + 1
	Dialogo.mudar_relacao(state, "rei_" + reino_id, -15, "espião capturado")
	var n: int = int(state["flagras"][reino_id])
	if n >= 3:
		state["flagras"][reino_id] = 0
		# devolve a pena: quem executa é jogo.gd, para não criar ciclo de import
		return {"ok": true, "prender": 3,
			"msg": "Terceiro espião capturado. Desta vez vieram atrás de VOCÊ."}
	return {"ok": true, "msg": "Espião CAPTURADO (%d de 3). Relação -15." % n}

## ---------- FABRICAR INTRIGA ----------
## Sai do flavor text: planta uma discórdia REAL entre dois reinos NPCs,
## derrubando a relação deles na geopolítica. Bem feito, faz dois vizinhos
## fortes se estraçalharem enquanto você cresce em paz.
static func fabricar_intriga(state: Dictionary, alvo_a: String, alvo_b: String) -> Dictionary:
	if alvo_a == alvo_b:
		return {"ok": false, "msg": "Não se semeia ódio entre um homem e ele mesmo."}
	var custo := 120
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false, "msg": "Falsários e mensageiros custam %d." % custo}
	state["jogador"]["ouro"] -= custo
	var chance: float = 0.35 + int(state["jogador"]["atributos"]["intriga"]) * 0.055
	# ter um segredo sobre um dos dois torna a mentira crível
	for s in state["segredos"]:
		if not s["usado"] and (s["reino"] == alvo_a or s["reino"] == alvo_b):
			chance += 0.20
			break
	if randf() < clampf(chance, 0.1, 0.85):
		Geopolitica.mudar_relacao(state, alvo_a, alvo_b, -Dados.ri(25, 45))
		return {"ok": true, "sucesso": true,
			"msg": "A carta forjada chegou às mãos certas. %s e %s se olham torto agora."
				% [alvo_a, alvo_b]}
	# exposto: os DOIS descobrem quem plantou
	Dialogo.mudar_relacao(state, "rei_" + alvo_a, -30, "intriga exposta")
	Dialogo.mudar_relacao(state, "rei_" + alvo_b, -30, "intriga exposta")
	return {"ok": true, "sucesso": false,
		"msg": "A intriga foi rastreada até você. Ambos os reinos sabem."}

## ---------- REIVINDICAR FEUDO ----------
## O segundo uso do documento forjado: tomar terra pela CORTE, sem guerra e
## sem a penalidade diplomática de uma agressão. É a rota do intrigante —
## mais barata em sangue, mais cara em risco de vergonha pública.
static func reivindicar_feudo(state: Dictionary, reino_id: String) -> Dictionary:
	if not state["casus_belli"].has(reino_id):
		return {"ok": false, "msg": "Sem documento que sustente a reivindicação."}
	var rel: int = int(state["tags"].get("rei_" + reino_id, {"relacao": 0})["relacao"])
	var chance: float = 0.25 + int(state["jogador"]["renome"]) * 0.002 + rel * 0.003
	state["casus_belli"].erase(reino_id)          # o papel é gasto de todo jeito
	if randf() < clampf(chance, 0.05, 0.75):
		for r in state["reinos"]:
			if r["id"] == reino_id:
				r["dominado_por"] = "jogador"
		if state["jogador"]["rei_de"] == "":
			state["jogador"]["rei_de"] = reino_id
		state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 25
		return {"ok": true, "sucesso": true,
			"msg": "A corte reconheceu seu direito. O feudo é seu — sem uma flecha disparada."}
	for r in state["reinos"]:
		Dialogo.mudar_relacao(state, "rei_" + r["id"], -25, "fraude na corte")
	return {"ok": true, "sucesso": false,
		"msg": "A fraude foi exposta diante de toda a corte. Todos os reinos souberam."}

## ---------- INCITAR REBELIÃO ----------
## Usa um segredo para virar o povo de um reino contra o próprio rei:
## derruba a força militar dele e queima o tesouro. É o golpe que prepara
## uma conquista futura sem custar um soldado seu.
static func incitar_rebeliao(state: Dictionary, reino_id: String) -> Dictionary:
	var idx := -1
	for i in state["segredos"].size():
		if state["segredos"][i]["reino"] == reino_id and not state["segredos"][i]["usado"]:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "msg": "Sem um segredo, ninguém acredita em você."}
	if int(state["jogador"]["ouro"]) < 200:
		return {"ok": false, "msg": "Comprar arautos e foices custa 200."}
	state["jogador"]["ouro"] -= 200
	state["segredos"][idx]["usado"] = true
	Geopolitica.inicializar(state)
	var r := Geopolitica.reino_por_id(state, reino_id)
	if r.is_empty():
		return {"ok": false, "msg": "Esse reino não existe mais."}
	if randf() < 0.5 + int(state["jogador"]["atributos"]["intriga"]) * 0.04:
		r["forca"] = maxi(5, int(int(r["forca"]) * 0.65))
		r["tesouro"] = int(int(r["tesouro"]) * 0.5)
		Economia.abalar(state, reino_id, "trigo", -0.5, 0.6, 4)
		return {"ok": true, "sucesso": true,
			"msg": "%s arde em revolta. O exército do rei está ocupado com o próprio povo."
				% r["nome"]}
	Dialogo.mudar_relacao(state, "rei_" + reino_id, -40, "sedição descoberta")
	return {"ok": true, "sucesso": false,
		"msg": "A sedição foi esmagada em uma semana, e seu nome estava nas confissões."}

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
