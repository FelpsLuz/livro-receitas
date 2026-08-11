# ============================================================
# CONTRATOS E RENOME (port da parte de contratos de js/combat.js)
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Combate = preload("res://scripts/combate.gd")

const TIPOS := [
	{"id": "escolta", "nome": "Escoltar caravana", "forca": 1,
	 "desc": "Mercadores pagam por proteção contra bandidos.", "ouro": [60, 120], "renome": 5},
	{"id": "bandidos", "nome": "Caçar bandidos", "forca": 2,
	 "desc": "Um vilarejo sofre com saqueadores. Limpe a região.", "ouro": [100, 180], "renome": 10},
	{"id": "incursao", "nome": "Queimar vila inimiga", "forca": 2,
	 "desc": "Trabalho sujo pago por um rei rival.", "ouro": [200, 350], "renome": 12},
	{"id": "patrulha", "nome": "Guarnecer fronteira", "forca": 3,
	 "desc": "Guerra na fronteira. Reforce a linha por um mês.", "ouro": [250, 400], "renome": 18},
]

## Reis que juraram nunca mais te contratar (documento "Era do Aço", Parte 5
## — a reação de Frederico Silver a uma chantagem falhada) somem do sorteio
## de contratante. Sem isso a flag existiria só no papel.
static func _contratantes_elegiveis(state: Dictionary) -> Array:
	# reino dominado não emite contrato — o rei que pagaria já não manda
	return state["reinos"].filter(func(r):
		return str(r.get("dominado_por", "")) == "" \
			and not bool(state.get("tags", {}).get("rei_" + r["id"], {})
			.get("flags", {}).get("nunca_mais_contrata", false)))

## Cada mural é de uma TAVERNA, não do mundo: cinco contratos por região,
## renovados a cada virada de mês. E a região manda na régua — o Covil
## Negro pede pouco e paga pouco; uma corte rica pede o serviço que mata.
const POR_TAVERNA := 5

## Quanto a região endurece o contrato, pelo mesmo tesouro que escala os
## empregos. Nenhum número novo: a riqueza do reino JÁ é a régua do jogo.
static func _degrau_da_regiao(state: Dictionary, reino_id: String) -> int:
	var Empregos = load("res://scripts/empregos.gd")
	var f: float = Empregos.fator_reino(state, reino_id)
	if f >= 1.5:
		return 2
	if f >= 1.0:
		return 1
	return 0

static func dificuldade(contrato: Dictionary) -> String:
	var f := int(contrato.get("forca", 1))
	if f <= 2:
		return "facil"
	return "media" if f <= 4 else "dificil"

## Quantos DIAS o serviço come. Sem o dia como unidade isto não existiria
## — era tudo instantâneo, e por isso não era escolha nenhuma.
static func duracao_dias(contrato: Dictionary) -> int:
	match dificuldade(contrato):
		"facil": return 1
		"media": return 2
	return 3

## Quebrar a palavra custa NOME, e custa mais quanto maior era o serviço.
const PENALIDADE_HONRA := {"facil": 10, "media": 15, "dificil": 25}

## E cumpri-la DEVOLVE nome — metade do que largar teria custado.
##
## Sem este caminho de volta a honra era uma via de mão única: três formas
## de perder e nenhuma de recuperar, então um deslize fechava para sempre
## os empregos de honra alta e a vassalagem (que pede 45). Reconstruir o
## nome tem que ser mais lento que perdê-lo — mas tem que existir.
const RECOMPENSA_HONRA := {"facil": 5, "media": 7, "dificil": 12}
const HONRA_MAX := 100

