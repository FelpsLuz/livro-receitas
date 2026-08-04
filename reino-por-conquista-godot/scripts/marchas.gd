# ============================================================
# MARCHAS — o exército deixa de teleportar.
#
# Enviar um ataque não resolve nada na hora: as tropas SAEM do seu bolso,
# entram na estrada, correm risco de emboscada, chegam, lutam, e só então
# começam a voltar. O saque só entra no cofre quando os sobreviventes
# cruzam o seu portão de novo.
#
# Toda a marcha mora no `state` — um Timer é nó de cena e o save é um
# Dictionary, então quem salvasse no meio da estrada perderia o exército no
# ar. O relógio (relogio.gd) só empurra os prazos.
#
# A máquina de estados é uma String em `fase`: ida → volta → (some da lista).
# Por ser texto num dicionário, atravessa save/load sem uma linha extra.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Rotas = preload("res://scripts/rotas.gd")
const Combate = preload("res://scripts/combate.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Enquanto marcha, o exército testa a sorte uma vez por dia de estrada.
const MINUTOS_POR_DIA := 20

# ------------------------------------------------------------
# Tempo
# ------------------------------------------------------------
## Minutos por campo da tropa MAIS LENTA — e a mais lenta é a de MAIOR `vel`,
## porque `vel` é minutos POR campo. Dividir aqui inverteria o jogo: o
## Explorador (9) viraria a unidade mais lenta e a Cavalaria Pesada voaria.
static func minutos_por_campo(tropas: Dictionary) -> int:
	var pior := 0
	for tipo in tropas:
		if int(tropas[tipo]) <= 0:
			continue
		var d = Dados.TROPAS.get(tipo)
		if d != null:
			pior = maxi(pior, int(d.get("vel", 20)))
	return pior

## Duração da viagem em minutos de jogo.
static func duracao(tropas: Dictionary, distancia: int) -> int:
	var mpc := minutos_por_campo(tropas)
	if mpc == 0 or distancia <= 0:
		return 0
	return maxi(1, distancia * mpc)

## Estimativa para a UI ANTES de despachar — é o que o jogador vê ao escolher
## o alvo: "Império · 3 dias de marcha · risco alto".
static func estimar(state: Dictionary, alvo: String, tropas: Dictionary) -> Dictionary:
	var origem: String = "jogador"
	var rota := Rotas.caminho(origem, alvo)
	var dur := duracao(tropas, int(rota["distancia"]))
	return {
		"alvo": alvo, "rota": rota, "distancia": int(rota["distancia"]),
		"minutos": dur, "perigo": float(rota["perigo"]),
		"trajeto": Rotas.descrever(state, rota),
		"risco": rotulo_de_risco(float(rota["perigo"])),
	}

static func rotulo_de_risco(p: float) -> String:
	if p <= 0.0:
		return "nenhum"
	if p < 0.12:
		return "baixo"
	if p < 0.25:
		return "moderado"
	return "alto"

static func lista(state: Dictionary) -> Array:
	if not state.has("marchas"):
		state["marchas"] = []
	return state["marchas"]

# ------------------------------------------------------------
# Despacho
# ------------------------------------------------------------
## Manda o exército à estrada. As tropas saem do bolso do jogador AGORA —
## exército em marcha não defende a própria casa, e é isso que torna atacar
## uma decisão e não um clique de graça.
static func despachar(state: Dictionary, alvo: String, tropas: Dictionary,
		intencao: String) -> Dictionary:
	if intencao != "saque" and intencao != "cerco":
		return {"ok": false, "msg": "Intenção inválida."}
	var soma := 0
	for tipo in tropas:
		var q: int = int(tropas[tipo])
		if q <= 0:
			continue
		soma += q
		if q > int(state["jogador"]["tropas"].get(tipo, 0)):
			return {"ok": false, "msg": "Você não tem tantos %s."
				% Dados.TROPAS.get(tipo, {}).get("nome", tipo)}
	if soma <= 0:
		return {"ok": false, "msg": "Nenhuma tropa selecionada."}

	var limpo := {}
	for tipo in tropas:
		if int(tropas[tipo]) > 0:
			limpo[tipo] = int(tropas[tipo])
			state["jogador"]["tropas"][tipo] = int(state["jogador"]["tropas"][tipo]) - int(tropas[tipo])

	var est := estimar(state, alvo, limpo)
	var agora: int = int(state.get("minuto", 0))
	var m := {
		"id": "m%d_%d" % [agora, lista(state).size()],
		"alvo": alvo, "tropas": limpo, "intencao": intencao, "fase": "ida",
		"distancia": int(est["distancia"]), "perigo": float(est["perigo"]),
		"duracao": int(est["minutos"]), "chega_em": agora + int(est["minutos"]),
		"proximo_teste": agora + MINUTOS_POR_DIA,
		"saque": {}, "trajeto": str(est["trajeto"]),
	}
	lista(state).append(m)
	Sinais.emitir(&"marcha_partiu", m)
	return {"ok": true, "marcha": m,
		"msg": "%d homens partem para %s. Chegada em %s." % [
			soma, Rotas.nome_do(state, alvo), _texto_dias(int(est["minutos"]))]}

## Chamar de volta um exército que ainda está de ida. A volta custa o que
## já foi andado — recuar não é de graça.
static func recolher(state: Dictionary, id: String) -> Dictionary:
	for m in lista(state):
		if m["id"] != id:
			continue
		if m["fase"] != "ida":
			return {"ok": false, "msg": "Esse exército já está voltando."}
		var agora: int = int(state.get("minuto", 0))
		var andado: int = maxi(1, int(m["duracao"]) - (int(m["chega_em"]) - agora))
		m["fase"] = "volta"
		m["chega_em"] = agora + andado
		m["proximo_teste"] = agora + MINUTOS_POR_DIA
		return {"ok": true, "msg": "Ordem de recuo enviada. Voltam em %s."
			% _texto_dias(andado)}
	return {"ok": false, "msg": "Exército não encontrado."}

# ------------------------------------------------------------
# O avanço
# ------------------------------------------------------------
## Empurra todas as marchas. Devolve a lista de eventos (emboscadas,
## batalhas, chegadas) para a UI narrar.
static func avancar(state: Dictionary, minutos: int, log: Callable = Callable()) -> Array:
	var eventos: Array = []
	var agora: int = int(state.get("minuto", 0))
	var vivas: Array = []
	for m in lista(state):
		# --- perigos da estrada, um teste por dia percorrido ---
		# `while`: avançar um mês de uma vez tem que rolar os ~30 dias, não um
		while int(m["proximo_teste"]) <= agora and int(m["proximo_teste"]) <= int(m["chega_em"]):
			m["proximo_teste"] = int(m["proximo_teste"]) + MINUTOS_POR_DIA
			if float(m["perigo"]) <= 0.0:
				continue
			# o perigo do caminho é para a viagem inteira; por dia é uma fatia
			var dias: float = maxf(1.0, float(m["duracao"]) / float(MINUTOS_POR_DIA))
			if randf() < float(m["perigo"]) / dias:
				var ev := _emboscada(state, m, log)
				eventos.append(ev)
				if Combate.total_homens(m["tropas"]) == 0:
					break

		if Combate.total_homens(m["tropas"]) == 0:
			# aniquilados na estrada: o saque se perde com eles
			if log.is_valid():
				log.call("Nenhum homem da marcha para %s voltou."
					% Rotas.nome_do(state, m["alvo"]))
			eventos.append({"tipo": "perdida", "marcha": m["id"]})
			continue

		if agora < int(m["chega_em"]):
			vivas.append(m)
			continue

		match m["fase"]:
			"ida":
				var rel := _resolver_chegada(state, m, log)
				eventos.append(rel)
				if Combate.total_homens(m["tropas"]) > 0:
					m["fase"] = "volta"
					# encadeia do prazo VENCIDO, não de "agora": avançar vários
					# meses de uma vez não pode alongar a volta
					m["chega_em"] = int(m["chega_em"]) + int(m["duracao"])
					m["proximo_teste"] = int(m["chega_em"]) - int(m["duracao"]) + MINUTOS_POR_DIA
					vivas.append(m)
				elif log.is_valid():
					log.call("O exército enviado a %s foi destruído."
						% Rotas.nome_do(state, m["alvo"]))
			"volta":
				eventos.append(_resolver_retorno(state, m, log))
	state["marchas"] = vivas
	return eventos

## Emboscada na estrada. Sem o jogador presente, resolve-se sozinha e vira
## relatório — bandidos levam parte do saque quando há saque para levar.
static func _emboscada(state: Dictionary, m: Dictionary, log: Callable) -> Dictionary:
	var bandidos := Combate.exercito_inimigo(1 if float(m["perigo"]) < 0.2 else 2)
	var antes := Combate.total_homens(m["tropas"])
	var rel := Combate.resolver_assalto(bandidos["tropas"], m["tropas"], 1.0, 1.0, "saque")
	var perdidos := antes - Combate.total_homens(m["tropas"])
	var roubado := {}
	if not m["saque"].is_empty() and randf() < 0.5:
		for g in m["saque"]:
			var leva: int = int(int(m["saque"][g]) * 0.35)
			if leva > 0:
				roubado[g] = leva
				m["saque"][g] = int(m["saque"][g]) - leva
	if log.is_valid():
		if perdidos > 0 or not roubado.is_empty():
			log.call("Emboscada na estrada para %s: %d homens caídos%s." % [
				Rotas.nome_do(state, m["alvo"]), perdidos,
				" e parte da carga levada" if not roubado.is_empty() else ""])
		else:
			log.call("Bandidos tentaram a sorte contra sua coluna e fugiram.")
	var ev := {"tipo": "emboscada", "marcha": m["id"], "perdidos": perdidos,
		"roubado": roubado, "fases": rel["fases"]}
	Sinais.emitir(&"marcha_emboscada", ev)
	return ev

## Chegada ao alvo: o combate de três fases que já existe roda aqui.
static func _resolver_chegada(state: Dictionary, m: Dictionary, log: Callable) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var alvo: String = m["alvo"]
	var guarnicao := _guarnicao_de(state, alvo)
	var bonus := Combate.bonus_de(state, m["tropas"])
	var rel := Combate.resolver_assalto(m["tropas"], guarnicao, bonus, 1.0, m["intencao"])
	rel["tipo"] = "batalha"
	rel["marcha"] = m["id"]
	rel["contexto"] = "%s a %s" % [
		"Saque" if m["intencao"] == "saque" else "Cerco", Rotas.nome_do(state, alvo)]

	var reino: Dictionary = Geopolitica.reino_por_id(state, alvo)
	if m["intencao"] == "saque":
		m["saque"] = _colher(state, alvo, m["tropas"])
		rel["saque"] = m["saque"].duplicate()
		if not reino.is_empty():
			# saque dói no cofre e na opinião, mas não é casus belli formal
			var Dialogo = load("res://scripts/dialogo.gd")
			Dialogo.mudar_relacao(state, "rei_" + alvo, -20, "saque")
	elif rel["vitoria"] and not reino.is_empty():
		# cerco vencido: quebra o exército do reino e abala a diplomacia
		reino["forca"] = maxi(5, int(int(reino.get("forca", 50)) * 0.45))
		reino["tesouro"] = int(int(reino.get("tesouro", 0)) * 0.6)
		state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 20
		var Dialogo2 = load("res://scripts/dialogo.gd")
		Dialogo2.mudar_relacao(state, "rei_" + alvo, -45, "cerco")
		if int(reino["forca"]) <= 8:
			reino["dominado_por"] = "jogador"
			if state["jogador"]["rei_de"] == "":
				state["jogador"]["rei_de"] = alvo
			rel["conquistou"] = true
	rel["resumo"] = Combate.montar_relatorio({
		"contexto": rel["contexto"], "intencao": m["intencao"], "fases": rel["fases"],
		"baixas_jogador": rel["baixas_atacante"], "baixas_inimigo": rel["baixas_defensor"],
		"vivos_jogador": Combate.total_homens(m["tropas"]),
		"vivos_inimigo": Combate.total_homens(guarnicao),
		"vitoria": rel["vitoria"], "debandada": ""})
	if log.is_valid():
		log.call(rel["resumo"].split("\n")[0] + (" VITÓRIA." if rel["vitoria"] else " Repelido."))
	Sinais.emitir(&"marcha_chegou", rel)
	return rel

## Volta para casa: tropas ao bolso, saque ao cofre.
static func _resolver_retorno(state: Dictionary, m: Dictionary, log: Callable) -> Dictionary:
	var voltaram := 0
	for tipo in m["tropas"]:
		var q: int = int(m["tropas"][tipo])
		if q <= 0:
			continue
		state["jogador"]["tropas"][tipo] = int(state["jogador"]["tropas"].get(tipo, 0)) + q
		voltaram += q
	var trouxe := {}
	for g in m["saque"]:
		var q2: int = int(m["saque"][g])
		if q2 <= 0:
			continue
		if g == "ouro":
			state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + q2
		else:
			state["carga"][g] = int(state["carga"].get(g, 0)) + q2
		trouxe[g] = q2
	if log.is_valid():
		if trouxe.is_empty():
			log.call("%d homens voltaram de %s de mãos vazias."
				% [voltaram, Rotas.nome_do(state, m["alvo"])])
		else:
			log.call("%d homens voltaram de %s com a carga."
				% [voltaram, Rotas.nome_do(state, m["alvo"])])
	var ev := {"tipo": "retorno", "marcha": m["id"], "homens": voltaram, "carga": trouxe}
	Sinais.emitir(&"marcha_voltou", ev)
	return ev

# ------------------------------------------------------------
# Alvo
# ------------------------------------------------------------
## Guarnição de um alvo, derivada da força que a geopolítica já mantém.
## Um reino forte tem muro de espadachins e lanças; um reino quebrado, quase nada.
static func _guarnicao_de(state: Dictionary, alvo: String) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var reino: Dictionary = Geopolitica.reino_por_id(state, alvo)
	if reino.is_empty():
		# Reino sem Rei: terra de ninguém, defendida por quem sobrou
		return {"campones": Dados.ri(10, 20), "barbaro": Dados.ri(4, 10)}
	var f: int = int(reino.get("forca", 40))
	return {
		"lanceiro": maxi(1, roundi(f * 0.5)),
		"espadachim": maxi(1, roundi(f * 0.3)),
		"arqueiro": maxi(1, roundi(f * 0.25)),
		"cav_leve": maxi(0, roundi(f * 0.06)),
	}

## O que há para saquear no alvo, e o que sai de lá.
static func _colher(state: Dictionary, alvo: String, sobreviventes: Dictionary) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var reino: Dictionary = Geopolitica.reino_por_id(state, alvo)
	var cofre := {}
	if reino.is_empty():
		cofre = {"trigo": Dados.ri(30, 80), "madeira": Dados.ri(20, 60)}
	else:
		cofre["ouro"] = int(int(reino.get("tesouro", 0)) * 0.4)
		for bem in reino.get("producao", []):
			cofre[bem] = Dados.ri(40, 120)
	var levado := Combate.colher_saque(sobreviventes, cofre)
	if not reino.is_empty() and levado.has("ouro"):
		reino["tesouro"] = maxi(0, int(reino.get("tesouro", 0)) - int(levado["ouro"]))
	return levado

# ------------------------------------------------------------
static func _texto_dias(minutos: int) -> String:
	var d: float = minutos / float(MINUTOS_POR_DIA)
	if d < 1.0:
		return "menos de um dia"
	if d < 2.0:
		return "1 dia"
	return "%d dias" % roundi(d)

## Resumo das marchas para a UI da aba de Exército.
static func em_transito(state: Dictionary) -> Array:
	var agora: int = int(state.get("minuto", 0))
	var saida: Array = []
	for m in lista(state):
		saida.append({
			"id": m["id"], "alvo": m["alvo"], "fase": m["fase"],
			"intencao": m["intencao"], "homens": Combate.total_homens(m["tropas"]),
			"faltam": maxi(0, int(m["chega_em"]) - agora),
			"texto_faltam": _texto_dias(maxi(0, int(m["chega_em"]) - agora)),
			"carga": m["saque"].duplicate(), "trajeto": str(m.get("trajeto", "")),
		})
	return saida
