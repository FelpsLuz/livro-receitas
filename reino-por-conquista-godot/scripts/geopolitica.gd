# ============================================================
# GEOPOLÍTICA DOS NPCs — o mundo acontece sem o jogador.
#
# Todo mês os seis reinos: ganham e gastam tesouro, mudam de opinião uns
# sobre os outros, assinam pactos de comércio e alianças militares, declaram
# guerras e — o que dá peso ao mapa — CONQUISTAM uns aos outros.
#
# Tudo mora no `state` (serializa em JSON de graça) e roda em `passar_mes`,
# sem Timer nenhum: a política é do turno, não do relógio.
#
# Compatibilidade: `dominado_por` já existia para a vitória do jogador
# (jogo.gd conta `== "jogador"`), então um reino dominado por OUTRO reino
# não conta como conquista sua — de propósito. Se o Império engolir metade
# do mapa, você tem que tomar de volta.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Quantos meses um pacto dura antes de precisar ser renovado.
const DURACAO_PACTO := 12
## Abaixo disto, dois reinos podem partir para a guerra.
const LIMIAR_GUERRA := -50
## Acima disto, viram aliados militares.
const LIMIAR_ALIANCA := 55

# ------------------------------------------------------------
# Estado
# ------------------------------------------------------------
## Chave canônica de um par, para a relação não depender da ordem.
static func chave(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)

static func relacao(state: Dictionary, a: String, b: String) -> int:
	return int(state["relacoes_npc"].get(chave(a, b), 0))

static func mudar_relacao(state: Dictionary, a: String, b: String, delta: int) -> void:
	var k := chave(a, b)
	state["relacoes_npc"][k] = clampi(relacao(state, a, b) + delta, -100, 100)

## Prepara os campos dos reinos. Idempotente — roda em jogo novo e em save
## antigo, sem duplicar nada.
static func inicializar(state: Dictionary) -> void:
	if not state.has("relacoes_npc"):
		state["relacoes_npc"] = {}
	if not state.has("pactos"):
		state["pactos"] = []
	for r in state["reinos"]:
		if not r.has("tesouro"):
			r["tesouro"] = Dados.ri(400, 900)
		if not r.has("forca"):
			# nobres é o que o mundo já usava para medir peso de um reino
			r["forca"] = int(r.get("nobres", 5)) * Dados.ri(8, 14)
	# opinião inicial: vizinhos que produzem a mesma coisa se estranham
	for i in state["reinos"].size():
		for j in range(i + 1, state["reinos"].size()):
			var a: Dictionary = state["reinos"][i]
			var b: Dictionary = state["reinos"][j]
			var k := chave(a["id"], b["id"])
			if state["relacoes_npc"].has(k):
				continue
			var atrito := 0
			for bem in a["producao"]:
				if b["producao"].has(bem):
					atrito -= 20        # concorrentes no mesmo mercado
			state["relacoes_npc"][k] = clampi(Dados.ri(-15, 25) + atrito, -100, 100)

static func vivo(r: Dictionary) -> bool:
	return str(r.get("dominado_por", "")) == ""

static func reino_por_id(state: Dictionary, id: String) -> Dictionary:
	for r in state["reinos"]:
		if r["id"] == id:
			return r
	return {}

# ------------------------------------------------------------
# Pactos
# ------------------------------------------------------------
static func tem_pacto(state: Dictionary, a: String, b: String, tipo: String = "") -> bool:
	for p in state["pactos"]:
		if chave(p["a"], p["b"]) == chave(a, b):
			if tipo == "" or p["tipo"] == tipo:
				return true
	return false

## Pactos de um reino, para a UI e para o briefing da IA.
static func pactos_de(state: Dictionary, id: String) -> Array:
	var lista: Array = []
	for p in state["pactos"]:
		if p["a"] == id or p["b"] == id:
			lista.append(p)
	return lista

static func _assinar(state: Dictionary, a: Dictionary, b: Dictionary,
		tipo: String, log: Callable) -> void:
	state["pactos"].append({"a": a["id"], "b": b["id"], "tipo": tipo, "meses": DURACAO_PACTO})
	mudar_relacao(state, a["id"], b["id"], 15 if tipo == "comercio" else 25)
	Sinais.emitir(&"pacto_npc", {"a": a["id"], "b": b["id"], "tipo": tipo})
	if tipo == "comercio":
		log.call("%s e %s assinaram um acordo comercial." % [a["nome"], b["nome"]])
	else:
		log.call("ALIANÇA: %s e %s juram defesa mútua." % [a["nome"], b["nome"]])

