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
const Cerco = preload("res://scripts/cerco.gd")
const Comandantes = preload("res://scripts/comandantes.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")

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

## O dict de tropas REAL por trás de uma origem — jogador ou um reino NPC.
## Referência, não cópia: despachar() precisa DEDUZIR dali de verdade.
static func _tropas_de(state: Dictionary, origem: String) -> Dictionary:
	if origem == "jogador":
		return state["jogador"]["tropas"]
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var reino: Dictionary = Geopolitica.reino_por_id(state, origem)
	if reino.is_empty():
		return {}
	if not reino.has("tropas"):
		reino["tropas"] = {}
	return reino["tropas"]

## Estimativa para a UI ANTES de despachar — é o que o jogador vê ao escolher
## o alvo: "Império · 3 dias de marcha · risco alto".
static func estimar(state: Dictionary, alvo: String, tropas: Dictionary,
		origem: String = "jogador") -> Dictionary:
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
## Manda o exército à estrada. As tropas saem do bolso da ORIGEM AGORA —
## exército em marcha não defende a própria casa, e é isso que torna atacar
## uma decisão e não um clique de graça.
##
## `origem` por padrão é "jogador" — todo chamador existente (a UI, os
## testes) continua funcionando sem tocar numa linha. É a Parte VII do
## patch consolidado (Estágio 6, "marcha NPC → terra do jogador"): agora um
## reino também pode ser a origem, mirando "jogador" como alvo.
static func despachar(state: Dictionary, alvo: String, tropas: Dictionary,
		intencao: String, comandante: String = "", origem: String = "jogador") -> Dictionary:
	if intencao != "saque" and intencao != "cerco":
		return {"ok": false, "msg": "Intenção inválida."}
	var fonte := _tropas_de(state, origem)
	var soma := 0
	for tipo in tropas:
		var q: int = int(tropas[tipo])
		if q <= 0:
			continue
		soma += q
		if q > int(fonte.get(tipo, 0)):
			return {"ok": false, "msg": "Você não tem tantos %s."
				% Dados.TROPAS.get(tipo, {}).get("nome", tipo)}
	if soma <= 0:
		return {"ok": false, "msg": "Nenhuma tropa selecionada."}

	var limpo := {}
	for tipo in tropas:
		if int(tropas[tipo]) > 0:
			limpo[tipo] = int(tropas[tipo])
			fonte[tipo] = int(fonte[tipo]) - int(tropas[tipo])

	var est := estimar(state, alvo, limpo, origem)
	var agora: int = int(state.get("minuto", 0))
	var m := {
		"id": "m%d_%d" % [agora, lista(state).size()],
		"alvo": alvo, "origem": origem, "tropas": limpo, "intencao": intencao, "fase": "ida",
		"distancia": int(est["distancia"]), "perigo": float(est["perigo"]),
		"duracao": int(est["minutos"]), "chega_em": agora + int(est["minutos"]),
		"proximo_teste": agora + MINUTOS_POR_DIA,
		"saque": {}, "trajeto": str(est["trajeto"]),
		"comandante": comandante,
	}
	# batedor experiente enxerga a emboscada antes dela acontecer — só existe
	# para o jogador: Comandantes.disponiveis() só lista gente do lado dele
	var cmd := Comandantes.por_id(state, comandante) if origem == "jogador" else {}
	if not cmd.is_empty():
		m["perigo"] = float(m["perigo"]) * Comandantes.fator_perigo(cmd)
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
			var cap := Comandantes.capturar(state,
				Comandantes.por_id(state, str(m.get("comandante", ""))), log)
			if int(cap.get("preso", 0)) > 0:
				var Jogo = load("res://scripts/jogo.gd")
				Jogo.prender(state, int(cap["preso"]), log)
			eventos.append({"tipo": "perdida", "marcha": m["id"], "comandante": cap})
			continue

		# ---- cerco em andamento: uma fase a cada 30 do relógio ----
		if m["fase"] == "cerco":
			if _rodar_cerco(state, m, agora, eventos, log):
				vivas.append(m)
			continue

		if agora < int(m["chega_em"]):
			vivas.append(m)
			continue

		var minha: bool = str(m.get("origem", "jogador")) == "jogador"
		match m["fase"]:
			"ida":
				# CERCO não resolve na chegada: vira atrito de seis fases.
				# Saque continua sendo bate-e-corre.
				if m["intencao"] == "cerco":
					m["fase"] = "cerco"
					# o cerco começa no instante em que a marcha CHEGOU, não
					# "agora": um salto grande de tempo (passar_mes = 600) tem
					# que gastar o resto do mês nos muros, e não parado
					Cerco.iniciar(m, int(m["chega_em"]))
					if log.is_valid():
						if minha:
							log.call("Seu exército acampou diante de %s. O cerco começou."
								% Rotas.nome_do(state, m["alvo"]))
						else:
							log.call("Um exército de %s acampou diante de suas terras. O cerco começou."
								% Rotas.nome_do(state, m["origem"]))
					eventos.append({"tipo": "cerco_iniciado", "marcha": m["id"]})
					# e as fases que já couberam nesse salto rodam JÁ
					if _rodar_cerco(state, m, agora, eventos, log):
						vivas.append(m)
					continue
				var rel := _resolver_qualquer_chegada(state, m, log)
				eventos.append(rel)
				if Combate.total_homens(m["tropas"]) > 0:
					m["fase"] = "volta"
					# encadeia do prazo VENCIDO, não de "agora": avançar vários
					# meses de uma vez não pode alongar a volta
					m["chega_em"] = int(m["chega_em"]) + int(m["duracao"])
					m["proximo_teste"] = int(m["chega_em"]) - int(m["duracao"]) + MINUTOS_POR_DIA
					vivas.append(m)
				else:
					# morreu diante dos muros: o comandante é CAPTURADO,
					# igual a quando o exército some na estrada (só existe
					# para o jogador — marcha de reino não tem comandante seu)
					var cap2 := Comandantes.capturar(state,
						Comandantes.por_id(state, str(m.get("comandante", ""))), log)
					if int(cap2.get("preso", 0)) > 0:
						var Jogo2 = load("res://scripts/jogo.gd")
						Jogo2.prender(state, int(cap2["preso"]), log)
					if log.is_valid():
						if minha:
							log.call("O exército enviado a %s foi destruído."
								% Rotas.nome_do(state, m["alvo"]))
						else:
							log.call("O exército de %s foi destruído diante de suas terras."
								% Rotas.nome_do(state, m["origem"]))
			"volta":
				eventos.append(_resolver_retorno(state, m, log))
	state["marchas"] = vivas
	return eventos

