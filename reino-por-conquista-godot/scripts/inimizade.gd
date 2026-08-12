# ============================================================
# INIMIZADE — ter inimigo passa a doer TODO DIA.
#
# Antes, declarar guerra mudava um número e o mundo seguia igual: o
# jogador podia estar em guerra com três reinos e caminhar pelo mapa como
# quem passeia. A guerra só existia quando ELE decidia marchar.
#
# Aqui a inimizade tem preço diário, e o preço depende de ONDE você está e
# do que você tem a perder:
#
#   com terra .......... 10%/dia de uma coluna inimiga aparecer no seu
#                        portão. O jogador escolhe: sair com o exército ou
#                        deixar a guarda da casa segurar sozinha.
#   sem terra .......... 15%/dia de emboscada na estrada. Perder é ser
#                        capturado — mercenário sem casa não tem para onde
#                        recuar.
#   na corte inimiga ... 75%. Entrar na capital de quem te odeia é entregar
#                        o pescoço; quem sobrevive sai a ferros.
#   em corte aliada .... 0%. Ali você está sob o teto de alguém.
#   em corte neutra .... 10% — e ZERO se aquele reino também estiver em
#                        guerra com o seu inimigo. Inimigo do meu inimigo
#                        não deixa te pegarem na praça dele.
#
# Tudo roda no passar do DIA, junto com o resto do relógio.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Combate = preload("res://scripts/combate.gd")
const Sinais = preload("res://scripts/sinais.gd")

const CHANCE_ATAQUE_TERRA := 0.10
const CHANCE_EMBOSCADA_SEM_TERRA := 0.15
const CHANCE_CORTE_INIMIGA := 0.75
const CHANCE_CORTE_NEUTRA := 0.10

## Os reinos em guerra com o jogador.
static func inimigos(state: Dictionary) -> Array:
	var lista: Array = []
	for g in state.get("guerras", []):
		if str(g.get("a", "")) == "jogador":
			lista.append(str(g["b"]))
		elif str(g.get("b", "")) == "jogador":
			lista.append(str(g["a"]))
	return lista

static func em_guerra(state: Dictionary) -> bool:
	return not inimigos(state).is_empty()

## Dois reinos estão em guerra entre si?
static func _guerra_entre(state: Dictionary, a: String, b: String) -> bool:
	for g in state.get("guerras", []):
		var x := str(g.get("a", ""))
		var y := str(g.get("b", ""))
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false

## A chance de ALGO acontecer hoje, onde o jogador está. Devolve também o
## tipo, porque emboscada na estrada e assalto à sua terra são coisas
## diferentes — e a interface precisa saber qual das duas anunciar.
static func risco_do_dia(state: Dictionary) -> Dictionary:
	var meus := inimigos(state)
	if meus.is_empty():
		return {"chance": 0.0, "tipo": "", "por": ""}
	var Jogo = load("res://scripts/jogo.gd")
	if Jogo.esta_preso(state):
		return {"chance": 0.0, "tipo": "", "por": ""}
	var onde := str(state.get("local", ""))
	# 1) na corte de um inimigo: quase certeza
	if meus.has(onde):
		return {"chance": CHANCE_CORTE_INIMIGA, "tipo": "captura", "por": onde}
	# 2) em corte de terceiro: depende de quem manda ali
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var anfitriao: Dictionary = Geopolitica.reino_por_id(state, onde)
	if not anfitriao.is_empty():
		var rel_anfitriao: int = int(state.get("tags", {})
			.get("rei_" + onde, {"relacao": 0})["relacao"])
		if rel_anfitriao >= 60:
			return {"chance": 0.0, "tipo": "", "por": ""}   # sob o teto de um aliado
		# inimigo do meu inimigo: eles não deixam te pegarem na praça deles
		for inimigo in meus:
			if _guerra_entre(state, onde, inimigo):
				return {"chance": 0.0, "tipo": "", "por": ""}
		return {"chance": CHANCE_CORTE_NEUTRA, "tipo": "emboscada", "por": meus[0]}
	# 3) na sua terra (ou em terra de ninguém)
	if state.get("terra") != null and onde == "jogador":
		return {"chance": CHANCE_ATAQUE_TERRA, "tipo": "ataque_terra", "por": meus[0]}
	return {"chance": CHANCE_EMBOSCADA_SEM_TERRA, "tipo": "emboscada", "por": meus[0]}

