# ============================================================
# O AÇO — o relógio que faz o sandbox virar corrida
#
# O mundo deste jogo anda sem o jogador, e isso é uma qualidade rara. Mas ele
# não vem ATRÁS dele. Não havia relógio de pressão nem condição de fim em
# lugar nenhum do mapa: os seis reinos se cutucavam num equilíbrio morno e a
# partida podia durar para sempre sem nada apertar. Sandbox sem antagonista
# não afunda em dificuldade — afunda em tédio, que é pior.
#
# ---- o desenho, e por que ele é barato ----
#
# Não é um sistema novo de guerra. É UM reino NPC que recebe um multiplicador
# crescente no tique econômico que já existe, mais uma linha de rumor na
# crônica em marcos escolhidos. Toda a maquinaria de marcha, cerco, conquista
# e vassalagem já está escrita e testada: o Aço não traz regras próprias, ele
# entra nas regras que existem com o polegar na balança.
#
# É o mesmo princípio do resto desta rodada — ligar o que já existe.
#
# ---- o relógio ----
#
# ANO 1-2   silêncio. Rumor de porto, de navio estranho, de moeda que
#           ninguém reconhece. Nada acontece mecanicamente.
# ANO 3     a Forja Estrangeira aparece: o reino escolhido começa a crescer
#           acima da curva. +25% de renda e de recrutamento.
# ANO 5     as vilas de fronteira começam a cair. +60%, e ele declara guerra
#           com mais frequência.
# ANO 7     o Aço marcha. +120%, e o mundo inteiro sabe.
#
# Quem é o Aço: o reino NPC mais RICO no fim do ano 2 — não um sorteio, e não
# um reino fixo. Assim a ameaça nasce de como a partida correu, cada saga tem
# um antagonista diferente, e o jogador que passou dois anos enriquecendo um
# vizinho por comércio descobre que criou o próprio carrasco.
#
# ---- a saída ----
#
# O Aço não é invencível e não deve ser: ele é um PRAZO. Quem conquista o
# continente antes do ano 7 nunca o vê marchar; quem funda uma casa e a
# fortifica pode segurá-lo; quem passou sete anos comerciando morre com o
# cofre cheio. É isso que transforma "eu jogo mais um mês" em "eu tenho
# quanto tempo?".
#
# ============================================================
# OS DENTES — porque buff mais anúncio não é ameaça
#
# A primeira versão disto era cenário: um número subindo num reino distante e
# uma linha na crônica. Nada no desenho fazia o Aço vir na direção do jogador,
# e a resposta mais barata ao relógio central da partida era identificar o
# reino mais rico no ano 2 e comprar relação 60 com ele — abrigo, portão
# aberto, ameaça desligada por diplomacia de tostão. Um relógio que não anda
# na sua direção é decoração de parede.
#
# Três dentes, e nenhum deles é maquinaria nova:
#
# 1. CRUELDADE DE REINO. Cada degrau dá 3, 5 e 7 de crueldade ao Aço. O
#    sistema do medo já sabia o que fazer com esse número — só não sabia
#    lê-lo do outro lado da mesa. Consequência imediata e de graça: o teto de
#    relação fecha, e a partir do segundo degrau ninguém faz aliança com o
#    Aço. A saída pela amizade morre sozinha, sem uma regra escrita para ela.
#
# 2. PACTO ROMPIDO. Quem cresce assim não precisa mais dos amigos que tinha.
#    A cada degrau o Aço rasga um pacto — e o antigo aliado descobre no mesmo
#    mês, de graça, pela maquinaria de relação que já existe.
#
# 3. ULTIMATO DE TRIBUTO. É o dente que morde o jogador. A cada degrau o Aço
#    cobra tributo do continente inteiro, jogador incluso. Os NPCs decidem na
#    hora pelo cofre e pelo exército: o fraco paga, o forte recusa. O jogador
#    escolhe — pagar sangra o cofre no pior momento possível, recusar é
#    guerra no degrau seguinte.
#
# A recusa não cobra nada HOJE, e é isso que a torna uma decisão: o preço
# chega dois anos depois, quando o Aço está 60% mais forte do que estava
# quando você disse não.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Os degraus, em ANOS. Cada um é um marco anunciado e um multiplicador.
const DEGRAUS := [
	{"ano": 3, "fator": 1.25, "crueldade": 3, "tributo": 400,
	 "nome": "A Forja Estrangeira",
	 "aviso": "Chegam notícias de uma casa que compra ferro em quantidade absurda e não vende nada. Os ferreiros dizem que o aço deles dobra sem quebrar."},
	{"ano": 5, "fator": 1.60, "crueldade": 5, "tributo": 900,
	 "nome": "As Vilas da Fronteira",
	 "aviso": "Três vilas de fronteira mudaram de bandeira em dois meses. Quem voltou de lá fala de linhas que não quebram e de flechas que não passam."},
	{"ano": 7, "fator": 2.20, "crueldade": 7, "tributo": 1800,
	 "nome": "O Aço Marcha",
	 "aviso": "Não é mais rumor. As colunas saíram, e o continente inteiro sabe para onde vão. Quem tem muro, que suba nele."},
]