## Roda as fases de cerco que couberem até `agora`. Devolve true se a marcha
## continua sitiando (false = já mudou de fase e foi tratada aqui).
static func _rodar_cerco(state: Dictionary, m: Dictionary, agora: int,
		eventos: Array, log: Callable) -> bool:
	# `while`: passar um mês de uma vez roda as seis fases, não uma
	while agora >= int(m["proxima_fase"]):
		m["proxima_fase"] = int(m["proxima_fase"]) + Cerco.MINUTOS_POR_FASE
		var evf := Cerco.avancar_fase(state, m, log)
		eventos.append(evf)
		if bool(evf["abandonou"]):
			if Combate.total_homens(m["tropas"]) > 0:
				_virar_para_casa(m, agora)       # levanta acampamento
				return true
			return false                          # exército acabou nos muros
		if bool(evf["efetivado"]):
			# os muros caem com METADE dos status: a recompensa do atrito
			eventos.append(_resolver_qualquer_chegada(state, m, log, Cerco.DEBUFF_DEFENSOR))
			if Combate.total_homens(m["tropas"]) > 0:
				_virar_para_casa(m, agora)
				return true
			return false
	return true

static func _virar_para_casa(m: Dictionary, agora: int) -> void:
	m["fase"] = "volta"
	m["chega_em"] = agora + int(m["duracao"])
	m["proximo_teste"] = agora + MINUTOS_POR_DIA

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

## Despacha para o resolvedor certo conforme a ORIGEM da marcha — jogador
## atacando (caminho de sempre, intocado) ou reino atacando o jogador
## (Parte VII do patch consolidado, Estágio 6).
static func _resolver_qualquer_chegada(state: Dictionary, m: Dictionary, log: Callable,
		debuff_defensor: float = 1.0) -> Dictionary:
	if str(m.get("origem", "jogador")) == "jogador":
		return _resolver_chegada(state, m, log, debuff_defensor)
	return _resolver_chegada_contra_jogador(state, m, log, debuff_defensor)

## O que um reino invasor consegue carregar das terras do jogador — MESMA
## função de saque que _colher usa para reinos-alvo, só que a fonte é o
## bolso do jogador. 40% do ouro disponível, como um reino só arrisca 40%
## do próprio tesouro por visita (_colher espelha o mesmo número).
static func _colher_do_jogador(state: Dictionary, sobreviventes: Dictionary) -> Dictionary:
	var cofre := {"ouro": int(int(state["jogador"]["ouro"]) * 0.4)}
	for g in state.get("carga", {}):
		if int(state["carga"][g]) > 0:
			cofre[g] = int(state["carga"][g])
	var levado := Combate.colher_saque(sobreviventes, cofre)
	if levado.has("ouro"):
		state["jogador"]["ouro"] = maxi(0, int(state["jogador"]["ouro"]) - int(levado["ouro"]))
	for g in levado:
		if g != "ouro":
			state["carga"][g] = maxi(0, int(state["carga"].get(g, 0)) - int(levado[g]))
	return levado

