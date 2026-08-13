# ============================================================
# LIVRO-RAZÃO — o mês deixa de ser uma caixa-preta
#
# O terceiro clique de "Passar o dia" roda vinte e um passos e o jogador via
# só o resultado, nunca a causa. Jogo de gerenciamento não morre porque o
# jogador perde: morre porque ele não entende POR QUE perdeu e conclui que é
# aleatório. Este arquivo existe para matar esse diagnóstico.
#
# O projeto já tinha a regra escrita — "a virada nunca pode ser surpresa" —
# e a aplicava só no TEXTO do botão, que troca para "Fechar o mês". O
# conteúdo da virada continuava chegando sem aviso.
#
# ---- três entregas de uma estrutura só ----
#
#   1. RELATÓRIO ITEMIZADO. Cada escrita nas moedas passa por `registrar`, e
#      no fim do mês o jogador lê linha por linha de onde veio e para onde
#      foi cada moeda.
#   2. PREVISÃO. `previsao()` monta a mesma conta ANTES do clique, sem tocar
#      no estado — soldo, tributo, colheita e aluguel do mês que vem.
#   3. TELEMETRIA. `csv()` despeja a série mensal inteira para balancear com
#      dado em vez de sensação.
#
# ---- por que estático, e não autoload ----
#
# `sinais.gd` já resolveu este problema no projeto e a solução vale aqui: as
# suítes rodam com `--script`, onde autoload NÃO é registrado, e uma classe
# que dependesse do nó global não compilaria nos testes. Aqui o estado mora
# no `state`, que é o único lugar que atravessa save, load e teste igual.
#
# ---- o que fica no save, e o que não fica ----
#
# `livro` guarda os lançamentos DO MÊS CORRENTE — some na virada, depois de
# virar relatório. `livro_meses` guarda um RESUMO por mês fechado: doze
# números, não trezentos lançamentos. Uma partida de dez anos custa 120
# linhas de resumo no save, e é isso que a telemetria precisa.
# ============================================================
extends RefCounted

## As moedas que o livro segue. Ficam fora `relação` (é por NPC, não uma
## conta só) e `dia` (não se ganha nem se perde: chega três por mês).
const MOEDAS := ["ouro", "alimento", "madeira", "moral", "renome", "honra"]

## Quantos meses de histórico o save carrega. Dez anos de partida.
const MESES_GUARDADOS := 120

static func _lancamentos(state: Dictionary) -> Array:
	if not (state.get("livro") is Array):
		state["livro"] = []
	return state["livro"]

static func meses(state: Dictionary) -> Array:
	if not (state.get("livro_meses") is Array):
		state["livro_meses"] = []
	return state["livro_meses"]

## REGISTRA UM LANÇAMENTO. É a única função que os sistemas chamam.
##
## `delta` zero é descartado de propósito: um relatório com trinta linhas de
## "±0" esconde as cinco que importam. E o motivo é obrigatório na prática —
## uma linha sem motivo é exatamente a caixa-preta que este arquivo veio
## abrir.
static func registrar(state: Dictionary, sistema: String, moeda: String,
		delta: int, motivo: String) -> void:
	if delta == 0 or state.is_empty():
		return
	_lancamentos(state).append({
		"sistema": sistema, "moeda": moeda, "delta": delta, "motivo": motivo,
		"dia": int(state.get("dia", 1)),
	})