## Antes do primeiro degrau o mundo é normal — mas não é silencioso.
const RUMORES := [
	"Um navio de casco escuro ancorou ao norte e não desceu carga nenhuma.",
	"Apareceu moeda estrangeira nas feiras. Ninguém sabe de que casa é o selo.",
	"Um mercador jura ter visto uma lâmina que corta elmo como quem corta pão.",
	"Os ferreiros do continente estão comprando carvão a preço de ouro. Alguém pagou mais.",
]

static func _ficha(state: Dictionary) -> Dictionary:
	if not (state.get("aco") is Dictionary):
		state["aco"] = {"reino": "", "degrau": 0, "ultimo_rumor": 0}
	var f: Dictionary = state["aco"]
	# saves anteriores aos dentes não conhecem estes campos
	if not f.has("recusou"):
		f["recusou"] = 0        # em qual degrau o jogador disse não
	if not f.has("pagou"):
		f["pagou"] = 0          # em qual degrau o jogador pagou
	if not f.has("marchou"):
		f["marchou"] = false    # o Aço já cobrou a recusa?
	return f

## Quem é o Aço. Vazio até o fim do ano 2, quando o mais rico é escolhido.
static func reino_id(state: Dictionary) -> String:
	return str(_ficha(state).get("reino", ""))

static func degrau(state: Dictionary) -> int:
	return int(_ficha(state).get("degrau", 0))

## O multiplicador que o tique econômico dos NPCs aplica a ESTE reino.
## Um para todos os outros — é uma linha só no `_tick_economia`.
static func fator(state: Dictionary, id: String) -> float:
	if id == "" or id != reino_id(state):
		return 1.0
	var d := degrau(state)
	if d <= 0:
		return 1.0
	return float(DEGRAUS[mini(d, DEGRAUS.size()) - 1]["fator"])

## O nome do degrau atual, para a interface. Vazio antes do ano 3.
static func nome_do_degrau(state: Dictionary) -> String:
	var d := degrau(state)
	if d <= 0:
		return ""
	return str(DEGRAUS[mini(d, DEGRAUS.size()) - 1]["nome"])

## Quantos meses faltam para o próximo degrau. −1 quando já chegou ao fim.
static func meses_ate_proximo(state: Dictionary) -> int:
	var d := degrau(state)
	if d >= DEGRAUS.size():
		return -1
	var ano_alvo: int = int(DEGRAUS[d]["ano"])
	return maxi(0, (ano_alvo - int(state.get("ano", 1))) * 12
		- int(state.get("mes", 1)) + 1)

## ESCOLHE O ANTAGONISTA: o reino NPC mais rico, medido no fim do ano 2.
##
## Não é sorteio nem reino fixo. A ameaça nasce de como a partida correu —
## e o jogador que passou dois anos enriquecendo um vizinho por pacto de
## comércio descobre que criou o próprio carrasco.
static func _escolher(state: Dictionary) -> String:
	var melhor := ""
	var maior := -1
	for r in state.get("reinos", []):
		if str(r.get("dominado_por", "")) != "" or bool(r.get("fundado_pelo_jogador", false)):
			continue
		var peso: int = int(r.get("tesouro", 0)) + int(r.get("forca", 0)) * 4
		if peso > maior:
			maior = peso
			melhor = str(r["id"])
	return melhor

