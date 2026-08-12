# ============================================================
# TERRAS BÁRBARAS — a única porta para fundar um reino DO ZERO.
#
# Todo o resto do jogo é herdar: você toma o trono de alguém, casa numa
# casa que já existe, jura a um rei que já reina. Aqui não há trono para
# tomar — há três clãs, nenhuma lei, e a chance de escrever um nome novo
# no mapa.
#
# E há uma regra dura: NÃO SE INVADE O QUE NÃO SE CONHECE. Sem mandar
# espião primeiro, os clãs são um borrão e o exército marcha às cegas —
# o jogo recusa a ordem em vez de deixar o jogador jogar 200 homens num
# número que ele nunca viu.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Combate = preload("res://scripts/combate.gd")
const Sinais = preload("res://scripts/sinais.gd")

const ID := "barbaros"
const CUSTO_ESPIAO := 180
const RENOME_PARA_FUNDAR := 60

## Os três clãs da estepe. Nomes e força saem de semente fixa: são os
## mesmos da primeira à última partida daquele save, então o jogador pode
## espiar hoje e marchar em três meses sabendo o que o espera.
const CLAS := [
	{"id": "geleira", "nome": "Tribo da Geleira Sangrenta",
		"nota": "Descem do gelo uma vez por geração. Esta é a geração."},
	{"id": "estepe", "nome": "Horda da Estepe Árida",
		"nota": "Não constroem muros porque não param em lugar nenhum."},
	{"id": "lama", "nome": "Senhores da Lama",
		"nota": "Vivem no pântano que engole cavalo e cavaleiro juntos."},
]

static func _ficha(state: Dictionary) -> Dictionary:
	if not (state.get("barbaros") is Dictionary):
		state["barbaros"] = {"reconhecido": false, "conquistado": false, "forcas": {}}
	return state["barbaros"]

static func reconhecido(state: Dictionary) -> bool:
	return bool(_ficha(state).get("reconhecido", false))

static func conquistado(state: Dictionary) -> bool:
	return bool(_ficha(state).get("conquistado", false))

## A força de cada clã. Existe desde sempre no save (é sorteada uma vez),
## mas só é MOSTRADA depois do reconhecimento — o segredo é a informação,
## não o número.
static func forcas(state: Dictionary) -> Dictionary:
	var f := _ficha(state)
	if (f.get("forcas") as Dictionary).is_empty():
		var sorteio := {}
		for c in CLAS:
			sorteio[c["id"]] = {
				"barbaro": Dados.ri(30, 60),
				"lanceiro": Dados.ri(10, 25),
				"arqueiro": Dados.ri(8, 20),
			}
		f["forcas"] = sorteio
	return f["forcas"]

static func total_de_homens(state: Dictionary) -> int:
	var t := 0
	for id in forcas(state):
		t += Combate.total_homens(forcas(state)[id])
	return t