static func gerar(state: Dictionary) -> Array:
	var contratos: Array = []
	var elegiveis := _contratantes_elegiveis(state)
	if elegiveis.is_empty():
		return contratos
	# um mural por região: a taverna do lugar onde você está é a que você vê
	for regiao in elegiveis:
		var regiao_id: String = str(regiao["id"])
		var degrau := _degrau_da_regiao(state, regiao_id)
		for i in POR_TAVERNA:
			var t: Dictionary = Dados.rnd(TIPOS)
			var contratante: Dictionary = Dados.rnd(elegiveis)
			var alvo := ""
			if t["id"] == "incursao" or t["id"] == "patrulha":
				for g in state["guerras"]:
					if g["a"] == contratante["id"]:
						alvo = g["b"]
					elif g["b"] == contratante["id"]:
						alvo = g["a"]
				if alvo == "":
					var alvos: Array = state["reinos"].filter(func(r):
						return r["id"] != contratante["id"] \
							and str(r.get("dominado_por", "")) == "")
					if alvos.is_empty():
						continue
					alvo = Dados.rnd(alvos)["id"]
			var c := t.duplicate()
			c["uid"] = str(randi()) + "_" + regiao_id + str(i)
			c["regiao"] = regiao_id
			c["contratante"] = contratante["id"]
			c["alvo"] = alvo
			c["forca"] = int(t["forca"]) + degrau
			# paga acompanha a dureza: serviço de corte rica vale o risco
			c["pagamento"] = roundi(Dados.ri(t["ouro"][0], t["ouro"][1])
				* (1.0 + 0.35 * degrau))
			c["renome"] = int(t["renome"]) + degrau * 3
			c["aceito"] = false
			contratos.append(c)
	return contratos

## O mural DESTA taverna.
static func do_local(state: Dictionary) -> Array:
	var aqui: String = str(state.get("local", ""))
	return state["contratos"].filter(func(c): return str(c.get("regiao", aqui)) == aqui)

static func por_uid(state: Dictionary, uid: String) -> Dictionary:
	for c in state["contratos"]:
		if str(c["uid"]) == uid:
			return c
	return {}

## Aceitar é dar a palavra: a partir daqui, largar custa honra.
static func aceitar(state: Dictionary, uid: String) -> Dictionary:
	var c := por_uid(state, uid)
	if c.is_empty():
		return {"ok": false, "msg": "Esse contrato saiu do mural."}
	for outro in state["contratos"]:
		if bool(outro.get("aceito", false)) and str(outro["uid"]) != uid:
			return {"ok": false, "msg": "Você já deu a palavra em outro contrato. Um de cada vez."}
	c["aceito"] = true
	return {"ok": true, "msg": "Palavra dada. Cumpra antes de o mês virar."}

static func aceito_de(state: Dictionary) -> Dictionary:
	for c in state["contratos"]:
		if bool(c.get("aceito", false)):
			return c
	return {}

## Largar o serviço — por escolha ou porque o mês virou. O preço é o mesmo:
## quem aceita e não entrega perde o nome, e o contratante lembra.
static func abandonar(state: Dictionary, uid: String, log: Callable) -> Dictionary:
	var c := por_uid(state, uid)
	if c.is_empty():
		return {"ok": false, "msg": "Contrato não encontrado."}
	var dif := dificuldade(c)
	var perda: int = int(PENALIDADE_HONRA[dif])
	state["jogador"]["honra"] = maxi(0, int(state["jogador"].get("honra", 50)) - perda)
	Dialogo.mudar_relacao(state, "rei_" + str(c["contratante"]), -12, "palavra quebrada")
	c["aceito"] = false
	if log.is_valid():
		log.call("Você largou \"%s\". A palavra quebrada corre: honra −%d." % [str(c["nome"]), perda])
	return {"ok": true, "msg": "Serviço largado. Honra −%d." % perda,
		"honra_perdida": perda}

## Chamada na virada do mês, ANTES de o mural ser renovado: contrato
## aceito e não cumprido é palavra quebrada, mesmo sem o jogador clicar.
static func expirar_pendentes(state: Dictionary, log: Callable) -> void:
	for c in state["contratos"]:
		if bool(c.get("aceito", false)):
			abandonar(state, str(c["uid"]), log)

