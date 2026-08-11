# ============================================================
# TESTES DAS MARCHAS — grafo de rotas, tempo de viagem, emboscadas,
# combate na chegada e o retorno com o saque.
#   godot --headless --path . --script res://tests/teste_marchas.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Combate = preload("res://scripts/combate.gd")
const Rotas = preload("res://scripts/rotas.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Cerco = preload("res://scripts/cerco.gd")
const Relogio = preload("res://scripts/relogio.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Dialogo = preload("res://scripts/dialogo.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func base() -> Dictionary:
	var s := Jogo.novo_jogo("Marcha")
	s["terra"] = {"nome": "Vale do Corvo", "nivel": 3, "populacao": 300,
		"alimento": 900, "madeira": 100, "felicidade": 70, "pressao": 0.0}
	s["jogador"]["ouro"] = 9999
	s["jogador"]["tropas"] = Jogo._tropas_zeradas(
		{"lanceiro": 60, "espadachim": 40, "arqueiro": 30, "cav_leve": 10})
	return s

func _init() -> void:
	seed(4242)
	print("=== MARCHAS ===")

	# ---------------- 1. O GRAFO ----------------
	var d1 := Rotas.entre("jogador", "touros")
	ok("rota direta é encontrada na ida", int(d1["distancia"]) == 5 and d1["direta"])
	var d2 := Rotas.entre("touros", "jogador")
	ok("a MESMA rota é encontrada na volta (B_A)",
		int(d2["distancia"]) == 5 and d2["direta"])
	var d3 := Rotas.entre("touros", "aguias")
	ok("par sem ligação cai no fallback, sem quebrar",
		not d3["direta"] and int(d3["distancia"]) == int(Dados.ROTA_DESCONHECIDA["distancia"]))
	ok("distância de um nó para si mesmo é zero",
		int(Rotas.entre("touros", "touros")["distancia"]) == 0)

	# ids com underscore não podem quebrar o parser de chaves
	ok("id composto (sem_rei) é lido corretamente",
		int(Rotas.entre("jogador", "sem_rei")["distancia"]) == 7)
	# 4 vizinhos desde as Terras Bárbaras: o Reino sem Rei é uma das duas
	# pontas por onde se chega à fronteira selvagem
	ok("vizinhos de sem_rei encontrados",
		Rotas.vizinhos("sem_rei").size() == 4
		and Rotas.vizinhos("sem_rei").has("barbaros"),
		", ".join(Rotas.vizinhos("sem_rei")))
	ok("todos os 9 nós existem (6 reinos + jogador + sem-rei + fronteira)",
		Rotas.todos_os_nos().size() == 9)

	# ---------------- 2. CAMINHO E GARGALOS ----------------
	var c_imp := Rotas.caminho("jogador", "imperio")
	ok("caminho até o Império passa pelos Touros",
		c_imp["existe"] and c_imp["nos"] == ["jogador", "touros", "imperio"],
		str(c_imp["nos"]))
	ok("distância do caminho soma os trechos", int(c_imp["distancia"]) == 13,
		"%d (5+8)" % int(c_imp["distancia"]))

	var c_leoes := Rotas.caminho("jogador", "leoes")
	ok("caminho até os Leões existe e é indireto",
		c_leoes["existe"] and c_leoes["nos"].size() >= 3, str(c_leoes["nos"]))
	ok("caminho longo é mais caro que o curto",
		int(c_leoes["distancia"]) > int(c_imp["distancia"]))
	# Dijkstra tem que escolher o MENOR: jogador→alvorecer→aguias = 16,
	# contra jogador→touros→imperio→alvorecer→aguias = 27
	var c_aguias := Rotas.caminho("jogador", "aguias")
	ok("Dijkstra escolhe o trajeto mais curto",
		int(c_aguias["distancia"]) == 16, "%d" % int(c_aguias["distancia"]))
	ok("o perigo do caminho acumula os trechos",
		float(c_aguias["perigo"]) > float(Rotas.entre("jogador", "alvorecer")["perigo"]))
	ok("perigo nunca passa de 1", float(c_aguias["perigo"]) <= 1.0)

	# ---------------- 3. TEMPO DE VIAGEM ----------------
	# a REGRA DE OURO: a tropa mais lenta manda, e a mais lenta é a de MAIOR vel
	var so_cavalo := {"cav_leve": 10}                    # vel 10
	var com_espada := {"cav_leve": 10, "espadachim": 1}  # vel 22 entra no lote
	ok("um espadachim atrasa a cavalaria inteira",
		Marchas.minutos_por_campo(com_espada) == 22
		and Marchas.minutos_por_campo(so_cavalo) == 10)
	ok("a marcha usa MAX(vel), não MIN",
		Marchas.duracao(com_espada, 10) > Marchas.duracao(so_cavalo, 10))
	ok("duração = distância × vel da mais lenta",
		Marchas.duracao({"lanceiro": 5}, 12) == 12 * 18)
	ok("exército vazio não viaja", Marchas.duracao({}, 10) == 0)

	# a conta que o jogador vê
	var s := base()
	var est := Marchas.estimar(s, "imperio", {"lanceiro": 10})
	ok("estimativa traz dias, risco e trajeto",
		est.has("minutos") and est.has("risco") and str(est["trajeto"]).contains("→"),
		str(est["trajeto"]))
	# UMA régua só: o "dia" da marcha é o mesmo dia do rodapé (200 minutos),
	# e não mais um trigésimo de mês. 13 campos de lanceiro = 234 minutos =
	# dois cliques de "Passar o dia" — a conta agora fecha na cabeça.
	ok("13 campos com lanceiros ≈ 2 dias do jogador",
		Relogio.texto_dias(int(est["minutos"])) == "2 dias",
		"%d min" % int(est["minutos"]))

	# ---------------- 4. DESPACHO ----------------
	var lanc0: int = int(s["jogador"]["tropas"]["lanceiro"])
	var r := Marchas.despachar(s, "touros", {"lanceiro": 20}, "saque")
	ok("despachar aceita a ordem", r["ok"], str(r["msg"]))
	ok("as tropas SAEM do bolso na hora",
		int(s["jogador"]["tropas"]["lanceiro"]) == lanc0 - 20)
	ok("a marcha entra na lista", Marchas.lista(s).size() == 1)
	ok("intenção inválida é recusada",
		not Marchas.despachar(s, "touros", {"lanceiro": 1}, "piquenique")["ok"])
	ok("não dá para enviar tropa que não existe",
		not Marchas.despachar(s, "touros", {"cav_pesada": 99}, "saque")["ok"])
	ok("exército vazio é recusado",
		not Marchas.despachar(s, "touros", {}, "saque")["ok"])

	# ---------------- 5. O RELÓGIO MOVE A MARCHA ----------------
	var m: Dictionary = Marchas.lista(s)[0]
	var quando: int = int(m["chega_em"])
	Relogio.avancar(s, quando - 1, Jogo.log_para(s))
	ok("um minuto antes, a marcha ainda está a caminho",
		Marchas.lista(s).size() == 1 and Marchas.lista(s)[0]["fase"] == "ida")
	Relogio.avancar(s, 1, Jogo.log_para(s))
	var apos: Array = Marchas.lista(s)
	ok("ao chegar, a marcha luta e passa para a volta",
		apos.is_empty() or apos[0]["fase"] == "volta",
		apos[0]["fase"] if not apos.is_empty() else "destruída")

	# ---------------- 6. SAQUE VOLTA COM CARGA ----------------
	# alvo fraco de propósito: o Reino sem Rei não tem exército de pé.
	# (Contra um dos seis reinos, 40 lanceiros morrem — e é para morrer mesmo:
	#  uma guarnição de verdade tem espadachins e arqueiros.)
	var s2 := base()
	var lanc_antes: int = int(s2["jogador"]["tropas"]["lanceiro"])
	Marchas.despachar(s2, "sem_rei", {"lanceiro": 50, "espadachim": 20}, "saque")
	var m2: Dictionary = Marchas.lista(s2)[0]
	m2["perigo"] = 0.0                       # sem emboscada: teste determinístico
	var carga_antes: int = int(s2["carga"].get("madeira", 0))
	var ouro_antes: int = int(s2["jogador"]["ouro"])
	# metade do caminho: as tropas ainda estão fora e a carga não chegou
	Relogio.avancar(s2, int(m2["duracao"]) + 5, Jogo.log_para(s2))
	ok("logo após a batalha, o saque AINDA não está no cofre",
		int(s2["carga"].get("madeira", 0)) == carga_antes
		and int(s2["carga"].get("trigo", 0)) == 0)
	ok("e as tropas ainda não voltaram",
		int(s2["jogador"]["tropas"]["lanceiro"]) == lanc_antes - 50)
	# agora a volta
	Relogio.avancar(s2, int(m2["duracao"]) + 5, Jogo.log_para(s2))
	ok("a marcha terminou e saiu da lista", Marchas.lista(s2).is_empty())
	ok("os sobreviventes voltaram ao exército",
		int(s2["jogador"]["tropas"]["lanceiro"]) > lanc_antes - 50,
		"%d de %d" % [int(s2["jogador"]["tropas"]["lanceiro"]), lanc_antes])
	ok("o saque entrou no cofre só depois da volta",
		int(s2["carga"].get("madeira", 0)) > carga_antes
		or int(s2["carga"].get("trigo", 0)) > 0,
		"madeira %d, trigo %d" % [int(s2["carga"].get("madeira", 0)),
			int(s2["carga"].get("trigo", 0))])

	# e o alvo sentiu o saque
	var s3 := base()
	Geopolitica.inicializar(s3)
	var tesouro0: int = int(Geopolitica.reino_por_id(s3, "touros")["tesouro"])
	Marchas.despachar(s3, "touros", {"lanceiro": 55, "cav_leve": 10}, "saque")
	Marchas.lista(s3)[0]["perigo"] = 0.0
	Relogio.avancar(s3, 10000, Jogo.log_para(s3))
	ok("o saque tira ouro do tesouro do alvo",
		int(Geopolitica.reino_por_id(s3, "touros")["tesouro"]) < tesouro0,
		"%d → %d" % [tesouro0, int(Geopolitica.reino_por_id(s3, "touros")["tesouro"])])

	# ---------------- 7. SAQUE × CERCO ----------------
	var s4 := base()
	Marchas.despachar(s4, "touros", {"lanceiro": 30, "arqueiro": 20, "cav_leve": 5}, "saque")
	var mm: Dictionary = Marchas.lista(s4)[0]
	mm["perigo"] = 0.0
	Relogio.avancar(s4, int(mm["duracao"]), Jogo.log_para(s4))
	# o relatório do saque tem UMA fase; o do cerco, três
	# Cerco NÃO resolve mais na chegada — virou máquina de seis fases, coberta
	# em teste_cerco.gd. Aqui o que interessa é o RELATÓRIO da batalha, então
	# o caminho direto é um saque, que resolve ao chegar.
	var s5 := base()
	Marchas.despachar(s5, "sem_rei", {"lanceiro": 30, "arqueiro": 20, "cav_leve": 5}, "saque")
	var mc: Dictionary = Marchas.lista(s5)[0]
	mc["perigo"] = 0.0
	var evs: Array = Relogio.avancar(s5, int(mc["duracao"]), Jogo.log_para(s5))["marchas"]
	var batalha := {}
	for e in evs:
		if e.get("tipo", "") == "batalha":
			batalha = e
	ok("a chegada gera um relatório de batalha", not batalha.is_empty())
	if not batalha.is_empty():
		ok("a batalha detalha as fases travadas", batalha["fases"].size() >= 1,
			"%d fases" % batalha["fases"].size())
		ok("o relatório é texto legível",
			str(batalha["resumo"]).contains("Disparo")
			or str(batalha["resumo"]).contains("Corpo a corpo"))

	# ---------------- 8. EMBOSCADA ----------------
	# `perigo` é a chance de UM dia ruim na viagem INTEIRA, repartida pelos
	# dias de estrada — então uma viagem só não garante emboscada. O teste
	# roda várias e cobra que aconteça, e que quando acontece, doa.
	var emboscadas := 0
	var doeu := false
	for tentativa in 15:
		var s6 := base()
		Marchas.despachar(s6, "sem_rei", {"lanceiro": 40}, "saque")
		var m6: Dictionary = Marchas.lista(s6)[0]
		m6["perigo"] = 1.0
		var homens0 := Combate.total_homens(m6["tropas"])
		var eventos: Array = Relogio.avancar(s6, int(m6["duracao"]) - 1,
			Jogo.log_para(s6))["marchas"]
		for e in eventos:
			if e.get("tipo", "") == "emboscada":
				emboscadas += 1
				if not Marchas.lista(s6).is_empty() \
						and Combate.total_homens(Marchas.lista(s6)[0]["tropas"]) < homens0:
					doeu = true
	ok("rota perigosa engatilha emboscadas", emboscadas > 0,
		"%d em 15 viagens" % emboscadas)
	ok("emboscada custa homens de verdade", doeu)

	# rota segura não deve emboscar
	var s7 := base()
	Marchas.despachar(s7, "touros", {"lanceiro": 20}, "saque")
	Marchas.lista(s7)[0]["perigo"] = 0.0
	var ev7: Array = Relogio.avancar(s7, int(Marchas.lista(s7)[0]["duracao"]), Jogo.log_para(s7))["marchas"]
	var emboscou := false
	for e in ev7:
		if e.get("tipo", "") == "emboscada":
			emboscou = true
	ok("perigo zero nunca embosca", not emboscou)

	# ---------------- 9. RECUAR ----------------
	var s8 := base()
	Marchas.despachar(s8, "leoes", {"lanceiro": 20}, "cerco")
	var m8: Dictionary = Marchas.lista(s8)[0]
	Relogio.avancar(s8, int(m8["duracao"]) / 3, Jogo.log_para(s8))
	var rec := Marchas.recolher(s8, m8["id"])
	ok("dá para chamar o exército de volta", rec["ok"], str(rec["msg"]))
	ok("recuar muda a fase para volta", Marchas.lista(s8)[0]["fase"] == "volta")
	ok("não dá para recuar quem já está voltando",
		not Marchas.recolher(s8, m8["id"])["ok"])
	var lanc_s8: int = int(s8["jogador"]["tropas"]["lanceiro"])
	Relogio.avancar(s8, 10000, Jogo.log_para(s8))
	ok("o exército recuado volta para casa",
		int(s8["jogador"]["tropas"]["lanceiro"]) > lanc_s8)

	# ---------------- 10. SAVE/LOAD ----------------
	var s9 := base()
	Marchas.despachar(s9, "imperio", {"lanceiro": 25, "espadachim": 10}, "cerco")
	Relogio.avancar(s9, 100, Jogo.log_para(s9))
	Jogo.salvar(s9)
	var s9b = Jogo.carregar()
	ok("marcha sobreviveu ao save/load",
		s9b != null and s9b["marchas"].size() == 1)
	ok("o prazo de chegada foi preservado",
		int(s9b["marchas"][0]["chega_em"]) == int(s9["marchas"][0]["chega_em"]))
	ok("o relógio foi preservado", int(s9b["minuto"]) == int(s9["minuto"]))
	ok("as tropas em marcha continuam fora do bolso",
		int(s9b["jogador"]["tropas"]["lanceiro"]) == int(s9["jogador"]["tropas"]["lanceiro"]))
	# e continua andando depois de carregar. Um cerco é ida + seis fases +
	# volta, e cada chamada de avancar() resolve uma transição de fase por
	# marcha — como no jogo real, onde passar_mes é chamado várias vezes.
	for i in 12:
		Relogio.avancar(s9b, 2000, Jogo.log_para(s9b))
	ok("a marcha carregada chega ao fim", s9b["marchas"].is_empty(),
		"%d pendentes" % s9b["marchas"].size())
	Jogo.apagar_save()

	# ---------------- 11. AVANÇO GRANDE DE UMA VEZ ----------------
	# passar 12 meses não pode deixar a marcha pendurada nem alongar a volta
	var s10 := base()
	Marchas.despachar(s10, "aguias", {"lanceiro": 30}, "saque")
	for i in 12:
		Jogo.passar_mes(s10)
	ok("12 meses resolvem a marcha inteira", s10["marchas"].is_empty(),
		"%d pendentes" % s10["marchas"].size())

	# ---------------- 12. UI ----------------
	var s11 := base()
	Marchas.despachar(s11, "imperio", {"lanceiro": 20}, "cerco")
	var t: Array = Marchas.em_transito(s11)
	ok("em_transito() serve à UI", t.size() == 1
		and t[0].has("texto_faltam") and t[0].has("homens") and t[0].has("trajeto"))
	ok("o texto de tempo é legível", str(t[0]["texto_faltam"]).contains("dias"),
		str(t[0]["texto_faltam"]))
	ok("rótulo de risco existe para toda rota",
		Marchas.rotulo_de_risco(0.0) == "nenhum"
		and Marchas.rotulo_de_risco(0.5) == "alto")
	ok("nome_do() traduz o id da terra do jogador",
		Rotas.nome_do(s11, "jogador") == "Vale do Corvo")
	ok("nome_do() conhece o Reino sem Rei",
		Rotas.nome_do(s11, "sem_rei") == "Reino sem Rei")

	# ---------------- 13. INTEGRAÇÃO ----------------
	var full := base()
	Recrutamento.enfileirar(full, "espadachim", 4)
	Marchas.despachar(full, "touros", {"lanceiro": 30}, "saque")
	Marchas.despachar(full, "alvorecer", {"arqueiro": 20}, "cerco")
	for i in 24:
		if full["evento_pendente"] != null:
			Jogo.resolver_evento(full, "ignorar")
		if full["fim"] != null:
			break
		Jogo.passar_mes(full)
	ok("quartel e marchas convivem no mesmo relógio",
		int(full["jogador"]["tropas"]["espadachim"]) >= 4)
	ok("nenhuma marcha ficou pendurada após 24 meses",
		full["marchas"].is_empty(), "%d" % full["marchas"].size())
	ok("o relógio andou 24 meses",
		int(full["minuto"]) >= 24 * Relogio.MINUTOS_POR_MES)

	# ---------------- 14. MARCHA NPC → JOGADOR (Estágio 6, Parte VII) ----------------
	# "O jogador pode ser atacado. O jogador não pode ser absorvido."

	# -- cerco vencido derruba um degrau da terra; NUNCA "dominado_por" --
	var sa := base()
	sa["terra"]["nivel"] = 3
	Geopolitica.inicializar(sa)
	var touros_a: Dictionary = Geopolitica.reino_por_id(sa, "touros")
	touros_a["tropas"] = {"cav_leve": 500}
	touros_a["tesouro"] = 999999
	touros_a["celeiro"] = 999999
	touros_a["madeireira"] = 999999
	touros_a["equip"] = 3
	var nivel_antes: int = int(sa["terra"]["nivel"])
	var dominados_antes := {}
	for reino in sa["reinos"]:
		dominados_antes[reino["id"]] = str(reino.get("dominado_por", ""))
	var desp := Marchas.despachar(sa, "jogador", {"cav_leve": 500}, "cerco", "", "touros")
	ok("um reino consegue despachar uma marcha contra o jogador", desp["ok"], str(desp["msg"]))
	ok("a marcha guarda o reino como origem, não o jogador",
		str(Marchas.lista(sa)[0]["origem"]) == "touros")
	Marchas.lista(sa)[0]["perigo"] = 0.0
	Relogio.avancar(sa, int(Marchas.lista(sa)[0]["duracao"]) + Cerco.MINUTOS_POR_FASE * Cerco.FASES + 20,
		Jogo.log_para(sa))
	ok("o cerco venceu e a terra caiu um degrau",
		int(sa["terra"]["nivel"]) < nivel_antes, "%d → %d" % [nivel_antes, int(sa["terra"]["nivel"])])
	var absorveu := false
	for reino in sa["reinos"]:
		if str(reino.get("dominado_por", "")) != str(dominados_antes[reino["id"]]):
			absorveu = true
	ok("nenhum reino ganhou 'dominado_por' por atacar o jogador", not absorveu)

	# -- vassalagem forçada (40% na vitória) limpa a guerra que a trouxe --
	var vassalagem_ocorreu := false
	for tentativa in 20:
		var sv := base()
		sv["terra"]["nivel"] = 3
		Geopolitica.inicializar(sv)
		var touros_v: Dictionary = Geopolitica.reino_por_id(sv, "touros")
		touros_v["tropas"] = {"cav_leve": 500}
		touros_v["tesouro"] = 999999
		touros_v["celeiro"] = 999999
		touros_v["madeireira"] = 999999
		touros_v["equip"] = 3
		sv["guerras"].append({"a": "touros", "b": "jogador", "meses": 5})
		Marchas.despachar(sv, "jogador", {"cav_leve": 500}, "cerco", "", "touros")
		Marchas.lista(sv)[0]["perigo"] = 0.0
		Relogio.avancar(sv, int(Marchas.lista(sv)[0]["duracao"]) + Cerco.MINUTOS_POR_FASE * Cerco.FASES + 20,
			Jogo.log_para(sv))
		if str(sv["jogador"].get("suserano", "")) == "touros":
			vassalagem_ocorreu = true
			var ainda_em_guerra := false
			for g in sv["guerras"]:
				if (g["a"] == "touros" and g["b"] == "jogador") \
						or (g["b"] == "touros" and g["a"] == "jogador"):
					ainda_em_guerra = true
			ok("vassalagem forçada encerra a guerra que a trouxe", not ainda_em_guerra)
			break
	ok("cerco vencido pode impor vassalagem forçada", vassalagem_ocorreu,
		"%d tentativas" % 20)

	# -- guarnição do jogador: terra alta + lordes leais reforça a defesa de verdade --
	var fraca := Jogo.novo_jogo("Fraco")
	fraca["terra"] = {"nome": "Vale", "nivel": 0, "populacao": 50,
		"alimento": 500, "madeira": 100, "felicidade": 60, "pressao": 0.0}
	fraca["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 5})
	Geopolitica.inicializar(fraca)
	Geopolitica.reino_por_id(fraca, "touros")["tropas"] = {"lanceiro": 60, "espadachim": 20}
	Marchas.despachar(fraca, "jogador", {"lanceiro": 60, "espadachim": 20}, "saque", "", "touros")
	Marchas.lista(fraca)[0]["perigo"] = 0.0
	var evs_fraca: Array = Relogio.avancar(fraca, int(Marchas.lista(fraca)[0]["duracao"]),
		Jogo.log_para(fraca))["marchas"]

	var forte := Jogo.novo_jogo("Forte")
	forte["terra"] = {"nome": "Vale", "nivel": 8, "populacao": 500,
		"alimento": 5000, "madeira": 2000, "felicidade": 70, "pressao": 0.0}
	forte["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 5})
	forte["terra"]["notaveis"] = []
	# margem generosa de propósito: o teste é sobre a DIREÇÃO do efeito
	# (terra + lordes reforçam a guarnição de verdade), não sobre achar o
	# ponto de equilíbrio exato do combate de 3 fases — 25 lordes contra o
	# mesmo ataque de 80 homens que já é suficiente pra derrubar a "fraca"
	for i in 25:
		forte["terra"]["notaveis"].append({"nome": "Lorde %d" % i, "oficio": "", "lealdade": 80,
			"riqueza": 10, "ambicao": 1, "lorde": true, "capturado": false})
	Geopolitica.inicializar(forte)
	Geopolitica.reino_por_id(forte, "touros")["tropas"] = {"lanceiro": 60, "espadachim": 20}
	Marchas.despachar(forte, "jogador", {"lanceiro": 60, "espadachim": 20}, "saque", "", "touros")
	Marchas.lista(forte)[0]["perigo"] = 0.0
	var evs_forte: Array = Relogio.avancar(forte, int(Marchas.lista(forte)[0]["duracao"]),
		Jogo.log_para(forte))["marchas"]

	var batalha_fraca := {}
	for e in evs_fraca:
		if e.get("tipo", "") == "batalha":
			batalha_fraca = e
	var batalha_forte := {}
	for e in evs_forte:
		if e.get("tipo", "") == "batalha":
			batalha_forte = e
	ok("sem terra e sem lordes, a mesma investida derruba a guarnição",
		not batalha_fraca.is_empty() and bool(batalha_fraca["vitoria"]))
	ok("terra em nível alto + lordes leais reforça a guarnição o bastante para repelir",
		not batalha_forte.is_empty() and not bool(batalha_forte["vitoria"]))

	# -- saque de reino contra o jogador drena ouro e carga, via _colher_do_jogador --
	var sg := base()
	Geopolitica.inicializar(sg)
	sg["jogador"]["ouro"] = 1000
	sg["carga"] = {"trigo": 200}
	Geopolitica.reino_por_id(sg, "touros")["tropas"] = {"cav_leve": 200}
	var ouro_antes_sg: int = int(sg["jogador"]["ouro"])
	var carga_antes_sg: int = int(sg["carga"]["trigo"])
	Marchas.despachar(sg, "jogador", {"cav_leve": 200}, "saque", "", "touros")
	Marchas.lista(sg)[0]["perigo"] = 0.0
	Relogio.avancar(sg, int(Marchas.lista(sg)[0]["duracao"]), Jogo.log_para(sg))
	ok("saque de reino contra o jogador drena ouro",
		int(sg["jogador"]["ouro"]) < ouro_antes_sg,
		"%d → %d" % [ouro_antes_sg, int(sg["jogador"]["ouro"])])
	ok("e drena a carga genérica também",
		int(sg["carga"]["trigo"]) < carga_antes_sg,
		"%d → %d" % [carga_antes_sg, int(sg["carga"]["trigo"])])

	# -- upkeep do cerco contra o jogador sai do cofre do RESINO atacante, não do bolso dele --
	var sh := base()
	sh["jogador"]["ouro"] = 5000
	Geopolitica.inicializar(sh)
	var touros_h: Dictionary = Geopolitica.reino_por_id(sh, "touros")
	touros_h["tropas"] = {"cav_leve": 300}
	touros_h["tesouro"] = 50000
	touros_h["celeiro"] = 50000
	touros_h["madeireira"] = 50000
	var tesouro_antes: int = int(touros_h["tesouro"])
	var celeiro_antes: int = int(touros_h["celeiro"])
	var madeireira_antes: int = int(touros_h["madeireira"])
	var ouro_jogador_antes: int = int(sh["jogador"]["ouro"])
	Marchas.despachar(sh, "jogador", {"cav_leve": 300}, "cerco", "", "touros")
	Marchas.lista(sh)[0]["perigo"] = 0.0
	Relogio.avancar(sh, int(Marchas.lista(sh)[0]["duracao"]) + Cerco.MINUTOS_POR_FASE * Cerco.FASES + 20,
		Jogo.log_para(sh))
	ok("o cerco de um reino contra o jogador não cobra do bolso dele",
		int(sh["jogador"]["ouro"]) == ouro_jogador_antes)
	ok("quem paga o upkeep é o cofre do PRÓPRIO reino sitiante",
		int(touros_h["tesouro"]) < tesouro_antes or int(touros_h["celeiro"]) < celeiro_antes
		or int(touros_h["madeireira"]) < madeireira_antes,
		"tesouro %d→%d, celeiro %d→%d, madeireira %d→%d" % [tesouro_antes, int(touros_h["tesouro"]),
			celeiro_antes, int(touros_h["celeiro"]), madeireira_antes, int(touros_h["madeireira"])])

	# ---------------- 15. RAMPA DE ELEGIBILIDADE (Parte VII, 6.4) ----------------
	# sem terra, ou terra nível < 2, o jogador nunca é alvo — mesmo se um rei o odeia.
	var sd := Jogo.novo_jogo("Elegibilidade")
	Dialogo.mudar_relacao(sd, "rei_touros", -100, "teste")
	for i in 24:
		Geopolitica.tick(sd, Jogo.log_para(sd))
	var guerra_sem_terra := false
	for g in sd["guerras"]:
		if g["a"] == "jogador" or g["b"] == "jogador":
			guerra_sem_terra = true
	ok("sem terra, nenhum reino declara guerra ao jogador mesmo o odiando",
		not guerra_sem_terra)

	var sd2 := Jogo.novo_jogo("Elegibilidade2")
	sd2["terra"] = {"nome": "Acampamento", "nivel": 1, "populacao": 20,
		"alimento": 200, "madeira": 50, "felicidade": 60, "pressao": 0.0}
	Dialogo.mudar_relacao(sd2, "rei_touros", -100, "teste")
	for i in 24:
		Geopolitica.tick(sd2, Jogo.log_para(sd2))
	var guerra_nivel1 := false
	for g in sd2["guerras"]:
		if g["a"] == "jogador" or g["b"] == "jogador":
			guerra_nivel1 = true
	ok("terra em nível 1 ainda não habilita o jogador como alvo",
		not guerra_nivel1)

	var sd3 := Jogo.novo_jogo("Elegibilidade3")
	sd3["terra"] = {"nome": "Vila", "nivel": 2, "populacao": 100,
		"alimento": 600, "madeira": 200, "felicidade": 60, "pressao": 0.0}
	Dialogo.mudar_relacao(sd3, "rei_touros", -100, "teste")
	var guerra_apareceu := false
	var marcha_apareceu := false
	for i in 80:
		Geopolitica.tick(sd3, Jogo.log_para(sd3))
		for g in sd3["guerras"]:
			if (g["a"] == "touros" and g["b"] == "jogador") or (g["b"] == "touros" and g["a"] == "jogador"):
				guerra_apareceu = true
		for marcha in sd3["marchas"]:
			if str(marcha.get("origem", "")) == "touros" and str(marcha.get("alvo", "")) == "jogador":
				marcha_apareceu = true
		if marcha_apareceu:
			break
	ok("com terra nível ≥2 e relação péssima, o reino acaba declarando guerra ao jogador",
		guerra_apareceu)
	ok("e eventualmente despacha uma marcha de verdade contra ele",
		marcha_apareceu)

	# ---------------- ALFA: regressões do teste de campo ----------------
	# levantar o cerco por ordem própria: antes recolher() recusava com a
	# mensagem da fase errada e a tropa ficava presa pagando upkeep dobrado
	var s_alfa := Jogo.novo_jogo("AlfaCerco")
	s_alfa["jogador"]["tropas"]["lanceiro"] = 40
	s_alfa["jogador"]["ouro"] = 3000
	Marchas.despachar(s_alfa, "touros", {"lanceiro": 30}, "cerco")
	var m_alfa: Dictionary = Marchas.lista(s_alfa)[0]
	Relogio.avancar(s_alfa, int(m_alfa["duracao"]) + 5, Jogo.log_para(s_alfa))
	ok("a marcha chegou e virou cerco", str(m_alfa["fase"]) == "cerco", str(m_alfa["fase"]))
	var r_alfa := Marchas.recolher(s_alfa, str(m_alfa["id"]))
	ok("levantar o cerco é uma ordem aceita", bool(r_alfa["ok"]), str(r_alfa["msg"]))
	ok("a tropa dá meia-volta de verdade", str(m_alfa["fase"]) == "volta")
	# as baixas da guarnição PERSISTEM: antes a batalha rodava numa cópia e
	# o exército do reino renascia intacto no tick seguinte
	var s_desg := Jogo.novo_jogo("AlfaDesgaste")
	s_desg["jogador"]["ouro"] = 9000
	# celeiro TRANSBORDANDO: o upkeep dobrado de um cerco de 300 homens por
	# 6 fases esvazia um celeiro comum — e sem comida o acampamento abandona
	# por moral ANTES do assalto, que é justamente o que se testa aqui
	s_desg["terra"] = {"nome": "Vale Teste", "nivel": 3, "populacao": 150,
		"alimento": 60000, "madeira": 9000, "felicidade": 70, "pressao": 0.0}
	for tipo_sb in s_desg["jogador"]["tropas"]:
		s_desg["jogador"]["tropas"][tipo_sb] = 0
	s_desg["jogador"]["tropas"]["lanceiro"] = 200
	s_desg["jogador"]["tropas"]["espadachim"] = 80
	s_desg["jogador"]["tropas"]["arqueiro"] = 60
	var reino_alvo: Dictionary = Geopolitica.reino_por_id(s_desg, "touros")
	var homens_antes: int = Combate.total_homens(reino_alvo.get("tropas", {}))
	Marchas.despachar(s_desg, "touros", {"lanceiro": 180, "espadachim": 70, "arqueiro": 50}, "cerco")
	Relogio.avancar(s_desg, 30000, Jogo.log_para(s_desg))
	var homens_depois: int = Combate.total_homens(reino_alvo.get("tropas", {}))
	ok("as baixas da guarnição valem de verdade no reino",
		homens_antes > 0 and homens_depois < homens_antes,
		"%d → %d" % [homens_antes, homens_depois])

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