## Chegada de uma marcha de RETALIAÇÃO NPC contra o jogador — Parte VII do
## patch consolidado. A regra que resolve os dois furos da Q5 (nenhuma NPC
## podia marchar, e geopolitica.gd pulava de propósito qualquer guerra do
## jogador para não deletá-lo pela rotina de conquista):
##
##   O JOGADOR PODE SER ATACADO. O JOGADOR NÃO PODE SER ABSORVIDO.
##
## Cerco vencido pelo atacante derruba UM degrau da terra — nunca
## `dominado_por`, que continua reservado para conquista entre reinos. É
## essa distinção que faz o skip de geopolitica.gd:357 continuar certo: ele
## protege contra ABSORÇÃO, não contra guerra — e esta função nunca toca em
## `state["reinos"]`, então não há como violar isso por acidente.
static func _resolver_chegada_contra_jogador(state: Dictionary, m: Dictionary, log: Callable,
		debuff_defensor: float = 1.0) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var Dialogo = load("res://scripts/dialogo.gd")
	var reino_id: String = str(m["origem"])
	var reino: Dictionary = Geopolitica.reino_por_id(state, reino_id)
	var nome_reino: String = str(reino.get("nome", reino_id))
	var guarnicao := _guarnicao_do_jogador(state)
	var bonus_atacante := 1.0 + int(reino.get("equip", 0)) * 0.15
	var rel := Combate.resolver_assalto(m["tropas"], guarnicao, bonus_atacante, debuff_defensor, m["intencao"])
	rel["tipo"] = "batalha"
	rel["marcha"] = m["id"]
	rel["contexto"] = "%s de %s contra suas terras" % [
		"Saque" if m["intencao"] == "saque" else "Cerco", nome_reino]

	if m["intencao"] == "saque":
		m["saque"] = _colher_do_jogador(state, m["tropas"])
		rel["saque"] = m["saque"].duplicate()
		if log.is_valid():
			log.call("%s saqueou suas terras." % nome_reino)
	elif rel["vitoria"]:
		# `rel["vitoria"]` aqui é do ATACANTE (o reino) — resolver_assalto
		# chama de "vitória" quando o DEFENSOR (a guarnição do jogador) é
		# zerada. É o reino que venceu, e é isso que os dois ramos abaixo tratam.
		if state["terra"] != null and int(state["terra"]["nivel"]) > 0:
			var nivel_antigo: int = int(state["terra"]["nivel"])
			state["terra"]["nivel"] = nivel_antigo - 1
			if log.is_valid():
				log.call("%s derrubou os muros — sua terra caiu para %s."
					% [nome_reino, Dados.NIVEIS_TERRA[nivel_antigo - 1]["nome"]])
		# vitória esmagadora pode impor vassalagem — sem custo de renome,
		# porque não foi o jogador quem escolheu se ajoelhar
		if str(state["jogador"].get("suserano", "")) == "" and randf() < 0.4:
			state["jogador"]["suserano"] = reino_id
			state["jogador"]["meses_vassalo"] = 0
			# a guerra que trouxe essa marcha até aqui se encerra — um vassalo
			# não continua em guerra com o próprio suserano
			var vivas: Array = []
			for g in state["guerras"]:
				if (g["a"] == reino_id and g["b"] == "jogador") \
						or (g["b"] == reino_id and g["a"] == "jogador"):
					continue
				vivas.append(g)
			state["guerras"] = vivas
			Dialogo.mudar_relacao(state, "rei_" + reino_id, 10, "vassalagem imposta")
			if log.is_valid():
				log.call("Derrotado, você jura lealdade a %s." % nome_reino)
		Dialogo.mudar_relacao(state, "rei_" + reino_id, -20, "invasão")
	else:
		# o jogador REPELIU a invasão: o invasor recua enfraquecido, e
		# defender a própria casa rende tanto renome quanto atacar fora
		reino["forca"] = maxi(5, int(int(reino.get("forca", 40)) * 0.75))
		state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 15
		if state["terra"] != null:
			state["terra"]["felicidade"] = clampi(int(state["terra"]["felicidade"]) + 10, 0, 100)
		if log.is_valid():
			log.call("Suas terras resistiram ao ataque de %s." % nome_reino)

	rel["resumo"] = Combate.montar_relatorio({
		"contexto": rel["contexto"], "intencao": m["intencao"], "fases": rel["fases"],
		"baixas_jogador": rel["baixas_defensor"], "baixas_inimigo": rel["baixas_atacante"],
		"vivos_jogador": Combate.total_homens(guarnicao),
		"vivos_inimigo": Combate.total_homens(m["tropas"]),
		"vitoria": not rel["vitoria"], "debandada": ""})
	if log.is_valid():
		log.call(rel["resumo"].split("\n")[0] + (" Repelido." if not rel["vitoria"] else " Suas terras sofreram."))
	Sinais.emitir(&"marcha_chegou", rel)
	return rel