## Mandar o espião. Custa ouro e um dia; revela a conta dos três clãs.
static func espiar(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	if reconhecido(state):
		return {"ok": false, "msg": "Você já sabe o que há lá. Marche ou desista."}
	if int(state["jogador"]["ouro"]) < CUSTO_ESPIAO:
		return {"ok": false,
			"msg": "Ninguém atravessa a fronteira de graça: %d de ouro." % CUSTO_ESPIAO}
	var Jogo = load("res://scripts/jogo.gd")
	if int(state.get("dia", 1)) + 1 > Jogo.DIAS_POR_MES + 1:
		return {"ok": false, "msg": "Não sobra dia no mês para esperar o batedor."}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - CUSTO_ESPIAO
	forcas(state)                                  # garante o sorteio
	_ficha(state)["reconhecido"] = true
	Jogo.passar_dia(state, log)
	if log.is_valid():
		_diz(log, "Seu batedor voltou das Terras Bárbaras: são %d homens em três clãs."
			% total_de_homens(state))
	Sinais.emitir(&"barbaros_reconhecidos", {"homens": total_de_homens(state)})
	return {"ok": true, "msg": "O batedor conta %d homens, em três clãs." % total_de_homens(state)}

static func pode_invadir(state: Dictionary) -> Dictionary:
	if conquistado(state):
		return {"ok": false, "msg": "As Terras Bárbaras já são suas."}
	if str(state.get("local", "")) != ID:
		return {"ok": false, "msg": "Você precisa estar na fronteira para atravessá-la."}
	if not reconhecido(state):
		return {"ok": false,
			"msg": "Marchar às cegas contra três clãs é enterrar o seu exército. Mande um batedor antes."}
	if Combate.total_homens(state["jogador"]["tropas"]) < 40:
		return {"ok": false, "msg": "Menos de 40 homens não atravessam a fronteira."}
	return {"ok": true}

## A invasão: um assalto por clã, na ordem, com o SEU exército carregando
## as baixas de um para o outro. Vencer os três é tomar a região.
static func invadir(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	var check := pode_invadir(state)
	if not bool(check["ok"]):
		return check
	var Jogo_i = load("res://scripts/jogo.gd")
	if Jogo_i.esta_preso(state):
		return Jogo_i.recusa_preso(state)
	var rel := {"ok": true, "fases": [], "vitoria": true,
		"baixas": 0, "clas_vencidos": []}
	var antes := Combate.total_homens(state["jogador"]["tropas"])
	var bonus := Combate.bonus_de(state, state["jogador"]["tropas"])
	for c in CLAS:
		var guarnicao: Dictionary = (forcas(state)[c["id"]] as Dictionary).duplicate(true)
		var r: Dictionary = Combate.resolver_assalto(
			state["jogador"]["tropas"], guarnicao, bonus, 1.0, "cerco")
		rel["fases"].append({"cla": str(c["nome"]),
			"vitoria": bool(r["vitoria"]),
			"baixas_suas": int(r["baixas_atacante"]),
			"baixas_deles": int(r["baixas_defensor"])})
		# o que sobrou do clã continua vivo: recuar não apaga o desgaste
		forcas(state)[c["id"]] = guarnicao
		if bool(r["vitoria"]):
			rel["clas_vencidos"].append(str(c["nome"]))
		else:
			rel["vitoria"] = false
			break
		if Combate.total_homens(state["jogador"]["tropas"]) == 0:
			rel["vitoria"] = false
			break
	rel["baixas"] = antes - Combate.total_homens(state["jogador"]["tropas"])
	if rel["vitoria"]:
		_ficha(state)["conquistado"] = true
		state["jogador"]["renome"] = int(state["jogador"]["renome"]) + 40
		if log.is_valid():
			_diz(log, "As Terras Bárbaras caíram. Três clãs, um senhor — e nenhum trono ainda.")
		Sinais.emitir(&"barbaros_conquistados", {})
	elif log.is_valid():
		_diz(log, "A invasão das Terras Bárbaras fracassou: %d homens ficaram no gelo."
			% int(rel["baixas"]))
	return rel

## FUNDAR O REINO — o que não existe em nenhum outro lugar do jogo.
##
## Não é herdar um trono: é criar uma casa nova no mapa, com capital,
## produção e brasão próprios, e entrar na geopolítica como igual dos
## seis. O reino nasce POBRE de propósito — quem funda começa do chão.
static func pode_fundar(state: Dictionary) -> Dictionary:
	if not conquistado(state):
		return {"ok": false, "msg": "Primeiro se toma a terra; depois se funda o reino."}
	if str(state["jogador"].get("rei_de", "")) != "":
		return {"ok": false, "msg": "Você já tem uma coroa."}
	if int(state["jogador"]["renome"]) < RENOME_PARA_FUNDAR:
		return {"ok": false,
			"msg": "Ninguém segue um nome pequeno: %d de renome para fundar uma casa."
				% RENOME_PARA_FUNDAR}
	return {"ok": true}

static func fundar_reino(state: Dictionary, nome_casa: String, capital: String,
		log: Callable = Callable()) -> Dictionary:
	var check := pode_fundar(state)
	if not bool(check["ok"]):
		return check
	var nome := nome_casa.strip_edges()
	if nome == "":
		nome = "Casa de " + str(state["jogador"]["nome"]).split(" ")[0]
	var cap := capital.strip_edges()
	if cap == "":
		cap = "Forte da Fronteira"
	var novo := {
		"id": ID, "nome": nome, "cor": "#7a5c2e", "nobres": 2,
		"producao": ["madeira", "pedra"],          # o que a estepe dá: mata e rocha
		"capital": cap,
		"rei": {"id": "rei_" + ID, "nome": str(state["jogador"]["nome"]),
			"genero": "m", "personalidade": "orgulhoso"},
		"tesouro": 200, "celeiro": 200, "madeireira": 150,
		"moral": 100, "equip": 0, "fila": [],
		"tropas": {"barbaro": 20, "lanceiro": 10},
		"fundado_pelo_jogador": true,
	}
	state["reinos"].append(novo)
	var Geopolitica = load("res://scripts/geopolitica.gd")
	Geopolitica.inicializar(state)                 # relações com os seis
	novo["forca"] = Geopolitica.forca_de(novo)
	state["jogador"]["rei_de"] = ID
	state["jogador"]["meses_reinando"] = 0
	# um mercado próprio, senão a praça nova não existiria para o comércio
	var Economia = load("res://scripts/economia.gd")
	if not state["mercados"].has(ID):
		var m := {}
		for g_id in Dados.MERCADORIAS:
			m[g_id] = {"oferta": 1.6 if novo["producao"].has(g_id) else 1.0, "demanda": 1.0}
		state["mercados"][ID] = m
	if log.is_valid():
		_diz(log, "Nasce %s, com capital em %s. O mapa tem sete casas — e você é rei de uma."
			% [nome, cap])
	Sinais.emitir(&"reino_fundado", {"nome": nome, "capital": cap})
	return {"ok": true, "msg": "%s está no mapa. Você é rei." % nome, "reino": novo}

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