## Roda uma vez por mês, dentro do tique da geopolítica.
static func tick(state: Dictionary, log: Callable = Callable()) -> void:
	var f := _ficha(state)
	var ano: int = int(state.get("ano", 1))

	# ---- ano 1 e 2: só rumor, e mesmo assim raro ----
	if str(f["reino"]) == "":
		if ano >= 3:
			f["reino"] = _escolher(state)
		else:
			# um rumor a cada quatro meses, para não virar ruído
			var absoluto: int = ano * 12 + int(state.get("mes", 1))
			if absoluto - int(f.get("ultimo_rumor", 0)) >= 4:
				f["ultimo_rumor"] = absoluto
				_diz(log, Dados.rnd(RUMORES))
			return

	# o Aço pode ter caído: se alguém o conquistou, a ameaça acabou e a
	# partida ganhou de volta o seu tempo — é uma vitória de verdade
	var alvo: Dictionary = {}
	for r in state.get("reinos", []):
		if str(r["id"]) == str(f["reino"]):
			alvo = r
	if alvo.is_empty() or str(alvo.get("dominado_por", "")) != "":
		if int(f["degrau"]) > 0:
			_diz(log, "A casa que forjava o aço caiu. O continente respira — e ninguém sabe por quanto tempo.")
			Sinais.emitir(&"aco_caiu", {"reino": str(f["reino"])})
		alvo_limpar_crueldade(state, str(f["reino"]))
		f["reino"] = ""
		f["degrau"] = 0
		f["recusou"] = 0
		f["pagou"] = 0
		f["marchou"] = false
		return

	# ---- sobe de degrau quando o ano chega ----
	var d: int = int(f["degrau"])
	while d < DEGRAUS.size() and ano >= int(DEGRAUS[d]["ano"]):
		d += 1
		f["degrau"] = d
		var marco: Dictionary = DEGRAUS[d - 1]
		_diz(log, "%s — %s" % [str(marco["nome"]), str(marco["aviso"])])
		Sinais.emitir(&"aco_avancou", {"degrau": d, "reino": str(f["reino"]),
			"nome": str(marco["nome"])})
		# ---- OS DENTES, na ordem em que doem ----
		# a crueldade primeiro: é ela que fecha o teto de relação, e o teto
		# tem que estar fechado ANTES de o ultimato chegar — senão o jogador
		# recebe a cobrança e ainda pode comprar amizade para escapar dela
		alvo["crueldade"] = int(marco["crueldade"])
		_romper_um_pacto(state, alvo, log)
		_cobrar_o_continente(state, alvo, marco, log)
		# a recusa do degrau anterior vence agora
		_cobrar_a_recusa(state, alvo, d, log)

	# ---- o polegar na balança: recruta acima da curva ----
	# A renda já é multiplicada em `Geopolitica._tick_economia` por `fator()`.
	# Aqui vem o exército: um reino rico que não recruta é só um cofre.
	if d > 0 and int(alvo.get("tesouro", 0)) > 400:
		var lote: int = 4 * d
		alvo["tropas"]["espadachim"] = int(alvo["tropas"].get("espadachim", 0)) + lote
		alvo["tropas"]["arqueiro"] = int(alvo["tropas"].get("arqueiro", 0)) + lote
		alvo["tesouro"] = int(alvo["tesouro"]) - 40 * d

# ============================================================
# OS DENTES
# ============================================================

## Quando o Aço cai, a crueldade dele cai junto. Sem isto o reino conquistado
## ficaria com 7 de crueldade para sempre e o teto de relação nunca reabriria
## — um antagonista morto continuaria envenenando o mapa.
static func alvo_limpar_crueldade(state: Dictionary, id: String) -> void:
	if id == "":
		return
	for r in state.get("reinos", []):
		if str(r.get("id", "")) == id:
			r["crueldade"] = 0

