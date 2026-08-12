# ============================================================
# ECONOMIA VIVA (port GDScript de js/economy.js)
# Oferta×demanda, guerra queima campos, fadiga de guerra,
# fome, rebelião, deserção por soldo atrasado.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Estacoes = preload("res://scripts/estacoes.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")

static func inicializar_mercados(state: Dictionary) -> void:
	state["mercados"] = {}
	for r in state["reinos"]:
		var m := {}
		for g_id in Dados.MERCADORIAS:
			m[g_id] = {"oferta": 1.6 if r["producao"].has(g_id) else 1.0, "demanda": 1.0}
		state["mercados"][r["id"]] = m

# ------------------------------------------------------------
# A ESTAÇÃO NO MERCADO
# ------------------------------------------------------------
## O que cada estação faz com a OFERTA de cada bem. Acima de 1 é fartura
## (preço cai), abaixo é escassez (preço sobe). É isto que transforma o
## comércio numa aposta de calendário: comprar trigo na colheita e segurar
## até o inverno é uma decisão, não uma tabela fixa.
##
## Bem que não aparece aqui não tem estação — prata e ferro saem do chão o
## ano inteiro, e é de propósito: nem tudo pode oscilar, ou nada oscila.
const SAZONALIDADE := {
	"trigo":   {"primavera": 0.85, "verao": 1.35, "outono": 1.20, "inverno": 0.55},
	"madeira": {"primavera": 1.10, "verao": 1.15, "outono": 1.05, "inverno": 0.70},
	"tecidos": {"primavera": 1.05, "verao": 1.15, "outono": 1.00, "inverno": 0.80},
	"sal":     {"primavera": 1.00, "verao": 1.20, "outono": 1.05, "inverno": 0.85},
	"pedra":   {"primavera": 1.05, "verao": 1.15, "outono": 1.00, "inverno": 0.75},
}

static func fator_sazonal(state: Dictionary, g_id: String) -> float:
	var tabela = SAZONALIDADE.get(g_id)
	if tabela == null:
		return 1.0
	return float(tabela.get(Estacoes.atual(state), 1.0))

## O MAPA COMERCIAL — a licença de negociar, comprada na taverna e válida
## por UM mês.
##
## É o freio da arbitragem infinita que o teste alfa mediu (150 → 22.000
## de ouro em 24 meses sem risco nenhum): agora o comércio tem custo fixo
## recorrente e obriga a voltar à taverna. Quem compra e vende pouco não
## paga o mapa; quem vive de rota, paga todo mês.
static func mapa_valido(state: Dictionary) -> bool:
	var m = state.get("mapa_comercial")
	if not (m is Dictionary):
		return false
	var absoluto: int = int(state["ano"]) * 12 + int(state["mes"])
	return int(m.get("ate", 0)) >= absoluto

static func mapa_meses_restantes(state: Dictionary) -> int:
	var m = state.get("mapa_comercial")
	if not (m is Dictionary):
		return 0
	return maxi(0, int(m.get("ate", 0)) - (int(state["ano"]) * 12 + int(state["mes"])) + 1)

## Renova (ou compra) o mapa: vale este mês e o próximo vira sozinho.
static func renovar_mapa(state: Dictionary, meses: int = 1) -> void:
	state["mapa_comercial"] = {
		"ate": int(state["ano"]) * 12 + int(state["mes"]) + maxi(0, meses - 1)}

## Existe armazém aqui? `state["mercados"]` só tem os SEIS reinos — o Reino
## sem Rei e as Terras Bárbaras são nós do mapa onde se viaja, se luta e se
## bebe, mas não se negocia. Sem esta pergunta, `preco_de` abortava com
## SCRIPT ERROR e devolvia 0, e comprar a preço zero era ouro infinito.
static func tem_praca(state: Dictionary, reino_id: String) -> bool:
	var m = state.get("mercados")
	return m is Dictionary and m.has(reino_id)

const AVISO_SEM_PRACA := "Aqui não há armazém nem feitor — só fogueira e desconfiança."