# ------------------------------------------------------------
# O turno
# ------------------------------------------------------------
static func tick(state: Dictionary, log: Callable) -> void:
	inicializar(state)
	_tick_economia(state)
	_tick_pactos(state, log)
	_tick_opiniao(state)
	_tick_declaracoes(state, log)
	_tick_conquistas(state, log)

## Tesouro e força oscilam: produção rende, guerra queima, comércio soma.
static func _tick_economia(state: Dictionary) -> void:
	for r in state["reinos"]:
		if not vivo(r):
			continue
		var renda: int = int(r.get("nobres", 5)) * Dados.ri(6, 14)
		for p in pactos_de(state, r["id"]):
			if p["tipo"] == "comercio":
				renda = roundi(renda * 1.25)
		var gasto: int = int(r["forca"]) / 4
		if _em_guerra(state, r["id"]):
			gasto = roundi(gasto * 2.2)          # campanha é cara
		r["tesouro"] = maxi(0, int(r["tesouro"]) + renda - gasto)
		# tesouro cheio vira soldado; cofre vazio dispersa o exército
		if int(r["tesouro"]) > 1200:
			r["tesouro"] = int(r["tesouro"]) - 200
			r["forca"] = int(r["forca"]) + Dados.ri(5, 12)
		elif int(r["tesouro"]) <= 0:
			r["forca"] = maxi(5, int(r["forca"]) - Dados.ri(3, 9))

static func _tick_pactos(state: Dictionary, log: Callable) -> void:
	var vivos: Array = []
	for p in state["pactos"]:
		p["meses"] = int(p["meses"]) - 1
		var ra := reino_por_id(state, p["a"])
		var rb := reino_por_id(state, p["b"])
		# pacto morre se expirou, se a relação azedou ou se um dos dois caiu
		if int(p["meses"]) <= 0 or relacao(state, p["a"], p["b"]) < 0 \
				or ra.is_empty() or rb.is_empty() or not vivo(ra) or not vivo(rb):
			if int(p["meses"]) <= 0 and not ra.is_empty() and not rb.is_empty():
				log.call("O pacto entre %s e %s expirou." % [ra["nome"], rb["nome"]])
			continue
		vivos.append(p)
	state["pactos"] = vivos

	# quem se dá bem e não tem pacto, tenta um
	for i in state["reinos"].size():
		for j in range(i + 1, state["reinos"].size()):
			var a: Dictionary = state["reinos"][i]
			var b: Dictionary = state["reinos"][j]
			if not vivo(a) or not vivo(b):
				continue
			if _em_guerra_entre(state, a["id"], b["id"]):
				continue
			var rel := relacao(state, a["id"], b["id"])
			if rel >= LIMIAR_ALIANCA and not tem_pacto(state, a["id"], b["id"], "alianca"):
				if randf() < 0.12:
					_assinar(state, a, b, "alianca", log)
			elif rel >= 20 and not tem_pacto(state, a["id"], b["id"]):
				# comércio nasce da complementaridade: produzem coisas diferentes
				var iguais := 0
				for bem in a["producao"]:
					if b["producao"].has(bem):
						iguais += 1
				if iguais == 0 and randf() < 0.15:
					_assinar(state, a, b, "comercio", log)

## A opinião anda sozinha: pactos aproximam, guerras afastam, o resto oscila.
static func _tick_opiniao(state: Dictionary) -> void:
	for i in state["reinos"].size():
		for j in range(i + 1, state["reinos"].size()):
			var a: String = state["reinos"][i]["id"]
			var b: String = state["reinos"][j]["id"]
			var delta := 0
			if tem_pacto(state, a, b, "alianca"):
				delta += 3
			elif tem_pacto(state, a, b, "comercio"):
				delta += 2
			if _em_guerra_entre(state, a, b):
				delta -= 6
			delta += Dados.ri(-2, 2)
			if delta != 0:
				mudar_relacao(state, a, b, delta)

