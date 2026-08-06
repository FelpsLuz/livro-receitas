# ============================================================
# VASSALAGEM — a diplomacia do ouro, e a saída para quem começa pobre.
#
# Os seis reinos começam ricos por lore; o jogador, com 150 moedas e cinco
# lanceiros. Se o Império marchar no Ano 1, não há defesa possível. Jurar
# lealdade é a válvula: o suserano não te ataca, mas leva 20% do seu ouro
# todo mês e convoca suas tropas quando entra em guerra.
#
# O jogo longo passa a ser crescer NAS SOMBRAS — subir a infraestrutura,
# encher o quartel — até poder rasgar o juramento. Declarar independência
# custa renome e faz o suserano marchar; é uma decisão, não um botão.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Fatia do ouro do vassalo que o suserano leva por mês.
const TRIBUTO := 0.20
## Renome perdido ao rasgar o juramento (traição é cara).
const CUSTO_INDEPENDENCIA := 25

static func suserano(state: Dictionary) -> String:
	return str(state["jogador"].get("suserano", ""))

static func e_vassalo(state: Dictionary) -> bool:
	return suserano(state) != ""

## Um reino só aceita vassalo que valha a pena proteger — ou que seja fraco
## o bastante para não ameaçar. Rei de si mesmo não jura a ninguém.
static func pode_jurar(state: Dictionary, reino_id: String) -> Dictionary:
	if e_vassalo(state):
		return {"ok": false, "msg": "Você já jurou lealdade a %s." % suserano(state)}
	if str(state["jogador"].get("rei_de", "")) != "":
		return {"ok": false, "msg": "Um rei não ajoelha diante de outro."}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, reino_id)
	if r.is_empty() or not Geopolitica.vivo(r):
		return {"ok": false, "msg": "Esse trono não manda mais em nada."}
	var rel: int = int(state["tags"].get("rei_" + reino_id, {"relacao": 0})["relacao"])
	if rel <= -40:
		return {"ok": false, "msg": "Ele prefere sua cabeça numa lança a seu juramento."}
	return {"ok": true, "reino": r}

static func jurar(state: Dictionary, reino_id: String, log: Callable) -> Dictionary:
	var check := pode_jurar(state, reino_id)
	if not check["ok"]:
		return check
	var r: Dictionary = check["reino"]
	state["jogador"]["suserano"] = reino_id
	state["jogador"]["meses_vassalo"] = 0
	var Dialogo = load("res://scripts/dialogo.gd")
	Dialogo.mudar_relacao(state, "rei_" + reino_id, 30, "juramento de lealdade")
	# proteção real: o suserano cancela guerra contra você
	var vivas: Array = []
	for g in state["guerras"]:
		if (g["a"] == reino_id and g["b"] == "jogador") \
				or (g["b"] == reino_id and g["a"] == "jogador"):
			continue
		vivas.append(g)
	state["guerras"] = vivas
	Sinais.emitir(&"vassalagem", {"suserano": reino_id, "jurou": true})
	log.call("Você dobrou o joelho diante de %s. Enquanto pagar, vive." % r["nome"])
	return {"ok": true, "msg": "Você agora é vassalo de %s. Tributo: %d%% do seu ouro."
		% [r["nome"], int(TRIBUTO * 100)]}

## Todo mês: o tributo sai, e o suserano leva também o que a guerra dele pedir.
static func tick(state: Dictionary, log: Callable) -> void:
	if not e_vassalo(state):
		return
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id := suserano(state)
	var r: Dictionary = Geopolitica.reino_por_id(state, id)
	if r.is_empty() or not Geopolitica.vivo(r):
		# o suserano caiu: você está livre, e ninguém precisou saber
		state["jogador"]["suserano"] = ""
		log.call("Seu suserano caiu. Ninguém mais reclama o seu tributo.")
		Sinais.emitir(&"vassalagem", {"suserano": "", "jurou": false})
		return
	state["jogador"]["meses_vassalo"] = int(state["jogador"].get("meses_vassalo", 0)) + 1

	var tributo: int = roundi(int(state["jogador"]["ouro"]) * TRIBUTO)
	if tributo > 0:
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - tributo
		r["tesouro"] = int(r.get("tesouro", 0)) + tributo
		if int(state["jogador"]["meses_vassalo"]) % 6 == 1:
			log.call("O cobrador de %s levou %d de ouro." % [r["nome"], tributo])

	# suserano em guerra convoca tropas do vassalo — e elas não voltam todas
	if _em_guerra(state, id) and randf() < 0.25:
		var levados := 0
		for tipo in state["jogador"]["tropas"]:
			var n: int = int(state["jogador"]["tropas"][tipo])
			var vao: int = int(n * 0.15)
			if vao > 0:
				state["jogador"]["tropas"][tipo] = n - vao
				levados += vao
		if levados > 0:
			r["tropas"][_maior_tipo(r)] = int(r["tropas"].get(_maior_tipo(r), 0)) + levados
			log.call("%s convocou %d dos seus homens para a guerra dele." % [r["nome"], levados])

static func _maior_tipo(r: Dictionary) -> String:
	var melhor := "lanceiro"
	var n := -1
	for tipo in r.get("tropas", {}):
		if int(r["tropas"][tipo]) > n:
			n = int(r["tropas"][tipo])
			melhor = tipo
	return melhor

static func _em_guerra(state: Dictionary, id: String) -> bool:
	for g in state["guerras"]:
		if g["a"] == id or g["b"] == id:
			return true
	return false

## Rasgar o juramento. O suserano marcha, o mundo condena, e você é livre.
static func declarar_independencia(state: Dictionary, log: Callable) -> Dictionary:
	if not e_vassalo(state):
		return {"ok": false, "msg": "Você não deve lealdade a ninguém."}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id := suserano(state)
	var r: Dictionary = Geopolitica.reino_por_id(state, id)
	state["jogador"]["suserano"] = ""
	state["jogador"]["renome"] = maxi(0, int(state["jogador"]["renome"]) - CUSTO_INDEPENDENCIA)
	var Dialogo = load("res://scripts/dialogo.gd")
	Dialogo.mudar_relacao(state, "rei_" + id, -70, "juramento rasgado")
	state["guerras"].append({"a": id, "b": "jogador", "meses": 0})
	if not state["casus_belli"].has(id):
		state["casus_belli"].append(id)      # agora a guerra é sua, e é legítima
	Sinais.emitir(&"vassalagem", {"suserano": "", "jurou": false, "independencia": true})
	var nome: String = str(r.get("nome", id))
	log.call("Você rasgou o juramento a %s. Os arautos já cavalgam." % nome)
	return {"ok": true, "msg": "Independência declarada. %s vem cobrar." % nome}

## Resumo para a UI.
static func resumo(state: Dictionary) -> Dictionary:
	if not e_vassalo(state):
		return {"vassalo": false}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, suserano(state))
	return {"vassalo": true, "suserano": suserano(state),
		"nome": str(r.get("nome", suserano(state))),
		"meses": int(state["jogador"].get("meses_vassalo", 0)),
		"tributo_estimado": roundi(int(state["jogador"]["ouro"]) * TRIBUTO)}
