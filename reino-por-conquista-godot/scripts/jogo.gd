# ============================================================
# NÚCLEO DO JOGO (port de js/game.js)
# Estado, turno mensal, morte e herança dinástica.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Equipar = preload("res://scripts/equipar.gd")
const Livro = preload("res://scripts/livro.gd")
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
const Armazem = preload("res://scripts/armazem.gd")
const Inimizade = preload("res://scripts/inimizade.gd")
const Medo = preload("res://scripts/medo.gd")

const ARQUIVO_SAVE := "user://save.json"

## O MOLDE das coleções do estado — a única lista que novo_jogo e _migrar
## consultam. Existe porque as duas divergiram: `novo_jogo` ganhou campos
## que `_migrar` não repunha, e um save antigo entrava sem `segredos`,
## `mensageiros`, `clas_ativos`, `cartas` ou `chantagem_pendente` — cada um
## indexado direto em clas.gd, intriga.gd e na interface. Campo novo aqui
## nasce reposto nos dois caminhos.
static func _molde_de_estado() -> Dictionary:
	return {
		"guerras": [], "tags": {}, "segredos": [], "casus_belli": [],
		"carga": {}, "mensageiros": [], "clas_ativos": [], "cartas": [],
		"cronica": [], "contratos": [], "evento_pendente": null,
		"chantagem_pendente": null, "fila_recrutamento": [], "pactos": [],
		"choques": [], "flagras": {}, "informantes": [], "marchas": [],
		"minuto": 0, "empregos": {}, "afetos": {}, "mapa_comercial": null,
		"progresso_atributo": {}, "intel": {}, "chantagens_ano": {},
		"licencas": {}, "avisos_ocultos": {}, "inimizade_fila": [],
		"livro": [], "livro_meses": [],
		"aco": {"reino": "", "degrau": 0, "ultimo_rumor": 0},
		"armazem": {"baias": 0, "proprio": false, "atraso": 0},
		"equipamento": {}, "fila_ferraria": [],
		"familia": {"conjuge": null, "filhos": []},
		"terra": null, "fim": null,
	}

