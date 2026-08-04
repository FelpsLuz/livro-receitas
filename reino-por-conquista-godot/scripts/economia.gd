# ============================================================
# ECONOMIA VIVA (port GDScript de js/economy.js)
# Oferta×demanda, guerra queima campos, fadiga de guerra,
# fome, rebelião, deserção por soldo atrasado.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")

static func inicializar_mercados(state: Dictionary) -> void:
	state["mercados"] = {}
	for r in state["reinos"]:
		var m := {}
		for g_id in Dados.MERCADORIAS:
			m[g_id] = {"oferta": 1.6 if r["producao"].has(g_id) else 1.0, "demanda": 1.0}
		state["mercados"][r["id"]] = m

static func preco_de(state: Dictionary, reino_id: String, g_id: String) -> int:
	var m: Dictionary = state["mercados"][reino_id][g_id]
	var preco: float = Dados.MERCADORIAS[g_id]["preco_base"] * (m["demanda"] / m["oferta"])
	var rel: int = state["tags"].get("rei_" + reino_id, {"relacao": 0})["relacao"]
	if rel <= -60: preco *= 1.6
	elif rel <= -25: preco *= 1.25
	elif rel >= 60: preco *= 0.85
	elif rel >= 25: preco *= 0.95
	return maxi(1, roundi(preco))

static func comprar(state: Dictionary, reino_id: String, g_id: String, qtd: int) -> Dictionary:
	var preco := preco_de(state, reino_id, g_id)
	var custo := preco * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Ouro insuficiente (custa %d)." % custo}
	state["jogador"]["ouro"] -= custo
	state["carga"][g_id] = int(state["carga"].get(g_id, 0)) + qtd
	var m: Dictionary = state["mercados"][reino_id][g_id]
	m["oferta"] = maxf(0.2, m["oferta"] - 0.02 * qtd)
	return {"ok": true, "msg": "Comprou %d por %d de ouro." % [qtd, custo]}

static func vender(state: Dictionary, reino_id: String, g_id: String, qtd: int) -> Dictionary:
	if int(state["carga"].get(g_id, 0)) < qtd:
		return {"ok": false, "msg": "Você não tem essa carga."}
	var em_guerra := _em_guerra(state, reino_id)
	var preco := preco_de(state, reino_id, g_id)
	if em_guerra and g_id == "trigo":
		preco = roundi(preco * 1.3)
		if randf() < 0.20:
			var perda := ceili(qtd / 2.0)
			state["carga"][g_id] = int(state["carga"][g_id]) - perda
			return {"ok": false, "msg": "Patrulha confiscou %d do contrabando!" % perda}
	var ganho := preco * qtd
	state["carga"][g_id] = int(state["carga"][g_id]) - qtd
	state["jogador"]["ouro"] += ganho
	var m: Dictionary = state["mercados"][reino_id][g_id]
	m["oferta"] = minf(3.0, m["oferta"] + 0.02 * qtd)
	return {"ok": true, "msg": "Vendeu %d por %d de ouro." % [qtd, ganho]}

static func _em_guerra(state: Dictionary, reino_id: String) -> bool:
	for g in state["guerras"]:
		if g["a"] == reino_id or g["b"] == reino_id:
			return true
	return false

static func talvez_iniciar_guerra(state: Dictionary, log: Callable) -> void:
	if state["guerras"].size() >= 2 or randf() > 0.10:
		return
	var livres: Array = state["reinos"].filter(func(r): return not _em_guerra(state, r["id"]))
	if livres.size() < 2:
		return
	var a: Dictionary = Dados.rnd(livres)
	var b: Dictionary = Dados.rnd(livres.filter(func(r): return r["id"] != a["id"]))
	state["guerras"].append({"a": a["id"], "b": b["id"], "meses": 0})
	log.call("GUERRA! %s declarou guerra a %s." % [a["nome"], b["nome"]])

static func tick_guerras(state: Dictionary, log: Callable) -> void:
	var vivas: Array = []
	for g in state["guerras"]:
		g["meses"] += 1
		for id in [g["a"], g["b"]]:
			var m: Dictionary = state["mercados"][id]
			m["trigo"]["oferta"] = maxf(0.25, m["trigo"]["oferta"] * 0.82)
			m["ferro"]["demanda"] = minf(3.0, m["ferro"]["demanda"] * 1.08)
		if g["meses"] >= 6 and randf() < 0.35:
			log.call("%s e %s assinaram a paz, exaustos." % [g["a"], g["b"]])
		else:
			vivas.append(g)
	state["guerras"] = vivas

