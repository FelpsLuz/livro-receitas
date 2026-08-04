# ============================================================
# TAVERNA COM UTILIDADE — informação vira dinheiro.
#
# Três serviços, cada um ligado a um sistema que já existe:
#   rumor de mercado  → agenda um CHOQUE de preço (economia.gd) que o jogador
#                       conhece antes de acontecer. É especulação com
#                       informação assimétrica — e o rumor pode ser falso.
#   rota comercial    → revela onde um bem está barato e onde está caro,
#                       poupando meses de viagem às cegas.
#   informante        → paga por mês e entrega notícia da geopolítica dos
#                       NPCs (guerras se formando, pactos, tesouro fraco).
#
# Nada aqui é texto de enfeite: tudo mexe em número que o jogador usa.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Economia = preload("res://scripts/economia.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Sinais = preload("res://scripts/sinais.gd")

const PRECO_RUMOR := 60
const PRECO_ROTA := 90
const PRECO_INFORMANTE := 120       # entrada; depois 25/mês

# ------------------------------------------------------------
# 1. Rumor de mercado
# ------------------------------------------------------------
## Compra um boato. Se for verdadeiro, o choque É agendado — o jogador soube
## antes do preço reagir. Se for falso, ele pagou por nada, e é isso que faz
## a informação valer alguma coisa.
static func comprar_rumor(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["ouro"]) < PRECO_RUMOR:
		return {"ok": false, "msg": "O taverneiro não fia rumor."}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_RUMOR
	var reino: Dictionary = Dados.rnd(state["reinos"])
	var bem: String = Dados.rnd(Dados.MERCADORIAS.keys())
	# intriga alta = fontes melhores
	var confianca: float = 0.60 + int(state["jogador"]["atributos"]["intriga"]) * 0.035
	var verdadeiro: bool = randf() < confianca
	if verdadeiro:
		# escassez: oferta cai, demanda sobe → preço dispara em 2-3 meses
		Economia.abalar(state, reino["id"], bem, -0.55, 0.45, 3)
		Sinais.emitir(&"rumor_comprado", {"reino": reino["id"], "bem": bem, "verdadeiro": true})
		return {"ok": true, "verdadeiro": true, "reino": reino["id"], "bem": bem,
			"msg": "\"A colheita de %s em %s se perdeu. Compre agora, venda em dois meses.\""
				% [Dados.MERCADORIAS[bem]["nome"], reino["nome"]]}
	Sinais.emitir(&"rumor_comprado", {"reino": reino["id"], "bem": bem, "verdadeiro": false})
	return {"ok": true, "verdadeiro": false, "reino": reino["id"], "bem": bem,
		"msg": "\"Falta %s em %s, juro pela minha mãe.\" (ele sorri demais)"
			% [Dados.MERCADORIAS[bem]["nome"], reino["nome"]]}

# ------------------------------------------------------------
# 2. Rota comercial
# ------------------------------------------------------------
## Revela o melhor par comprar/vender de um bem AGORA. É informação que o
## jogador poderia obter viajando — só que viajar custa meses.
static func comprar_rota(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["ouro"]) < PRECO_ROTA:
		return {"ok": false, "msg": "Cartógrafos bêbados custam %d." % PRECO_ROTA}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_ROTA
	var melhor := {}
	var melhor_lucro := 0
	for bem in Dados.MERCADORIAS:
		var barato := ""
		var caro := ""
		var p_min := 99999
		var p_max := 0
		for r in state["reinos"]:
			if not Geopolitica.vivo(r):
				continue
			var p := Economia.preco_de(state, r["id"], bem)
			if p < p_min:
				p_min = p
				barato = r["id"]
			if p > p_max:
				p_max = p
				caro = r["id"]
		if p_max - p_min > melhor_lucro:
			melhor_lucro = p_max - p_min
			melhor = {"bem": bem, "compra": barato, "venda": caro,
				"preco_compra": p_min, "preco_venda": p_max}
	if melhor.is_empty():
		return {"ok": true, "msg": "Ninguém sabe de nada útil esta noite."}
	melhor["ok"] = true
	melhor["lucro"] = melhor_lucro
	melhor["msg"] = "\"%s: compre em %s por %d, venda em %s por %d. Lucro de %d por unidade.\"" % [
		Dados.MERCADORIAS[melhor["bem"]]["nome"],
		_nome_reino(state, melhor["compra"]), melhor["preco_compra"],
		_nome_reino(state, melhor["venda"]), melhor["preco_venda"], melhor_lucro]
	return melhor

# ------------------------------------------------------------
# 3. Informante permanente
# ------------------------------------------------------------
static func contratar_informante(state: Dictionary, reino_id: String) -> Dictionary:
	if not state.has("informantes"):
		state["informantes"] = []
	if state["informantes"].has(reino_id):
		return {"ok": false, "msg": "Você já tem ouvidos nesse reino."}
	if int(state["jogador"]["ouro"]) < PRECO_INFORMANTE:
		return {"ok": false, "msg": "Um par de ouvidos custa %d." % PRECO_INFORMANTE}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_INFORMANTE
	state["informantes"].append(reino_id)
	return {"ok": true, "msg": "Você tem ouvidos em %s." % _nome_reino(state, reino_id)}

## Todo mês: cobra o soldo e entrega notícia. Informante sem pagamento some.
static func tick(state: Dictionary, log: Callable) -> void:
	if not state.has("informantes") or state["informantes"].is_empty():
		return
	var custo: int = 25 * state["informantes"].size()
	if int(state["jogador"]["ouro"]) < custo:
		log.call("Sem soldo, seus informantes sumiram nas sombras.")
		state["informantes"] = []
		return
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	for id in state["informantes"]:
		var r := Geopolitica.reino_por_id(state, id)
		if r.is_empty():
			continue
		# entrega o que a geopolítica está cozinhando — informação de verdade
		var noticias: Array = []
		if int(r.get("tesouro", 0)) < 150:
			noticias.append("o tesouro de %s está no fim" % r["nome"])
		for p in Geopolitica.pactos_de(state, id):
			var outro: String = p["b"] if p["a"] == id else p["a"]
			noticias.append("%s tem pacto de %s com %s"
				% [r["nome"], p["tipo"], _nome_reino(state, outro)])
		for outro in state["reinos"]:
			if outro["id"] == id or not Geopolitica.vivo(outro):
				continue
			if Geopolitica.relacao(state, id, outro["id"]) <= -45:
				noticias.append("%s e %s estão à beira da guerra"
					% [r["nome"], outro["nome"]])
		if not noticias.is_empty():
			log.call("Informante: %s." % Dados.rnd(noticias))

static func _nome_reino(state: Dictionary, id: String) -> String:
	var r := Geopolitica.reino_por_id(state, id)
	return str(r.get("nome", id))