static func novo_jogo(nome: String = "") -> Dictionary:
	var state := {
		"ano": 1, "mes": 3, "dia": 1,
		"jogador": {
			"nome": nome if nome != "" else Dados.rnd(Dados.NOMES_M) + " " + Dados.rnd(Dados.SOBRENOMES),
			# ---- VINTE ANOS, E O RELÓGIO CONSERTADO DE OUTRO JEITO ----
			#
			# O jogo começa com um ninguém que precisa fazer a própria
			# história: aos 40 ele já teria uma, e a fantasia do mercenário
			# sem nome morre na tela de criação.
			#
			# Só que aos 20 o primeiro sorteio de morte rolava aos 46 —
			# vinte e seis anos de jogo, que a 3 dias por mês são 936
			# cliques antes de o dado ser lançado UMA vez. A sucessão, o
			# herdeiro e a regência ficavam fora da janela da partida.
			#
			# A idade não é a resposta: a MORTALIDADE é. Este mundo mata
			# jovem por doença, estrada e ferro (ver `RISCO_MUNDO`), e é
			# isso que faz o herdeiro valer aos vinte e um anos de idade
			# sem precisar envelhecer o protagonista.
			"idade": 20,
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
		"licencas": {},            # selo da guilda por praça (economia.gd)
		"avisos_ocultos": {},      # "não mostrar de novo" por aviso (UI)
		"intel": {},               # o que o espião revelou (intel.gd)
		"chantagens_ano": {},      # cooldown de 1x/ano por rei (intriga.gd)
	}
	state.merge(_molde_de_estado())
	Economia.inicializar_mercados(state)
	Geopolitica.inicializar(state)
	state["contratos"] = Contratos.gerar(state)
	var log := log_para(state)
	_diz(log, "Ano 1. Você é %s: sem terras, sem título, com %d moedas e 5 lanceiros leais." %
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
## Devolve o que o dia trouxe ({"recrutas": n, "marchas": [...]}), porque
## a UI precisa narrar emboscada e recruta pronto — antes isso vinha de um
## Timer girando o relógio em tempo real, e o tempo passava sem o jogador.
static func passar_dia(state: Dictionary, log_ext: Callable = Callable()) -> Dictionary:
	if state["fim"] != null or state["evento_pendente"] != null:
		return {"recrutas": 0, "marchas": []}
	var log := log_ext if log_ext.is_valid() else log_para(state)
	Armazem.tick_dia(state, log)          # o feitor cobra por DIA, não por mês
	var r := Relogio.avancar(state, Relogio.MINUTOS_POR_DIA, log)
	state["dia"] = int(state.get("dia", 1)) + 1
	if int(state["dia"]) > DIAS_POR_MES:
		state["dia"] = 1
		passar_mes(state, false)
	# ---- TER INIMIGO DÓI TODO DIA, INCLUSIVE NOS DIAS EM QUE VOCÊ AGE ----
	#
	# O acontecimento continua voltando no retorno — guardá-lo em
	# `evento_pendente` travaria o relógio, e este é um acontecimento do dia
	# que JÁ passou. Mas o retorno sozinho não bastava, e esse era o furo:
	#
	# `passar_dia` tem sete chamadores. Só UM — o botão "Passar o dia" —
	# lia `r["inimizade"]`. Trabalhar, viajar, cumprir contrato, cortejar,
	# invadir e espiar chamam o mesmo dia e descartavam o retorno inteiro.
	# Resultado: o único sistema que faz a guerra doer no cotidiano era
	# desligado por qualquer ação produtiva, e trabalhar três dias era
	# estritamente mais seguro que passar três dias parado.
	#
	# Agora o acontecimento também é PARADO NO ESTADO. Quem chama não
	# precisa saber que ele existe; a interface drena a fila no próximo
	# `atualizar()`, que roda depois de toda ação. A fila é uma lista porque
	# um turno de trabalho passa até três dias de uma vez, e cada um deles
	# rola o próprio dado.
	if state["fim"] == null:
		var ataque := Inimizade.tick_dia(state, log)
		if not ataque.is_empty():
			r["inimizade"] = ataque
			var fila: Array = state.get("inimizade_fila", [])
			fila.append(ataque)
			state["inimizade_fila"] = fila
	return r

## Tira o próximo acontecimento de inimizade da fila, ou {} se não há.
##
## A interface é a única consumidora: ela abre o modal e o jogador escolhe
## enfrentar ou trancar as portas. Enquanto a fila tiver item, a próxima
## chamada de `atualizar()` volta a abrir.
static func puxar_inimizade(state: Dictionary) -> Dictionary:
	var fila: Array = state.get("inimizade_fila", [])
	if fila.is_empty():
		return {}
	var ev: Dictionary = fila.pop_front()
	state["inimizade_fila"] = fila
	return ev

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
			# A CADEIA NÃO CONGELA A IDADE. O ramo de prisão retornava sem
			# chamar `_envelhecer`, e o comentário deste arquivo promete que
			# "cadeia é castigo, não abrigo": cumprir três anos de pena
			# deixava o jogador com a mesma idade e sem sorteio de morte.
			_envelhecer(state, log)
		_diz(log, "Mais um mês a ferros. As paredes escorrem.")
		Economia.tick_mercados(state)         # o mundo segue sem você
		Economia.tick_choques(state)
		Economia.tick_guerras(state, log)
		Geopolitica.tick(state, log)
		# AS CONTAS NÃO ESPERAM O SENHOR SAIR. Antes a masmorra pulava
		# upkeep, tributo e palavra dada — e ficar preso saía mais barato
		# que ficar livre (medido: 6 meses preso preservavam ouro, homens e
		# moral intactos). Cadeia é castigo, não abrigo: a tropa continua
		# comendo, o suserano continua cobrando, e o contrato que você
		# jurou cumprir continua vencendo sem você.
		Economia.tick_terra(state, log)
		Economia.tick_exercito(state, log)
		Vassalagem.tick(state, log)
		Contratos.expirar_pendentes(state, log)
		state["contratos"] = Contratos.gerar(state)
		# as marchas já despachadas continuam: quem está na estrada não sabe
		# que o senhor foi preso, e volta para uma casa sem dono
		if avancar_relogio:
			Relogio.avancar(state, Relogio.MINUTOS_POR_MES, log)
		_tick_ruina(state, log)
		# a ferros a fama continua trabalhando contra você
		Medo.aplicar_tetos(state)
		# a cadeia também fecha o livro: o mês passou, o soldo foi cobrado e
		# o jogador tem direito de ver a conta quando sair
		state["ultimo_balanco"] = Livro.fechar_mes(state)
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
	# ---- O MEDO COBRA ----
	# Depois de TODOS os tiques que mexem em felicidade e relação, e por isso
	# aqui e não dentro de `tick_terra`: lá o teto seria aplicado antes do
	# bônus da esposa e antes de `Geopolitica`/`Clas` mexerem nas cortes, e
	# um teto aplicado antes do último aumento não é teto nenhum. Fora que
	# `tick_terra` volta na porta quando o jogador não tem terra — e o
	# mercenário sem chão também tem que sentir a fama de queimar vila.
	Medo.aplicar_tetos(state)
	# ---- FECHA O LIVRO-RAZÃO ----
	# Depois de TUDO, e é a ordem que importa: fechar antes deixaria de fora
	# o soldo do clã, a família e a expiração de contrato, que rodam no fim.
	# O relatório fica em `ultimo_balanco` para a interface abrir quando o
	# jogador voltar — a virada pode acontecer dentro de um turno de trabalho
	# de três dias, e o modal não pode aparecer no meio do turno.
	state["ultimo_balanco"] = Livro.fechar_mes(state)
	# VITÓRIA: ser suserano de TODOS os reinos por 12 meses (conquista via guerra)
	#
	# O reino que VOCÊ fundou não entra na conta: ele nunca aparece como
	# "dominado por jogador" (é seu de nascença), e por isso a soma jamais
	# fechava — fundar uma casa nas Terras Bárbaras tornava a vitória
	# matematicamente impossível. Sua própria coroa não é um alvo.
	var dominados := 0
	var alvos := 0
	for r in state["reinos"]:
		if bool(r.get("fundado_pelo_jogador", false)):
			continue
		alvos += 1
		if r.get("dominado_por", "") == "jogador":
			dominados += 1
	if dominados >= alvos and alvos > 0:
		# A COROAÇÃO PRECISA SER SEGURADA, e não esperada.
		#
		# Eram 12 meses de nada: a última batalha acabava e sobravam 36
		# cliques de "passar o dia" contra ZERO pressão declarada. Anticlímax
		# por desenho — o jogo mais tenso do continente terminava num
		# cronômetro. Agora cada mês é um teste: as casas conquistadas
		# testam quem as conquistou, e uma revolta zera o contador.
		if not _testar_conquistados(state, log):
			state["jogador"]["meses_imperador"] = state["jogador"].get("meses_imperador", 0) + 1
			if state["jogador"]["meses_imperador"] >= 12:
				state["fim"] = {"tipo": "vitoria", "arco": "conquista"}
	else:
		state["jogador"]["meses_imperador"] = 0
	_tick_ferimento(state, log)
	_tick_legitimidade(state, log)
	_tick_ruina(state, log)

# ============================================================
# OS ARCOS DE VITÓRIA
#
# Havia UM: dominar os seis reinos e segurar por doze meses. É a saída do
# conquistador, e ela é longa, cara e única — quem joga de mercador, de
# intrigante ou de fundador de casa não tinha nenhum fim para perseguir, e
# um sandbox sem linha de chegada é um sandbox que se abandona.
#
# São três agora, e cada um premia um jeito de jogar que o motor JÁ
# sustentava sem ter onde desaguar:
#
#   CONQUISTA     todas as casas dominadas, doze meses. A que já existia.
#   LEGITIMIDADE  fundar a própria casa e fazê-la DURAR: 24 meses de reinado
#                 com a vila contente. É a vitória de quem construiu em vez
#                 de tomar — e usa `meses_reinando`, que era incrementado
#                 todo mês e nunca consultado por linha nenhuma.
#   USURPAÇÃO     sentar no trono de um dos seis pela corte e não pelo
#                 exército (ver `Intriga.assaltar_trono`).
#
# A derrota continua sendo uma só: morrer sem herdeiro.
# ============================================================
const MESES_PARA_LEGITIMAR := 24
const FELICIDADE_PARA_LEGITIMAR := 50

static func _tick_legitimidade(state: Dictionary, log: Callable) -> void:
	var j: Dictionary = state["jogador"]
	if str(j.get("rei_de", "")) == "" or state["fim"] != null:
		return
	# a vila contente é a prova de que a coroa é aceita, e não só usada
	var fel: int = int(state["terra"]["felicidade"]) if state.get("terra") != null else 0
	if fel < FELICIDADE_PARA_LEGITIMAR:
		# não zera o contador de reinado: reinar mal continua sendo reinar.
		# O que se perde é o mês de legitimidade, e isso é medido à parte.
		j["meses_legitimo"] = 0
		return
	var m: int = int(j.get("meses_legitimo", 0)) + 1
	j["meses_legitimo"] = m
	if m == roundi(MESES_PARA_LEGITIMAR * 0.5):
		_diz(log, "Metade do caminho: já falam da sua casa como se ela sempre tivesse existido.")
	if m >= MESES_PARA_LEGITIMAR:
		state["fim"] = {"tipo": "vitoria", "arco": "legitimidade"}

## Quanto falta para a coroa virar linhagem. Devolve {} quando o jogador
## ainda não tem reino — a interface usa isto para mostrar o arco.
static func progresso_legitimidade(state: Dictionary) -> Dictionary:
	var j: Dictionary = state["jogador"]
	if str(j.get("rei_de", "")) == "":
		return {}
	var fel: int = int(state["terra"]["felicidade"]) if state.get("terra") != null else 0
	return {"meses": int(j.get("meses_legitimo", 0)),
		"alvo": MESES_PARA_LEGITIMAR,
		"felicidade": fel, "felicidade_alvo": FELICIDADE_PARA_LEGITIMAR,
		"contando": fel >= FELICIDADE_PARA_LEGITIMAR}

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
		_diz(log, "Um agiota compra o que resta do seu nome: +150 de ouro, e menos um naco de orgulho.")
	elif state["meses_ruina"] >= 6:
		_diz(log, "Sem ouro, sem homens, sem terra. O mundo esqueceu seu nome.")
		state["fim"] = {"tipo": "derrota", "causa": "ruina"}

# ============================================================
# SEGURAR A COROA — os 12 meses que eram um cronômetro
#
# A vitória por conquista pedia doze meses seguidos de suserania sobre todos
# os reinos, sem nenhuma pressão declarada nesse intervalo. Trinta e seis
# cliques de nada depois da última batalha: o clímax do jogo virava tela de
# espera. E o jogador que já ganhou não tem por que continuar jogando.
#
# Cada mês agora é um teste. Uma casa conquistada tem chance de se levantar,
# e a chance depende do que você é para ela:
#
#   · relação com aquela corte (odiado se revolta, leal não)
#   · a sua crueldade (o medo SEGURA — é o único lugar do jogo em que
#     governar pelo terror é a jogada certa sem contrapartida imediata)
#   · o seu exército em casa (guarnição vazia é convite)
#
# Revolta devolve o reino ao mapa E zera o contador. Quem tomou o continente
# tem que provar que sabe segurá-lo — que é a única definição de império que
# vale a pena escrever.
# ============================================================
## UMA rolagem por mês, e não uma por reino. A primeira versão rolava por
## casa conquistada: seis dados por mês, setenta e dois em doze meses, e
## qualquer chance por dado virava certeza no agregado — a vitória por
## conquista ficava estatisticamente impossível, que é o extremo oposto do
## problema que este código veio consertar.
##
## Rola contra a casa MAIS insatisfeita: é ela quem se levanta primeiro, e
## saber qual é dá ao jogador o que fazer com os doze meses (visitar aquela
## corte, guarnecer aquela fronteira) em vez de clicar.
const CHANCE_REVOLTA_BASE := 0.04

static func _pior_conquistado(state: Dictionary) -> Dictionary:
	var pior: Dictionary = {}
	# a menor relação entre as casas que você domina
	var menor := 999
	for r in state["reinos"]:
		if str(r.get("dominado_por", "")) != "jogador":
			continue
		var rel: int = int(state["tags"].get("rei_" + str(r["id"]),
			{"relacao": 0})["relacao"])
		if rel < menor:
			menor = rel
			pior = r
	return pior

## O risco de perder uma casa neste mês — para o dado E para a interface.
static func risco_revolta(state: Dictionary) -> float:
	var pior := _pior_conquistado(state)
	if pior.is_empty():
		return 0.0
	var rel: int = int(state["tags"].get("rei_" + str(pior["id"]),
		{"relacao": 0})["relacao"])
	var chance := CHANCE_REVOLTA_BASE
	chance += 0.10 if rel <= -25 else (0.04 if rel < 25 else 0.0)
	# O MEDO SEGURA. Aqui, e só aqui, governar pelo terror paga sem cobrar
	# nada em troca: é a única casa do tabuleiro em que a crueldade é
	# simplesmente a jogada certa.
	chance -= 0.01 * Medo.nivel(state)
	# guarnição em casa é o que impede a notícia de virar coragem
	if Combate.total_homens(state["jogador"]["tropas"]) < 100:
		chance += 0.08
	return clampf(chance, 0.0, 0.95)

static func _testar_conquistados(state: Dictionary, log: Callable) -> bool:
	var pior := _pior_conquistado(state)
	if pior.is_empty() or randf() >= risco_revolta(state):
		return false
	# A CASA SAI DO MAPA, e é só isso: o contador zera sozinho no mês
	# seguinte, porque `dominados >= alvos` deixa de valer. Zerar o contador
	# À MÃO aqui seria castigar duas vezes o mesmo dado.
	pior["dominado_por"] = ""
	Dialogo.mudar_relacao(state, "rei_" + str(pior["id"]), -30, "revolta")
	state["jogador"]["renome"] = maxi(0, int(state["jogador"]["renome"]) - 10)
	_diz(log, "%s se levantou. A coroa que você quase teve escorregou de novo." % str(pior["nome"]))
	Sinais.emitir(&"revolta_conquistado", {"reino": str(pior["id"])})
	return true

## Quanto falta para a coroa — e o risco de perdê-la neste mês. A interface
## precisa dos dois, senão os doze meses continuam parecendo um cronômetro.
static func progresso_conquista(state: Dictionary) -> Dictionary:
	var dominados := 0
	var alvos := 0
	for r in state["reinos"]:
		if bool(r.get("fundado_pelo_jogador", false)):
			continue
		alvos += 1
		if str(r.get("dominado_por", "")) == "jogador":
			dominados += 1
	var pior := _pior_conquistado(state)
	return {"dominados": dominados, "alvos": alvos,
		"meses": int(state["jogador"].get("meses_imperador", 0)), "alvo_meses": 12,
		"risco": risco_revolta(state),
		"frágil": "" if pior.is_empty() else str(pior.get("nome", ""))}

## +3% ao ano por cicatriz, para sempre. É o dano que não fecha.
const RISCO_POR_CICATRIZ := 0.03

## ---- O RISCO QUE NÃO VEM DA IDADE ----
##
## A escada de mortalidade era 0% até os 45, e o jogador começa aos 20. Isso
## queria dizer vinte e seis anos de campanha — 936 cliques de "passar o dia"
## — antes de o dado ser lançado uma única vez. O herdeiro, a regência e a
## sucessão, que são o que separa esta saga de um Mount & Blade, ficavam
## fora da janela em que a partida acontece.
##
## Envelhecer o protagonista resolveria e custaria a fantasia: o jogo é sobre
## um ninguém que faz o próprio nome, e um ninguém tem vinte anos.
##
## Então o que muda é a régua. Este mundo mata jovem — febre no acampamento,
## estrada ruim, ferida que infecciona, faca na taverna. Dois por cento ao
## ano desde o primeiro: sozinho não é ameaça (uma campanha de dez anos passa
## com 82% de chance), mas soma com ferida e cicatriz, e faz a pergunta "eu
## tenho herdeiro?" existir aos vinte e um anos de idade em vez de aos
## quarenta e seis.
const RISCO_MUNDO := 0.02

## O risco de morrer neste ano, para o sorteio e para a interface — e é a
## MESMA função nos dois lugares, senão a barra da Casa mente.
static func risco_anual(state: Dictionary) -> float:
	var idade: int = int(state["jogador"]["idade"])
	var base := 0.25 if idade > 65 else (0.10 if idade > 55 else (0.04 if idade > 45 else 0.0))
	return minf(0.90, RISCO_MUNDO + base + RISCO_POR_CICATRIZ * cicatrizes(state))

static func _envelhecer(state: Dictionary, log: Callable) -> void:
	state["jogador"]["idade"] += 1
	for f in state["familia"]["filhos"]:
		f["idade"] += 1
	if randf() < risco_anual(state):
		morrer(state, "idade", log)

# ============================================================
# O FERIMENTO — a morte que faz o herdeiro valer alguma coisa
#
# A herança dinástica deste jogo está escrita, testada e é o que o separa de
# um Mount & Blade: o filho é educado no seu atributo mais forte e assume a
# casa quando você cai. E quase ninguém chegava a ver, porque a única morte
# possível era a de velhice — 4% ao ano depois dos 45. Começando aos 22, uma
# partida de dez anos termina aos 32, e o herdeiro nunca entra em cena.
#
# A correção não é subir a mortalidade por idade: isso puniria quem joga
# devagar, que é o oposto do desenho. É dar à BATALHA um risco pessoal.
#
#   · uma derrota esmagadora deixa um ferimento (marcado em `combate.gd`)
#   · cada ferimento cobra risco TODO MÊS, e não uma vez por ano
#   · nove meses sem sangrar fecham um
#   · o TERCEIRO ferimento não fecha: vira cicatriz, e cicatriz cobra para
#     sempre no sorteio anual
#
# ---- por que 1,5% e não 3% ----
#
# A cura era de três meses, e com 3% ao mês um ferimento custava 8,7% de
# chance de morrer antes de fechar. Nove meses de cura ao mesmo 3% seriam
# 24% por batalha perdida — uma derrota feia viraria um quarto de saga
# jogada fora, e o jogador aprenderia a nunca arriscar batalha, que é o
# oposto do que o sistema quer ensinar. A 1,5% em nove meses dá 12,7%: dói,
# dá para administrar, e dois ferimentos ao mesmo tempo (24%) são a hora de
# parar e se recompor.
#
# O resultado é que uma campanha desastrosa passa a ter consequência que
# dura, e o testamento — quem herda, com que atributos — vira parte do jogo
# em vez de uma tela que quase ninguém abre.
# ============================================================
const RISCO_POR_FERIMENTO := 0.015
const MESES_PARA_CICATRIZAR := 9
## Quantos ferimentos abertos ao mesmo tempo o corpo aguenta antes de um
## deles virar permanente.
const FERIMENTOS_ATE_CICATRIZ := 3

static func _tick_ferimento(state: Dictionary, log: Callable) -> void:
	var j: Dictionary = state["jogador"]
	var n: int = int(j.get("ferimentos", 0))
	# O TERCEIRO NÃO FECHA. Acumular três feridas abertas ao mesmo tempo
	# converte uma delas em dano permanente: o corpo devolve duas e fica com
	# a terceira. É o que impede a espiral de "perdi feio três vezes e nove
	# meses depois estava novo".
	if n >= FERIMENTOS_ATE_CICATRIZ:
		j["ferimentos"] = n - 1
		j["cicatrizes"] = int(j.get("cicatrizes", 0)) + 1
		j["meses_sem_sangrar"] = 0
		n -= 1
		_diz(log, "A terceira ferida não vai fechar. Você vai levá-la até o fim.")
	if n <= 0:
		return
	if randf() < RISCO_POR_FERIMENTO * n:
		_diz(log, "A ferida não fechou. %s não passou deste mês." % str(j["nome"]))
		morrer(state, "ferimento", log)
		return
	var parado: int = int(j.get("meses_sem_sangrar", 0)) + 1
	j["meses_sem_sangrar"] = parado
	if parado >= MESES_PARA_CICATRIZAR:
		j["ferimentos"] = n - 1
		j["meses_sem_sangrar"] = 0
		if n - 1 <= 0:
			_diz(log, "A ferida fechou. Ficou a marca e o que ela lembra.")

## Quantos ferimentos o jogador carrega — a interface precisa mostrar, senão
## é um relógio de morte invisível, que é o pior tipo.
static func ferimentos(state: Dictionary) -> int:
	return int(state["jogador"].get("ferimentos", 0))

## E quantas cicatrizes, que não fecham nunca.
static func cicatrizes(state: Dictionary) -> int:
	return int(state["jogador"].get("cicatrizes", 0))

# ============================================================
# A SUCESSÃO — e a regência, que é o que faz o laço da casa disparar
#
# A idade de maioridade era 16, e com filho nascendo por volta do ano 2 isso
# punha o herdeiro válido no ano 18 de jogo. Somado ao sorteio de morte que
# só começava aos 46, o resultado medido era cara-ou-coroa: metade das sagas
# terminava antes de o herdeiro valer alguma coisa, e "a derrota mais
# administrável" não era administrável coisa nenhuma.
#
# Duas mexidas resolvem, e a segunda é a que importa:
#
#   · MAIORIDADE 14. Um adolescente pega em espada neste mundo.
#   · REGÊNCIA. Morrer com filho MENOR deixou de ser derrota. A casa segue,
#     o filho assume com a idade que tem, e o preço é o que um regente
#     sempre paga: o continente testa a casa. Perde-se uma terra ou um naco
#     de nome, os vassalos duvidam e a relação com todas as cortes cai.
#
# Morrer sem filho NENHUM continua sendo o fim, e tem que continuar: é a
# única derrota que o jogador escolhe não evitar.
# ============================================================
const MAIORIDADE := 14
const PEDAGIO_REGENCIA_RENOME := 20

static func morrer(state: Dictionary, causa: String, log: Callable) -> void:
	var herdeiro: Dictionary = {}
	var menor: Dictionary = {}
	for f in state["familia"]["filhos"]:
		if int(f["idade"]) >= MAIORIDADE:
			herdeiro = f
			break
		if menor.is_empty() or int(f["idade"]) > int(menor["idade"]):
			menor = f
	if herdeiro.is_empty() and menor.is_empty():
		state["fim"] = {"tipo": "derrota", "causa": causa}
		return
	var regencia := herdeiro.is_empty()
	if regencia:
		herdeiro = menor
	_diz(log, "%s morre (%s). %s assume a casa." % [state["jogador"]["nome"], causa, herdeiro["nome"]])
	state["jogador"]["nome"] = herdeiro["nome"]
	state["jogador"]["idade"] = herdeiro["idade"]
	state["jogador"]["atributos"] = herdeiro["atributos"]
	state["jogador"]["crueldade"] = 2 if herdeiro.get("mimado", false) else 0
	# a casa nova começa inteira: as feridas eram do pai
	state["jogador"]["ferimentos"] = 0
	state["jogador"]["cicatrizes"] = 0
	state["jogador"]["meses_sem_sangrar"] = 0
	state["familia"]["filhos"].erase(herdeiro)
	state["familia"]["conjuge"] = null
	if regencia:
		_cobrar_regencia(state, herdeiro, log)

## O PEDÁGIO DA REGÊNCIA. Uma criança no trono é um convite, e o continente
## atende: perde-se a terra (que é o que um vizinho toma primeiro) ou, sem
## terra, um naco do nome. E toda corte desconta o que a casa vale.
static func _cobrar_regencia(state: Dictionary, herdeiro: Dictionary,
		log: Callable) -> void:
	state["regencia"] = {"ate_idade": MAIORIDADE, "nome": str(herdeiro["nome"])}
	if state.get("terra") != null:
		var nome_t: String = str(state["terra"]["nome"])
		state["terra"] = null
		Armazem.desassentar(state)
		_diz(log, "%s tem %d anos. Um vizinho tomou %s antes do fim do luto." % [
			str(herdeiro["nome"]), int(herdeiro["idade"]), nome_t])
	else:
		state["jogador"]["renome"] = maxi(0,
			int(state["jogador"]["renome"]) - PEDAGIO_REGENCIA_RENOME)
		_diz(log, "%s tem %d anos, e um menino não comanda homens feitos. O nome da casa encolheu." % [
			str(herdeiro["nome"]), int(herdeiro["idade"])])
	# o continente testa a casa: toda corte desconta
	for r in state.get("reinos", []):
		Dialogo.mudar_relacao(state, "rei_" + str(r["id"]), -20, "regência")
	# e o suserano, se houver, considera o juramento em suspenso
	state["jogador"]["suserano"] = ""
	state["jogador"]["meses_vassalo"] = 0
	Sinais.emitir(&"regencia", {"nome": str(herdeiro["nome"]),
		"idade": int(herdeiro["idade"])})

static func comprar_terra(state: Dictionary) -> Dictionary:
	if state["terra"] != null:
		return {"ok": false, "msg": "Você já tem terras."}
	if state["jogador"]["renome"] < 25:
		return {"ok": false, "msg": "Renome insuficiente (25)."}
	if state["jogador"]["ouro"] < Dados.PRECO_TERRA:
		return {"ok": false,
			"msg": "Terra custa %d de ouro. Trabalhe, cumpra contratos, negocie." % Dados.PRECO_TERRA}
	state["jogador"]["ouro"] -= Dados.PRECO_TERRA
	state["terra"] = {"nome": "Vale " + Dados.rnd(["Sereno", "das Pedras", "do Corvo", "Dourado", "Frio"]),
		"nivel": 0, "populacao": 20, "alimento": 80, "madeira": 20, "felicidade": 60}
	# o depósito que você alugava passa a ser SEU: para de cobrar diária
	Armazem.assentar(state)
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
## Recrutar agora ENFILEIRA: a tropa leva dias de relógio para ficar pronta.
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
	_diz(log, "Capturado. %d meses a ferros." % meses)

## Você está a ferros? A pergunta que TODA ação de fora da cela tem que
## fazer. Existia desde sempre e não era chamada por ninguém: o jogador
## era preso e seguia viajando, trabalhando e marchando como se nada
## fosse. Agora viagem, emprego, contrato, marcha, invasão, cortejo e
## juramento passam por aqui.
static func esta_preso(state: Dictionary) -> bool:
	return int(state["jogador"].get("preso_ate", 0)) > _mes_absoluto(state)

## Quantos meses ainda faltam — para a interface dizer, e para a fiança
## saber quanto cobrar.
static func meses_preso(state: Dictionary) -> int:
	return maxi(0, int(state["jogador"].get("preso_ate", 0)) - _mes_absoluto(state))

const AVISO_PRESO := "Você está a ferros. Daqui não se manda em nada."

## A SAGA ACABOU? A mesma pergunta que a cela faz, e que a morte não fazia.
##
## `passar_dia` e `passar_mes` já voltavam na porta com `fim != null`, mas
## quem PAGA antes de gastar o dia não voltava: medido, o lenhador que
## morria no primeiro turno continuava cortando lenha e embolsando a paga
## por mais quatro turnos, porque `Empregos.trabalhar` credita o ouro e o
## progresso de ofício ANTES de chamar o funil do tempo — e o funil era o
## único lugar que sabia da morte.
##
## Um defunto não bate ponto. Toda ação que credita alguma coisa passa a
## perguntar aqui, do mesmo jeito que já pergunta pela cela.
static func acabou(state: Dictionary) -> bool:
	return state.get("fim") != null

## A recusa padrão para quem tentar agir com a saga encerrada.
static func recusa_fim(state: Dictionary) -> Dictionary:
	var f: Dictionary = state.get("fim", {}) if state.get("fim") != null else {}
	return {"ok": false, "acabou": true,
		"msg": "A saga terminou (%s). Não há mais o que fazer com esta casa." %
			str(f.get("causa", "fim"))}

## A recusa padrão, em personagem, para quem tentar agir da cela.
static func recusa_preso(state: Dictionary) -> Dictionary:
	var m := meses_preso(state)
	return {"ok": false, "preso": true,
		"msg": "%s Faltam %d %s." % [AVISO_PRESO, m, "mês" if m == 1 else "meses"]}

## A FIANÇA — ouro compra liberdade, como sempre comprou.
##
## Sem ela a cadeia era um beco: o jogador só podia clicar "passar o dia"
## até o prazo vencer, e nenhum recurso do jogo tocava a masmorra. Aqui o
## cofre conversa com o calendário — e o preço sobe com o que falta.
const FIANCA_POR_MES := 240

static func preco_fianca(state: Dictionary) -> int:
	return FIANCA_POR_MES * meses_preso(state)

static func pagar_fianca(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	if not esta_preso(state):
		return {"ok": false, "msg": "Você não está preso."}
	var custo := preco_fianca(state)
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false,
			"msg": "O carcereiro conta com o dedo: %d de ouro, nem uma moeda a menos." % custo}
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	state["jogador"]["preso_ate"] = 0
	# comprar a saída não é o mesmo que sair inocente
	state["jogador"]["honra"] = maxi(0, roundi(int(state["jogador"].get("honra", 50)) * 0.93))
	if log.is_valid():
		_diz(log, "Fiança paga: %d de ouro. O portão range e você anda de novo." % custo)
	return {"ok": true, "msg": "Fiança paga: %d de ouro." % custo, "custo": custo}

static func contratar_guardas(state: Dictionary, qtd: int) -> Dictionary:
	var custo := 60 * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Guarda de elite custa 60/homem (%d)." % custo}
	state["jogador"]["ouro"] -= custo
	state["jogador"]["guardas"] = int(state["jogador"]["guardas"]) + qtd
	return {"ok": true, "msg": "%d guardas de elite contratados." % qtd}

## VESTIR O EXÉRCITO INTEIRO um degrau acima.
##
## Esta função era um sistema paralelo e órfão: subia `jogador.equip` de 0 a
## 3 por 200 × nível de ouro, cobrava o desconto da casa da noiva, e NÃO ERA
## CHAMADA POR NENHUM BOTÃO — só por um teste. Enquanto isso a Ferraria da
## tela mexia noutra tabela, por unidade. Dois sistemas de equipamento, um
## visível e travado em 0/3, o outro funcionando e sem contador.
##
## Agora ela delega para o sistema que existe. O contador 0/3 passa a ser
## derivado da tabela por unidade (`Equipar.nivel_do_exercito`), o desconto
## da noiva mudou-se para `Equipar.custo` — onde vale para a Ferraria toda —
## e o preço deixa de ser um número redondo inventado: é o custo real de
## vestir os homens que você de fato tem.
static func melhorar_equip(state: Dictionary) -> Dictionary:
	var de: int = Equipar.nivel_do_exercito(state)
	if de >= Equipar.MAX_NIVEL:
		return {"ok": false, "msg": "Equipamento no máximo."}
	return Equipar.equipar_tudo(state, de)

## Vender o excedente do celeiro é COMÉRCIO, e passa pelas mesmas duas
## regras da Feira: precisa da licença e empurra a oferta da praça. Sem
## isso a exportação era um cano paralelo que furava os dois freios —
## vendia sem Mapa Comercial, no preço cheio, quantas vezes quisesse, e o
## preço do trigo nunca caía por mais trigo que fosse despejado nele.
static func exportar_comida(state: Dictionary, qtd: int) -> Dictionary:
	if state["terra"] == null:
		return {"ok": false, "msg": "Você não tem terras."}
	var t: Dictionary = state["terra"]
	if int(t["alimento"]) < qtd:
		return {"ok": false, "msg": "Não há tanto alimento nos celeiros."}
	if not Economia.tem_praca(state, str(state["local"])):
		return {"ok": false, "msg": Economia.AVISO_SEM_PRACA}
	if not Economia.mapa_valido(state):
		return {"ok": false, "msg": Economia.AVISO_MAPA}
	t["alimento"] = int(t["alimento"]) - qtd
	# +10% sobre o preço: o excedente da própria terra sai sem intermediário
	var ganho: int = roundi(Economia.preco_de(state, state["local"], "trigo") * qtd * 1.1)
	state["jogador"]["ouro"] += ganho
	Economia.empurrar_oferta(state, str(state["local"]), "trigo", qtd)
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
						_diz(log, "Você afogou a rebelião em sangue — e %s morreu com a turba que liderou." % lider)
					else:
						_diz(log, "Você afogou a rebelião em sangue. A vila obedece — e odeia.")
				else:
					morrer(state, "rebeliao", log)
			else:
				# sem terra não há celeiro para abrir: o evento pode chegar a
				# quem perdeu tudo (ou a um save mutilado), e o ramo caía num
				# SCRIPT ERROR em vez de simplesmente não acontecer
				if state["terra"] == null:
					_diz(log, "Não há celeiro para abrir. A turba se dispersa sozinha, por ora.")
					return {}
				# ---- A SAÍDA NÃO-CRUEL, E ELA PRECISA DOER ----
				# Custava `min(ouro, 200)`, o que significa que um jogador
				# quebrado pagava ZERO e ainda comprava felicidade 55 — a
				# opção humana era a barata, e a espiral que ela deveria
				# quebrar (pobre → infeliz → rebelião → reprimir → +2 de
				# crueldade → teto mais baixo → mais rebelião) continuava
				# fechada porque reprimir era o único caminho com preço.
				#
				# Agora ceder custa o que uma vila come: ouro proporcional ao
				# tamanho dela E o imposto do mês inteiro. É caro, é sempre
				# possível, e não soma um ponto de crueldade sequer.
				var t_reb: Dictionary = state["terra"]
				var custo: int = mini(int(state["jogador"]["ouro"]),
					200 + int(t_reb["populacao"]) * 2)
				state["jogador"]["ouro"] -= custo
				t_reb["alimento"] = int(t_reb["alimento"]) + 60
				# o imposto deste mês não sai: quem abre celeiro não cobra
				# aluguel na mesma semana
				state["jogador"]["imposto_perdoado_em"] = "%d/%d" % [
					int(state.get("ano", 1)), int(state.get("mes", 1))]
				Livro.registrar(state, "terra", "ouro", -custo, "Celeiros abertos")
				if lider == "":
					t_reb["felicidade"] = 55
					_diz(log, "Você abriu os celeiros (-%d ouro) e perdoou o imposto do mês. O povo abaixa as foices." % custo)
				else:
					# o povo se acalma, mas o capataz que armou a revolta segue
					# no cargo — a ambição dele só cresceu com o gosto do poder
					state["terra"]["felicidade"] = 45
					for n in Cidadaos.lista(state):
						if str(n.get("nome", "")) == lider:
							n["ambicao"] = mini(10, int(n.get("ambicao", 5)) + 2)
							break
					_diz(log, "Você abriu os celeiros (-%d ouro). O povo abaixa as foices — mas %s, o capataz, continua no cargo, e não esqueceu." % [custo, lider])
		"notavel_ambicioso":
			# escolha: "comprar" (lealdade por ouro), "exilar" ou ignorar
			resultado = {"msg": Cidadaos.resolver_ambicioso(state, ev["nome"], escolha, log)}
		"traicao_guardas":
			var custo_g: int = int(state["jogador"]["guardas"]) * 15
			if escolha == "pagar" and state["jogador"]["ouro"] >= custo_g:
				state["jogador"]["ouro"] -= custo_g
				state["jogador"]["meses_sem_pagar"] = 0
				_diz(log, "Você pagou a guarda em dobro (-%d). Os portões continuam seus." % custo_g)
			else:
				_diz(log, "Sua guarda abriu os portões na calada da noite. Você fugiu pelo esgoto.")
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
	# A LISTA VEM DE novo_jogo, não de uma cópia à mão: era assim que
	# `segredos`, `mensageiros`, `clas_ativos`, `cartas` e
	# `chantagem_pendente` ficaram de fora — cada um indexado DIRETO em
	# clas.gd, intriga.gd e na interface, e cada save antigo virava um
	# SCRIPT ERROR por mês e duas abas que paravam de desenhar no meio.
	# Chave nova em novo_jogo passa a ser reposta sozinha, para sempre.
	var molde: Dictionary = _molde_de_estado()
	for campo in molde:
		if not state.has(campo):
			var padrao = molde[campo]
			state[campo] = padrao.duplicate(true) if padrao is Array or padrao is Dictionary \
				else padrao
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

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
