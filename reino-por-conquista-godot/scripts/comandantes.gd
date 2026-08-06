# ============================================================
# COMANDANTES — quem lidera a marcha muda o que a marcha faz.
#
# Até aqui as tropas lutavam só pelos números crus de dados.gd. Um comandante
# põe um NOME na frente delas e um bônus atrás: o próprio senhor, um lorde
# que subiu de cidadão, ou o capitão contratado na taverna.
#
# O risco é o que dá peso: se o exército for obliterado, o comandante NÃO
# morre — é CAPTURADO, e cai no sistema de prisão que já existe. Mandar seu
# melhor general junto do exército é apostar duas coisas de uma vez.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Cada perfil de comandante dá UM bônus claro — nada de somar cinco efeitos
## pequenos que ninguém consegue sentir jogando.
const PERFIS := {
	"senhor": {
		"nome": "O próprio senhor", "atributo": "forca",
		"desc": "+15% de ataque em todas as fases; se cair, é você quem vai preso",
		"atq": 0.15, "comida_cerco": 0.0, "moral_cerco": 0,
	},
	"capitao": {
		"nome": "Capitão de mercenários", "atributo": "forca",
		"desc": "+10% de ataque e a tropa aguenta melhor o cerco",
		"atq": 0.10, "comida_cerco": 0.0, "moral_cerco": 3,
	},
	"quartel_mestre": {
		"nome": "Quartel-mestre", "atributo": "gestao",
		"desc": "-20% de comida no cerco: campanha longa fica viável",
		"atq": 0.0, "comida_cerco": -0.20, "moral_cerco": 1,
	},
	"batedor": {
		"nome": "Batedor veterano", "atributo": "intriga",
		"desc": "+20% na fase de Disparo e menos emboscadas na estrada",
		"atq": 0.0, "atq_arq": 0.20, "comida_cerco": 0.0, "moral_cerco": 0,
		"perigo": -0.5,
	},
}

## Quem está disponível para comandar: você, seus lordes jurados e o capitão.
static func disponiveis(state: Dictionary) -> Array:
	var lista: Array = [{
		"id": "senhor", "perfil": "senhor",
		"nome": str(state["jogador"]["nome"]),
		"atributo": int(state["jogador"]["atributos"]["forca"]),
	}]
	var Cidadaos = load("res://scripts/cidadaos.gd")
	for n in Cidadaos.lordes(state):
		# um lorde comanda conforme a ambição que o levou até ali
		var perfil: String = "quartel_mestre" if int(n.get("ambicao", 5)) < 6 else "capitao"
		lista.append({"id": "lorde:" + str(n["nome"]), "perfil": perfil,
			"nome": str(n["nome"]), "atributo": int(n.get("ambicao", 5))})
	for a in state.get("clas_ativos", []):
		lista.append({"id": "cla:" + str(a["id"]), "perfil": "batedor",
			"nome": "Chefe dos " + str(a["id"]).replace("cla_", ""),
			"atributo": 6})
	return lista

static func por_id(state: Dictionary, id: String) -> Dictionary:
	for c in disponiveis(state):
		if c["id"] == id:
			return c
	return {}

## O bônus de ataque total. O atributo do comandante escala o efeito do
## perfil — um senhor forte lidera melhor que um senhor fraco.
static func bonus_ataque(cmd: Dictionary, classe: String = "") -> float:
	if cmd.is_empty():
		return 1.0
	var p: Dictionary = PERFIS.get(cmd.get("perfil", ""), {})
	if p.is_empty():
		return 1.0
	var escala: float = 0.5 + int(cmd.get("atributo", 5)) * 0.1   # 5 → 1.0
	var b: float = float(p.get("atq", 0.0))
	if classe == "arq":
		b += float(p.get("atq_arq", 0.0))
	return 1.0 + b * escala

## Multiplicador de comida no cerco (1.0 = sem efeito).
static func fator_comida_cerco(cmd: Dictionary) -> float:
	if cmd.is_empty():
		return 1.0
	var p: Dictionary = PERFIS.get(cmd.get("perfil", ""), {})
	return 1.0 + float(p.get("comida_cerco", 0.0))

## Quanto de moral o comandante segura por fase de cerco.
static func moral_cerco(cmd: Dictionary) -> int:
	if cmd.is_empty():
		return 0
	return int(PERFIS.get(cmd.get("perfil", ""), {}).get("moral_cerco", 0))

## Redução do perigo da estrada (batedor).
static func fator_perigo(cmd: Dictionary) -> float:
	if cmd.is_empty():
		return 1.0
	return 1.0 + float(PERFIS.get(cmd.get("perfil", ""), {}).get("perigo", 0.0))

## O exército foi obliterado: o comandante é CAPTURADO, não morto.
## Devolve o que a UI deve narrar; quem aplica a pena é jogo.gd.
static func capturar(state: Dictionary, cmd: Dictionary, log: Callable) -> Dictionary:
	if cmd.is_empty():
		return {}
	var id: String = str(cmd.get("id", ""))
	if id == "senhor":
		log.call("Seu estandarte caiu. Você foi capturado no campo.")
		return {"preso": 3, "quem": "senhor", "nome": str(cmd["nome"])}
	if id.begins_with("lorde:"):
		# um lorde capturado deixa de render imposto até ser resgatado
		var Cidadaos = load("res://scripts/cidadaos.gd")
		for n in Cidadaos.lista(state):
			if "lorde:" + str(n["nome"]) == id:
				n["capturado"] = true
		log.call("%s foi capturado e está a ferros em terra inimiga." % cmd["nome"])
		return {"preso": 0, "quem": "lorde", "nome": str(cmd["nome"]), "resgate": 300}
	log.call("%s não voltou do campo." % cmd["nome"])
	return {"preso": 0, "quem": "outro", "nome": str(cmd["nome"])}

## Resgate de um lorde capturado — ouro por lealdade.
static func resgatar(state: Dictionary, nome: String) -> Dictionary:
	var Cidadaos = load("res://scripts/cidadaos.gd")
	for n in Cidadaos.lista(state):
		if str(n["nome"]) != nome or not bool(n.get("capturado", false)):
			continue
		var preco := 300
		if int(state["jogador"]["ouro"]) < preco:
			return {"ok": false, "msg": "O resgate custa %d de ouro." % preco}
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - preco
		n["capturado"] = false
		n["lealdade"] = clampi(int(n.get("lealdade", 50)) + 20, 0, 100)
		return {"ok": true, "msg": "%s voltou para casa, e não vai esquecer." % nome}
	return {"ok": false, "msg": "Ninguém com esse nome está preso."}
