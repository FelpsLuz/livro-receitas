# ============================================================
# CERCO — atrito, não um clique.
#
# Chegar aos muros não resolve nada. O cerco dura SEIS FASES, uma a cada 30
# unidades do relógio (30 segundos reais, já que o Timer da cena anda 1 por
# segundo). Cada fase cobra o dobro do upkeep normal do exército acampado,
# derruba a moral, e tem 3 em 10 de trazer um lorde aliado do defensor pelas
# costas do sitiante.
#
# Aguentar as seis fases EFETIVA o cerco: os defensores entram na batalha de
# três fases com metade dos status. É a recompensa por bancar o atrito — e
# a razão de um cerco valer mais que um saque, apesar de custar muito mais.
#
# Sair antes (sem ouro, sem comida, sem moral) é fugir: o exército vira para
# casa sem nada. Toda a máquina mora no dicionário da marcha, então atravessa
# save/load como o resto.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Combate = preload("res://scripts/combate.gd")
const Economia = preload("res://scripts/economia.gd")
const Sinais = preload("res://scripts/sinais.gd")
const Estacoes = preload("res://scripts/estacoes.gd")
const Comandantes = preload("res://scripts/comandantes.gd")

## Seis fases, uma a cada 30 do relógio unificado.
const FASES := 6
const MINUTOS_POR_FASE := 30
## Acampado longe de casa, o exército consome o dobro.
const MULTIPLICADOR_UPKEEP := 2.0
## Chance, por fase, de um lorde aliado do defensor cair em cima do sitiante.
const CHANCE_REFORCO := 0.30
## Abaixo disto a tropa se recusa a continuar e levanta acampamento.
const MORAL_MINIMA := 25
## O prêmio: os defensores lutam com metade dos status.
const DEBUFF_DEFENSOR := 0.5

static func iniciar(m: Dictionary, minuto_atual: int) -> void:
	m["cerco"] = {
		"fase": 0, "moral": 100, "efetivado": false,
		"gasto": {"ouro": 0, "comida": 0, "madeira": 0},
		"reforcos": 0, "abandonado": false,
	}
	m["proxima_fase"] = minuto_atual + MINUTOS_POR_FASE

## Uma fase de cerco. Devolve o que aconteceu para virar log/relatório.
static func avancar_fase(state: Dictionary, m: Dictionary, log: Callable) -> Dictionary:
	var c: Dictionary = m["cerco"]
	c["fase"] = int(c["fase"]) + 1
	var ev := {"tipo": "cerco_fase", "marcha": m["id"], "fase": int(c["fase"]),
		"reforco": false, "abandonou": false, "efetivado": false}

	# ---- 1. o custo de ficar parado no campo inimigo ----
	# o dobro por estar acampado, vezes a estação: no inverno são QUATRO
	# vezes o upkeep normal, e é isso que mata cerco de dezembro
	var fator := MULTIPLICADOR_UPKEEP * Estacoes.fator_cerco(state)
	var cmd: Dictionary = Comandantes.por_id(state, str(m.get("comandante", "")))
	var custo := Economia.upkeep_de(m["tropas"], fator)
	# um quartel-mestre competente é a diferença entre campanha e fome
	custo["comida"] = roundi(int(custo["comida"]) * Comandantes.fator_comida_cerco(cmd))
	var pagou := _cobrar(state, custo, c)
	ev["inverno"] = Estacoes.e_inverno(state)
	if not pagou.is_empty():
		c["moral"] = int(c["moral"]) - 18 * pagou.size()
		if log.is_valid():
			log.call("Cerco (fase %d): falta %s no acampamento."
				% [int(c["fase"]), " e ".join(pagou)])
	else:
		# tédio e lama cobram sozinhos; a neve cobra mais
		c["moral"] = int(c["moral"]) - maxi(1,
			(7 if Estacoes.e_inverno(state) else 4) - Comandantes.moral_cerco(cmd))

	# ---- 2. reforços do defensor pelas costas ----
	if randf() < CHANCE_REFORCO:
		c["reforcos"] = int(c["reforcos"]) + 1
		ev["reforco"] = true
		var socorro := _lorde_aliado(state, m["alvo"])
		var antes := Combate.total_homens(m["tropas"])
		# eles atacam o sitiante, que está de costas para o campo
		Combate.resolver_assalto(socorro, m["tropas"], 1.0, 0.85, "cerco")
		ev["perdidos"] = antes - Combate.total_homens(m["tropas"])
		c["moral"] = int(c["moral"]) - 9
		if log.is_valid():
			log.call("Cerco (fase %d): um lorde aliado atacou seu acampamento — %d baixas."
				% [int(c["fase"]), int(ev["perdidos"])])

	c["moral"] = clampi(int(c["moral"]), 0, 100)
	ev["moral"] = int(c["moral"])

	# ---- 3. o cerco aguenta? ----
	if Combate.total_homens(m["tropas"]) == 0:
		ev["abandonou"] = true
		c["abandonado"] = true
		return ev
	if int(c["moral"]) <= MORAL_MINIMA:
		ev["abandonou"] = true
		c["abandonado"] = true
		if log.is_valid():
			log.call("O cerco a %s foi levantado: a tropa não aguentou mais." % m["alvo"])
		Sinais.emitir(&"cerco_abandonado", {"marcha": m["id"], "fase": int(c["fase"])})
		return ev

	if int(c["fase"]) >= FASES:
		c["efetivado"] = true
		ev["efetivado"] = true
		if log.is_valid():
			log.call("CERCO EFETIVADO em %s: os muros estão famintos." % m["alvo"])
		Sinais.emitir(&"cerco_efetivado", {"marcha": m["id"]})
	return ev

