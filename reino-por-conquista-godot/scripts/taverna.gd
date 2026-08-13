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
const Livro = preload("res://scripts/livro.gd")
const Economia = preload("res://scripts/economia.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Sinais = preload("res://scripts/sinais.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")

const PRECO_RUMOR := 60
const PRECO_ROTA := 60
const PRECO_INFORMANTE := 120       # entrada; depois 25/mês

# ============================================================
# 1. A MESA DO VETERANO — o que se sabe de um rei, e não de um preço
#
# O balcão vendia DUAS informações de preço: "rumor de mercado" (um choque
# vindouro num bem) e "mapa comercial" (onde cada bem está barato e caro).
# Da cadeira do jogador é a mesma compra por 60 de ouro, e ele escolhe pela
# arte do retrato — o rumor era o mapa com mais passos.
#
# O rumor virou outra coisa, e virou porque a formação de batalha passou a
# depender da PERSONALIDADE de quem comanda: o orgulhoso carrega em cunha, o
# honrado segura a linha, o calculista responde à sua formação, o cruel gira
# pelo ciclo. Isso é conhecimento militar de valor real, e é exatamente o
# tipo de coisa que um veterano bêbado sabe e um cartógrafo não.
#
# 60 de ouro contra os 180 do espião: o veterano diz o TEMPERAMENTO (que não
# muda nunca), o espião diz a formação DESTE MÊS. Um é a régua, o outro é a
# leitura — e contra o calculista nem o espião serve, porque ele lê você.
# ============================================================
static func veteranos_disponiveis(state: Dictionary) -> Array:
	var lista: Array = []
	for r in state["reinos"]:
		if str(r.get("dominado_por", "")) != "" or bool(r.get("fundado_pelo_jogador", false)):
			continue
		if not bool(state.get("doutrinas", {}).get(str(r["id"]), false)):
			lista.append(r)
	return lista

const DOUTRINA := {
	"orgulhoso": {"formacao": "Cunha",
		"txt": "Esse não manobra. Ele escolhe um ponto da sua linha e vai por dentro, sempre. Cunha, todo santo mês, faça chuva ou faça sol.",
		"conselho": "Envolvimento come cunha. Traga os flancos."},
	"honrado": {"formacao": "Linha de Escudos",
		"txt": "Homem de manual. Linha de escudos, de frente, sem truque — ele acha que manobrar é trapaça.",
		"conselho": "Cunha rompe linha. Concentre e fure."},
	"calculista": {"formacao": "o contrário da sua",
		"txt": "Esse é o perigoso. Ele não tem doutrina: ele tem espião. Manda formar o que ganha da SUA formação, e descobre qual é antes de você chegar.",
		"conselho": "Contra ele espião não vale nada. Troque de formação e não repita."},
	"cruel": {"formacao": "muda todo mês",
		"txt": "Ninguém sabe. Nem os homens dele sabem até a manhã da batalha — ele troca por capricho, e enforca quem reclama.",
		"conselho": "Contra ele o relatório de espião vale, e vale todo mês."},
}

static func comprar_doutrina(state: Dictionary, reino_id: String) -> Dictionary:
	if int(state["jogador"]["ouro"]) < PRECO_RUMOR:
		return {"ok": false, "msg": "O veterano não fia história de guerra."}
	var reino: Dictionary = {}
	for r in state["reinos"]:
		if str(r["id"]) == reino_id:
			reino = r
	if reino.is_empty():
		return {"ok": false, "msg": "Ninguém aqui serviu nesse lugar."}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_RUMOR
	if not (state.get("doutrinas") is Dictionary):
		state["doutrinas"] = {}
	state["doutrinas"][reino_id] = true
	var pers: String = str((reino.get("rei", {}) as Dictionary).get("personalidade", "cruel"))
	var d: Dictionary = DOUTRINA.get(pers, DOUTRINA["cruel"])
	Sinais.emitir(&"doutrina_comprada", {"reino": reino_id})
	return {"ok": true, "reino": reino_id, "nome": str(reino["nome"]),
		"rei": str((reino.get("rei", {}) as Dictionary).get("nome", "")),
		"formacao": str(d["formacao"]), "conselho": str(d["conselho"]),
		"msg": "\"%s? Servi contra ele. %s\"\n\n%s" % [
			str((reino.get("rei", {}) as Dictionary).get("nome", "Ele")),
			str(d["txt"]), str(d["conselho"])]}

## O que o jogador já pagou para saber. A aba Guerra lê isto para mostrar a
## doutrina ao lado de cada casa — informação comprada tem que ficar à vista,
## senão o jogador paga duas vezes pela mesma coisa.
static func doutrina_conhecida(state: Dictionary, reino_id: String) -> Dictionary:
	if not bool(state.get("doutrinas", {}).get(reino_id, false)):
		return {}
	for r in state["reinos"]:
		if str(r["id"]) == reino_id:
			var pers: String = str((r.get("rei", {}) as Dictionary).get("personalidade", "cruel"))
			var d: Dictionary = DOUTRINA.get(pers, DOUTRINA["cruel"])
			return {"formacao": str(d["formacao"]), "conselho": str(d["conselho"])}
	return {}

# ------------------------------------------------------------
# 1b. Rumor de mercado (mantido para o Mercador leal, ver `tick`)
# ------------------------------------------------------------
## Compra um boato. Se for verdadeiro, o choque É agendado — o jogador soube
## antes do preço reagir. Se for falso, ele pagou por nada, e é isso que faz
## a informação valer alguma coisa.
##
## Saiu do balcão (era a mesma compra que o mapa comercial, com mais passos)
## e continua vivo aqui porque o Mercador leal da sua vila entrega um por
## mês de graça — ver `_tick_mercador`.
static func comprar_rumor(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["ouro"]) < PRECO_RUMOR:
		return {"ok": false, "msg": "O taverneiro não fia rumor."}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_RUMOR
	var reino: Dictionary = Dados.rnd(state["reinos"])
	var bem: String = Dados.rnd(Dados.MERCADORIAS.keys())
	# intriga alta = fontes melhores; um taverneiro leal filtra o boato ruim
	# antes de ele chegar até você — é o ofício dele, é a mesa dele
	var confianca: float = 0.60 + int(state["jogador"]["atributos"]["intriga"]) * 0.035
	if Cidadaos.oficio_ativo(state, "taverneiro"):
		confianca += 0.20
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
## O par comprar/vender mais lucrativo do mapa AGORA. Extraído de
## `comprar_rota` para o Mercador leal (ver `tick`) reusar a MESMA busca sem
## pagar — ele já sabe os preços do ofício, não precisa de cartógrafo bêbado.
static func _melhor_rota(state: Dictionary) -> Dictionary:
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
	if not melhor.is_empty():
		melhor["lucro"] = melhor_lucro
	return melhor

## Revela o melhor par comprar/vender de um bem AGORA. É informação que o
## jogador poderia obter viajando — só que viajar custa meses.
## O MAPA COMERCIAL é um RETRATO, não uma assinatura.
##
## Ele deixou de ser a licença de negociar (isso agora é o selo da guilda,
## comprado praça a praça) e voltou a ser o que o nome diz: onde cada bem
## está barato e onde está caro, HOJE. O cartógrafo desenha uma vez; quando
## o jogador fecha o relatório, o papel já não vale — quem quiser olhar de
## novo compra outro. É informação perecível, e é isso que a torna cara.
static func comprar_rota(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["ouro"]) < PRECO_ROTA:
		return {"ok": false, "msg": "Cartógrafos bêbados custam %d." % PRECO_ROTA}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - PRECO_ROTA
	var linhas: Array = Economia.retrato_de_precos(state)
	var melhor := _melhor_rota(state)
	var msg := "O cartógrafo desenha de memória, e a memória dele é de hoje."
	if not melhor.is_empty():
		msg = "\"%s: compre em %s por %d, venda em %s por %d — %d de lucro por unidade.\"" % [
			Dados.MERCADORIAS[melhor["bem"]]["nome"],
			_nome_reino(state, melhor["compra"]), melhor["preco_compra"],
			_nome_reino(state, melhor["venda"]), melhor["preco_venda"], melhor["lucro"]]
	return {"ok": true, "msg": msg, "linhas": linhas, "melhor": melhor}

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

## Mercador leal: entrega a MESMA leitura de `comprar_rota`, uma vez por mês,
## sem cobrar — é o ofício dele, não um serviço de taverna. Silencioso se
## não houver rota lucrativa, como o serviço pago também é.
static func _tick_mercador(state: Dictionary, log: Callable) -> void:
	if not Cidadaos.oficio_ativo(state, "mercador"):
		return
	var melhor := _melhor_rota(state)
	if melhor.is_empty():
		return
	_diz(log, "Seu mercador: \"%s vale mais em %s do que em %s — leve a carga.\""
		% [Dados.MERCADORIAS[melhor["bem"]]["nome"], _nome_reino(state, melhor["venda"]),
			_nome_reino(state, melhor["compra"])])

## Todo mês: cobra o soldo e entrega notícia. Informante sem pagamento some.
static func tick(state: Dictionary, log: Callable) -> void:
	_tick_mercador(state, log)
	if not state.has("informantes") or state["informantes"].is_empty():
		return
	var custo: int = 25 * state["informantes"].size()
	if int(state["jogador"]["ouro"]) < custo:
		_diz(log, "Sem soldo, seus informantes sumiram nas sombras.")
		state["informantes"] = []
		return
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	Livro.registrar(state, "taverna", "ouro", -custo, "Informantes na corte")
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
			_diz(log, "Informante: %s." % Dados.rnd(noticias))

static func _nome_reino(state: Dictionary, id: String) -> String:
	var r := Geopolitica.reino_por_id(state, id)
	return str(r.get("nome", id))

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
