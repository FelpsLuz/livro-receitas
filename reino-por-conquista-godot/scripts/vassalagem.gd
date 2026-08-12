# ============================================================
# VASSALAGEM — a diplomacia do ouro, e a saída para quem começa pobre.
#
# Os seis reinos começam ricos por lore; o jogador, com 150 moedas e cinco
# lanceiros. Se o Império marchar no Ano 1, não há defesa possível. Jurar
# lealdade é a válvula: o suserano não te ataca, mas leva 20% do seu ouro
# todo mês e convoca suas tropas quando entra em guerra.
#
# O jogo longo passa a ser crescer NAS SOMBRAS — subir a infraestrutura,
# encher o quartel — até poder rasgar o juramento. Declarar independência
# custa renome e faz o suserano marchar; é uma decisão, não um botão.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")

## O que o armazém do jogador vale a preço da praça onde ele está — a base
## que o cobrador enxerga além do cofre.
static func _valor_da_carga(state: Dictionary) -> int:
	var local := str(state.get("local", ""))
	if not Economia.tem_praca(state, local):
		return 0
	var total := 0
	for g_id in state.get("carga", {}):
		total += int(state["carga"][g_id]) * Economia.preco_de(state, local, g_id)
	return total

## Faltou moeda: o cobrador leva mercadoria até fechar a conta. Devolve o
## valor efetivamente confiscado.
static func _confiscar_carga(state: Dictionary, falta: int) -> int:
	var local := str(state.get("local", ""))
	if falta <= 0 or not Economia.tem_praca(state, local):
		return 0
	var levado := 0
	for g_id in state.get("carga", {}).keys():
		if levado >= falta:
			break
		var preco: int = Economia.preco_de(state, local, g_id)
		if preco <= 0:
			continue
		var tem: int = int(state["carga"][g_id])
		var quer: int = mini(tem, ceili(float(falta - levado) / preco))
		if quer <= 0:
			continue
		state["carga"][g_id] = tem - quer
		levado += quer * preco
	return levado

## Fatia do ouro do vassalo que o suserano leva por mês.
const TRIBUTO := 0.20
## Renome perdido ao rasgar o juramento (traição é cara).
const CUSTO_INDEPENDENCIA := 25

static func suserano(state: Dictionary) -> String:
	return str(state["jogador"].get("suserano", ""))

static func e_vassalo(state: Dictionary) -> bool:
	return suserano(state) != ""

## Um reino só aceita vassalo que valha a pena proteger — ou que seja fraco
## o bastante para não ameaçar. Rei de si mesmo não jura a ninguém.
## A ESCADA DA CASA. Vassalagem deixou de ser um interruptor (paga 20% e
## pronto) e virou carreira: quanto mais tempo de lealdade provada, menor
## o tributo e MAIOR a contrapartida. É de mão dupla — o suserano que só
## cobra não é suserano, é cobrador.
const CARGOS := [
	{"nome": "Juramentado",        "meses": 0,  "relacao": -20,
		"tributo": 0.20, "soldo": 0,   "tropas": 0},
	{"nome": "Homem de confiança", "meses": 6,  "relacao": 25,
		"tributo": 0.17, "soldo": 60,  "tropas": 3},
	{"nome": "Capitão da Casa",    "meses": 18, "relacao": 45,
		"tributo": 0.14, "soldo": 140, "tropas": 6},
	{"nome": "Mão do Rei",         "meses": 36, "relacao": 65,
		"tributo": 0.10, "soldo": 260, "tropas": 10},
]

## Honra mínima para um rei sequer ouvir o juramento: quem quebra palavra
## com taverneiro não jura a um trono.
const HONRA_PARA_JURAR := 45
const MESES_ENTRE_LOTES := 6

## Em que degrau o jogador está HOJE — tempo servido e confiança, os dois.
static func cargo(state: Dictionary) -> Dictionary:
	if not e_vassalo(state):
		return CARGOS[0]
	var meses: int = int(state["jogador"].get("meses_vassalo", 0))
	var rel: int = int(state["tags"].get("rei_" + suserano(state),
		{"relacao": 0})["relacao"])
	var atual: Dictionary = CARGOS[0]
	for c in CARGOS:
		if meses >= int(c["meses"]) and rel >= int(c["relacao"]):
			atual = c
	return atual

static func pode_jurar(state: Dictionary, reino_id: String) -> Dictionary:
	if e_vassalo(state):
		return {"ok": false, "msg": "Você já jurou lealdade a %s." % suserano(state)}
	if str(state["jogador"].get("rei_de", "")) != "":
		return {"ok": false, "msg": "Um rei não ajoelha diante de outro."}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, reino_id)
	if r.is_empty() or not Geopolitica.vivo(r):
		return {"ok": false, "msg": "Esse trono não manda mais em nada."}
	# PRESENCIAL: juramento se faz de joelho, na capital dele — não por
	# carta e não pelo mapa. É o que amarra a vassalagem à viagem.
	if str(state.get("local", "")) != reino_id:
		return {"ok": false,
			"msg": "Juramento se faz diante do trono. Viaje até %s." % str(r["nome"])}
	if int(state["jogador"].get("honra", 50)) < HONRA_PARA_JURAR:
		return {"ok": false,
			"msg": "\"Sua palavra já valeu pouco antes. Por que valeria agora?\""}
	var rel: int = int(state["tags"].get("rei_" + reino_id, {"relacao": 0})["relacao"])
	if rel < 25:
		return {"ok": false,
			"msg": "\"Não te conheço o bastante para te dever proteção.\" (relação %d de 25)" % rel}
	return {"ok": true, "reino": r}