## DENTE 2 — quem cresce assim não precisa mais dos amigos que tinha.
##
## Rasga o pacto mais VELHO (o de maior investimento), e não um qualquer: o
## aliado de longa data é quem sente a traição, e é a traição que ensina o
## resto do continente o que o Aço virou.
static func _romper_um_pacto(state: Dictionary, alvo: Dictionary,
		log: Callable) -> void:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id: String = str(alvo["id"])
	var vitima := ""
	var mais_velho := 99999
	for p in state.get("pactos", []):
		var outro := ""
		if str(p["a"]) == id:
			outro = str(p["b"])
		elif str(p["b"]) == id:
			outro = str(p["a"])
		if outro == "":
			continue
		if int(p["meses"]) < mais_velho:
			mais_velho = int(p["meses"])
			vitima = outro
	if vitima == "":
		return
	var vivos: Array = []
	for p in state["pactos"]:
		var toca: bool = (str(p["a"]) == id and str(p["b"]) == vitima) \
			or (str(p["b"]) == id and str(p["a"]) == vitima)
		if not toca:
			vivos.append(p)
	state["pactos"] = vivos
	Geopolitica.mudar_relacao(state, id, vitima, -60)
	var nv: Dictionary = Geopolitica.reino_por_id(state, vitima)
	_diz(log, "%s rasgou o pacto com %s sem dar explicação." % [
		str(alvo["nome"]), str(nv.get("nome", vitima))])
	Sinais.emitir(&"aco_rompeu_pacto", {"aco": id, "vitima": vitima})

## DENTE 3 — o ultimato de tributo, e é aqui que o relógio anda na direção
## do jogador.
##
## Os NPCs resolvem na hora, por uma conta simples e legível: quem tem menos
## exército que o Aço paga, quem tem mais recusa. Pagar drena o cofre para o
## Aço (que fica mais forte ainda — o tributo é um laço, não um imposto) e
## custa relação com quem pagou; recusar é guerra declarada no mês.
##
## O JOGADOR não resolve na hora: vira `evento_pendente`, porque a decisão
## precisa de tela e de números na frente dela.
static func _cobrar_o_continente(state: Dictionary, alvo: Dictionary,
		marco: Dictionary, log: Callable) -> void:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id: String = str(alvo["id"])
	var valor: int = int(marco["tributo"])
	var pagaram: Array = []
	var recusaram: Array = []
	for r in state.get("reinos", []):
		if str(r["id"]) == id or str(r.get("dominado_por", "")) != "" \
				or bool(r.get("fundado_pelo_jogador", false)):
			continue
		# a conta que o rei NPC faz: consigo segurar essa coluna?
		if int(r.get("forca", 0)) >= int(alvo.get("forca", 0)):
			recusaram.append(str(r["nome"]))
			Geopolitica.mudar_relacao(state, id, str(r["id"]), -40)
			if not _em_guerra(state, id, str(r["id"])):
				state["guerras"].append({"a": id, "b": str(r["id"]), "meses": 0})
		else:
			var pago: int = mini(valor, int(r.get("tesouro", 0)))
			r["tesouro"] = int(r.get("tesouro", 0)) - pago
			alvo["tesouro"] = int(alvo.get("tesouro", 0)) + pago
			pagaram.append(str(r["nome"]))
			Geopolitica.mudar_relacao(state, id, str(r["id"]), -15)
	if not pagaram.is_empty():
		_diz(log, "Os arautos de %s cobraram tributo. %s pagaram." % [
			str(alvo["nome"]), ", ".join(pagaram)])
	if not recusaram.is_empty():
		_diz(log, "%s recusaram o tributo. Há guerra no continente." % ", ".join(recusaram))
	# ---- e agora a conta do jogador ----
	# Só cobra de quem tem o que perder: sem terra e sem tropa o jogador é
	# um mercenário sem nome, e arauto não cavalga três dias para cobrar de
	# quem não tem cofre. É o mesmo princípio do resto do jogo — a ameaça
	# aparece quando você vira alguém.
	var Combate = load("res://scripts/combate.gd")
	var meu: int = Combate.total_homens(state["jogador"]["tropas"])
	if state.get("terra") == null and meu < 30:
		return
	state["evento_pendente"] = {
		"tipo": "ultimato_aco",
		"reino": id,
		"nome_reino": str(alvo["nome"]),
		"degrau": int(_ficha(state)["degrau"]),
		"marco": str(marco["nome"]),
		"valor": valor,
	}
	Sinais.emitir(&"aco_ultimato", {"reino": id, "valor": valor})

