# ============================================================
# NÚCLEO DO JOGO (port de js/game.js)
# Estado, turno mensal, morte e herança dinástica.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Clas = preload("res://scripts/clas.gd")
const Intriga = preload("res://scripts/intriga.gd")

static func novo_jogo(nome: String = "") -> Dictionary:
	var state := {
		"ano": 1, "mes": 3,
		"jogador": {
			"nome": nome if nome != "" else Dados.rnd(Dados.NOMES_M) + " " + Dados.rnd(Dados.SOBRENOMES),
			"idade": 22,
			"atributos": {"forca": Dados.ri(4, 7), "carisma": Dados.ri(4, 7),
				"gestao": Dados.ri(4, 7), "intriga": Dados.ri(3, 6)},
			"renome": 0, "ouro": 150, "crueldade": 0,
			"tropas": {"campones": 0, "lanceiro": 5, "arqueiro": 0, "cavaleiro": 0},
			"equip": 0, "formacao": "linha", "guardas": 0,
			"rei_de": "", "meses_reinando": 0, "meses_sem_pagar": 0,
		},
		"reinos": Dados.REINOS_BASE.duplicate(true),
		"guerras": [], "tags": {}, "segredos": [], "casus_belli": [],
		"carga": {}, "terra": null, "local": "valdria",
		"familia": {"conjuge": null, "filhos": []},
		"mensageiros": [], "clas_ativos": [], "cartas": [],
		"cronica": [], "evento_pendente": null, "chantagem_pendente": null,
		"fim": null,
	}
	Economia.inicializar_mercados(state)
	return state

static func log_para(state: Dictionary) -> Callable:
	return func(msg: String):
		state["cronica"].push_front({"ano": state["ano"], "mes": state["mes"], "msg": msg})
		if state["cronica"].size() > 60:
			state["cronica"].pop_back()

static func passar_mes(state: Dictionary) -> void:
	if state["fim"] != null or state["evento_pendente"] != null:
		return
	var log := log_para(state)
	state["mes"] += 1
	if state["mes"] > 12:
		state["mes"] = 1
		state["ano"] += 1
		_envelhecer(state, log)
		if state["fim"] != null:
			return
	Economia.talvez_iniciar_guerra(state, log)
	Economia.tick_guerras(state, log)
	Economia.tick_mercados(state)
	Economia.tick_terra(state, log)
	Economia.tick_exercito(state, log)
	Clas.tick(state, log)
	Intriga.tick_familia(state, log)
	if state["jogador"]["rei_de"] != "":
		state["jogador"]["meses_reinando"] += 1
		if state["jogador"]["meses_reinando"] >= 12:
			state["fim"] = {"tipo": "vitoria"}

static func _envelhecer(state: Dictionary, log: Callable) -> void:
	state["jogador"]["idade"] += 1
	for f in state["familia"]["filhos"]:
		f["idade"] += 1
	var idade: int = state["jogador"]["idade"]
	var chance := 0.25 if idade > 65 else (0.10 if idade > 55 else (0.04 if idade > 45 else 0.0))
	if randf() < chance:
		morrer(state, "idade", log)

static func morrer(state: Dictionary, causa: String, log: Callable) -> void:
	var herdeiro: Dictionary = {}
	for f in state["familia"]["filhos"]:
		if f["idade"] >= 16:
			herdeiro = f
			break
	if herdeiro.is_empty():
		state["fim"] = {"tipo": "derrota", "causa": causa}
		return
	log.call("%s morre (%s). %s assume a casa." % [state["jogador"]["nome"], causa, herdeiro["nome"]])
	state["jogador"]["nome"] = herdeiro["nome"]
	state["jogador"]["idade"] = herdeiro["idade"]
	state["jogador"]["atributos"] = herdeiro["atributos"]
	state["jogador"]["crueldade"] = 2 if herdeiro.get("mimado", false) else 0
	state["familia"]["filhos"].erase(herdeiro)
	state["familia"]["conjuge"] = null

static func comprar_terra(state: Dictionary) -> Dictionary:
	if state["terra"] != null:
		return {"ok": false, "msg": "Você já tem terras."}
	if state["jogador"]["renome"] < 25:
		return {"ok": false, "msg": "Renome insuficiente (25)."}
	if state["jogador"]["ouro"] < 300:
		return {"ok": false, "msg": "Terra custa 300 de ouro."}
	state["jogador"]["ouro"] -= 300
	state["terra"] = {"nome": "Vale " + Dados.rnd(["Sereno", "das Pedras", "do Corvo", "Dourado", "Frio"]),
		"nivel": 0, "populacao": 20, "alimento": 80, "madeira": 20, "felicidade": 60}
	return {"ok": true, "msg": "Terra adquirida!"}

static func melhorar_terra(state: Dictionary) -> Dictionary:
	if state["terra"] == null:
		return {"ok": false, "msg": "Sem terras."}
	var t: Dictionary = state["terra"]
	if t["nivel"] >= 5:
		return {"ok": false, "msg": "Nível máximo."}
	var prox: Dictionary = Dados.NIVEIS_TERRA[t["nivel"] + 1]
	if state["jogador"]["ouro"] < prox["custo_ouro"] or t["madeira"] < prox["custo_madeira"]:
		return {"ok": false, "msg": "Recursos insuficientes."}
	state["jogador"]["ouro"] -= int(prox["custo_ouro"])
	t["madeira"] = int(t["madeira"]) - int(prox["custo_madeira"])
	t["nivel"] += 1
	t["populacao"] += Dados.ri(10, 20)
	return {"ok": true, "msg": "Evoluiu para %s!" % prox["nome"]}
