# ============================================================
# CIDADÃOS NOTÁVEIS — a sociedade da sua terra, simulada barato.
#
# Não simula 200 pessoas: simula de 3 a 6 NOTÁVEIS por terra, com status
# ocultos (riqueza, ambição, lealdade). É o suficiente para o jogador sentir
# que há gente ali, e barato o bastante para caber no JSON do save.
#
# O arco: um cidadão enriquece com o crescimento da vila. Ao cruzar o limiar,
# ele decide — se for leal, jura lealdade e vira um LORDE seu, que passa a
# render imposto e tropa. Se for ambicioso e desleal, vira um rival dentro de
# casa, e a intriga que você sofre passa a vir de dentro dos seus muros.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Riqueza necessária para o cidadão bater à sua porta.
const LIMIAR_ASCENSAO := 400
## Lealdade mínima para o pedido ser um juramento, e não uma ameaça.
const LEALDADE_MINIMA := 60

static func lista(state: Dictionary) -> Array:
	if state.get("terra") == null:
		return []
	if not state["terra"].has("notaveis"):
		state["terra"]["notaveis"] = []
	return state["terra"]["notaveis"]

## CORTE OPERACIONAL — o ofício de um notável LEAL rende um efeito de verdade.
##
## Binário, não cumulativo: um ferreiro leal já é O ferreiro da vila. Dois
## ferreiros leais não fabricam ferro em dobro — a vila só tem uma forja.
## `oficio_ativo` responde "existe alguém competente nesse posto agora?",
## e é essa pergunta que economia.gd e taverna.gd fazem antes de aplicar
## qualquer bônus de corte.
static func oficio_ativo(state: Dictionary, oficio: String) -> bool:
	for n in lista(state):
		if str(n.get("oficio", "")) == oficio and int(n.get("lealdade", 0)) >= LEALDADE_MINIMA:
			return true
	return false

## O Capataz rico e desleal que estaria pronto para virar ameaça (mesmo
## limiar que `resumo()` chama de "quase rico" e "desleal") NÃO precisa
## esperar cruzar LIMIAR_ASCENSAO para ser perigoso quando a vila já está
## em felicidade crítica — ele lidera. Devolve {} se não há candidato.
static func capataz_lider(state: Dictionary) -> Dictionary:
	for n in lista(state):
		if str(n.get("oficio", "")) != "capataz" or bool(n.get("lorde", false)):
			continue
		if int(n.get("riqueza", 0)) >= LIMIAR_ASCENSAO * 0.7 and int(n.get("lealdade", 100)) < 40:
			return n
	return {}

## Lordes já jurados: é o que a UI mostra na Corte e o que rende por mês.
static func lordes(state: Dictionary) -> Array:
	var saida: Array = []
	for n in lista(state):
		if bool(n.get("lorde", false)):
			saida.append(n)
	return saida

static func _nascer(state: Dictionary) -> Dictionary:
	var genero := "m" if randf() < 0.6 else "f"
	var nome: String = Dados.rnd(Dados.NOMES_M) if genero == "m" else Dados.rnd(Dados.NOMES_F)
	return {
		"nome": nome + " " + Dados.rnd(Dados.SOBRENOMES),
		"genero": genero,
		# status OCULTOS: a UI mostra só o que o jogador poderia perceber
		"riqueza": Dados.ri(20, 90),
		"ambicao": Dados.ri(1, 10),
		"lealdade": Dados.ri(40, 70),
		"oficio": Dados.rnd(["mercador", "ferreiro", "moleiro", "taverneiro", "capataz"]),
		"lorde": false,
	}

