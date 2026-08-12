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
const Economia = preload("res://scripts/economia.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Combate = preload("res://scripts/combate.gd")

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
		if not r.has("celeiro"):
			r["celeiro"] = Dados.ri(300, 700)
		if not r.has("madeireira"):
			r["madeireira"] = Dados.ri(150, 400)
		if not r.has("moral"):
			r["moral"] = 100
		if not r.has("equip"):
			r["equip"] = 0
		if not r.has("fila"):
			r["fila"] = []
		if not r.has("tropas"):
			# exército DE VERDADE, não um número abstrato: é o que permite ao
			# espião contar cabeças e ao upkeep cobrar por elas
			var base: int = int(r.get("nobres", 5)) * Dados.ri(2, 4)
			r["tropas"] = {
				"lanceiro": base * 2, "espadachim": roundi(base * 1.2),
				"arqueiro": base, "cav_leve": maxi(1, roundi(base * 0.25)),
			}
		r["forca"] = forca_de(r)
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

## `forca` deixa de ser um número solto: agora é o RESUMO do exército real.
## O resto do código (guerras, conquistas, guarnições) continua lendo forca,
## então nada quebra — só passa a refletir tropas que existem de fato.
static func forca_de(r: Dictionary) -> int:
	var t = r.get("tropas")
	if t == null:
		return int(r.get("forca", 40))
	var total := 0
	for tipo in t:
		total += int(t[tipo]) * int(Dados.TROPAS.get(tipo, {}).get("pop", 1))
	return maxi(1, total)

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
		_diz(log, "%s e %s assinaram um acordo comercial." % [a["nome"], b["nome"]])
	else:
		_diz(log, "ALIANÇA: %s e %s juram defesa mútua." % [a["nome"], b["nome"]])

# ------------------------------------------------------------
# O turno
# ------------------------------------------------------------
static func tick(state: Dictionary, log: Callable) -> void:
	inicializar(state)
	_tick_economia(state, log)
	_tick_pactos(state, log)
	_tick_opiniao(state)
	_tick_declaracoes(state, log)
	_tick_declaracao_jogador(state, log)
	_tick_ataques_jogador(state, log)
	_tick_conquistas(state, log)

## Tesouro, celeiro e madeireira rendem; o EXÉRCITO consome. Um rei NPC
## joga pelas mesmas regras do jogador: se não paga, a moral cai e os homens
## desertam. Se sobra, ele treina mais gente — na mesma fila.
static func _tick_economia(state: Dictionary, log: Callable) -> void:
	for r in state["reinos"]:
		if not vivo(r):
			continue
		# ---- renda ----
		var nobres: int = int(r.get("nobres", 5))
		# A renda tem que SUSTENTAR um exército de verdade. Calibrado contra o
		# upkeep real: um reino de 10 nobres arrecada ~350 de ouro e mantém
		# ~130 homens. Com a renda antiga (nobres × 6-14), todo reino do mapa
		# faliria em vinte meses e o mundo esvaziava sozinho.
		var renda: int = nobres * Dados.ri(25, 45)
		for p in pactos_de(state, r["id"]):
			if p["tipo"] == "comercio":
				renda = roundi(renda * 1.25)
		r["tesouro"] = int(r.get("tesouro", 0)) + renda
		r["celeiro"] = int(r.get("celeiro", 0)) + nobres * Dados.ri(20, 35)
		r["madeireira"] = int(r.get("madeireira", 0)) + nobres * Dados.ri(10, 20)

		# ---- upkeep: MESMA função que cobra do jogador ----
		var em_guerra := _em_guerra(state, r["id"])
		var custo := Economia.upkeep_de(r["tropas"], 1.6 if em_guerra else 1.0)
		var faltou := 0
		for par in [["tesouro", "ouro"], ["celeiro", "comida"], ["madeireira", "madeira"]]:
			var cofre: String = par[0]
			var chave_custo: String = par[1]
			if int(r[cofre]) >= int(custo[chave_custo]):
				r[cofre] = int(r[cofre]) - int(custo[chave_custo])
			else:
				r[cofre] = 0
				if int(custo[chave_custo]) > 0:
					faltou += 1

		# ---- moral e deserção, iguais às do jogador ----
		if faltou == 0:
			r["moral"] = clampi(int(r.get("moral", 100)) + 5, 0, 100)
		else:
			r["moral"] = clampi(int(r.get("moral", 100)) - 10 * faltou, 0, 100)
			if int(r["moral"]) <= 35:
				var perdidos := 0
				for tipo in r["tropas"]:
					var n: int = int(r["tropas"][tipo])
					var vao: int = mini(n, ceili(n * 0.12))
					r["tropas"][tipo] = n - vao
					perdidos += vao
				if perdidos > 0 and randf() < 0.35:
					_diz(log, "Sem soldo, %d homens desertaram de %s." % [perdidos, r["nome"]])

		# ---- recrutamento e melhorias ----
		_npc_treina(state, r)
		_npc_melhora(r)
		r["forca"] = forca_de(r)

## O rei NPC enfileira tropas quando tem folga no cofre — pela MESMA fila e
## pelos MESMOS tempos de treino que o jogador usa (Recrutamento.avancar_fila).
static func _npc_treina(state: Dictionary, r: Dictionary) -> void:
	var f: Array = r["fila"]
	# escolhe o que treinar pelo que falta: reino sem lança morre de cavalaria
	if f.size() < 2 and int(r["tesouro"]) > 350:
		var alvo := "lanceiro"
		var t: Dictionary = r["tropas"]
		if int(t.get("lanceiro", 0)) > int(t.get("espadachim", 0)) * 2:
			alvo = "espadachim"
		elif int(t.get("arqueiro", 0)) < int(t.get("lanceiro", 0)) / 2:
			alvo = "arqueiro"
		elif int(r["tesouro"]) > 900:
			alvo = "cav_leve"
		var qtd: int = Dados.ri(3, 8)
		var custo: int = int(Dados.TROPAS[alvo]["custo"]) * qtd
		if int(r["tesouro"]) >= custo:
			r["tesouro"] = int(r["tesouro"]) - custo
			f.append({"tipo": alvo, "restantes": qtd,
				"restante": int(Dados.TEMPO_TREINO.get(alvo, 60))})
	# um mês de treino, pelo mesmo motor do quartel do jogador
	Recrutamento.avancar_fila(f, 600,
		func(tipo): return int(Dados.TEMPO_TREINO.get(tipo, 60)),
		func(tipo): r["tropas"][tipo] = int(r["tropas"].get(tipo, 0)) + 1)

## Melhoria de equipamento também custa — e também vale para o NPC.
static func _npc_melhora(r: Dictionary) -> void:
	var nivel: int = int(r.get("equip", 0))
	if nivel >= 3:
		return
	var preco: int = 200 * (nivel + 1)
	if int(r["tesouro"]) >= preco + 400 and int(r["madeireira"]) >= 80:
		r["tesouro"] = int(r["tesouro"]) - preco
		r["madeireira"] = int(r["madeireira"]) - 80
		r["equip"] = nivel + 1

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
				_diz(log, "O pacto entre %s e %s expirou." % [ra["nome"], rb["nome"]])
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

## A opinião anda sozinha — mas não é passeio aleatório. Há PRESSÃO:
## quem disputa o mesmo mercado se estranha todo mês, e quem vê o vizinho
## ficar forte demais aprende a temê-lo. Sem essas duas forças, um dado de
## ±2 quase nunca chega aos -50 da guerra, e o mapa fica em paz eterna.
static func _tick_opiniao(state: Dictionary) -> void:
	for i in state["reinos"].size():
		for j in range(i + 1, state["reinos"].size()):
			var ra: Dictionary = state["reinos"][i]
			var rb: Dictionary = state["reinos"][j]
			if not vivo(ra) or not vivo(rb):
				continue
			var a: String = ra["id"]
			var b: String = rb["id"]
			var delta := 0
			if tem_pacto(state, a, b, "alianca"):
				delta += 3
			elif tem_pacto(state, a, b, "comercio"):
				delta += 2
			else:
				# Concorrência empurra para a guerra; complementaridade, para o
				# comércio. As duas precisam coexistir: só a primeira e o mapa
				# vira guerra de todos contra todos, sem pacto nenhum.
				var disputados := 0
				for bem in ra.get("producao", []):
					if rb.get("producao", []).has(bem):
						disputados += 1
				if disputados > 0:
					delta -= disputados          # brigam pelo mesmo mercado
				else:
					delta += 1                   # têm o que trocar
				# medo: o vizinho que cresce DEMAIS vira ameaça
				var fa := float(maxi(1, int(ra["forca"])))
				var fb := float(maxi(1, int(rb["forca"])))
				if maxf(fa, fb) / minf(fa, fb) >= 2.0:
					delta -= 1
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
			_diz(log, "GUERRA! %s marcha contra %s." % [forte["nome"], fraco["nome"]])
			# aliados são arrastados: é o que torna uma aliança perigosa
			for p in pactos_de(state, fraco["id"]):
				if p["tipo"] != "alianca":
					continue
				var aliado_id: String = p["b"] if p["a"] == fraco["id"] else p["a"]
				mudar_relacao(state, aliado_id, forte["id"], -30)
				_diz(log, "%s honra a aliança e volta-se contra %s."
					% [reino_por_id(state, aliado_id)["nome"], forte["nome"]])
			return              # uma declaração por mês, para o mapa respirar

## Rampa de elegibilidade (Parte VII, 6.4): sem terra, ou terra ainda de
## acampamento (nível < 2), o jogador não é um alvo válido. Sem isto, um
## reino hostil já no Ano 1 — antes do jogador ter chão para perder —
## poderia abrir uma guerra e a campanha morreria antes de começar.
static func _jogador_elegivel(state: Dictionary) -> bool:
	var t = state.get("terra")
	return t != null and int(t.get("nivel", 0)) >= 2

## Guerra do reino CONTRA o jogador: usa a relação do REI com o jogador
## (Dialogo.tags_de, "rei_<id>"), não `relacoes_npc` — essa nunca guarda
## "jogador" (Geopolitica.inicializar só semeia pares entre state["reinos"]).
## É a relação que o próprio jogador constrói em diálogo (insultos, ameaças,
## suborno) que decide se um rei chega a odiá-lo o bastante para marchar.
static func _tick_declaracao_jogador(state: Dictionary, log: Callable) -> void:
	if not _jogador_elegivel(state):
		return
	if state["guerras"].size() >= 3:
		return
	var Dialogo = load("res://scripts/dialogo.gd")
	for r in state["reinos"]:
		if not vivo(r):
			continue
		if _em_guerra_entre(state, r["id"], "jogador"):
			continue
		var rel: int = int(Dialogo.tags_de(state, "rei_" + r["id"])["relacao"])
		if rel > LIMIAR_GUERRA:
			continue
		if randf() > 0.15:
			continue
		state["guerras"].append({"a": r["id"], "b": "jogador", "meses": 0})
		Sinais.emitir(&"guerra_npc", {"a": r["id"], "b": "jogador"})
		_diz(log, "GUERRA! %s declara guerra contra você." % r["nome"])
		return                       # uma declaração por mês, igual às demais

## Já em guerra, o reino tenta de fato marchar — sem isto a guerra fica só
## no papel. "O JOGADOR PODE SER ATACADO. O JOGADOR NÃO PODE SER ABSORVIDO":
## quem resolve a chegada é `Marchas._resolver_chegada_contra_jogador`, que
## nunca escreve em `state["reinos"]` — só em terra/relação/vassalagem do
## jogador. Esta função só decide QUANDO a marcha parte.
const CHANCE_MARCHA_JOGADOR := 0.25

static func _tick_ataques_jogador(state: Dictionary, log: Callable) -> void:
	if not _jogador_elegivel(state):
		return
	var Marchas = load("res://scripts/marchas.gd")
	for g in state["guerras"]:
		if g["a"] != "jogador" and g["b"] != "jogador":
			continue
		var reino_id: String = g["b"] if g["a"] == "jogador" else g["a"]
		var r := reino_por_id(state, reino_id)
		if r.is_empty() or not vivo(r):
			continue
		if _marchando_contra_jogador(state, reino_id):
			continue                 # um reino não manda duas marchas de uma vez
		if randf() > CHANCE_MARCHA_JOGADOR:
			continue
		var tropas := _fatia_expedicionaria(r)
		if tropas.is_empty():
			continue
		var intencao := "cerco" if randf() < 0.5 else "saque"
		var res: Dictionary = Marchas.despachar(state, "jogador", tropas, intencao, "", reino_id)
		if bool(res.get("ok", false)) and log.is_valid():
			_diz(log, "%s reúne tropas e marcha contra suas terras." % r["nome"])

static func _marchando_contra_jogador(state: Dictionary, reino_id: String) -> bool:
	for m in state.get("marchas", []):
		if str(m.get("origem", "")) == reino_id and str(m.get("alvo", "")) == "jogador":
			return true
	return false

## O reino não manda o exército inteiro atrás do jogador — mantém o resto em
## casa, senão um vizinho oportunista aproveita a ausência (mesma lógica de
## destacamento que `Cerco._lorde_aliado` já usa para o socorro do defensor).
static func _fatia_expedicionaria(r: Dictionary) -> Dictionary:
	var fatia := {}
	for tipo in r.get("tropas", {}):
		var n: int = int(int(r["tropas"][tipo]) * 0.4)
		if n > 0:
			fatia[tipo] = n
	return fatia

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
		# O JOGADOR PODE SER ATACADO, MAS NÃO PODE SER ABSORVIDO — o
		# invariante que marchas.gd já respeitava. O reino fundado por ele
		# é uma casa dele: entra em guerra, perde tropas, mas nenhum NPC
		# resolve o mapa dele por decreto num tick mensal.
		if bool(a.get("fundado_pelo_jogador", false)) \
				or bool(b.get("fundado_pelo_jogador", false)):
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
		_diz(log, "%s CONQUISTOU %s. O equilíbrio do mundo mudou."
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

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