## A resposta do jogador ao ultimato. Chamada pela interface.
static func responder_ultimato(state: Dictionary, pagar: bool,
		log: Callable = Callable()) -> Dictionary:
	var ev = state.get("evento_pendente")
	if not (ev is Dictionary) or str(ev.get("tipo", "")) != "ultimato_aco":
		return {"ok": false, "msg": "Não há ultimato na mesa."}
	var f := _ficha(state)
	var valor: int = int(ev["valor"])
	var nome: String = str(ev["nome_reino"])
	state["evento_pendente"] = null
	if not pagar:
		f["recusou"] = int(ev["degrau"])
		_diz(log, "Você mandou o arauto de %s de volta sem resposta escrita." % nome)
		return {"ok": true, "pagou": false,
			"msg": "O arauto voltou de mãos vazias. Eles não vão esquecer — e no próximo degrau estarão bem mais fortes do que hoje."}
	var tenho: int = int(state["jogador"]["ouro"])
	var pago: int = mini(valor, tenho)
	state["jogador"]["ouro"] = tenho - pago
	f["pagou"] = int(ev["degrau"])
	f["recusou"] = 0
	var Livro = load("res://scripts/livro.gd")
	Livro.registrar(state, "aco", "ouro", -pago, "Tributo a %s" % nome)
	for r in state.get("reinos", []):
		if str(r["id"]) == str(ev["reino"]):
			r["tesouro"] = int(r.get("tesouro", 0)) + pago
	if pago < valor:
		# pagar menos do que foi cobrado é meio caminho: eles aceitam o ouro
		# e continuam contando você entre os que não pagaram
		f["recusou"] = int(ev["degrau"])
		_diz(log, "Você pagou o que tinha a %s. Não foi o que pediram." % nome)
		return {"ok": true, "pagou": false, "ouro": pago,
			"msg": "Você entregou %d dos %d exigidos. Eles pegaram o ouro e anotaram a diferença." % [pago, valor]}
	_diz(log, "O tributo a %s saiu do cofre: %d de ouro." % [nome, pago])
	return {"ok": true, "pagou": true, "ouro": pago,
		"msg": "Pago. %d de ouro saíram do cofre e foram engordar o exército que você vai enfrentar." % pago}

## A recusa vence no degrau seguinte, e não no mês em que foi dita. É o que
## faz "não" ser uma decisão de verdade: o preço chega dois anos depois, com
## o Aço 60% mais forte do que estava quando você disse não.
static func _cobrar_a_recusa(state: Dictionary, alvo: Dictionary, d: int,
		log: Callable) -> void:
	var f := _ficha(state)
	var recusou: int = int(f.get("recusou", 0))
	if recusou <= 0 or d <= recusou or bool(f.get("marchou", false)):
		return
	f["marchou"] = true
	var id: String = str(alvo["id"])
	if _em_guerra(state, id, "jogador"):
		return
	state["guerras"].append({"a": id, "b": "jogador", "meses": 0})
	var Dialogo = load("res://scripts/dialogo.gd")
	Dialogo.mudar_relacao(state, "rei_" + id, -70, "tributo recusado")
	_diz(log, "%s não esqueceu a sua recusa. As colunas deles viraram para o seu lado." % str(alvo["nome"]))
	Sinais.emitir(&"aco_declarou", {"reino": id})

static func _em_guerra(state: Dictionary, a: String, b: String) -> bool:
	for g in state.get("guerras", []):
		var ga := str(g["a"])
		var gb := str(g["b"])
		if (ga == a and gb == b) or (ga == b and gb == a):
			return true
	return false

static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)

## O texto que a interface mostra — vazio antes de haver o que mostrar.
static func aviso(state: Dictionary) -> String:
	var d := degrau(state)
	if d <= 0:
		return ""
	var Rotas = load("res://scripts/rotas.gd")
	var nome: String = Rotas.nome_do(state, reino_id(state))
	match d:
		1: return "%s cresce acima de qualquer curva. Ninguém sabe com que ouro." % nome
		2: return "%s já tomou três vilas de fronteira. As linhas deles não quebram." % nome
		_: return "%s marchou. Quem tem muro, que suba nele." % nome
	return ""
