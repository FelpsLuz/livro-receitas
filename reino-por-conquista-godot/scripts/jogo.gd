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
const Relogio = preload("res://scripts/relogio.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Intel = preload("res://scripts/intel.gd")
const Estacoes = preload("res://scripts/estacoes.gd")
const Vassalagem = preload("res://scripts/vassalagem.gd")

const ARQUIVO_SAVE := "user://save.json"

static func novo_jogo(nome: String = "") -> Dictionary:
	var state := {
		"ano": 1, "mes": 3, "dia": 1,
		"jogador": {
			"nome": nome if nome != "" else Dados.rnd(Dados.NOMES_M) + " " + Dados.rnd(Dados.SOBRENOMES),
			"idade": 22,
			"atributos": {"forca": Dados.ri(4, 7), "carisma": Dados.ri(4, 7),
				"gestao": Dados.ri(4, 7), "intriga": Dados.ri(3, 6)},
			"renome": 0, "ouro": 150, "crueldade": 0, "moral": 100,
			"tropas": _tropas_zeradas({"lanceiro": 5}),
			"equip": 0, "formacao": "linha", "guardas": 0,
			"rei_de": "", "meses_reinando": 0, "meses_sem_pagar": 0, "meses_imperador": 0,
			"suserano": "", "meses_vassalo": 0,
			# HONRA é a reputação que abre e fecha portas: o conselho real
			# não contrata bandido conhecido, e O Corvo não confia num santo.
			# Começa no meio — você ainda não é ninguém.
			"honra": 50,
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
		"marchas": [],             # exércitos na estrada (marchas.gd)
		"minuto": 0,               # relógio único do mundo (relogio.gd)
		"empregos": {},            # portas de trabalho já abertas (empregos.gd)
		"afetos": {},              # cortejo em andamento (pretendentes.gd)
		"mapa_comercial": null,    # licença de negociar, 1 mês (economia.gd)
		"progresso_atributo": {},  # dias de ofício rumo ao próximo ponto
		"intel": {},               # o que o espião revelou (intel.gd)
		"chantagens_ano": {},      # cooldown de 1x/ano por rei (intriga.gd)
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

## Quantos cliques de "Passar o dia" cabem num mês. Três: o mês é a
## unidade da economia e da política, mas contrato de taverna, turno de
## trabalho e viagem precisavam de uma unidade MENOR para existir como
## escolha — sem o dia, "1 a 3 dias de missão" não tinha onde acontecer.
const DIAS_POR_MES := 3

## Um dia. Move o relógio (quartel e marchas andam junto) e, no último
## dia, vira o mês inteiro — daí o `false`: quem virou o relógio foi o
## dia, e passar_mes não pode virar de novo.
static func passar_dia(state: Dictionary, log_ext: Callable = Callable()) -> void:
	if state["fim"] != null or state["evento_pendente"] != null:
		return
	var log := log_ext if log_ext.is_valid() else log_para(state)
	Relogio.avancar(state, Relogio.MINUTOS_POR_MES / DIAS_POR_MES, log)
	state["dia"] = int(state.get("dia", 1)) + 1
	if int(state["dia"]) > DIAS_POR_MES:
		state["dia"] = 1
		passar_mes(state, false)

static func passar_mes(state: Dictionary, avancar_relogio: bool = true) -> void:
	if state["fim"] != null or state["evento_pendente"] != null:
		return
	state["dia"] = 1
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
		# as marchas já despachadas continuam: quem está na estrada não sabe
		# que o senhor foi preso, e volta para uma casa sem dono
		if avancar_relogio:
			Relogio.avancar(state, Relogio.MINUTOS_POR_MES, log)
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
	Intel.tick(state)                     # relatórios de espião envelhecem
	Cidadaos.tick(state, log)             # a sua sociedade também
	Taverna.tick(state, log)              # informantes cobram e reportam
	Vassalagem.tick(state, log)           # o suserano cobra o tributo
	# um mês de jogo = 600 minutos: empurra quartel E marchas pelo mesmo relógio.
	# Quando quem chamou foi passar_dia, o relógio JÁ andou dia a dia.
	if avancar_relogio:
		Relogio.avancar(state, Relogio.MINUTOS_POR_MES, log)
	Clas.tick(state, log)
	Intriga.tick_familia(state, log)
	# palavra dada e não cumprida cobra ANTES de o mural ser renovado —
	# senão o contrato aceito sumiria de graça na virada
	Contratos.expirar_pendentes(state, log)
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
	_tick_ruina(state, log)

## Ruína total: sem ouro, sem homens, sem terra e sem marcha não existe
## NENHUMA ação que gere renda — sem esta função o jogo virava um estado
## zumbi infinito (20 anos parado, medido em soak). O agiota compra o resto
## do nome duas vezes; na terceira queda, a saga acaba.
static func _tick_ruina(state: Dictionary, log: Callable) -> void:
	var j: Dictionary = state["jogador"]
	var arruinado: bool = state["terra"] == null and str(j["rei_de"]) == "" \
		and int(j["ouro"]) < 20 and Combate.total_homens(j["tropas"]) == 0 \
		and (state["marchas"] as Array).is_empty() \
		and (state["fila_recrutamento"] as Array).is_empty() \
		and int(j.get("preso_ate", 0)) <= _mes_absoluto(state)
	if not arruinado:
		state["meses_ruina"] = 0
		return
	state["meses_ruina"] = int(state.get("meses_ruina", 0)) + 1
	if state["meses_ruina"] >= 3 and int(state.get("resgates_agiota", 0)) < 2:
		state["resgates_agiota"] = int(state.get("resgates_agiota", 0)) + 1
		state["meses_ruina"] = 0
		j["ouro"] = int(j["ouro"]) + 150
		j["renome"] = maxi(0, int(j["renome"]) - 5)
		log.call("Um agiota compra o que resta do seu nome: +150 de ouro, e menos um naco de orgulho.")
	elif state["meses_ruina"] >= 6:
		log.call("Sem ouro, sem homens, sem terra. O mundo esqueceu seu nome.")
		state["fim"] = {"tipo": "derrota", "causa": "ruina"}

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
	# O teto vem da TABELA, não de um 5 escrito à mão. Com a escada em nove
	# degraus o literal teria travado o jogador na "Vila de Pedra" — e sem
	# erro nenhum, só uma mensagem de "nível máximo" que era mentira.
	if int(t["nivel"]) >= Dados.NIVEIS_TERRA.size() - 1:
		return {"ok": false, "msg": "Nível máximo."}
	var prox: Dictionary = Dados.NIVEIS_TERRA[t["nivel"] + 1]
	# Capataz LEAL na Corte é mestre de obra: -10% no custo de MATERIAL do
	# próximo degrau (não no ouro). Hoje "material" é só madeira — quando a
	# pedra entrar na escada (Estágio 1 do patch), este desconto se aplica
	# a ela também, sem precisar tocar aqui de novo.
	var custo_material: int = int(prox["custo_madeira"])
	if Cidadaos.oficio_ativo(state, "capataz"):
		custo_material = roundi(custo_material * 0.9)
	if state["jogador"]["ouro"] < prox["custo_ouro"] or t["madeira"] < custo_material:
		return {"ok": false, "msg": "Recursos insuficientes."}
	state["jogador"]["ouro"] -= int(prox["custo_ouro"])
	t["madeira"] = int(t["madeira"]) - custo_material
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
	# a forja da família da esposa cobra o preço de casa
	var Pretendentes = load("res://scripts/pretendentes.gd")
	var custo: int = roundi(200 * (int(state["jogador"]["equip"]) + 1)
		* Pretendentes.fator_equipamento(state))
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
			# um capataz LIDERANDO é uma revolta maior, e "abrir os celeiros"
			# sozinho não resolve — ele continua vivo, continua ambicioso, e
			# continua no cargo até ser comprado, exilado ou esmagado com a turba
			var lider: String = str(ev.get("lider", ""))
			if escolha == "reprimir":
				var mult: int = 2 if lider != "" else 1
				var rebeldes := {"tropas": {"campones": Dados.ri(15, 30) * mult,
					"lanceiro": Dados.ri(2, 5) * mult}, "equip": 0, "formacao": "cerco"}
				resultado = Combate.batalhar(state, rebeldes, "Rebelião camponesa")
				if resultado["vitoria"]:
					state["terra"]["felicidade"] = 35
					state["terra"]["populacao"] = maxi(5, int(state["terra"]["populacao"]) - Dados.ri(4, 8) * mult)
					state["jogador"]["crueldade"] = int(state["jogador"].get("crueldade", 0)) + (2 if lider != "" else 1)
					if lider != "":
						for n in Cidadaos.lista(state):
							if str(n.get("nome", "")) == lider:
								Cidadaos.lista(state).erase(n)
								break
						log.call("Você afogou a rebelião em sangue — e %s morreu com a turba que liderou." % lider)
					else:
						log.call("Você afogou a rebelião em sangue. A vila obedece — e odeia.")
				else:
					morrer(state, "rebeliao", log)
			else:
				# sem terra não há celeiro para abrir: o evento pode chegar a
				# quem perdeu tudo (ou a um save mutilado), e o ramo caía num
				# SCRIPT ERROR em vez de simplesmente não acontecer
				if state["terra"] == null:
					log.call("Não há celeiro para abrir. A turba se dispersa sozinha, por ora.")
					return {}
				var custo: int = mini(int(state["jogador"]["ouro"]), 200)
				state["jogador"]["ouro"] -= custo
				state["terra"]["alimento"] = int(state["terra"]["alimento"]) + 60
				if lider == "":
					state["terra"]["felicidade"] = 55
					log.call("Você abriu os celeiros (-%d ouro). O povo abaixa as foices." % custo)
				else:
					# o povo se acalma, mas o capataz que armou a revolta segue
					# no cargo — a ambição dele só cresceu com o gosto do poder
					state["terra"]["felicidade"] = 45
					for n in Cidadaos.lista(state):
						if str(n.get("nome", "")) == lider:
							n["ambicao"] = mini(10, int(n.get("ambicao", 5)) + 2)
							break
					log.call("Você abriu os celeiros (-%d ouro). O povo abaixa as foices — mas %s, o capataz, continua no cargo, e não esqueceu." % [custo, lider])
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
	# um save sem as chaves centrais não é um save: recusar aqui (null) é o
	# que deixa o título avisar — sem isto, um JSON válido porém mutilado
	# passava e o jogo entrava numa tela morta
	if dados == null or not (dados is Dictionary):
		return null
	for chave in ["jogador", "reinos", "mes", "ano"]:
		if not (dados as Dictionary).has(chave):
			return null
	return _migrar(_normalizar(dados))

## Save de antes da Fase 3 não tem os campos novos. Preencher aqui (e não
## com `.get()` espalhado por dez arquivos) mantém o resto do código simples
## e garante que um save antigo carregue sem quebrar.
static func _migrar(state: Dictionary) -> Dictionary:
	# chaves centrais que um save editado à mão (ou de versão futura) pode
	# não trazer: repor aqui evita SCRIPT ERROR em cascata a cada mês
	if not state.has("terra"):
		state["terra"] = null
	if not state.has("fim"):
		state["fim"] = null
	if not state.has("evento_pendente"):
		state["evento_pendente"] = null
	if not state.has("familia"):
		state["familia"] = {"conjuge": null, "filhos": []}
	for campo in ["cronica", "guerras", "contratos", "casus_belli"]:
		if not state.has(campo):
			state[campo] = []
	for campo in ["tags", "carga"]:
		if not state.has(campo):
			state[campo] = {}
	if not state.has("mercados") and state.get("reinos") != null:
		Economia.inicializar_mercados(state)
	if not state.has("local") and state.get("reinos") != null \
			and not (state["reinos"] as Array).is_empty():
		state["local"] = str(state["reinos"][0]["id"])
	for campo in ["fila_recrutamento", "pactos", "choques", "informantes", "marchas"]:
		if not state.has(campo):
			state[campo] = []
	if not state.has("minuto"):
		state["minuto"] = 0
	# a fila guardava `restante_seg` quando o quartel tinha relógio próprio;
	# agora tudo é minuto de jogo, e o nome mentiria sobre a unidade
	for item in state.get("fila_recrutamento", []):
		if item.has("restante_seg") and not item.has("restante"):
			item["restante"] = item["restante_seg"]
			item.erase("restante_seg")
	for campo in ["relacoes_npc", "flagras", "intel", "chantagens_ano"]:
		if not state.has(campo):
			state[campo] = {}
	if not state["jogador"].has("moral"):
		state["jogador"]["moral"] = 100
	if not state["jogador"].has("honra"):
		state["jogador"]["honra"] = 50
	if not state.has("dia"):
		state["dia"] = 1
	if not state.has("afetos"):
		state["afetos"] = {}
	if not state.has("mapa_comercial"):
		state["mapa_comercial"] = null
	for campo_novo in ["empregos", "progresso_atributo"]:
		if not state.has(campo_novo):
			state[campo_novo] = {}
	if not state["jogador"].has("suserano"):
		state["jogador"]["suserano"] = ""
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