static func tick(state: Dictionary, log: Callable) -> void:
	if state.get("terra") == null:
		return
	var t: Dictionary = state["terra"]
	var povo := lista(state)

	# a sociedade só aparece quando há vila de verdade (nível 1+)
	if int(t["nivel"]) >= 1 and povo.is_empty():
		for i in Dados.ri(3, 5):
			povo.append(_nascer(state))
		_diz(log, "Famílias notáveis começam a se destacar em %s." % t["nome"])

	for n in povo:
		if bool(n.get("lorde", false)):
			# lorde jurado rende imposto e, de vez em quando, homens
			state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + Dados.ri(8, 20)
			if randf() < 0.08:
				var q := Dados.ri(1, 3)
				state["jogador"]["tropas"]["lanceiro"] = \
					int(state["jogador"]["tropas"].get("lanceiro", 0)) + q
				_diz(log, "%s enviou %d lanceiros da própria casa." % [n["nome"], q])
			continue

		# riqueza cresce com o nível da terra e com a ambição do sujeito
		var ganho: int = roundi((int(t["nivel"]) + 1) * (1.5 + int(n["ambicao"]) * 0.6))
		if int(t["felicidade"]) < 40:
			ganho = roundi(ganho * 0.5)          # vila infeliz não gera riqueza
		n["riqueza"] = int(n["riqueza"]) + ganho

		# lealdade acompanha como a vila está sendo governada
		var d := 0
		if int(t["felicidade"]) > 60:
			d += 2
		elif int(t["felicidade"]) < 35:
			d -= 4
		if int(t["alimento"]) <= 0:
			d -= 5                                # fome corrói primeiro os ricos
		if int(state["jogador"].get("crueldade", 0)) >= 3:
			d -= 2
		n["lealdade"] = clampi(int(n["lealdade"]) + d, 0, 100)

		if int(n["riqueza"]) < LIMIAR_ASCENSAO:
			continue

		# a hora da decisão
		if int(n["lealdade"]) >= LEALDADE_MINIMA:
			n["lorde"] = true
			state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 10
			Sinais.emitir(&"cidadao_ascendeu", {"nome": n["nome"], "riqueza": int(n["riqueza"])})
			_diz(log, "%s, o %s, enriqueceu e jurou lealdade a você. Agora é seu lorde."
				% [n["nome"], n["oficio"]])
		elif state.get("evento_pendente") == null:
			# rico e desleal: vira ameaça interna, e o jogador precisa decidir
			state["evento_pendente"] = {"tipo": "notavel_ambicioso", "nome": n["nome"]}
			n["riqueza"] = int(n["riqueza"]) - 120     # gastou comprando apoio
			_diz(log, "%s ficou rico demais e olha o seu assento com fome." % n["nome"])

## Resolve o evento do notável ambicioso (chamado por jogo.gd).
static func resolver_ambicioso(state: Dictionary, nome: String, escolha: String,
		log: Callable) -> String:
	var alvo: Dictionary = {}
	for n in lista(state):
		if n["nome"] == nome:
			alvo = n
			break
	if alvo.is_empty():
		return "O homem já não está mais na vila."
	match escolha:
		"comprar":
			# compra a lealdade: caro, mas ganha um lorde
			var preco: int = 250
			if int(state["jogador"]["ouro"]) < preco:
				return "Você não tem os %d de ouro que ele espera." % preco
			state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - preco
			alvo["lealdade"] = clampi(int(alvo["lealdade"]) + 35, 0, 100)
			_diz(log, "Você comprou a lealdade de %s por %d de ouro." % [nome, preco])
			return "Ouro compra joelhos dobrados — por enquanto."
		"exilar":
			lista(state).erase(alvo)
			state["terra"]["felicidade"] = clampi(int(state["terra"]["felicidade"]) - 10, 0, 100)
			_diz(log, "%s foi exilado. A vila viu, e não gostou." % nome)
			return "A casa dele foi esvaziada antes do amanhecer."
		_:
			# ignorar sai barato agora e caro depois
			alvo["ambicao"] = mini(10, int(alvo["ambicao"]) + 2)
			state["terra"]["pressao"] = float(state["terra"].get("pressao", 0.0)) + 15.0
			_diz(log, "Você ignorou %s. Ele sorriu, e isso foi pior." % nome)
			return "Ele se curva. O sorriso não alcança os olhos."

## Resumo para a UI da Corte.
static func resumo(state: Dictionary) -> Dictionary:
	var povo := lista(state)
	var ricos := 0
	var desleais := 0
	for n in povo:
		if int(n["riqueza"]) >= LIMIAR_ASCENSAO * 0.7 and not bool(n.get("lorde", false)):
			ricos += 1
		if int(n["lealdade"]) < 40:
			desleais += 1
	return {"total": povo.size(), "lordes": lordes(state).size(),
		"quase_ricos": ricos, "desleais": desleais}

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