## Chegada ao alvo: o combate de três fases que já existe roda aqui.
static func _resolver_chegada(state: Dictionary, m: Dictionary, log: Callable,
		debuff_defensor: float = 1.0) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var alvo: String = m["alvo"]
	var guarnicao := _guarnicao_de(state, alvo)
	var bonus := Combate.bonus_de(state, m["tropas"])
	var cmd: Dictionary = Comandantes.por_id(state, str(m.get("comandante", "")))
	bonus *= Comandantes.bonus_ataque(cmd)
	var rel := Combate.resolver_assalto(m["tropas"], guarnicao, bonus, debuff_defensor, m["intencao"])
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
	var origem: String = str(m.get("origem", "jogador"))
	var voltaram := 0
	var fonte := _tropas_de(state, origem)
	for tipo in m["tropas"]:
		var q: int = int(m["tropas"][tipo])
		if q <= 0:
			continue
		fonte[tipo] = int(fonte.get(tipo, 0)) + q
		voltaram += q
	var trouxe := {}
	for g in m["saque"]:
		var q2: int = int(m["saque"][g])
		if q2 <= 0:
			continue
		if origem == "jogador":
			if g == "ouro":
				state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + q2
			else:
				state["carga"][g] = int(state["carga"].get(g, 0)) + q2
		else:
			# a economia de reino NPC não guarda bens genericamente — só
			# tesouro, celeiro e madeireira (Geopolitica.inicializar). O
			# saque vira valor de tesouro qualquer que seja o bem, que é a
			# mesma simplificação que o reino já faz da própria renda.
			var Geopolitica = load("res://scripts/geopolitica.gd")
			var reino: Dictionary = Geopolitica.reino_por_id(state, origem)
			if not reino.is_empty():
				reino["tesouro"] = int(reino.get("tesouro", 0)) + q2
		trouxe[g] = q2
	if log.is_valid():
		if origem == "jogador":
			if trouxe.is_empty():
				log.call("%d homens voltaram de %s de mãos vazias."
					% [voltaram, Rotas.nome_do(state, m["alvo"])])
			else:
				log.call("%d homens voltaram de %s com a carga."
					% [voltaram, Rotas.nome_do(state, m["alvo"])])
		else:
			log.call("O exército de %s voltou de suas terras." % Rotas.nome_do(state, origem))
	var ev := {"tipo": "retorno", "marcha": m["id"], "homens": voltaram, "carga": trouxe}
	Sinais.emitir(&"marcha_voltou", ev)
	return ev

# ------------------------------------------------------------
# Alvo
# ------------------------------------------------------------
## Guarnição do PRÓPRIO JOGADOR — a Parte VII do patch consolidado (6.2).
## Até aqui a escada de fortificação (Seção 4) só valia número num painel,
## porque nenhum exército marchava contra a casa do jogador para ela
## defender. Agora vale: cada degrau de terra soma milícia de muralha — não
## sai do bolso, não pesa upkeep, é o que os moradores pegam em armas quando
## os portões se fecham. E os lordes jurados somam alguns lanceiros da
## própria casa (a mesma ideia de Cidadaos.tick, aqui como presença
## permanente e não como evento raro).
static func _guarnicao_do_jogador(state: Dictionary) -> Dictionary:
	var g: Dictionary = state["jogador"]["tropas"].duplicate(true)
	if state.get("terra") != null:
		var extra: int = int(state["terra"]["nivel"]) * 8
		if extra > 0:
			g["campones"] = int(g.get("campones", 0)) + extra
	for lorde in Cidadaos.lordes(state):
		if not bool(lorde.get("capturado", false)):
			g["lanceiro"] = int(g.get("lanceiro", 0)) + 4
	return g

## Guarnição de um alvo, derivada da força que a geopolítica já mantém.
## Um reino forte tem muro de espadachins e lanças; um reino quebrado, quase nada.
static func _guarnicao_de(state: Dictionary, alvo: String) -> Dictionary:
	if alvo == "jogador":
		return _guarnicao_do_jogador(state)
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var reino: Dictionary = Geopolitica.reino_por_id(state, alvo)
	if reino.is_empty():
		# Reino sem Rei: terra de ninguém, defendida por quem sobrou
		return {"campones": Dados.ri(10, 20), "barbaro": Dados.ri(4, 10)}
	# o reino tem exército DE VERDADE desde o upkeep global: a guarnição é
	# uma cópia dele, para a batalha não alterar o original antes da hora
	var t = reino.get("tropas")
	if t != null and not t.is_empty():
		return t.duplicate(true)
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
			"cerco": Cerco.progresso(m),
		})
	return saida