static func preco_de(state: Dictionary, reino_id: String, g_id: String) -> int:
	if not tem_praca(state, reino_id):
		return 0
	var m: Dictionary = state["mercados"][reino_id][g_id]
	# float SEMPRE: o load normaliza 3.0 para int 3, e int/int trunca —
	# o preço mudava sozinho (3 → 1) só por salvar e recarregar o jogo
	var preco: float = Dados.MERCADORIAS[g_id]["preco_base"] \
		* (float(m["demanda"]) / maxf(0.05, float(m["oferta"])))
	var rel: int = state["tags"].get("rei_" + reino_id, {"relacao": 0})["relacao"]
	if rel <= -60: preco *= 1.6
	elif rel <= -25: preco *= 1.25
	elif rel >= 60: preco *= 0.85
	elif rel >= 25: preco *= 0.95
	return maxi(1, roundi(preco))

const AVISO_MAPA := "Sem Mapa Comercial válido, nenhum feitor te vende nem te compra. Renove na taverna."

## Quanto cada unidade negociada move a oferta do armazém.
##
## Era 0,02 — um lote de 5 empurrava a oferta 0,10, e como o preço é
## `base × demanda / oferta`, quarenta lotes levavam a oferta ao piso e
## quintuplicavam o preço contra quem estava comprando. Isso matou o
## exploit do teste alfa (150 → 22.000 em 24 meses), mas matou junto a
## rota inteira: a sonda `tests/medir_arbitragem.gd` mediu um mercador
## sensato PERDENDO dinheiro em toda bolsa — a licença mensal custava
## mais que a margem que a rota conseguia entregar.
##
## 0,006 (com a licença a 60) dá fôlego para uma carga de verdade sem
## devolver o dinheiro infinito. O que a sonda mede hoje, em 24 meses:
##
##   bolsa    mercador sensato      mercador ganancioso
##   150      30    (não decola)    30
##   1.000    2.255 (2,3×)          270  (quebra)
##   4.000    5.924 (1,5×)          1.326 (quebra)
##
## É o desenho certo: a rota paga a quem sabe PARAR de comprar, arruína
## quem enche a carroça cegamente, e não substitui empregos e contratos
## para quem começa do zero. A sonda é a régua — mexer aqui obriga a
## rodá-la de novo (`tests/medir_arbitragem.gd`).
const ELASTICIDADE := 0.006

static func comprar(state: Dictionary, reino_id: String, g_id: String, qtd: int) -> Dictionary:
	if not tem_praca(state, reino_id):
		return {"ok": false, "msg": AVISO_SEM_PRACA}
	if not mapa_valido(state):
		return {"ok": false, "msg": AVISO_MAPA}
	var preco := preco_de(state, reino_id, g_id)
	var custo := preco * qtd
	if state["jogador"]["ouro"] < custo:
		return {"ok": false, "msg": "Ouro insuficiente (custa %d)." % custo}
	state["jogador"]["ouro"] -= custo
	state["carga"][g_id] = int(state["carga"].get(g_id, 0)) + qtd
	var m: Dictionary = state["mercados"][reino_id][g_id]
	m["oferta"] = maxf(0.2, m["oferta"] - ELASTICIDADE * qtd)
	return {"ok": true, "msg": "Comprou %d por %d de ouro." % [qtd, custo]}

static func vender(state: Dictionary, reino_id: String, g_id: String, qtd: int) -> Dictionary:
	if not tem_praca(state, reino_id):
		return {"ok": false, "msg": AVISO_SEM_PRACA}
	if not mapa_valido(state):
		return {"ok": false, "msg": AVISO_MAPA}
	if int(state["carga"].get(g_id, 0)) < qtd:
		return {"ok": false, "msg": "Você não tem essa carga."}
	var em_guerra := _em_guerra(state, reino_id)
	var preco := preco_de(state, reino_id, g_id)
	if em_guerra and g_id == "trigo":
		preco = roundi(preco * 1.3)
		if randf() < 0.20:
			var perda := ceili(qtd / 2.0)
			state["carga"][g_id] = int(state["carga"][g_id]) - perda
			return {"ok": false, "msg": "Patrulha confiscou %d do contrabando!" % perda}
	var ganho := preco * qtd
	state["carga"][g_id] = int(state["carga"][g_id]) - qtd
	state["jogador"]["ouro"] += ganho
	empurrar_oferta(state, reino_id, g_id, qtd)
	return {"ok": true, "msg": "Vendeu %d por %d de ouro." % [qtd, ganho]}