## O que aconteceu no mês corrente, agrupado por moeda.
##
## Devolve {moeda: {"entrou": n, "saiu": n, "saldo": n, "linhas": [...]}} —
## as linhas já vêm somadas por (sistema, motivo), senão trinta cobranças de
## aluguel diário viram trinta linhas de 5 de ouro.
static func do_mes(state: Dictionary) -> Dictionary:
	var por_moeda := {}
	for l in _lancamentos(state):
		var m := str(l["moeda"])
		if not por_moeda.has(m):
			por_moeda[m] = {"entrou": 0, "saiu": 0, "saldo": 0, "linhas": []}
		var d := int(l["delta"])
		var bloco: Dictionary = por_moeda[m]
		bloco["saldo"] = int(bloco["saldo"]) + d
		if d > 0:
			bloco["entrou"] = int(bloco["entrou"]) + d
		else:
			bloco["saiu"] = int(bloco["saiu"]) - d
		# agrupa por motivo: o jogador quer "aluguel do armazém −45", não
		# nove linhas de −5
		var achou := false
		for linha in bloco["linhas"]:
			if str(linha["motivo"]) == str(l["motivo"]):
				linha["delta"] = int(linha["delta"]) + d
				linha["vezes"] = int(linha["vezes"]) + 1
				achou = true
				break
		if not achou:
			bloco["linhas"].append({"sistema": str(l["sistema"]),
				"motivo": str(l["motivo"]), "delta": d, "vezes": 1})
	# maior impacto primeiro: o jogador lê as duas de cima e já sabe o mês
	for m in por_moeda:
		(por_moeda[m]["linhas"] as Array).sort_custom(
			func(a, b): return abs(int(a["delta"])) > abs(int(b["delta"])))
	return por_moeda

## Fecha o mês: guarda o resumo, devolve o relatório e zera os lançamentos.
## Chamado por `Jogo.passar_mes`, no fim de tudo.
static func fechar_mes(state: Dictionary) -> Dictionary:
	var rel := do_mes(state)
	var resumo := {"mes": int(state.get("mes", 1)), "ano": int(state.get("ano", 1))}
	for m in MOEDAS:
		var b: Dictionary = rel.get(m, {})
		resumo[m] = int(b.get("saldo", 0))
	resumo["ouro_cofre"] = int(state["jogador"].get("ouro", 0))
	resumo["homens"] = 0
	for t in state["jogador"].get("tropas", {}):
		resumo["homens"] += int(state["jogador"]["tropas"][t])
	var h := meses(state)
	h.append(resumo)
	while h.size() > MESES_GUARDADOS:
		h.pop_front()
	state["livro"] = []
	return rel

