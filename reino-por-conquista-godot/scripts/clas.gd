# ============================================================
# CLÃS MERCENÁRIOS VIA MENSAGEIROS (port de js/clans.js)
# Oferta viaja 1 mês; pode ser interceptada; soldo mensal;
# calote gera saque e má fama entre os clãs.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Livro = preload("res://scripts/livro.gd")
const Dialogo = preload("res://scripts/dialogo.gd")

# `especialidade` é a classe em que o clã dá +20% (ver Combate.bonus_de):
# contratar os Filhos da Estepe é escolher uma DOUTRINA, não só comprar homens.
const CLAS := [
	{"id": "cla_lobos", "nome": "Lobos de Ferro", "lider": "Ragnar Meio-Lobo",
	 "contingente": {"lanceiro": 25}, "preco_base": 350, "soldo": 45, "renome_min": 20,
	 "especialidade": "inf"},
	{"id": "cla_corvos", "nome": "Corvos da Névoa", "lider": "Sira Olho-Vazio",
	 "contingente": {"arqueiro": 20}, "preco_base": 300, "soldo": 38, "renome_min": 15,
	 "especialidade": "arq"},
	{"id": "cla_estepe", "nome": "Filhos da Estepe", "lider": "Khal Tembu",
	 "contingente": {"cav_leve": 8}, "preco_base": 500, "soldo": 60, "renome_min": 35,
	 "especialidade": "cav"},
	{"id": "cla_machados", "nome": "Machados do Norte", "lider": "Ulf Barba-Gelo",
	 "contingente": {"barbaro": 15, "arqueiro": 8}, "preco_base": 400, "soldo": 50, "renome_min": 25,
	 "especialidade": "inf"},
]

static func cla_por_id(id: String) -> Dictionary:
	for c in CLAS:
		if c["id"] == id:
			return c
	return {}

static func ativo(state: Dictionary, cla_id: String) -> Dictionary:
	for a in state["clas_ativos"]:
		if a["id"] == cla_id:
			return a
	return {}

static func enviar_mensageiro(state: Dictionary, cla_id: String, oferta: int) -> Dictionary:
	var cla := cla_por_id(cla_id)
	if cla.is_empty():
		return {"ok": false, "msg": "Clã desconhecido."}
	if not ativo(state, cla_id).is_empty():
		return {"ok": false, "msg": "Já sob contrato."}
	for m in state["mensageiros"]:
		if m["cla"] == cla_id:
			return {"ok": false, "msg": "Mensageiro já na estrada."}
	if state["jogador"]["renome"] < cla["renome_min"]:
		return {"ok": false, "msg": "Renome insuficiente (%d/%d)." % [state["jogador"]["renome"], cla["renome_min"]]}
	if state["jogador"]["ouro"] < oferta + 10:
		return {"ok": false, "msg": "Ouro insuficiente."}
	state["jogador"]["ouro"] -= 10
	state["mensageiros"].append({"cla": cla_id, "oferta": oferta, "meses": 1})
	return {"ok": true, "msg": "Mensageiro a caminho."}

static func tick(state: Dictionary, log: Callable) -> void:
	# mensageiros
	var pendentes: Array = []
	for m in state["mensageiros"]:
		m["meses"] -= 1
		if m["meses"] > 0:
			pendentes.append(m)
			continue
		var cla := cla_por_id(m["cla"])
		if state["guerras"].size() > 0 and randf() < 0.15:
			_diz(log, "Mensageiro para %s interceptado na estrada." % cla["nome"])
			continue
		var relacao: int = state["tags"].get(cla["id"], {"relacao": 0})["relacao"]
		var generosidade: float = float(m["oferta"]) / cla["preco_base"]
		# CARISMA entra aqui: negociar com chefe mercenário é conversa, e
		# o atributo só servia para acelerar cortejo. Neutro em 5, ±2% por
		# ponto — pesa menos que a oferta, como tem que ser (mercenário
		# ouve moeda antes de ouvir charme).
		var carisma: int = int(state["jogador"].get("atributos", {}).get("carisma", 5))
		var chance: float = minf(0.95, generosidade * 0.55
			+ state["jogador"]["renome"] / 200.0 + relacao / 150.0
			+ (carisma - 5) * 0.02)
		if state["jogador"].get("traiu_clas", false):
			chance -= 0.3
		if generosidade >= 1.5:
			chance = maxf(chance, 0.9)
		if randf() < chance and state["jogador"]["ouro"] >= m["oferta"]:
			state["jogador"]["ouro"] -= m["oferta"]
			state["clas_ativos"].append({"id": cla["id"], "meses": 6,
				"contingente": cla["contingente"].duplicate(),
				"especialidade": cla.get("especialidade", "")})
			for tipo in cla["contingente"]:
				state["jogador"]["tropas"][tipo] = int(state["jogador"]["tropas"].get(tipo, 0)) + int(cla["contingente"][tipo])
			Dialogo.mudar_relacao(state, cla["id"], 10, "contrato")
			_diz(log, "Os %s aceitaram o contrato!" % cla["nome"])
		else:
			_diz(log, "Os %s recusaram a oferta de %d." % [cla["nome"], m["oferta"]])
	state["mensageiros"] = pendentes

	# contratos ativos
	var vivos: Array = []
	for a in state["clas_ativos"]:
		var cla := cla_por_id(a["id"])
		if state["jogador"]["ouro"] >= cla["soldo"]:
			state["jogador"]["ouro"] -= int(cla["soldo"])
			Livro.registrar(state, "clas", "ouro", -int(cla["soldo"]), "Soldo dos mercenários")
			a["meses"] -= 1
			if a["meses"] <= 0:
				_remover_contingente(state, a)
				Dialogo.mudar_relacao(state, a["id"], 10, "contrato honrado")
				_diz(log, "Contrato com os %s encerrado em bons termos." % cla["nome"])
			else:
				vivos.append(a)
		else:
			_remover_contingente(state, a)
			state["jogador"]["traiu_clas"] = true
			Dialogo.mudar_relacao(state, a["id"], -50, "calote")
			if randf() < 0.4 and state["terra"] != null:
				var saque: int = mini(int(state["terra"]["alimento"]), 40)
				state["terra"]["alimento"] = int(state["terra"]["alimento"]) - saque
				_diz(log, "Os %s saquearam %d de alimento ao partir sem soldo!" % [cla["nome"], saque])
			else:
				_diz(log, "Sem soldo, os %s rasgaram o contrato." % cla["nome"])
	state["clas_ativos"] = vivos

static func _remover_contingente(state: Dictionary, a: Dictionary) -> void:
	for tipo in a["contingente"]:
		state["jogador"]["tropas"][tipo] = maxi(0,
			int(state["jogador"]["tropas"].get(tipo, 0)) - int(a["contingente"][tipo]))

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