## Despejar mercadoria numa praça derruba o preço dela. Público porque a
## exportação do celeiro (jogo.gd) também é despejo — e tem que pagar o
## mesmo preço em preço.
static func empurrar_oferta(state: Dictionary, reino_id: String, g_id: String,
		qtd: int) -> void:
	if not tem_praca(state, reino_id):
		return
	var m: Dictionary = state["mercados"][reino_id][g_id]
	m["oferta"] = minf(3.0, float(m["oferta"]) + ELASTICIDADE * qtd)

static func _em_guerra(state: Dictionary, reino_id: String) -> bool:
	for g in state["guerras"]:
		if g["a"] == reino_id or g["b"] == reino_id:
			return true
	return false

static func talvez_iniciar_guerra(state: Dictionary, log: Callable) -> void:
	if state["guerras"].size() >= 2 or randf() > 0.10:
		return
	# reino dominado não declara guerra: sem este filtro o mapa enchia de
	# guerras com participantes que já não existem politicamente
	var livres: Array = state["reinos"].filter(func(r):
		return not _em_guerra(state, r["id"]) \
			and str(r.get("dominado_por", "")) == "")
	if livres.size() < 2:
		return
	var a: Dictionary = Dados.rnd(livres)
	var b: Dictionary = Dados.rnd(livres.filter(func(r): return r["id"] != a["id"]))
	state["guerras"].append({"a": a["id"], "b": b["id"], "meses": 0})
	_diz(log, "GUERRA! %s declarou guerra a %s." % [a["nome"], b["nome"]])

static func tick_guerras(state: Dictionary, log: Callable) -> void:
	var vivas: Array = []
	for g in state["guerras"]:
		g["meses"] += 1
		for id in [g["a"], g["b"]]:
			# o jogador não tem mercado próprio em state["mercados"] (só os
			# seis reinos têm) — Parte VII (Estágio 6) passou a permitir
			# guerra com "jogador", e sem este guard o índice quebraria aqui
			if id == "jogador":
				continue
			var m: Dictionary = state["mercados"][id]
			m["trigo"]["oferta"] = maxf(0.25, m["trigo"]["oferta"] * 0.82)
			m["ferro"]["demanda"] = minf(3.0, m["ferro"]["demanda"] * 1.08)
		if g["meses"] >= 6 and randf() < 0.35:
			_diz(log, "%s e %s assinaram a paz, exaustos." % [g["a"], g["b"]])
		else:
			vivas.append(g)
	state["guerras"] = vivas

## ---------- CHOQUES DE MERCADO ----------
## Um choque é um empurrão com prazo: {reino, bem, oferta, demanda, meses}.
## Qualquer sistema pode empilhar um — guerra, saque, rumor de taverna,
## intriga — e todos passam pelo MESMO caminho até o preço. Sem isto, cada
## novo evento vira um caso especial dentro de preco_de().
static func abalar(state: Dictionary, reino: String, bem: String,
		d_oferta: float, d_demanda: float, meses: int) -> void:
	if not state.has("choques"):
		state["choques"] = []
	state["choques"].append({"reino": reino, "bem": bem,
		"oferta": d_oferta, "demanda": d_demanda, "meses": meses})

static func tick_choques(state: Dictionary) -> void:
	if not state.has("choques"):
		state["choques"] = []
		return
	var vivos: Array = []
	for c in state["choques"]:
		var mercado_reino = state["mercados"].get(c["reino"])
		if mercado_reino == null:
			continue
		var m: Dictionary = mercado_reino[c["bem"]]
		m["oferta"] = clampf(m["oferta"] + float(c["oferta"]), 0.2, 3.0)
		m["demanda"] = clampf(m["demanda"] + float(c["demanda"]), 0.5, 3.0)
		c["meses"] = int(c["meses"]) - 1
		if int(c["meses"]) > 0:
			vivos.append(c)
	state["choques"] = vivos