# ============================================================
# PREVISÃO — a mesma conta, ANTES do clique
#
# Nenhuma linha daqui escreve no estado. Ela remonta o que `passar_mes` vai
# cobrar usando os MESMOS leitores puros que a economia usa, para não haver
# duas verdades: se `imposto_mensal` mudar, a previsão muda junto.
#
# O que ela NÃO promete, e o texto na tela precisa dizer: eventos, guerra
# declarada por NPC, colheita perdida por invasão. A previsão é a conta
# ordinária do mês, não uma profecia.
# ============================================================
static func previsao(state: Dictionary) -> Dictionary:
	var Economia = load("res://scripts/economia.gd")
	var Armazem = load("res://scripts/armazem.gd")
	var Vassalagem = load("res://scripts/vassalagem.gd")
	var Cidadaos = load("res://scripts/cidadaos.gd")
	var linhas: Array = []
	var j: Dictionary = state["jogador"]
	var t = state.get("terra")

	# ---- entra ----
	if t != null:
		var imp: int = Economia.imposto_mensal(state)
		if imp > 0:
			linhas.append({"moeda": "ouro", "delta": imp, "motivo": "Imposto da vila"})
		var col: int = Economia.colheita_mensal(state)
		if col > 0:
			linhas.append({"moeda": "alimento", "delta": col, "motivo": "Colheita"})
		var len_: int = Economia.lenha_mensal(state)
		if len_ > 0:
			linhas.append({"moeda": "madeira", "delta": len_, "motivo": "Madeireira"})
		# lorde jurado rende imposto próprio — a faixa média das duas pontas
		var lordes := 0
		for n in Cidadaos.lista_ro(state):
			if bool(n.get("lorde", false)) and not bool(n.get("capturado", false)):
				lordes += 1
		if lordes > 0:
			linhas.append({"moeda": "ouro", "delta": lordes * 14,
				"motivo": "Imposto dos lordes (aproximado)"})

	# ---- sai ----
	var up: Dictionary = Economia.upkeep_de(j["tropas"],
		2.0 - Economia.fator_gestao(state) if t != null else 1.0,
		Cidadaos.oficio_ativo(state, "ferreiro"))
	if int(up["ouro"]) > 0:
		linhas.append({"moeda": "ouro", "delta": -int(up["ouro"]),
			"motivo": "Soldo do exército"})
	if int(up["comida"]) > 0:
		linhas.append({"moeda": "alimento", "delta": -int(up["comida"]),
			"motivo": "O exército come"})
	if int(up["madeira"]) > 0:
		linhas.append({"moeda": "madeira", "delta": -int(up["madeira"]),
			"motivo": "Manutenção de armas"})
	# o aluguel é DIÁRIO: o que falta do mês, não o mês inteiro
	var Jogo = load("res://scripts/jogo.gd")
	var dias_restantes: int = maxi(0, Jogo.DIAS_POR_MES - int(state.get("dia", 1)) + 1)
	var aluguel: int = Armazem.aluguel_diario(state) * dias_restantes
	if aluguel > 0:
		linhas.append({"moeda": "ouro", "delta": -aluguel,
			"motivo": "Aluguel do armazém (%d dia%s)" % [dias_restantes,
				"" if dias_restantes == 1 else "s"]})
	var vs: Dictionary = Vassalagem.resumo(state)
	if bool(vs.get("vassalo", false)):
		var trib: int = int(vs.get("tributo_estimado", 0))
		if trib > 0:
			linhas.append({"moeda": "ouro", "delta": -trib,
				"motivo": "Tributo a %s" % str(vs.get("nome", "seu suserano"))})
	for a in state.get("clas_ativos", []):
		var soldo_cla: int = int(a.get("soldo", 0))
		if soldo_cla > 0:
			linhas.append({"moeda": "ouro", "delta": -soldo_cla,
				"motivo": "Soldo do clã"})
	var informantes: int = (state.get("informantes", []) as Array).size()
	if informantes > 0:
		linhas.append({"moeda": "ouro", "delta": -25 * informantes,
			"motivo": "Informantes (%d)" % informantes})

	# ---- fecha por moeda ----
	var saldo := {}
	for l in linhas:
		var m := str(l["moeda"])
		saldo[m] = int(saldo.get(m, 0)) + int(l["delta"])
	linhas.sort_custom(func(a, b): return abs(int(a["delta"])) > abs(int(b["delta"])))
	return {"linhas": linhas, "saldo": saldo,
		"ouro_depois": int(j["ouro"]) + int(saldo.get("ouro", 0))}

# ============================================================
# TELEMETRIA
#
# Uma linha por mês fechado. Serve para responder com número as perguntas
# que hoje se responde com sensação: em que mês o soldo passa o imposto? o
# celeiro cresce ou encolhe numa campanha? quantos meses de ouro guardado
# custa a primeira terra?
# ============================================================
static func csv(state: Dictionary) -> String:
	var l: Array = ["ano;mes;ouro_saldo;alimento_saldo;madeira_saldo;moral_saldo;renome_saldo;honra_saldo;ouro_cofre;homens"]
	for m in meses(state):
		l.append("%d;%d;%d;%d;%d;%d;%d;%d;%d;%d" % [
			int(m.get("ano", 0)), int(m.get("mes", 0)),
			int(m.get("ouro", 0)), int(m.get("alimento", 0)),
			int(m.get("madeira", 0)), int(m.get("moral", 0)),
			int(m.get("renome", 0)), int(m.get("honra", 0)),
			int(m.get("ouro_cofre", 0)), int(m.get("homens", 0))])
	return "\n".join(l)

## Grava o CSV em `user://`, que é a pasta do jogador em qualquer plataforma.
static func exportar_csv(state: Dictionary) -> String:
	var caminho := "user://livro_%s.csv" % str(state["jogador"].get("nome", "saga")) \
		.to_lower().replace(" ", "_")
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(csv(state))
	f.close()
	return ProjectSettings.globalize_path(caminho)