## ---------- CHOQUES DE MERCADO ----------
## Um choque é um empurrão com prazo: {reino, bem, oferta, demanda, meses}.
## Qualquer sistema pode empilhar um — guerra, saque, rumor de taverna,
## intriga — e todos passam pelo MESMO caminho até o preço. Sem isto, cada
## novo evento vira um caso especial dentro de preco_de().
static func abalar(state: Dictionary, reino: String, bem: String,
		d_oferta: float, d_demanda: float, meses: int) -> void:
	if not state.has("choques"):
		state["choques"] = []
	state["choques"].append({"reino": reino, "bem": bem,
		"oferta": d_oferta, "demanda": d_demanda, "meses": meses})

static func tick_choques(state: Dictionary) -> void:
	if not state.has("choques"):
		state["choques"] = []
		return
	var vivos: Array = []
	for c in state["choques"]:
		var mercado_reino = state["mercados"].get(c["reino"])
		if mercado_reino == null:
			continue
		var m: Dictionary = mercado_reino[c["bem"]]
		m["oferta"] = clampf(m["oferta"] + float(c["oferta"]), 0.2, 3.0)
		m["demanda"] = clampf(m["demanda"] + float(c["demanda"]), 0.5, 3.0)
		c["meses"] = int(c["meses"]) - 1
		if int(c["meses"]) > 0:
			vivos.append(c)
	state["choques"] = vivos

static func tick_mercados(state: Dictionary) -> void:
	for r in state["reinos"]:
		var em_guerra := _em_guerra(state, r["id"])
		for g_id in Dados.MERCADORIAS:
			var m: Dictionary = state["mercados"][r["id"]][g_id]
			var alvo: float = 1.6 if r["producao"].has(g_id) else 1.0
			if not em_guerra:
				m["oferta"] += (alvo - m["oferta"]) * 0.15
			m["demanda"] += (1.0 - m["demanda"]) * 0.10
			m["demanda"] = clampf(m["demanda"] * (1.0 + (randf() - 0.5) * 0.06), 0.5, 3.0)

static func tick_terra(state: Dictionary, log: Callable) -> void:
	if state["terra"] == null:
		return
	var t: Dictionary = state["terra"]
	var convocados: int = int(state["jogador"]["tropas"].get("campones", 0))
	var trabalhando: int = maxi(0, t["populacao"] - convocados)
	var producao: int = roundi(trabalhando * 1.5 * (1.0 + t["nivel"] * 0.15))
	t["alimento"] = maxi(0, t["alimento"] + producao - t["populacao"])
	t["madeira"] += 2 + t["nivel"] * 2
	if convocados > t["populacao"] * 0.4:
		log.call("Quase metade da vila está no exército: a colheita despencou.")
	if t["alimento"] <= 0:
		t["felicidade"] = clampi(t["felicidade"] - 20, 0, 100)
		t["populacao"] = maxi(5, t["populacao"] - Dados.ri(1, 4))
		log.call("FOME em %s! Felicidade -20." % t["nome"])
	elif t["felicidade"] < 70:
		t["felicidade"] = clampi(t["felicidade"] + 5, 0, 100)
	state["jogador"]["ouro"] += roundi(trabalhando * 0.8 * (1.0 + t["nivel"] * 0.2))
	if t["felicidade"] <= 20 and randf() < 0.5:
		log.call("REBELIÃO em %s!" % t["nome"])
		state["evento_pendente"] = {"tipo": "rebeliao"}

static func tick_exercito(state: Dictionary, log: Callable) -> void:
	var manut := 0
	for tipo in state["jogador"]["tropas"]:
		manut += int(Dados.TROPAS[tipo]["manut"]) * int(state["jogador"]["tropas"][tipo])
	manut += int(state["jogador"]["guardas"]) * 4
	state["jogador"]["ultima_manut"] = manut
	if state["jogador"]["ouro"] >= manut:
		state["jogador"]["ouro"] -= manut
		state["jogador"]["meses_sem_pagar"] = 0
	else:
		state["jogador"]["ouro"] = 0
		state["jogador"]["meses_sem_pagar"] = int(state["jogador"].get("meses_sem_pagar", 0)) + 1
		log.call("O tesouro zerou! Tropas sem soldo.")
		if state["jogador"]["meses_sem_pagar"] >= 2:
			for tipo in state["jogador"]["tropas"]:
				var n: int = int(state["jogador"]["tropas"][tipo])
				state["jogador"]["tropas"][tipo] = maxi(0, n - ceili(n * 0.3))
			log.call("Tropas desertaram em massa.")
			if state["jogador"]["guardas"] > 0 and state["terra"] != null and randf() < 0.5:
				state["evento_pendente"] = {"tipo": "traicao_guardas"}
				log.call("Um reino rival ofereceu ouro à sua guarda de elite...")