static func tick_mercados(state: Dictionary) -> void:
	for r in state["reinos"]:
		var em_guerra := _em_guerra(state, r["id"])
		for g_id in Dados.MERCADORIAS:
			var m: Dictionary = state["mercados"][r["id"]][g_id]
			# o alvo do mês É a estação: no inverno o celeiro do produtor de
			# trigo encolhe, na colheita transborda. O mercado persegue esse
			# alvo em vez de voltar sempre ao mesmo número — é o que faz
			# existir hora certa de comprar e hora certa de vender.
			var base: float = 1.6 if r["producao"].has(g_id) else 1.0
			var alvo: float = clampf(base * fator_sazonal(state, g_id), 0.25, 3.0)
			if not em_guerra:
				# 0.15 → 0.10: a janela de lucro precisa durar mais que um
				# mês, senão a sazonalidade some antes de o jogador viajar
				m["oferta"] += (alvo - m["oferta"]) * 0.10
			# ESTOQUE que flutua sozinho: cada praça respira num ritmo
			# próprio, e é essa diferença entre praças que sustenta a rota
			m["oferta"] = clampf(float(m["oferta"]) * (1.0 + (randf() - 0.5) * 0.10), 0.2, 3.0)
			m["demanda"] += (1.0 - m["demanda"]) * 0.10
			m["demanda"] = clampf(m["demanda"] * (1.0 + (randf() - 0.5) * 0.10), 0.5, 3.0)

## ---------- O DILEMA DA POPULAÇÃO ----------
## Quem pega em armas SAI da lavoura e do rol de contribuintes. Um exército
## de 200 homens não é só caro de manter: ele apaga 200 pagadores de imposto
## da sua própria terra. É a escolha central da economia — muitos homens
## medíocres ou poucos de elite.
static func pop_em_armas(state: Dictionary) -> int:
	var t := 0
	for tipo in state["jogador"]["tropas"]:
		var d = Dados.TROPAS.get(tipo)
		if d != null:
			t += int(state["jogador"]["tropas"][tipo]) * int(d.get("pop", 1))
	# quem está na estrada também não colhe nem paga imposto
	for m in state.get("marchas", []):
		for tipo in m.get("tropas", {}):
			var d2 = Dados.TROPAS.get(tipo)
			if d2 != null:
				t += int(m["tropas"][tipo]) * int(d2.get("pop", 1))
	return t

## População que ainda trabalha: é ela que colhe e paga imposto.
static func populacao_ativa(state: Dictionary) -> int:
	if state.get("terra") == null:
		return 0
	return maxi(0, int(state["terra"]["populacao"]) - pop_em_armas(state))

## Imposto do mês. Sai do NÍVEL da terra (o portão de progressão) vezes a
## população que sobrou trabalhando.
## GESTÃO, o atributo que não valia nada.
##
## Dois empregos a subiam (Supervisor de obras, Intendente de suprimentos),
## a ficha da Casa mostrava a barra e os filhos herdavam o número — e
## NENHUMA mecânica lia o valor. Agora ela vale nos dois lugares onde um
## bom administrador aparece: o que entra da terra e o que sai do quartel.
## Neutra em 5 (o meio da escala, onde o jogador começa), ±4% por ponto.
static func fator_gestao(state: Dictionary) -> float:
	var g: int = int(state["jogador"].get("atributos", {}).get("gestao", 5))
	return 1.0 + (g - 5) * 0.04

static func imposto_mensal(state: Dictionary) -> int:
	if state.get("terra") == null:
		return 0
	var nivel: int = clampi(int(state["terra"]["nivel"]), 0, Dados.NIVEIS_TERRA.size() - 1)
	var taxa: float = float(Dados.NIVEIS_TERRA[nivel]["imposto"])
	return roundi(populacao_ativa(state) * taxa * fator_gestao(state))

