# ============================================================
# NÚCLEO DO JOGO (port de js/game.js)
# Estado, turno mensal, morte e herança dinástica.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Clas = preload("res://scripts/clas.gd")
const Intriga = preload("res://scripts/intriga.gd")
const Contratos = preload("res://scripts/contratos.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Sinais = preload("res://scripts/sinais.gd")

const ARQUIVO_SAVE := "user://save.json"

static func novo_jogo(nome: String = "") -> Dictionary:
	var state := {
		"ano": 1, "mes": 3,
		"jogador": {
			"nome": nome if nome != "" else Dados.rnd(Dados.NOMES_M) + " " + Dados.rnd(Dados.SOBRENOMES),
			"idade": 22,
			"atributos": {"forca": Dados.ri(4, 7), "carisma": Dados.ri(4, 7),
				"gestao": Dados.ri(4, 7), "intriga": Dados.ri(3, 6)},
			"renome": 0, "ouro": 150, "crueldade": 0,
			"tropas": _tropas_zeradas({"lanceiro": 5}),
			"equip": 0, "formacao": "linha", "guardas": 0,
			"rei_de": "", "meses_reinando": 0, "meses_sem_pagar": 0, "meses_imperador": 0,
		},
		"reinos": Dados.REINOS_BASE.duplicate(true),
		"guerras": [], "tags": {}, "segredos": [], "casus_belli": [],
		"carga": {}, "terra": null, "local": "touros",
		"familia": {"conjuge": null, "filhos": []},
		"mensageiros": [], "clas_ativos": [], "cartas": [],
		"cronica": [], "contratos": [], "evento_pendente": null, "chantagem_pendente": null,
		"fim": null,
		# ---- Fase 3 ----
		"fila_recrutamento": [],   # lotes em treino (recrutamento.gd)
		"relacoes_npc": {},        # opinião de cada par de reinos (geopolitica.gd)
		"pactos": [],              # comércio e alianças entre NPCs
		"choques": [],             # empurrões de preço com prazo (economia.gd)
		"flagras": {},             # espiões seus pegos por reino (intriga.gd)
		"informantes": [],         # ouvidos comprados na taverna
	}
	Economia.inicializar_mercados(state)
	Geopolitica.inicializar(state)
	state["contratos"] = Contratos.gerar(state)
	var log := log_para(state)
	log.call("Ano 1. Você é %s: sem terras, sem título, com %d moedas e 5 lanceiros leais." %
		[state["jogador"]["nome"], state["jogador"]["ouro"]])
	return state

## Um dicionário com TODAS as tropas do catálogo em zero, para o exército
## nunca ter buracos. Sem isso, código que faz tropas["barbaro"] += 1 num
## save antigo criaria a chave sozinho e a UI mostraria a lista incompleta.
static func _tropas_zeradas(inicial: Dictionary = {}) -> Dictionary:
	var t := {}
	for tipo in Dados.TROPAS:
		t[tipo] = int(inicial.get(tipo, 0))
	return t

static func log_para(state: Dictionary) -> Callable:
	return func(msg: String):
		state["cronica"].push_front({"ano": state["ano"], "mes": state["mes"], "msg": msg})
		if state["cronica"].size() > 60:
			state["cronica"].pop_back()

static func passar_mes(state: Dictionary) -> void:
	if state["fim"] != null or state["evento_pendente"] != null:
		return
	var log := log_para(state)

	# ---- CADEIA ----
	# O tempo PASSA na masmorra (é essa a punição), mas o jogador não age.
	# Modelar prisão como evento_pendente travaria o jogo: o guard acima
	# retorna cedo e os meses nunca correriam.
	if int(state["jogador"].get("preso_ate", 0)) > _mes_absoluto(state):
		state["mes"] += 1
		if state["mes"] > 12:
			state["mes"] = 1
			state["ano"] += 1
		log.call("Mais um mês a ferros. As paredes escorrem.")
		Economia.tick_mercados(state)         # o mundo segue sem você
		Economia.tick_choques(state)
		Economia.tick_guerras(state, log)
		Geopolitica.tick(state, log)
		# de propósito: sem tick_terra e sem tick_exercito — sua casa apodrece
		return

	state["mes"] += 1
	if state["mes"] > 12:
		state["mes"] = 1
		state["ano"] += 1
		_envelhecer(state, log)
		if state["fim"] != null:
			return
	Economia.talvez_iniciar_guerra(state, log)
	Economia.tick_guerras(state, log)
	Economia.tick_choques(state)          # antes de tick_mercados: o choque
	Economia.tick_mercados(state)         # empurra, o mercado então relaxa
	Economia.tick_terra(state, log)
	Economia.tick_exercito(state, log)
	Geopolitica.tick(state, log)          # o mundo dos NPCs anda sozinho
	Cidadaos.tick(state, log)             # a sua sociedade também
	Taverna.tick(state, log)              # informantes cobram e reportam
	# um mês de jogo vale SEG_POR_MES de treino no quartel
	Recrutamento.avancar(state, Recrutamento.SEG_POR_MES, log)
	Clas.tick(state, log)
	Intriga.tick_familia(state, log)
	state["contratos"] = Contratos.gerar(state)
	if state["jogador"]["rei_de"] != "":
		state["jogador"]["meses_reinando"] += 1
	# VITÓRIA: ser suserano de TODOS os reinos por 12 meses (conquista via guerra)
	var dominados := 0
	for r in state["reinos"]:
		if r.get("dominado_por", "") == "jogador":
			dominados += 1
	if dominados >= state["reinos"].size() and state["reinos"].size() > 0:
		state["jogador"]["meses_imperador"] = state["jogador"].get("meses_imperador", 0) + 1
		if state["jogador"]["meses_imperador"] >= 12:
			state["fim"] = {"tipo": "vitoria"}
	else:
		state["jogador"]["meses_imperador"] = 0

static func _envelhecer(state: Dictionary, log: Callable) -> void:
	state["jogador"]["idade"] += 1
	for f in state["familia"]["filhos"]:
		f["idade"] += 1
	var idade: int = state["jogador"]["idade"]
	var chance := 0.25 if idade > 65 else (0.10 if idade > 55 else (0.04 if idade > 45 else 0.0))
	if randf() < chance:
		morrer(state, "idade", log)

static func morrer(state: Dictionary, causa: String, log: Callable) -> void:
	var herdeiro: Dictionary = {}
	for f in state["familia"]["filhos"]:
		if f["idade"] >= 16:
			herdeiro = f
			break
	if herdeiro.is_empty():
		state["fim"] = {"tipo": "derrota", "causa": causa}
		return
	log.call("%s morre (%s). %s assume a casa." % [state["jogador"]["nome"], causa, herdeiro["nome"]])
	state["jogador"]["nome"] = herdeiro["nome"]
	state["jogador"]["idade"] = herdeiro["idade"]
	state["jogador"]["atributos"] = herdeiro["atributos"]
	state["jogador"]["crueldade"] = 2 if herdeiro.get("mimado", false) else 0
	state["familia"]["filhos"].erase(herdeiro)
	state["familia"]["conjuge"] = null

static func comprar_terra(state: Dictionary) -> Dictionary:
	if state["terra"] != null:
		return {"ok": false, "msg": "Você já tem terras."}
	if state["jogador"]["renome"] < 25:
		return {"ok": false, "msg": "Renome insuficiente (25)."}
	if state["jogador"]["ouro"] < 300:
		return {"ok": false, "msg": "Terra custa 300 de ouro."}
	state["jogador"]["ouro"] -= 300
	state["terra"] = {"nome": "Vale " + Dados.rnd(["Sereno", "das Pedras", "do Corvo", "Dourado", "Frio"]),
		"nivel": 0, "populacao": 20, "alimento": 80, "madeira": 20, "felicidade": 60}
	return {"ok": true, "msg": "Terra adquirida!"}

static func melhorar_terra(state: Dictionary) -> Dictionary:
	if state["terra"] == null:
		return {"ok": false, "msg": "Sem terras."}
	var t: Dictionary = state["terra"]
	if t["nivel"] >= 5:
		return {"ok": false, "msg": "Nível máximo."}
	var prox: Dictionary = Dados.NIVEIS_TERRA[t["nivel"] + 1]
	if state["jogador"]["ouro"] < prox["custo_ouro"] or t["madeira"] < prox["custo_madeira"]:
		return {"ok": false, "msg": "Recursos insuficientes."}
	state["jogador"]["ouro"] -= int(prox["custo_ouro"])
	t["madeira"] = int(t["madeira"]) - int(prox["custo_madeira"])
	t["nivel"] += 1
	t["populacao"] += Dados.ri(10, 20)
	return {"ok": true, "msg": "Evoluiu para %s!" % prox["nome"]}

# ---------- gestão do exército ----------
## Recrutar agora ENFILEIRA: a tropa leva segundos para ficar pronta.
## Mesma assinatura de antes, então a UI e os testes existentes seguem valendo.
static func recrutar(state: Dictionary, tipo: String, qtd: int) -> Dictionary:
	return Recrutamento.enfileirar(state, tipo, qtd)

## Mês absoluto — usado pela cadeia e por qualquer prazo em meses.
static func _mes_absoluto(state: Dictionary) -> int:
	return int(state["ano"]) * 12 + int(state["mes"])

## Aplica a pena de prisão. Chamada por quem detecta o crime (intriga.gd
## devolve {"prender": N} em vez de chamar isto, para não fechar ciclo).
static func prender(state: Dictionary, meses: int, log: Callable) -> void:
	var j: Dictionary = state["jogador"]
	j["preso_ate"] = _mes_absoluto(state) + meses
	j["ouro"] = int(int(j["ouro"]) * 0.4)
	j["renome"] = maxi(0, int(j["renome"]) - 30)
	for tipo in j["tropas"]:
		j["tropas"][tipo] = int(int(j["tropas"][tipo]) * 0.5)
	Sinais.emitir(&"preso", {"meses": meses})
	log.call("Capturado. %d meses a ferros." % meses)

static func esta_preso(state: Dictionary) -> bool:
	return int(state["jogador"].get("preso_ate", 0)) > _mes_absoluto(state)

static func contratar_guardas(state: Dictionary, qtd: int) -> Dictionary:
	var custo := 60 * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Guarda de elite custa 60/homem (%d)." % custo}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["guardas"] = int(state["jogador"]["guardas"]) + qtd
	return {"ok": true, "msg": "%d guardas de elite contratados." % qtd}

static func melhorar_equip(state: Dictionary) -> Dictionary:
	if int(state["jogador"]["equip"]) >= 3:
		return {"ok": false, "msg": "Equipamento no máximo."}
	var custo: int = 200 * (int(state["jogador"]["equip"]) + 1)
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Melhoria custa %d de ouro." % custo}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["equip"] = int(state["jogador"]["equip"]) + 1
	return {"ok": true, "msg": "Equipamento nível %d (+15%% de força)." % state["jogador"]["equip"]}

static func exportar_comida(state: Dictionary, qtd: int) -> Dictionary:
	if state["terra"] == null:
		return {"ok": false, "msg": "Você não tem terras."}
	var t: Dictionary = state["terra"]
	if int(t["alimento"]) < qtd:
		return {"ok": false, "msg": "Não há tanto alimento nos celeiros."}
	t["alimento"] = int(t["alimento"]) - qtd
	var ganho: int = roundi(Economia.preco_de(state, state["local"], "trigo") * qtd * 1.1)
	state["jogador"]["ouro"] += ganho
	if int(t["alimento"]) < int(t["populacao"]) * 2:
		t["felicidade"] = clampi(int(t["felicidade"]) - 15, 0, 100)
		return {"ok": true, "msg": "Vendeu %d de alimento por %d — o povo murmura (felicidade -15)." % [qtd, ganho]}
	return {"ok": true, "msg": "Exportou %d de alimento por %d de ouro." % [qtd, ganho]}

# ---------- eventos pendentes ----------
static func resolver_evento(state: Dictionary, escolha: String) -> Dictionary:
	var ev = state["evento_pendente"]
	if ev == null:
		return {}
	state["evento_pendente"] = null
	var log := log_para(state)
	var resultado := {}
	match ev["tipo"]:
		"rebeliao":
			if escolha == "reprimir":
				var rebeldes := {"tropas": {"campones": Dados.ri(15, 30), "lanceiro": Dados.ri(2, 5)},
					"equip": 0, "formacao": "cerco"}
				resultado = Combate.batalhar(state, rebeldes, "Rebelião camponesa")
				if resultado["vitoria"]:
					state["terra"]["felicidade"] = 35
					state["terra"]["populacao"] = maxi(5, int(state["terra"]["populacao"]) - Dados.ri(4, 8))
					state["jogador"]["crueldade"] = int(state["jogador"].get("crueldade", 0)) + 1
					log.call("Você afogou a rebelião em sangue. A vila obedece — e odeia.")
				else:
					morrer(state, "rebeliao", log)
			else:
				var custo: int = mini(int(state["jogador"]["ouro"]), 200)
				state["jogador"]["ouro"] -= custo
				state["terra"]["alimento"] = int(state["terra"]["alimento"]) + 60
				state["terra"]["felicidade"] = 55
				log.call("Você abriu os celeiros (-%d ouro). O povo abaixa as foices." % custo)
		"notavel_ambicioso":
			# escolha: "comprar" (lealdade por ouro), "exilar" ou ignorar
			resultado = {"msg": Cidadaos.resolver_ambicioso(state, ev["nome"], escolha, log)}
		"traicao_guardas":
			var custo_g: int = int(state["jogador"]["guardas"]) * 15
			if escolha == "pagar" and state["jogador"]["ouro"] >= custo_g:
				state["jogador"]["ouro"] -= custo_g
				state["jogador"]["meses_sem_pagar"] = 0
				log.call("Você pagou a guarda em dobro (-%d). Os portões continuam seus." % custo_g)
			else:
				log.call("Sua guarda abriu os portões na calada da noite. Você fugiu pelo esgoto.")
				state["jogador"]["guardas"] = 0
				state["jogador"]["ouro"] = int(state["jogador"]["ouro"] / 2.0)
				if state["terra"] != null:
					state["terra"]["nivel"] = maxi(0, int(state["terra"]["nivel"]) - 2)
	return resultado

# ---------- save / load (JSON em user://) ----------
static func salvar(state: Dictionary) -> bool:
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	return true

static func tem_save() -> bool:
	return FileAccess.file_exists(ARQUIVO_SAVE)

static func carregar() -> Variant:
	if not tem_save():
		return null
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.READ)
	var dados = JSON.parse_string(f.get_as_text())
	if dados == null:
		return null
	return _migrar(_normalizar(dados))

