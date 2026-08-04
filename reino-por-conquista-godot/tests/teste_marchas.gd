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
const Relogio = preload("res://scripts/relogio.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")

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
	ok("vizinhos de sem_rei encontrados",
		Rotas.vizinhos("sem_rei").size() == 3,
		", ".join(Rotas.vizinhos("sem_rei")))
	ok("todos os 8 nós existem", Rotas.todos_os_nos().size() == 8)

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
	ok("13 campos com lanceiros ≈ 12 dias",
		Relogio.texto_dias(int(est["minutos"])) == "12 dias",
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

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