## Rola o dado do dia. Devolve {} quando o dia foi calmo; senão devolve o
## acontecimento para a interface abrir o modal.
static func tick_dia(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	var r := risco_do_dia(state)
	if float(r["chance"]) <= 0.0 or randf() >= float(r["chance"]):
		return {}
	var Rotas = load("res://scripts/rotas.gd")
	var quem: String = Rotas.nome_do(state, str(r["por"]))
	match str(r["tipo"]):
		"ataque_terra":
			var forca := _forca_do_inimigo(state, str(r["por"]), 0.35)
			return {"tipo": "ataque_terra", "por": str(r["por"]), "nome": quem,
				"tropas": forca, "homens": Combate.total_homens(forca),
				"titulo": "Coluna de %s no seu portão" % quem,
				"texto": "Vieram pela estrada baixa, ao amanhecer: %d homens de %s formando diante das suas cercas.\n\nVocê pode sair com o exército — e arriscar os homens no campo aberto — ou trancar tudo e deixar a guarda da casa segurar o portão." % [
					Combate.total_homens(forca), quem]}
		"captura":
			return {"tipo": "captura", "por": str(r["por"]), "nome": quem,
				"titulo": "Reconheceram você",
				"texto": "Você está na capital de quem te declarou guerra, e alguém na praça sabe a sua cara.\n\nSão muitos, e o portão da cidade já foi fechado."}
	var forca_e := _forca_do_inimigo(state, str(r["por"]), 0.18)
	return {"tipo": "emboscada", "por": str(r["por"]), "nome": quem,
		"tropas": forca_e, "homens": Combate.total_homens(forca_e),
		"titulo": "Emboscada na estrada",
		"texto": "Homens de %s esperavam na curva — %d deles, e não é encontro de acaso: alguém contou onde você estava.\n\nSem casa para onde recuar, quem perde aqui acorda numa cela." % [
			quem, Combate.total_homens(forca_e)]}

## Uma fatia do exército do inimigo — não o exército inteiro. Quem ataca
## manda uma coluna, não a guarnição toda.
static func _forca_do_inimigo(state: Dictionary, reino_id: String, fatia: float) -> Dictionary:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, reino_id)
	var saida := {}
	if r.is_empty():
		return {"lanceiro": Dados.ri(8, 18), "arqueiro": Dados.ri(3, 8)}
	for tipo in r.get("tropas", {}):
		var n: int = roundi(int(r["tropas"][tipo]) * fatia)
		if n > 0:
			saida[tipo] = n
	if saida.is_empty():
		saida = {"lanceiro": Dados.ri(6, 14)}
	return saida

## O jogador sai com o exército. Batalha normal — e a derrota, sem terra,
## termina em cela.
static func enfrentar(state: Dictionary, ev: Dictionary,
		log: Callable = Callable()) -> Dictionary:
	var inimigo := {"tropas": (ev.get("tropas", {}) as Dictionary).duplicate(true),
		"equip": 1}
	var rel := Combate.batalhar(state, inimigo, str(ev.get("titulo", "Emboscada")))
	var Jogo = load("res://scripts/jogo.gd")
	if not bool(rel.get("vitoria", false)):
		if state.get("terra") == null or str(ev["tipo"]) != "ataque_terra":
			Jogo.prender(state, 2, log)
			rel["preso"] = true
	else:
		state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 8
		rel["ganho_renome"] = 8
	Sinais.emitir(&"inimizade", {"tipo": str(ev["tipo"]), "vitoria": rel.get("vitoria", false)})
	return rel

## O jogador tranca as portas: quem luta é a guarda da casa (e os lordes).
## Sem exército em risco, mas a terra sofre se o portão cair.
static func deixar_a_guarda(state: Dictionary, ev: Dictionary,
		log: Callable = Callable()) -> Dictionary:
	var guarda := {}
	var elite: int = int(state["jogador"].get("guardas", 0))
	if elite > 0:
		guarda["espadachim"] = elite * 2
	var Cidadaos = load("res://scripts/cidadaos.gd")
	for lorde in Cidadaos.lordes(state):
		if not bool(lorde.get("capturado", false)):
			guarda["lanceiro"] = int(guarda.get("lanceiro", 0)) + 4
	if state.get("terra") != null:
		guarda["campones"] = int(state["terra"]["nivel"]) * 8 + 5
	var atacante: Dictionary = (ev.get("tropas", {}) as Dictionary).duplicate(true)
	var rel := Combate.resolver_assalto(atacante, guarda, 1.0, 1.0, "cerco")
	var aguentou: bool = Combate.total_homens(guarda) > 0
	rel["contexto"] = "Defesa da casa"
	rel["vitoria"] = aguentou
	# a guarda que morreu, morreu: o número no state cai junto
	var perdidos: int = maxi(0, elite * 2 - int(guarda.get("espadachim", 0)))
	if perdidos > 0:
		state["jogador"]["guardas"] = maxi(0, elite - ceili(perdidos / 2.0))
	if not aguentou and state.get("terra") != null:
		var t: Dictionary = state["terra"]
		t["alimento"] = roundi(int(t["alimento"]) * 0.5)
		t["felicidade"] = clampi(int(t["felicidade"]) - 15, 0, 100)
		if log.is_valid():
			log.call("O portão caiu. Queimaram metade do celeiro e o povo viu.")
	elif log.is_valid():
		log.call("A guarda da casa segurou o portão. Custou homens, mas segurou.")
	return rel