## Cobra do jogador o que o acampamento consumiu. Devolve o que FALTOU.
static func _cobrar(state: Dictionary, custo: Dictionary, c: Dictionary) -> Array:
	var faltou: Array = []
	var g: Dictionary = c["gasto"]
	if int(state["jogador"]["ouro"]) >= int(custo["ouro"]):
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - int(custo["ouro"])
		g["ouro"] = int(g["ouro"]) + int(custo["ouro"])
	else:
		state["jogador"]["ouro"] = 0
		faltou.append("soldo")
	var t = state.get("terra")
	if t == null:
		# sem terra, comida e madeira vêm da estrada — e a estrada é ingrata
		if int(custo["comida"]) > 0:
			faltou.append("comida")
		return faltou
	for par in [["alimento", "comida"], ["madeira", "madeira"]]:
		var cofre: String = par[0]
		var chave: String = par[1]
		if int(custo[chave]) <= 0:
			continue
		if int(t[cofre]) >= int(custo[chave]):
			t[cofre] = int(t[cofre]) - int(custo[chave])
			g[chave] = int(g[chave]) + int(custo[chave])
		else:
			t[cofre] = 0
			faltou.append(chave)
	return faltou

## Quem vem socorrer o sitiado: um aliado do reino atacado. Sem aliado, é a
## milícia local que aparece — menor, mas ainda custa sangue.
static func _lorde_aliado(state: Dictionary, alvo: String) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	for p in Geopolitica.pactos_de(state, alvo):
		if p["tipo"] != "alianca":
			continue
		var outro: String = p["b"] if p["a"] == alvo else p["a"]
		var r: Dictionary = Geopolitica.reino_por_id(state, outro)
		if r.is_empty() or not Geopolitica.vivo(r):
			continue
		# o aliado manda um destacamento, não o exército inteiro
		var envio := {}
		for tipo in r.get("tropas", {}):
			var n: int = int(int(r["tropas"][tipo]) * 0.2)
			if n > 0:
				envio[tipo] = n
		if not envio.is_empty():
			return envio
	return {"lanceiro": Dados.ri(8, 18), "arqueiro": Dados.ri(4, 10)}

## Resumo para a UI acompanhar o cerco fase a fase.
static func progresso(m: Dictionary) -> Dictionary:
	var c = m.get("cerco")
	if c == null:
		return {}
	return {"fase": int(c["fase"]), "de": FASES, "moral": int(c["moral"]),
		"efetivado": bool(c["efetivado"]), "reforcos": int(c["reforcos"]),
		"gasto": c["gasto"].duplicate()}
