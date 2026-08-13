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
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Os degraus, em ANOS. Cada um é um marco anunciado e um multiplicador.
const DEGRAUS := [
	{"ano": 3, "fator": 1.25, "nome": "A Forja Estrangeira",
	 "aviso": "Chegam notícias de uma casa que compra ferro em quantidade absurda e não vende nada. Os ferreiros dizem que o aço deles dobra sem quebrar."},
	{"ano": 5, "fator": 1.60, "nome": "As Vilas da Fronteira",
	 "aviso": "Três vilas de fronteira mudaram de bandeira em dois meses. Quem voltou de lá fala de linhas que não quebram e de flechas que não passam."},
	{"ano": 7, "fator": 2.20, "nome": "O Aço Marcha",
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
	return state["aco"]

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
		f["reino"] = ""
		f["degrau"] = 0
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

	# ---- o polegar na balança: recruta acima da curva ----
	# A renda já é multiplicada em `Geopolitica._tick_economia` por `fator()`.
	# Aqui vem o exército: um reino rico que não recruta é só um cofre.
	if d > 0 and int(alvo.get("tesouro", 0)) > 400:
		var lote: int = 4 * d
		alvo["tropas"]["espadachim"] = int(alvo["tropas"].get("espadachim", 0)) + lote
		alvo["tropas"]["arqueiro"] = int(alvo["tropas"].get("arqueiro", 0)) + lote
		alvo["tesouro"] = int(alvo["tesouro"]) - 40 * d

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