## O RELATÓRIO DE PREPARAÇÃO: o que o jogador precisa saber ANTES de
## marchar. Sem ele, aceitar um contrato era apostar no escuro.
static func relatorio_preparacao(state: Dictionary, contrato: Dictionary) -> Dictionary:
	var inimigo := Combate.exercito_inimigo(int(contrato["forca"]))
	var deles := Combate.total_homens(inimigo["tropas"])
	var meus := Combate.total_homens(state["jogador"]["tropas"])
	var razao := float(meus) / maxf(1.0, float(deles))
	var veredito := "Suicídio. Recrute antes."
	if razao >= 2.0:
		veredito = "Folgado: você tem o dobro deles."
	elif razao >= 1.2:
		veredito = "Favorável, mas vai custar homens."
	elif razao >= 0.8:
		veredito = "Parelho. Uma virada de dado decide."
	elif razao >= 0.5:
		veredito = "Desfavorável: eles são mais."
	return {"inimigos": deles, "meus": meus, "razao": razao,
		"veredito": veredito, "dias": duracao_dias(contrato),
		"dificuldade": dificuldade(contrato),
		"penalidade": int(PENALIDADE_HONRA[dificuldade(contrato)]),
		"equipamento": int(state["jogador"].get("equip", 0)),
		"moral": int(state["jogador"].get("moral", 100))}

## O que cada rei paga por contrato (documento "Era do Aço", Parte 4): "Frederico
## paga o melhor do mapa" (Garças de Prata, maior contratante) e "Ignis é
## raro, mas paga o dobro e cumpre à letra" (Cervos Escarlates).
static func _pagamento_de(contratante: String, base: int) -> int:
	if contratante == "aguias":
		return roundi(base * 1.3)
	if contratante == "leoes":
		return base * 2
	return base

static func executar(state: Dictionary, contrato: Dictionary, log: Callable) -> Dictionary:
	# o serviço come DIAS, e tem que caber no mês: é isso que transforma
	# "aceitar tudo" numa escolha de agenda
	var Jogo = load("res://scripts/jogo.gd")
	var dias := duracao_dias(contrato)
	if int(state.get("dia", 1)) + dias > Jogo.DIAS_POR_MES + 1:
		return {"ok": false, "sem_tempo": true,
			"msg": "Não sobra mês para %d %s de serviço." % [dias,
				"dia" if dias == 1 else "dias"]}
	contrato["aceito"] = false
	var inimigo := Combate.exercito_inimigo(int(contrato["forca"]))
	var rel := Combate.batalhar(state, inimigo, contrato["nome"])
	if rel["vitoria"]:
		contrato["pagamento"] = _pagamento_de(contrato["contratante"], int(contrato["pagamento"]))
		state["jogador"]["ouro"] += int(contrato["pagamento"])
		state["jogador"]["renome"] += int(contrato["renome"])
		var ganho_h: int = int(RECOMPENSA_HONRA[dificuldade(contrato)])
		state["jogador"]["honra"] = mini(HONRA_MAX,
			int(state["jogador"].get("honra", 50)) + ganho_h)
		Dialogo.mudar_relacao(state, "rei_" + contrato["contratante"], 8, "contrato cumprido")
		log.call("Contrato cumprido: +%d ouro, +%d renome, +%d de honra."
			% [contrato["pagamento"], contrato["renome"], ganho_h])
		if contrato["id"] == "incursao" and contrato["alvo"] != "":
			Dialogo.mudar_relacao(state, "rei_" + contrato["alvo"], -25, "queimou vila")
			state["jogador"]["crueldade"] = int(state["jogador"].get("crueldade", 0)) + 1
			log.call("Você queimou uma vila de %s. O rei de lá não esquecerá." % contrato["alvo"])
	else:
		state["jogador"]["renome"] = maxi(0, state["jogador"]["renome"] - 5)
		log.call("Contrato fracassou. Renome -5.")
		# derrota esmagadora não é só perder: é ser CAPTURADO no campo
		if rel.get("esmagado", false):
			Jogo.prender(state, 3, log)
	rel["ok"] = true
	rel["dias"] = dias
	for i in dias:
		Jogo.passar_dia(state, log)
		if state["fim"] != null:
			break
	return rel

static func titulo(state: Dictionary) -> String:
	if state["jogador"]["rei_de"] != "":
		return "Rei"
	if state["terra"] != null and int(state["terra"]["nivel"]) >= 3:
		return "Conde"
	if state["terra"] != null:
		return "Senhor"
	if state["jogador"]["renome"] >= 50:
		return "Capitão Mercenário"
	return "Mercenário"