static func tick_terra(state: Dictionary, log: Callable) -> void:
	if state["terra"] == null:
		return
	var t: Dictionary = state["terra"]
	var trabalhando := populacao_ativa(state)
	var em_armas := pop_em_armas(state)

	# ---- colheita, dobrada à estação ----
	var fator := Estacoes.fator_comida(state)
	var producao: int = roundi(trabalhando * 1.5 * (1.0 + t["nivel"] * 0.15) * fator)
	# Moleiro leal: o design original pedia "+20% na capacidade do celeiro",
	# mas o celeiro nunca teve teto — alimento acumula livre. Um moleiro
	# competente rende mais farinha do MESMO trigo, então o bônus vira +20%
	# na PRODUÇÃO, que é o número que de fato existe. No inverno a produção
	# já é zero e continua zero: farinha não nasce de campo que não colheu.
	if Cidadaos.oficio_ativo(state, "moleiro"):
		producao = roundi(producao * 1.2)
	# a casa da esposa também trabalha: filha de moleiro sabe onde o grão
	# rende, e é esse o dote de quem casa fora da nobreza
	var Pretendentes = load("res://scripts/pretendentes.gd")
	producao = roundi(producao * Pretendentes.fator_colheita(state))
	t["alimento"] = maxi(0, int(t["alimento"]) + producao - int(t["populacao"]))
	t["madeira"] = int(t["madeira"]) + 2 + int(t["nivel"]) * 2 + int(trabalhando / 12.0)

	if Estacoes.e_inverno(state) and producao == 0:
		_diz(log, "Inverno: as fazendas de %s pararam. O celeiro é o que há." % t["nome"])
	elif em_armas > int(t["populacao"]) * 0.4:
		_diz(log, "Quase metade da vila está em armas: a colheita e o imposto despencaram.")

	# ---- imposto: só quem ficou é que paga ----
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + imposto_mensal(state)
	state["jogador"]["ultimo_imposto"] = imposto_mensal(state)

	# ---- fome e pressão ----
	if int(t["alimento"]) <= 0:
		t["felicidade"] = clampi(int(t["felicidade"]) - 20, 0, 100)
		t["populacao"] = maxi(5, int(t["populacao"]) - Dados.ri(1, 4))
		_diz(log, "FOME em %s! Felicidade -20." % t["nome"])
	elif int(t["felicidade"]) < 70:
		t["felicidade"] = clampi(int(t["felicidade"]) + 5, 0, 100)
	# filha do capataz: a vila obedecia a ela antes de obedecer a você
	# CRUELDADE TEM CAMINHO DE VOLTA. Saquear uma caravana marcava você
	# para sempre: o número só subia, e ele fecha portas (os notáveis
	# reagem a partir de 3, e o herdeiro nasce mimado). Governar bem por
	# meio ano seguido apaga um ponto — reputação se refaz devagar, mas
	# se refaz. Um único ato cruel zera o contador (jogo.gd/viagem.gd).
	if int(t["felicidade"]) >= 65:
		var limpos: int = int(state["jogador"].get("meses_limpos", 0)) + 1
		state["jogador"]["meses_limpos"] = limpos
		if limpos >= 6 and int(state["jogador"].get("crueldade", 0)) > 0:
			state["jogador"]["crueldade"] = int(state["jogador"]["crueldade"]) - 1
			state["jogador"]["meses_limpos"] = 0
			_diz(log, "Meio ano de bom governo: o povo já fala de você com menos medo.")
	else:
		state["jogador"]["meses_limpos"] = 0

	var bonus_esposa: int = Pretendentes.bonus_felicidade(state)
	if bonus_esposa > 0:
		t["felicidade"] = clampi(int(t["felicidade"]) + bonus_esposa, 0, 100)
	if int(t["felicidade"]) <= 20 and randf() < 0.5:
		# um capataz rico e desleal não espera cruzar o limiar de ascensão
		# quando a vila já está pronta para pegar em foices — ele lidera
		var lider := Cidadaos.capataz_lider(state)
		if lider.is_empty():
			_diz(log, "REBELIÃO em %s!" % t["nome"])
			state["evento_pendente"] = {"tipo": "rebeliao"}
		else:
			_diz(log, "REBELIÃO em %s — e %s, o capataz, está à frente dela!"
				% [t["nome"], str(lider["nome"])])
			state["evento_pendente"] = {"tipo": "rebeliao", "lider": str(lider["nome"])}

## ---------- UPKEEP ----------
## O que um exército consome por mês: ouro (soldo), comida e madeira.
## Vale para o jogador e para os reinos NPC — a mesma função, os mesmos
## números. É isto que impede um exército de existir de graça.
##
## `desconto_ferreiro`: o ofício de Ferreiro, quando LEAL na Corte (ver
## Cidadaos.oficio_ativo), aparelha melhor a cavalaria — -15% no soldo
## (`manut`) das tropas de CHOQUE. O documento de design original pedia
## desconto no "upkeep de ferro das tropas de choque", mas o jogo nunca
## rastreou ferro como custo de manutenção — só ouro, comida e madeira.
## Dar ao Ferreiro o desconto sobre o soldo da cavalaria preserva a
## intenção (ele é quem arma os cavaleiros) sem inventar um recurso novo.
static func upkeep_de(tropas: Dictionary, multiplicador: float = 1.0,
		desconto_ferreiro: bool = false) -> Dictionary:
	var ouro := 0.0
	var comida := 0.0
	var madeira := 0.0
	for tipo in tropas:
		var d = Dados.TROPAS.get(tipo)
		if d == null:
			continue
		var n: int = int(tropas[tipo])
		var soldo: float = float(d.get("manut", 0))
		if desconto_ferreiro and str(d.get("classe", "")) == "cav":
			soldo *= 0.85
		ouro += soldo * n
		comida += float(d.get("comida", 0)) * n
		madeira += float(d.get("madeira", 0)) * n
	return {"ouro": roundi(ouro * multiplicador),
		"comida": roundi(comida * multiplicador),
		"madeira": roundi(madeira * multiplicador)}