## Save de antes da Fase 3 não tem os campos novos. Preencher aqui (e não
## com `.get()` espalhado por dez arquivos) mantém o resto do código simples
## e garante que um save antigo carregue sem quebrar.
static func _migrar(state: Dictionary) -> Dictionary:
	for campo in ["fila_recrutamento", "pactos", "choques", "informantes"]:
		if not state.has(campo):
			state[campo] = []
	for campo in ["relacoes_npc", "flagras"]:
		if not state.has(campo):
			state[campo] = {}
	# tropas renomeadas (cavaleiro → cav_leve) e as oito novas, que um save
	# anterior à Fase 3 não conhece
	if state.get("jogador") != null and state["jogador"].get("tropas") != null:
		var velhas: Dictionary = state["jogador"]["tropas"]
		for antigo in Dados.TROPAS_RENOMEADAS:
			if velhas.has(antigo):
				var novo: String = Dados.TROPAS_RENOMEADAS[antigo]
				velhas[novo] = int(velhas.get(novo, 0)) + int(velhas[antigo])
				velhas.erase(antigo)
		for tipo in Dados.TROPAS:
			if not velhas.has(tipo):
				velhas[tipo] = 0
	# a fila também pode carregar um nome antigo
	for item in state.get("fila_recrutamento", []):
		if Dados.TROPAS_RENOMEADAS.has(item.get("tipo", "")):
			item["tipo"] = Dados.TROPAS_RENOMEADAS[item["tipo"]]
	if state.get("reinos") != null:
		Geopolitica.inicializar(state)
	return state

static func apagar_save() -> void:
	if tem_save():
		DirAccess.remove_absolute(ARQUIVO_SAVE)

# JSON devolve todo número como float; converte inteiros de volta.
static func _normalizar(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _normalizar(v[k])
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _normalizar(v[i])
		TYPE_FLOAT:
			if v == floorf(v):
				return int(v)
	return v
