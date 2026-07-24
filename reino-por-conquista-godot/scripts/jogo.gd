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
const Contratos = preload("res://scripts/contratos.gd")

const ARQUIVO_SAVE := "user://save.json"

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
		"cronica": [], "contratos": [], "evento_pendente": null, "chantagem_pendente": null,
		"fim": null,
	}
	Economia.inicializar_mercados(state)
	state["contratos"] = Contratos.gerar(state)
	var log := log_para(state)
	log.call("Ano 1. Você é %s: sem terras, sem título, com %d moedas e 5 lanceiros leais." %
		[state["jogador"]["nome"], state["jogador"]["ouro"]])
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
	state["contratos"] = Contratos.gerar(state)
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

# ---------- gestão do exército ----------
static func recrutar(state: Dictionary, tipo: String, qtd: int) -> Dictionary:
	var custo: int = int(Dados.TROPAS[tipo]["custo"]) * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Custa %d de ouro." % custo}
	if tipo == "campones":
		if state["terra"] == null:
			return {"ok": false, "msg": "Camponeses vêm da SUA terra — e você não tem uma."}
		var disponiveis: int = int(state["terra"]["populacao"]) - int(state["jogador"]["tropas"].get("campones", 0))
		if qtd > disponiveis:
			return {"ok": false, "msg": "Só há %d camponeses disponíveis." % disponiveis}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["tropas"][tipo] = int(state["jogador"]["tropas"].get(tipo, 0)) + qtd
	return {"ok": true, "msg": "Recrutou %d× %s." % [qtd, Dados.TROPAS[tipo]["nome"]]}

static func contratar_guardas(state: Dictionary, qtd: int) -> Dictionary:
	var custo := 60 * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Guarda de elite custa 60/homem (%d)." % custo}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["guardas"] = int(state["jogador"]["guardas"]) + qtd
	return {"ok": true, "msg": "%d guardas de elite contratados." % qtd}

static func melhorar_equip(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["equip"]) >= 3:
		return {"ok": false, "msg": "Equipamento no máximo."}
	var custo: int = 200 * (int(state["jogador"]["equip"]) + 1)
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Melhoria custa %d de ouro." % custo}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["equip"] = int(state["jogador"]["equip"]) + 1
	return {"ok": true, "msg": "Equipamento nível %d (+15%% de força)." % state["jogador"]["equip"]}

static func exportar_comida(state: Dictionary, qtd: int) -> Dictionary:
	if state["terra"] == null:
		return {"ok": false, "msg": "Você não tem terras."}
	var t: Dictionary = state["terra"]
	if int(t["alimento"]) < qtd:
		return {"ok": false, "msg": "Não há tanto alimento nos celeiros."}
	t["alimento"] = int(t["alimento"]) - qtd
	var ganho: int = roundi(Economia.preco_de(state, state["local"], "trigo") * qtd * 1.1)
	state["jogador"]["ouro"] += ganho
	if int(t["alimento"]) < int(t["populacao"]) * 2:
		t["felicidade"] = clampi(int(t["felicidade"]) - 15, 0, 100)
		return {"ok": true, "msg": "Vendeu %d de alimento por %d — o povo murmura (felicidade -15)." % [qtd, ganho]}
	return {"ok": true, "msg": "Exportou %d de alimento por %d de ouro." % [qtd, ganho]}

# ---------- eventos pendentes ----------
static func resolver_evento(state: Dictionary, escolha: String) -> Dictionary:
	var ev = state["evento_pendente"]
	if ev == null:
		return {}
	state["evento_pendente"] = null
	var log := log_para(state)
	var resultado := {}
	match ev["tipo"]:
		"rebeliao":
			if escolha == "reprimir":
				var rebeldes := {"tropas": {"campones": Dados.ri(15, 30), "lanceiro": Dados.ri(2, 5)},
					"equip": 0, "formacao": "cerco"}
				resultado = Combate.batalhar(state, rebeldes, "Rebelião camponesa")
				if resultado["vitoria"]:
					state["terra"]["felicidade"] = 35
					state["terra"]["populacao"] = maxi(5, int(state["terra"]["populacao"]) - Dados.ri(4, 8))
					state["jogador"]["crueldade"] = int(state["jogador"].get("crueldade", 0)) + 1
					log.call("Você afogou a rebelião em sangue. A vila obedece — e odeia.")
				else:
					morrer(state, "rebeliao", log)
			else:
				var custo: int = mini(int(state["jogador"]["ouro"]), 200)
				state["jogador"]["ouro"] -= custo
				state["terra"]["alimento"] = int(state["terra"]["alimento"]) + 60
				state["terra"]["felicidade"] = 55
				log.call("Você abriu os celeiros (-%d ouro). O povo abaixa as foices." % custo)
		"traicao_guardas":
			var custo_g: int = int(state["jogador"]["guardas"]) * 15
			if escolha == "pagar" and state["jogador"]["ouro"] >= custo_g:
				state["jogador"]["ouro"] -= custo_g
				state["jogador"]["meses_sem_pagar"] = 0
				log.call("Você pagou a guarda em dobro (-%d). Os portões continuam seus." % custo_g)
			else:
				log.call("Sua guarda abriu os portões na calada da noite. Você fugiu pelo esgoto.")
				state["jogador"]["guardas"] = 0
				state["jogador"]["ouro"] = int(state["jogador"]["ouro"] / 2.0)
				if state["terra"] != null:
					state["terra"]["nivel"] = maxi(0, int(state["terra"]["nivel"]) - 2)
	return resultado

# ---------- save / load (JSON em user://) ----------
static func salvar(state: Dictionary) -> bool:
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	return true

static func tem_save() -> bool:
	return FileAccess.file_exists(ARQUIVO_SAVE)

static func carregar() -> Variant:
	if not tem_save():
		return null
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.READ)
	var dados = JSON.parse_string(f.get_as_text())
	if dados == null:
		return null
	return _normalizar(dados)

static func apagar_save() -> void:
	if tem_save():
		DirAccess.remove_absolute(ARQUIVO_SAVE)

# JSON devolve todo número como float; converte inteiros de volta.
static func _normalizar(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _normalizar(v[k])
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _normalizar(v[i])
		TYPE_FLOAT:
			if v == floorf(v):
				return int(v)
	return v
