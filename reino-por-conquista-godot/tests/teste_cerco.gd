# ============================================================
# TESTES DOS TRÊS PILARES: upkeep global, neblina de guerra e cerco.
#   godot --headless --path . --script res://tests/teste_cerco.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Intriga = preload("res://scripts/intriga.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Intel = preload("res://scripts/intel.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Cerco = preload("res://scripts/cerco.gd")
const Relogio = preload("res://scripts/relogio.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func rico() -> Dictionary:
	var s := Jogo.novo_jogo("Sitiante")
	# suprimento para bancar as seis fases: um cerco consome ~600 de comida e
	# ~640 de madeira POR FASE (o dobro do upkeep normal). Quem acampa sem
	# estoque levanta acampamento — e há um teste só para esse caso.
	s["terra"] = {"nome": "Vale do Corvo", "nivel": 4, "populacao": 400,
		"alimento": 12000, "madeira": 12000, "felicidade": 80, "pressao": 0.0}
	s["jogador"]["ouro"] = 50000
	s["jogador"]["tropas"] = Jogo._tropas_zeradas(
		{"lanceiro": 120, "espadachim": 90, "arqueiro": 70, "cav_leve": 25})
	return s

func _init() -> void:
	seed(31337)
	print("=== UPKEEP, NEBLINA E CERCO ===")

	# ================= PILAR 1: UPKEEP =================
	var custo := Economia.upkeep_de({"lanceiro": 10, "cav_pesada": 2})
	ok("upkeep soma ouro, comida e madeira",
		int(custo["ouro"]) == 10 * 2 + 2 * 14
		and int(custo["comida"]) == 10 * 1 + 2 * 4
		and int(custo["madeira"]) == 10 * 1 + 2 * 2,
		str(custo))
	ok("cavalo come mais que homem",
		int(Dados.TROPAS["cav_pesada"]["comida"]) > int(Dados.TROPAS["lanceiro"]["comida"]))
	ok("arqueiro gasta madeira em flecha",
		int(Dados.TROPAS["arqueiro"]["madeira"]) > int(Dados.TROPAS["espadachim"]["madeira"]))
	ok("multiplicador dobra o custo",
		int(Economia.upkeep_de({"lanceiro": 10}, 2.0)["ouro"])
		== int(Economia.upkeep_de({"lanceiro": 10})["ouro"]) * 2)

	# exército pago = moral sobe
	var s := rico()
	s["jogador"]["moral"] = 70
	Economia.tick_exercito(s, Jogo.log_para(s))
	ok("exército pago recupera moral", Economia.moral(s) > 70, "%d" % Economia.moral(s))
	ok("o ouro saiu do bolso", int(s["jogador"]["ouro"]) < 50000)
	ok("a comida saiu do celeiro", int(s["terra"]["alimento"]) < 12000)
	ok("a madeira saiu do depósito", int(s["terra"]["madeira"]) < 12000)

	# sem recursos = moral cai e o exército derrete
	var f := rico()
	f["jogador"]["ouro"] = 0
	f["terra"]["alimento"] = 0
	f["terra"]["madeira"] = 0
	var homens0 := Combate.total_homens(f["jogador"]["tropas"])
	for i in 4:
		Economia.tick_exercito(f, Jogo.log_para(f))
	ok("sem pagamento a moral despenca", Economia.moral(f) < 40, "%d" % Economia.moral(f))
	ok("moral baixa gera deserção",
		Combate.total_homens(f["jogador"]["tropas"]) < homens0,
		"%d → %d" % [homens0, Combate.total_homens(f["jogador"]["tropas"])])
	ok("moral nunca sai da faixa 0-100",
		Economia.moral(f) >= 0 and Economia.mudar_moral(f, 999) == 100)

	# ---- NPCs pelas mesmas regras ----
	var g := Jogo.novo_jogo("NPCs")
	var r0: Dictionary = g["reinos"][0]
	ok("reino NPC tem exército de VERDADE, não um número",
		r0.has("tropas") and Combate.total_homens(r0["tropas"]) > 0,
		"%d homens" % Combate.total_homens(r0["tropas"]))
	ok("reino NPC tem celeiro e madeireira",
		r0.has("celeiro") and r0.has("madeireira"))
	ok("forca é o resumo do exército real",
		int(r0["forca"]) == Geopolitica.forca_de(r0))
	ok("reino NPC tem fila de recrutamento", r0.has("fila"))

	var tropas_iniciais := Combate.total_homens(r0["tropas"])
	var equip0 := int(r0.get("equip", 0))
	for i in 60:
		Geopolitica.tick(g, Jogo.log_para(g))
	var r0b: Dictionary = Geopolitica.reino_por_id(g, r0["id"])
	ok("NPC recruta sozinho ao longo do tempo",
		Combate.total_homens(r0b["tropas"]) != tropas_iniciais,
		"%d → %d" % [tropas_iniciais, Combate.total_homens(r0b["tropas"])])
	var algum_melhorou := false
	for rr in g["reinos"]:
		if int(rr.get("equip", 0)) > equip0:
			algum_melhorou = true
	ok("NPC melhora equipamento gastando recursos", algum_melhorou)
	ok("forca dos NPCs continua consistente com as tropas",
		int(r0b["forca"]) == Geopolitica.forca_de(r0b))

	# NPC falido perde homens
	var q := Jogo.novo_jogo("Falido")
	var alvo: Dictionary = q["reinos"][1]
	alvo["tesouro"] = 0
	alvo["celeiro"] = 0
	alvo["madeireira"] = 0
	alvo["nobres"] = 0                       # sem renda nenhuma
	var antes_npc := Combate.total_homens(alvo["tropas"])
	for i in 12:
		Geopolitica.tick(q, Jogo.log_para(q))
	ok("reino NPC sem recursos perde a moral e os homens",
		int(alvo["moral"]) < 100
		and Combate.total_homens(alvo["tropas"]) < antes_npc,
		"moral %d, %d → %d" % [int(alvo["moral"]), antes_npc,
			Combate.total_homens(alvo["tropas"])])

	# ================= PILAR 2: NEBLINA =================
	var n := Jogo.novo_jogo("Neblina")
	ok("sem espião, o exército inimigo é ???",
		not Intel.tem(n, "touros")
		and Intel.sobre(n, "touros")["texto"] == "???")

	n["jogador"]["ouro"] = 99999
	n["jogador"]["atributos"]["intriga"] = 10   # falha mínima
	var revelou := false
	for i in 20:
		var e := Intriga.espionar(n, "touros")
		if int(e.get("revelou", 0)) > 0:
			revelou = true
			break
	ok("espião bem-sucedido revela o exército", revelou and Intel.tem(n, "touros"))
	var vis := Intel.sobre(n, "touros")
	ok("o relatório traz a contagem de homens",
		vis["conhecido"] and int(vis["homens"]) > 0, str(vis["texto"]))
	ok("o relatório detalha por tipo de tropa",
		Intel.detalhar(n, "touros").size() > 0,
		"%d tipos" % Intel.detalhar(n, "touros").size())
	ok("só o reino espionado é revelado", not Intel.tem(n, "leoes"))

	# a informação ENVELHECE
	for i in Intel.MESES_VALIDO + 1:
		n["mes"] = int(n["mes"]) + 1
		if int(n["mes"]) > 12:
			n["mes"] = 1
			n["ano"] = int(n["ano"]) + 1
	ok("relatório vencido volta a ser ???",
		not Intel.tem(n, "touros")
		and str(Intel.sobre(n, "touros")["texto"]).begins_with("???"),
		str(Intel.sobre(n, "touros")["texto"]))
	ok("mas o jogador lembra que já soube",
		bool(Intel.sobre(n, "touros").get("vencido", false)))

	# a foto não se atualiza sozinha
	var n2 := Jogo.novo_jogo("Foto")
	Geopolitica.inicializar(n2)
	var t2: Dictionary = Geopolitica.reino_por_id(n2, "rosa")
	Intel.registrar(n2, "rosa", t2["tropas"], int(t2["forca"]))
	var visto0: int = int(Intel.sobre(n2, "rosa")["homens"])
	t2["tropas"]["lanceiro"] = int(t2["tropas"]["lanceiro"]) + 500
	ok("o relatório é uma FOTOGRAFIA, não um espelho",
		int(Intel.sobre(n2, "rosa")["homens"]) == visto0,
		"continua %d" % visto0)

	# ================= PILAR 3: CERCO =================
	ok("o cerco tem seis fases", Cerco.FASES == 6)
	ok("uma fase a cada 30 do relógio", Cerco.MINUTOS_POR_FASE == 30)
	ok("acampamento custa o dobro", Cerco.MULTIPLICADOR_UPKEEP == 2.0)
	ok("reforço em 3 de 10", is_equal_approx(Cerco.CHANCE_REFORCO, 0.30))
	ok("debuff do defensor é de 50%", is_equal_approx(Cerco.DEBUFF_DEFENSOR, 0.5))

	# ---- o cerco NÃO resolve na chegada ----
	var c := rico()
	Marchas.despachar(c, "touros", {"lanceiro": 100, "espadachim": 80,
		"arqueiro": 60, "cav_leve": 20}, "cerco")
	var m: Dictionary = Marchas.lista(c)[0]
	m["perigo"] = 0.0
	Relogio.avancar(c, int(m["duracao"]), Jogo.log_para(c))
	ok("ao chegar, o cerco COMEÇA em vez de resolver",
		not Marchas.lista(c).is_empty() and Marchas.lista(c)[0]["fase"] == "cerco",
		Marchas.lista(c)[0]["fase"] if not Marchas.lista(c).is_empty() else "sumiu")
	var prog := Cerco.progresso(Marchas.lista(c)[0])
	ok("o progresso do cerco serve à UI",
		prog.has("fase") and int(prog["de"]) == 6 and prog.has("moral"))

	# ---- as fases avançam e cobram ----
	var ouro_pre: int = int(c["jogador"]["ouro"])
	var alim_pre: int = int(c["terra"]["alimento"])
	Relogio.avancar(c, Cerco.MINUTOS_POR_FASE, Jogo.log_para(c))
	ok("uma fase passou", int(Cerco.progresso(Marchas.lista(c)[0])["fase"]) == 1)
	ok("a fase cobrou ouro do sitiante", int(c["jogador"]["ouro"]) < ouro_pre)
	ok("a fase cobrou comida do celeiro", int(c["terra"]["alimento"]) < alim_pre)
	ok("a moral do cerco começa a cair",
		int(Cerco.progresso(Marchas.lista(c)[0])["moral"]) < 100)

	# ---- seis fases efetivam o cerco e disparam a batalha ----
	var evs: Array = Relogio.avancar(c, Cerco.MINUTOS_POR_FASE * 6, Jogo.log_para(c))["marchas"]
	var efetivou := false
	var teve_batalha := false
	var teve_reforco := false
	for e in evs:
		if e.get("efetivado", false):
			efetivou = true
		if e.get("tipo", "") == "batalha":
			teve_batalha = true
		if e.get("reforco", false):
			teve_reforco = true
	ok("aguentar as seis fases efetiva o cerco", efetivou)
	ok("cerco efetivado dispara a batalha de três fases", teve_batalha)
	var apos: Array = Marchas.lista(c)
	ok("depois da batalha o exército volta para casa",
		apos.is_empty() or apos[0]["fase"] == "volta",
		apos[0]["fase"] if not apos.is_empty() else "destruído")

	# ---- o debuff de 50% é real ----
	# guarnição forte de propósito: com os status cheios ela SEGURA, e é só
	# assim que dá para medir o efeito do debuff (um exército que varre tudo
	# nos dois casos não prova nada)
	var guarn := {"espadachim": 200}
	var atacante := {"barbaro": 120}
	var g_cheia := guarn.duplicate(true)
	var g_meia := guarn.duplicate(true)
	Combate.resolver_assalto(atacante.duplicate(true), g_cheia, 1.0, 1.0, "cerco")
	Combate.resolver_assalto(atacante.duplicate(true), g_meia, 1.0, 0.5, "cerco")
	ok("defensor com metade dos status sofre MUITO mais",
		Combate.total_homens(g_meia) < Combate.total_homens(g_cheia),
		"%d vivos contra %d" % [Combate.total_homens(g_meia), Combate.total_homens(g_cheia)])

	# ---- cerco sem recursos é levantado ----
	var pobre := rico()
	Marchas.despachar(pobre, "touros", {"lanceiro": 60, "espadachim": 40}, "cerco")
	var mp: Dictionary = Marchas.lista(pobre)[0]
	mp["perigo"] = 0.0
	Relogio.avancar(pobre, int(mp["duracao"]), Jogo.log_para(pobre))
	pobre["jogador"]["ouro"] = 0              # falência no meio do cerco
	pobre["terra"]["alimento"] = 0
	pobre["terra"]["madeira"] = 0
	var ev2: Array = Relogio.avancar(pobre, Cerco.MINUTOS_POR_FASE * 6,
		Jogo.log_para(pobre))["marchas"]
	var abandonou := false
	for e in ev2:
		if e.get("abandonou", false):
			abandonou = true
	ok("cerco sem recursos é levantado antes das seis fases", abandonou)
	var ap2: Array = Marchas.lista(pobre)
	ok("quem levanta acampamento volta para casa",
		ap2.is_empty() or ap2[0]["fase"] == "volta")

	# ---- reforços aparecem ao longo de muitos cercos ----
	var reforcos := 0
	for tentativa in 8:
		var rr := rico()
		Marchas.despachar(rr, "touros", {"lanceiro": 100, "espadachim": 80,
			"arqueiro": 60}, "cerco")
		var mr: Dictionary = Marchas.lista(rr)[0]
		mr["perigo"] = 0.0
		Relogio.avancar(rr, int(mr["duracao"]), Jogo.log_para(rr))
		for e in Relogio.avancar(rr, Cerco.MINUTOS_POR_FASE * 6, Jogo.log_para(rr))["marchas"]:
			if e.get("reforco", false):
				reforcos += 1
	ok("lordes aliados intervêm em ~30% das fases", reforcos > 0,
		"%d intervenções em 8 cercos" % reforcos)

	# ---- saque continua instantâneo (não vira cerco) ----
	var sq := rico()
	Marchas.despachar(sq, "sem_rei", {"lanceiro": 60, "espadachim": 30}, "saque")
	var ms: Dictionary = Marchas.lista(sq)[0]
	ms["perigo"] = 0.0
	Relogio.avancar(sq, int(ms["duracao"]), Jogo.log_para(sq))
	ok("saque NÃO entra em cerco: resolve na chegada",
		Marchas.lista(sq).is_empty() or Marchas.lista(sq)[0]["fase"] == "volta",
		Marchas.lista(sq)[0]["fase"] if not Marchas.lista(sq).is_empty() else "destruído")

	# ---- o cerco atravessa save/load ----
	var sv := rico()
	Marchas.despachar(sv, "touros", {"lanceiro": 80, "espadachim": 60}, "cerco")
	var msv: Dictionary = Marchas.lista(sv)[0]
	msv["perigo"] = 0.0
	Relogio.avancar(sv, int(msv["duracao"]) + Cerco.MINUTOS_POR_FASE * 2, Jogo.log_para(sv))
	var fase_antes: int = int(Cerco.progresso(Marchas.lista(sv)[0])["fase"])
	Jogo.salvar(sv)
	var svb = Jogo.carregar()
	ok("o cerco sobreviveu ao save/load",
		svb != null and not svb["marchas"].is_empty()
		and svb["marchas"][0]["fase"] == "cerco")
	ok("a fase do cerco foi preservada",
		int(Cerco.progresso(svb["marchas"][0])["fase"]) == fase_antes,
		"fase %d" % fase_antes)
	Relogio.avancar(svb, Cerco.MINUTOS_POR_FASE * 8, Jogo.log_para(svb))
	ok("o cerco carregado continua e termina",
		svb["marchas"].is_empty() or svb["marchas"][0]["fase"] != "cerco")
	Jogo.apagar_save()

	# ---- passar meses de uma vez roda todas as fases ----
	var mes := rico()
	Marchas.despachar(mes, "touros", {"lanceiro": 100, "espadachim": 80,
		"arqueiro": 60}, "cerco")
	for i in 6:
		if mes["evento_pendente"] != null:
			Jogo.resolver_evento(mes, "ignorar")
		Jogo.passar_mes(mes)
	ok("passar meses resolve o cerco inteiro, sem travar",
		mes["marchas"].is_empty(), "%d pendentes" % mes["marchas"].size())

	# ================= INTEGRAÇÃO =================
	var full := rico()
	Jogo.recrutar(full, "espadachim", 5)
	Marchas.despachar(full, "touros", {"lanceiro": 60}, "cerco")
	Marchas.despachar(full, "sem_rei", {"arqueiro": 40}, "saque")
	for i in 24:
		if full["evento_pendente"] != null:
			Jogo.resolver_evento(full, "ignorar")
		if full["fim"] != null:
			break
		Jogo.passar_mes(full)
	ok("24 meses com upkeep, cerco e neblina ligados",
		full["marchas"].is_empty(), "%d marchas" % full["marchas"].size())
	ok("a moral do jogador continua numa faixa sã",
		Economia.moral(full) >= 0 and Economia.moral(full) <= 100,
		"%d" % Economia.moral(full))
	ok("os NPCs continuam com exércitos coerentes",
		Geopolitica.forca_de(full["reinos"][0]) == int(full["reinos"][0]["forca"]))

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
