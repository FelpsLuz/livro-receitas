# ============================================================
# PRETENDENTES — o casamento como escolha de VIDA, não de menu.
#
# Duas portas, e elas se excluem:
#
#   PLEBEIA  traz OFÍCIO. A família dela sabe fazer alguma coisa, e isso
#            aparece todo mês na sua terra. Não traz dote nem aliança, e
#            os reis cospem no chão: −10 de relação com cada um, −5 de
#            renome. O povo, esse, ama.
#   NOBRE    traz DOTE e ALIANÇA (intriga.gd já resolve), mas exige nome
#            feito — e o sogro cobra.
#
# Cortejar custa tempo e presente. Cortejar DUAS ao mesmo tempo é
# escândalo, e escândalo custa honra: é a única trava, e ela é social.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## O que cada casa plebeia sabe fazer. O buff é permanente enquanto o
## casamento durar — é o dote de quem não tem ouro.
const CASAS := [
	{"oficio": "ferreiro", "buff": "equip",
		"titulo": "filha do ferreiro",
		"dom": "A forja da família arma os seus homens a preço de custo.",
		"efeito": "−15% no custo de equipar tropas"},
	{"oficio": "moleiro", "buff": "colheita",
		"titulo": "filha do moleiro",
		"dom": "Ela sabe onde o grão rende e onde o moinho engana.",
		"efeito": "+10% de colheita na sua terra"},
	{"oficio": "taverneiro", "buff": "rumor",
		"titulo": "filha do taverneiro",
		"dom": "O balcão do pai ouve o reino inteiro, e agora ouve para você.",
		"efeito": "um rumor de mercado de graça por mês"},
	{"oficio": "capataz", "buff": "felicidade",
		"titulo": "filha do capataz",
		"dom": "A vila obedece a ela desde antes de você chegar.",
		"efeito": "+8 de felicidade na sua terra"},
]

const AFETO_PARA_CASAR := 60
const CUSTO_CORTEJO := 40           # o presente: flores, fita, uma noite de vinho

## Preço social de casar fora da nobreza — cobrado uma vez, no altar.
const PENALIDADE_RELACAO := -10
const PENALIDADE_RENOME := 5
const ESCANDALO_HONRA := 12