## Guerra entre NPCs: precisa de ódio, de exército e de nenhum pacto.
static func _tick_declaracoes(state: Dictionary, log: Callable) -> void:
	if state["guerras"].size() >= 3:
		return
	for i in state["reinos"].size():
		for j in range(i + 1, state["reinos"].size()):
			var a: Dictionary = state["reinos"][i]
			var b: Dictionary = state["reinos"][j]
			if not vivo(a) or not vivo(b):
				continue
			if _em_guerra_entre(state, a["id"], b["id"]):
				continue
			if tem_pacto(state, a["id"], b["id"]):
				continue
			if relacao(state, a["id"], b["id"]) > LIMIAR_GUERRA:
				continue
			# o agressor é o mais forte, e só ataca com vantagem real
			var forte: Dictionary = a if int(a["forca"]) >= int(b["forca"]) else b
			var fraco: Dictionary = b if forte == a else a
			if int(forte["forca"]) < int(fraco["forca"]) * 1.2:
				continue
			if randf() > 0.18:
				continue
			state["guerras"].append({"a": forte["id"], "b": fraco["id"], "meses": 0})
			Sinais.emitir(&"guerra_npc", {"a": forte["id"], "b": fraco["id"]})
			log.call("GUERRA! %s marcha contra %s." % [forte["nome"], fraco["nome"]])
			# aliados são arrastados: é o que torna uma aliança perigosa
			for p in pactos_de(state, fraco["id"]):
				if p["tipo"] != "alianca":
					continue
				var aliado_id: String = p["b"] if p["a"] == fraco["id"] else p["a"]
				mudar_relacao(state, aliado_id, forte["id"], -30)
				log.call("%s honra a aliança e volta-se contra %s."
					% [reino_por_id(state, aliado_id)["nome"], forte["nome"]])
			return              # uma declaração por mês, para o mapa respirar

## Guerra longa decide território. Quem tem mais força e mais tesouro vence.
static func _tick_conquistas(state: Dictionary, log: Callable) -> void:
	for g in state["guerras"]:
		# guerra do jogador não se resolve sozinha: ele é quem luta
		if g["a"] == "jogador" or g["b"] == "jogador":
			continue
		if int(g["meses"]) < 4:
			continue
		var a := reino_por_id(state, g["a"])
		var b := reino_por_id(state, g["b"])
		if a.is_empty() or b.is_empty() or not vivo(a) or not vivo(b):
			continue
		var forca_a: float = float(a["forca"]) * (1.0 + int(a["tesouro"]) / 2000.0)
		var forca_b: float = float(b["forca"]) * (1.0 + int(b["tesouro"]) / 2000.0)
		var razao: float = forca_a / maxf(1.0, forca_b)
		if razao < 1.6 and razao > 0.625:
			continue                     # empate técnico: a guerra se arrasta
		if randf() > 0.22:
			continue
		var vencedor: Dictionary = a if razao >= 1.6 else b
		var perdedor: Dictionary = b if razao >= 1.6 else a
		perdedor["dominado_por"] = vencedor["id"]
		vencedor["forca"] = int(vencedor["forca"]) + int(int(perdedor["forca"]) * 0.4)
		vencedor["tesouro"] = int(vencedor["tesouro"]) + int(int(perdedor["tesouro"]) * 0.5)
		vencedor["nobres"] = int(vencedor.get("nobres", 5)) + 2
		perdedor["forca"] = maxi(5, int(int(perdedor["forca"]) * 0.3))
		# o mundo inteiro reage a um vizinho que cresceu demais
		for r in state["reinos"]:
			if r["id"] != vencedor["id"] and vivo(r):
				mudar_relacao(state, r["id"], vencedor["id"], -15)
		Sinais.emitir(&"conquista_npc", {"vencedor": vencedor["id"], "perdedor": perdedor["id"]})
		log.call("%s CONQUISTOU %s. O equilíbrio do mundo mudou."
			% [vencedor["nome"], perdedor["nome"]])
		return                           # uma conquista por mês

# ------------------------------------------------------------
static func _em_guerra(state: Dictionary, id: String) -> bool:
	for g in state["guerras"]:
		if g["a"] == id or g["b"] == id:
			return true
	return false

static func _em_guerra_entre(state: Dictionary, a: String, b: String) -> bool:
	for g in state["guerras"]:
		if chave(g["a"], g["b"]) == chave(a, b):
			return true
	return false

## Resumo para a UI: como está o mundo agora.
static func panorama(state: Dictionary) -> Array:
	inicializar(state)
	var linhas: Array = []
	for r in state["reinos"]:
		linhas.append({
			"id": r["id"], "nome": r["nome"], "vivo": vivo(r),
			"senhor": str(r.get("dominado_por", "")),
			"tesouro": int(r.get("tesouro", 0)), "forca": int(r.get("forca", 0)),
			"em_guerra": _em_guerra(state, r["id"]),
			"pactos": pactos_de(state, r["id"]).size(),
		})
	return linhas
