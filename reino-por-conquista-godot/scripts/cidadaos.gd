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

## A MESMA LISTA, SEM CRIAR NADA.
##
## `lista()` inicializa `terra["notaveis"]` por preguiça, o que é certo para
## quem vai mexer nela e errado para quem só quer olhar: a previsão do
## Livro-Razão passou a chamá-la e virou uma função de leitura que escrevia
## no estado. O teste que exige a previsão pura pegou isso na hora.
##
## Leitura que escreve é leitura que surpreende — e o ponto do Livro-Razão é
## exatamente acabar com surpresa.
static func lista_ro(state: Dictionary) -> Array:
	if state.get("terra") == null:
		return []
	var n = state["terra"].get("notaveis")
	return n if n is Array else []

## CORTE OPERACIONAL — o ofício de um notável LEAL rende um efeito de verdade.
##
## Binário, não cumulativo: um ferreiro leal já é O ferreiro da vila. Dois
## ferreiros leais não fabricam ferro em dobro — a vila só tem uma forja.
## `oficio_ativo` responde "existe alguém competente nesse posto agora?",
## e é essa pergunta que economia.gd e taverna.gd fazem antes de aplicar
## qualquer bônus de corte.
static func oficio_ativo(state: Dictionary, oficio: String) -> bool:
	for n in lista_ro(state):
		if str(n.get("oficio", "")) == oficio and int(n.get("lealdade", 0)) >= LEALDADE_MINIMA:
			return true
	return false

## O Capataz rico e desleal que estaria pronto para virar ameaça (mesmo
## limiar que `resumo()` chama de "quase rico" e "desleal") NÃO precisa
## esperar cruzar LIMIAR_ASCENSAO para ser perigoso quando a vila já está
## em felicidade crítica — ele lidera. Devolve {} se não há candidato.
static func capataz_lider(state: Dictionary) -> Dictionary:
	for n in lista_ro(state):
		if str(n.get("oficio", "")) != "capataz" or bool(n.get("lorde", false)):
			continue
		if int(n.get("riqueza", 0)) >= LIMIAR_ASCENSAO * 0.7 and int(n.get("lealdade", 100)) < 40:
			return n
	return {}

## Lordes já jurados: é o que a UI mostra na Corte e o que rende por mês.
static func lordes(state: Dictionary) -> Array:
	var saida: Array = []
	for n in lista_ro(state):
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

## A PRESSÃO DA VILA — o número que subia e ninguém lia.
##
## `resolver_ambicioso` soma 15 de pressão toda vez que o jogador ignora um
## cidadão ambicioso, com o texto "ele sorriu, e isso foi pior". Mecanicamente
## era MELHOR: só a ambição do sujeito subia, e a pressão ia para um campo
## que nenhuma linha do projeto consultava. Havia até um sinal `pressao_alta`
## declarado, sem emissor e sem ouvinte.
##
## Agora ela é lida todo mês, e o desenho é este:
##
##   · abaixo de 40 ela esfria sozinha (−8/mês). Uma vila que passou por um
##     mês difícil e foi bem tratada esquece.
##   · de 40 a 69 já custa: o povo murmura e a felicidade cai devagar.
##   · a partir de 70 os notáveis mandam uma EXIGÊNCIA. É evento, não
##     rolagem escondida: o jogador escolhe ceder ou peitar.
##
## O teto de 100 existe para a pressão não virar dívida impagável — o jogo já
## tem `_tick_ruina` para isso, e dois relógios de derrota competindo é um a
## mais.
const PRESSAO_EXIGENCIA := 70.0
const PRESSAO_MAX := 100.0
const PRESSAO_ALIVIO := 8.0

static func pressao(state: Dictionary) -> float:
	if state.get("terra") == null:
		return 0.0
	return clampf(float(state["terra"].get("pressao", 0.0)), 0.0, PRESSAO_MAX)

static func _tick_pressao(state: Dictionary, log: Callable) -> void:
	var t: Dictionary = state["terra"]
	var p := pressao(state)
	if p < 40.0:
		# esfria sozinha, mas nunca abaixo de zero
		t["pressao"] = maxf(0.0, p - PRESSAO_ALIVIO)
		return
	if p < PRESSAO_EXIGENCIA:
		t["felicidade"] = clampi(int(t["felicidade"]) - 2, 0, 100)
		_diz(log, "Os notáveis de %s conversam baixo quando você passa." % t["nome"])
		t["pressao"] = maxf(0.0, p - 3.0)
		return
	# ---- a exigência ----
	# Não é um dado rolado às escondidas: vira evento, e o jogador decide.
	# Ceder custa ouro e alivia; peitar mantém o cofre e cobra felicidade.
	t["pressao"] = minf(PRESSAO_MAX, p)
	if state.get("evento_pendente") == null:
		var preco: int = maxi(60, roundi(p * 4.0))
		state["evento_pendente"] = {
			"tipo": "exigencia_notaveis",
			"titulo": "Os notáveis exigem",
			"texto": "As famílias que enriqueceram em %s vieram juntas, e não vieram pedir. Querem voz nas contas da vila, e trouxeram uma cifra: %d de ouro em obras que levem os nomes deles.\n\nJá foram ignoradas antes. Desta vez estão contando quantos homens cada uma pode armar." % [t["nome"], preco],
			"preco": preco,
			"opcoes": ["Ceder às exigências", "Mandar que voltem ao trabalho"],
		}
		Sinais.emitir(&"pressao_alta", {"pressao": p, "preco": preco})
		_diz(log, "Os notáveis de %s exigem voz nas contas." % t["nome"])

## Resolve a exigência. `ceder` gasta ouro e zera a pressão; peitar mantém o
## cofre, derruba felicidade e deixa a pressão no teto — o problema volta.
static func resolver_exigencia(state: Dictionary, ceder: bool,
		log: Callable = Callable()) -> Dictionary:
	var t: Dictionary = state.get("terra")
	if t == null:
		return {"ok": false, "msg": "Sem terra, sem notáveis."}
	var ev: Dictionary = state.get("evento_pendente", {})
	var preco: int = int(ev.get("preco", 120)) if ev != null else 120
	state["evento_pendente"] = null
	if ceder:
		var pago: int = mini(preco, int(state["jogador"]["ouro"]))
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - pago
		t["pressao"] = 0.0
		t["felicidade"] = clampi(int(t["felicidade"]) + 6, 0, 100)
		_diz(log, "As obras começam, e os nomes deles vão na pedra.")
		return {"ok": true, "cedeu": true, "custo": pago,
			"msg": "Você cedeu: %d de ouro em obras. A vila respira." % pago}
	t["pressao"] = PRESSAO_MAX
	t["felicidade"] = clampi(int(t["felicidade"]) - 12, 0, 100)
	for n in lista(state):
		if not bool(n.get("lorde", false)):
			n["ambicao"] = mini(10, int(n.get("ambicao", 5)) + 1)
	_diz(log, "Você mandou que voltassem ao trabalho. Eles voltaram — calados.")
	return {"ok": true, "cedeu": false,
		"msg": "Você peitou os notáveis. Eles não esqueceram."}

static func tick(state: Dictionary, log: Callable) -> void:
	if state.get("terra") == null:
		return
	var t: Dictionary = state["terra"]
	var povo := lista(state)
	_tick_pressao(state, log)

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
	for n in lista_ro(state):
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