static func _hash(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = ((h ^ s.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h

## As TRÊS moças da região. Determinísticas por reino: são as mesmas na
## partida inteira, então o jogador pode voltar para cortejar a mesma.
static func do_reino(state: Dictionary, reino_id: String) -> Array:
	var lista: Array = []
	for i in 3:
		var semente := _hash(reino_id + "|pretendente|" + str(i))
		var casa: Dictionary = CASAS[semente % CASAS.size()]
		var nome: String = "%s %s" % [
			Dados.NOMES_F[semente % Dados.NOMES_F.size()],
			Dados.SOBRENOMES[(semente / 11) % Dados.SOBRENOMES.size()]]
		lista.append({
			"idx": i, "reino": reino_id, "nome": nome,
			"oficio": casa["oficio"], "buff": casa["buff"],
			"titulo": casa["titulo"], "dom": casa["dom"], "efeito": casa["efeito"],
			"atributos": {
				"forca": 2 + semente % 5, "carisma": 3 + (semente / 3) % 6,
				"gestao": 3 + (semente / 5) % 6, "intriga": 2 + (semente / 7) % 5},
			"afeto": afeto(state, reino_id, i),
		})
	return lista

static func _chave(reino_id: String, idx: int) -> String:
	return "%s:%d" % [reino_id, idx]

static func afeto(state: Dictionary, reino_id: String, idx: int) -> int:
	return int(state.get("afetos", {}).get(_chave(reino_id, idx), 0))

## Quem já recebeu cortejo seu e ainda não foi ao altar.
static func cortejadas(state: Dictionary) -> Array:
	var quem: Array = []
	for k in state.get("afetos", {}):
		if int(state["afetos"][k]) > 0:
			quem.append(str(k))
	return quem

## Um cortejo: custa ouro, custa UM DIA, e rende afeto conforme o seu
## carisma. Cortejar uma segunda moça enquanto a primeira espera é
## escândalo — a vila fala, e a honra paga.
static func cortejar(state: Dictionary, reino_id: String, idx: int,
		log: Callable = Callable()) -> Dictionary:
	var Jogo = load("res://scripts/jogo.gd")
	if Jogo.acabou(state):
		return Jogo.recusa_fim(state)
	if Jogo.esta_preso(state):
		return Jogo.recusa_preso(state)
	if state["familia"]["conjuge"] != null:
		return {"ok": false, "msg": "Você é casado. A vila inteira sabe."}
	if int(state["jogador"]["ouro"]) < CUSTO_CORTEJO:
		return {"ok": false, "msg": "Cortejar de mãos vazias não é cortejar. Faltam moedas."}
	if int(state.get("dia", 1)) + 1 > Jogo.DIAS_POR_MES + 1:
		return {"ok": false, "msg": "Não sobra dia no mês para uma visita."}
	var chave := _chave(reino_id, idx)
	if not state.has("afetos"):
		state["afetos"] = {}
	var escandalo := false
	for outra in cortejadas(state):
		if str(outra) != chave:
			escandalo = true
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - CUSTO_CORTEJO
	var carisma: int = int(state["jogador"]["atributos"].get("carisma", 5))
	var ganho: int = Dados.ri(8, 14) + carisma
	state["afetos"][chave] = mini(100, afeto(state, reino_id, idx) + ganho)
	var msg := "A visita correu bem."
	if escandalo:
		state["jogador"]["honra"] = maxi(0,
			int(state["jogador"].get("honra", 50)) - ESCANDALO_HONRA)
		msg = "A vila comenta que você visita duas portas. Honra −%d." % ESCANDALO_HONRA
		if log.is_valid():
			_diz(log, "Falam de você nas duas casas. Honra −%d." % ESCANDALO_HONRA)
	Jogo.passar_dia(state, log)
	return {"ok": true, "msg": msg, "afeto": int(state["afetos"][chave]),
		"escandalo": escandalo}

## Pedir a mão. Sem afeto não há casamento — e o preço social vem junto.
static func pedir_a_mao(state: Dictionary, reino_id: String, idx: int,
		log: Callable = Callable()) -> Dictionary:
	if state["familia"]["conjuge"] != null:
		return {"ok": false, "msg": "Você já é casado."}
	var a := afeto(state, reino_id, idx)
	if a < AFETO_PARA_CASAR:
		return {"ok": false,
			"msg": "\"Ainda não te conheço o bastante para dizer sim.\" (%d de %d)"
				% [a, AFETO_PARA_CASAR]}
	var moca: Dictionary = {}
	for p in do_reino(state, reino_id):
		if int(p["idx"]) == idx:
			moca = p
	if moca.is_empty():
		return {"ok": false, "msg": "Ela não está mais aqui."}
	# o cônjuge tem a MESMA forma do casamento nobre (intriga.gd), senão a
	# aba Família e a herança de atributos não o reconheceriam
	state["familia"]["conjuge"] = {
		"nome": str(moca["nome"]), "genero": "f", "reino": reino_id,
		"forcado": false, "plebeia": true,
		"oficio": str(moca["oficio"]), "buff": str(moca["buff"]),
		"titulo": str(moca["titulo"]),
		"atributos": moca["atributos"],
	}
	# a nobreza cospe no chão; o povo levanta a caneca
	var Dialogo = load("res://scripts/dialogo.gd")
	for r in state["reinos"]:
		Dialogo.mudar_relacao(state, "rei_" + str(r["id"]), PENALIDADE_RELACAO,
			"casou fora da nobreza")
	state["jogador"]["renome"] = maxi(0,
		int(state["jogador"]["renome"]) - PENALIDADE_RENOME)
	if state.get("terra") != null:
		state["terra"]["felicidade"] = mini(100,
			int(state["terra"]["felicidade"]) + 6)
	state["afetos"] = {}
	if log.is_valid():
		_diz(log, "Você casa com %s, %s. Os reis torcem o nariz; a vila bebe até de manhã."
			% [str(moca["nome"]), str(moca["titulo"])])
	Sinais.emitir(&"casamento", {"plebeia": true, "reino": reino_id})
	return {"ok": true, "msg": "Casados. %s" % str(moca["dom"]),
		"efeito": str(moca["efeito"])}

# ------------------------------------------------------------
# OS BUFFS — o dote de quem não tem ouro
# ------------------------------------------------------------
## O ofício da casa dela está ativo? É a pergunta que a economia faz.
static func buff_ativo(state: Dictionary, buff: String) -> bool:
	var c = state.get("familia", {}).get("conjuge")
	return c is Dictionary and str(c.get("buff", "")) == buff

## Multiplicador do custo de equipar: a forja da família cobra o de casa.
static func fator_equipamento(state: Dictionary) -> float:
	return 0.85 if buff_ativo(state, "equip") else 1.0

## Multiplicador da colheita.
static func fator_colheita(state: Dictionary) -> float:
	return 1.10 if buff_ativo(state, "colheita") else 1.0

## Felicidade que a casa dela segura sozinha, todo mês.
static func bonus_felicidade(state: Dictionary) -> int:
	return 8 if buff_ativo(state, "felicidade") else 0

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