## Moral do exército do jogador. Cai quando falta pagamento ou comida, sobe
## devagar quando tudo está em dia — deserção vem da moral, não do dado.
static func moral(state: Dictionary) -> int:
	return int(state["jogador"].get("moral", 100))

static func mudar_moral(state: Dictionary, delta: int) -> int:
	var m := clampi(moral(state) + delta, 0, 100)
	state["jogador"]["moral"] = m
	return m

static func tick_exercito(state: Dictionary, log: Callable) -> void:
	# tropas em marcha também comem — só que do que carregam, e o Cerco
	# cobra em dobro. Aqui paga-se pelo que está EM CASA.
	# um quartel-mestre de verdade compra melhor: gestão alta desconta o
	# soldo, gestão baixa o encarece (mesmo fator do imposto, invertido)
	var custo := upkeep_de(state["jogador"]["tropas"], 2.0 - fator_gestao(state),
		Cidadaos.oficio_ativo(state, "ferreiro"))
	state["jogador"]["ultima_manut"] = int(custo["ouro"])
	state["jogador"]["ultimo_upkeep"] = custo

	var faltou: Array = []
	# ouro
	if int(state["jogador"]["ouro"]) >= int(custo["ouro"]):
		state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - int(custo["ouro"])
		state["jogador"]["meses_sem_pagar"] = 0
	else:
		state["jogador"]["ouro"] = 0
		state["jogador"]["meses_sem_pagar"] = int(state["jogador"].get("meses_sem_pagar", 0)) + 1
		faltou.append("soldo")
	# comida e madeira saem da terra; sem terra, o mercenário compra na estrada
	var t = state.get("terra")
	if t != null:
		if int(t["alimento"]) >= int(custo["comida"]):
			t["alimento"] = int(t["alimento"]) - int(custo["comida"])
		else:
			t["alimento"] = 0
			faltou.append("comida")
		if int(t["madeira"]) >= int(custo["madeira"]):
			t["madeira"] = int(t["madeira"]) - int(custo["madeira"])
		else:
			t["madeira"] = 0
			if int(custo["madeira"]) > 0:
				faltou.append("madeira")
	elif int(custo["comida"]) > 0 and int(state["jogador"]["ouro"]) < int(custo["comida"]) * 2:
		faltou.append("comida")

	# ---- moral: é ela que deserta, não o dado ----
	if faltou.is_empty():
		mudar_moral(state, 6)
		return
	mudar_moral(state, -12 * faltou.size())
	_diz(log, "Falta %s ao seu exército. A moral cai (%d)."
		% [" e ".join(faltou), moral(state)])

	if moral(state) <= 35:
		var perdidos := 0
		for tipo in state["jogador"]["tropas"]:
			var n: int = int(state["jogador"]["tropas"][tipo])
			if n <= 0:
				continue
			# quanto pior a moral, maior a sangria
			var taxa: float = 0.10 + (35 - moral(state)) * 0.008
			var vao: int = mini(n, ceili(n * taxa))
			state["jogador"]["tropas"][tipo] = n - vao
			perdidos += vao
		if perdidos > 0:
			_diz(log, "%d homens desertaram na calada da noite." % perdidos)
	if moral(state) <= 10 and int(state["jogador"]["guardas"]) > 0 \
			and state["terra"] != null and randf() < 0.5:
		state["evento_pendente"] = {"tipo": "traicao_guardas"}
		_diz(log, "Um reino rival ofereceu ouro à sua guarda de elite...")

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