static func jurar(state: Dictionary, reino_id: String, log: Callable) -> Dictionary:
	var check := pode_jurar(state, reino_id)
	if not check["ok"]:
		return check
	var Jogo_j = load("res://scripts/jogo.gd")
	if Jogo_j.esta_preso(state):
		return Jogo_j.recusa_preso(state)
	var r: Dictionary = check["reino"]
	state["jogador"]["suserano"] = reino_id
	state["jogador"]["meses_vassalo"] = 0
	var Dialogo = load("res://scripts/dialogo.gd")
	Dialogo.mudar_relacao(state, "rei_" + reino_id, 30, "juramento de lealdade")
	# proteção real: o suserano cancela guerra contra você
	var vivas: Array = []
	for g in state["guerras"]:
		if (g["a"] == reino_id and g["b"] == "jogador") \
				or (g["b"] == reino_id and g["a"] == "jogador"):
			continue
		vivas.append(g)
	state["guerras"] = vivas
	Sinais.emitir(&"vassalagem", {"suserano": reino_id, "jurou": true})
	_diz(log, "Você dobrou o joelho diante de %s. Enquanto pagar, vive." % r["nome"])
	return {"ok": true, "msg": "Você agora é vassalo de %s. Tributo: %d%% do seu ouro."
		% [r["nome"], int(TRIBUTO * 100)]}

## Todo mês: o tributo sai, e o suserano leva também o que a guerra dele pedir.
static func tick(state: Dictionary, log: Callable) -> void:
	if not e_vassalo(state):
		return
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id := suserano(state)
	var r: Dictionary = Geopolitica.reino_por_id(state, id)
	if r.is_empty() or not Geopolitica.vivo(r):
		# o suserano caiu: você está livre, e ninguém precisou saber
		state["jogador"]["suserano"] = ""
		_diz(log, "Seu suserano caiu. Ninguém mais reclama o seu tributo.")
		Sinais.emitir(&"vassalagem", {"suserano": "", "jurou": false})
		return
	state["jogador"]["meses_vassalo"] = int(state["jogador"].get("meses_vassalo", 0)) + 1

	var posto := cargo(state)
	# O TRIBUTO INCIDE SOBRE A RIQUEZA, NÃO SOBRE O SALDO DO INSTANTE.
	#
	# Cobrar só o ouro na mão fazia do vassalo leal uma renda de risco zero:
	# bastava esvaziar o cofre em mercadoria antes da virada do mês para
	# pagar ZERO e receber o soldo cheio (medido: 60 meses guardando rendem
	# 1.469; gastando tudo, 5.566). O cobrador do rei não é cego — ele conta
	# o que está no armazém também, e leva em carga o que faltar em moeda.
	var riqueza: int = int(state["jogador"]["ouro"]) + _valor_da_carga(state)
	var tributo: int = roundi(riqueza * float(posto["tributo"]))
	var pago_em_ouro: int = mini(tributo, int(state["jogador"]["ouro"]))
	var em_carga: int = 0
	if pago_em_ouro > 0:
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - pago_em_ouro
	if tributo > pago_em_ouro:
		em_carga = _confiscar_carga(state, tributo - pago_em_ouro)
	var recolhido: int = pago_em_ouro + em_carga
	if recolhido > 0:
		r["tesouro"] = int(r.get("tesouro", 0)) + recolhido
		if int(state["jogador"]["meses_vassalo"]) % 6 == 1:
			_diz(log, "O cobrador de %s levou %d de ouro%s." % [r["nome"], pago_em_ouro,
				" e %d em carga do seu armazém" % em_carga if em_carga > 0 else ""])
	# ---- SERVIR CONSTRÓI A CONFIANÇA QUE A PROMOÇÃO EXIGE ----
	# A escada pede relação 25 → 45 → 65, e nada dentro da vassalagem a
	# movia: doze meses pagando tributo e sangrando nas guerras dele davam
	# delta ZERO. O sistema dependia de um número que ele mesmo não
	# alimentava. Agora o tributo pago conta como serviço — e o cofre
	# vazio na hora da cobrança conta como desfeita.
	if tributo > 0 and recolhido >= tributo:
		Dialogo.mudar_relacao(state, "rei_" + id, 2, "tributo em dia")
	elif recolhido < tributo:
		Dialogo.mudar_relacao(state, "rei_" + id, -3, "cobrador de mãos vazias")
		if int(state["jogador"]["meses_vassalo"]) % 6 == 1:
			_diz(log, "O cobrador de %s voltou de mãos vazias. A casa anota." % r["nome"])

	# ---- A CONTRAPARTIDA ----
	# O soldo da casa: o suserano paga quem serve, e paga do próprio cofre.
	# Cofre vazio não paga — e vassalo não pago é vassalo que escuta ofertas.
	var soldo: int = int(posto["soldo"])
	if soldo > 0:
		soldo = mini(soldo, int(r.get("tesouro", 0)))
		if soldo > 0:
			r["tesouro"] = int(r["tesouro"]) - soldo
			state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + soldo
			if int(state["jogador"]["meses_vassalo"]) % 6 == 1:
				_diz(log, "O soldo de %s como %s: +%d de ouro."
					% [r["nome"], str(posto["nome"]), soldo])
		else:
			_diz(log, "O cofre de %s não tem seu soldo este mês. A casa range." % r["nome"])
	# E as lanças emprestadas, a cada meia dúzia de meses de lealdade.
	var lote: int = int(posto["tropas"])
	if lote > 0 and int(state["jogador"]["meses_vassalo"]) % MESES_ENTRE_LOTES == 0:
		state["jogador"]["tropas"]["lanceiro"] = \
			int(state["jogador"]["tropas"].get("lanceiro", 0)) + lote
		_diz(log, "%s manda %d lanceiros para a sua casa — como manda o costume."
			% [r["nome"], lote])
	# promoção anunciada: a escada tem que ser VISÍVEL para valer como meta
	var ultimo := str(state["jogador"].get("ultimo_cargo", ""))
	if ultimo != str(posto["nome"]):
		state["jogador"]["ultimo_cargo"] = str(posto["nome"])
		if ultimo != "":
			_diz(log, "A casa de %s te nomeia %s." % [r["nome"], str(posto["nome"])])

	# suserano em guerra convoca tropas do vassalo — e elas não voltam todas
	if _em_guerra(state, id) and randf() < 0.25:
		var levados := 0
		for tipo in state["jogador"]["tropas"]:
			var n: int = int(state["jogador"]["tropas"][tipo])
			var vao: int = int(n * 0.15)
			if vao > 0:
				state["jogador"]["tropas"][tipo] = n - vao
				levados += vao
		if levados > 0:
			r["tropas"][_maior_tipo(r)] = int(r["tropas"].get(_maior_tipo(r), 0)) + levados
			_diz(log, "%s convocou %d dos seus homens para a guerra dele." % [r["nome"], levados])
			# sangrar pela casa vale mais que pagar por ela
			Dialogo.mudar_relacao(state, "rei_" + id, 3, "homens dados à guerra do suserano")

static func _maior_tipo(r: Dictionary) -> String:
	var melhor := "lanceiro"
	var n := -1
	for tipo in r.get("tropas", {}):
		if int(r["tropas"][tipo]) > n:
			n = int(r["tropas"][tipo])
			melhor = tipo
	return melhor

static func _em_guerra(state: Dictionary, id: String) -> bool:
	for g in state["guerras"]:
		if g["a"] == id or g["b"] == id:
			return true
	return false

## Rasgar o juramento. O suserano marcha, o mundo condena, e você é livre.
static func declarar_independencia(state: Dictionary, log: Callable) -> Dictionary:
	if not e_vassalo(state):
		return {"ok": false, "msg": "Você não deve lealdade a ninguém."}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var id := suserano(state)
	var r: Dictionary = Geopolitica.reino_por_id(state, id)
	state["jogador"]["suserano"] = ""
	state["jogador"]["renome"] = maxi(0, int(state["jogador"]["renome"]) - CUSTO_INDEPENDENCIA)
	var Dialogo = load("res://scripts/dialogo.gd")
	Dialogo.mudar_relacao(state, "rei_" + id, -70, "juramento rasgado")
	state["guerras"].append({"a": id, "b": "jogador", "meses": 0})
	if not state["casus_belli"].has(id):
		state["casus_belli"].append(id)      # agora a guerra é sua, e é legítima
	Sinais.emitir(&"vassalagem", {"suserano": "", "jurou": false, "independencia": true})
	var nome: String = str(r.get("nome", id))
	_diz(log, "Você rasgou o juramento a %s. Os arautos já cavalgam." % nome)
	return {"ok": true, "msg": "Independência declarada. %s vem cobrar." % nome}

## Resumo para a UI.
static func resumo(state: Dictionary) -> Dictionary:
	if not e_vassalo(state):
		return {"vassalo": false}
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, suserano(state))
	var posto := cargo(state)
	var prox: Dictionary = {}
	for c in CARGOS:
		if int(c["meses"]) > int(posto["meses"]):
			prox = c
			break
	return {"vassalo": true, "suserano": suserano(state),
		"nome": str(r.get("nome", suserano(state))),
		"meses": int(state["jogador"].get("meses_vassalo", 0)),
		"cargo": str(posto["nome"]), "soldo": int(posto["soldo"]),
		"tropas_lote": int(posto["tropas"]),
		"proximo_cargo": str(prox.get("nome", "")),
		"proximo_meses": int(prox.get("meses", 0)),
		"proximo_relacao": int(prox.get("relacao", 0)),
		"tributo_estimado": roundi(int(state["jogador"]["ouro"]) * float(posto["tributo"]))}

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
