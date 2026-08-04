# ============================================================
# TESTES DO SISTEMA MILITAR — as 8 tropas e o combate em 3 fases.
#
# O ponto central: o equilíbrio destas tropas é por POPULAÇÃO, não por
# número de unidades. Os testes de contra-jogo abaixo comparam exércitos de
# custo populacional parecido — é assim que a lança tem que vencer o cavalo.
#   godot --headless --path . --script res://tests/teste_combate.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Combate = preload("res://scripts/combate.gd")
const Clas = preload("res://scripts/clas.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

## Roda N assaltos e devolve em quantos o atacante limpou a guarnição.
func taxa_vitoria(atk: Dictionary, def_: Dictionary, n: int = 200) -> float:
	var v := 0
	for i in n:
		var a := atk.duplicate(true)
		var d := def_.duplicate(true)
		var rel := Combate.resolver_assalto(a, d, 1.0, 1.0, "cerco")
		if rel["vitoria"]:
			v += 1
	return float(v) / n

func _init() -> void:
	seed(7)
	print("=== SISTEMA MILITAR (8 tropas, 3 fases) ===")

	# ---------------- catálogo ----------------
	var esperadas := ["lanceiro", "espadachim", "barbaro", "arqueiro",
		"explorador", "cav_leve", "arq_cavalo", "cav_pesada"]
	var faltando: Array = []
	for t in esperadas:
		if not Dados.TROPAS.has(t):
			faltando.append(t)
	ok("as 8 tropas estão no catálogo", faltando.is_empty(), ", ".join(faltando))
	ok("milícia camponesa preservada", Dados.TROPAS.has("campones"))

	# os números exatos que você especificou
	var L: Dictionary = Dados.TROPAS["lanceiro"]
	ok("lanceiro com os status exatos",
		L["atq"] == 10 and L["dg"] == 15 and L["dc"] == 45 and L["da"] == 20
		and L["pop"] == 1 and L["saque"] == 25 and L["vel"] == 18)
	var CP: Dictionary = Dados.TROPAS["cav_pesada"]
	ok("cavalaria pesada com os status exatos",
		CP["atq"] == 150 and CP["dg"] == 200 and CP["dc"] == 80 and CP["da"] == 180
		and CP["pop"] == 6 and CP["saque"] == 50 and CP["vel"] == 11)

	# vel é MINUTOS POR CAMPO: menor = mais rápido
	ok("explorador é o mais rápido do catálogo",
		Dados.TROPAS["explorador"]["vel"] == 9)
	ok("espadachim é o mais lento", Dados.TROPAS["espadachim"]["vel"] == 22)
	var mais_lento := 0
	for t in Dados.TROPAS:
		mais_lento = maxi(mais_lento, int(Dados.TROPAS[t]["vel"]))
	ok("a tropa mais lenta é a de MAIOR vel (max, não min)", mais_lento == 22)

	# ---------------- classes e fases ----------------
	ok("arqueiros atacam na fase de disparo",
		Dados.TROPAS["arqueiro"]["classe"] == "arq"
		and Dados.TROPAS["arq_cavalo"]["classe"] == "arq")
	ok("cavalarias atacam na fase de choque",
		Dados.TROPAS["cav_leve"]["classe"] == "cav"
		and Dados.TROPAS["cav_pesada"]["classe"] == "cav")
	ok("a ordem das fases é disparo → choque → corpo a corpo",
		Combate.FASES[0][0] == "arq" and Combate.FASES[1][0] == "cav"
		and Combate.FASES[2][0] == "inf")
	ok("cada fase responde à defesa correspondente",
		Combate.FASES[0][1] == "da" and Combate.FASES[1][1] == "dc"
		and Combate.FASES[2][1] == "dg")

	# a fase só usa o ataque da SUA classe
	var misto := {"arqueiro": 10, "cav_leve": 10, "barbaro": 10}
	ok("ataque de disparo conta só os arqueiros",
		is_equal_approx(Combate.ataque_da_classe(misto, "arq"), 150.0))
	ok("ataque de choque conta só a cavalaria",
		is_equal_approx(Combate.ataque_da_classe(misto, "cav"), 1300.0))
	ok("defesa anticavalaria usa o stat certo",
		is_equal_approx(Combate.defesa({"lanceiro": 10}, "dc"), 450.0))

	# ---------------- A ARMADILHA QUE A SIMULAÇÃO PEGOU ----------------
	# Uma fase sozinha NÃO pode varrer a guarnição inteira. Um exército só de
	# arqueiros contra cavalaria pesada tem que sangrar, não passear.
	var guarnicao := {"cav_pesada": 20}
	var so_arqueiros := {"arqueiro": 30}
	var g2 := guarnicao.duplicate(true)
	var a2 := so_arqueiros.duplicate(true)
	Combate.resolver_assalto(a2, g2, 1.0, 1.0, "cerco")
	ok("uma fase só não aniquila a guarnição inteira",
		Combate.total_homens(g2) > 0,
		"restaram %d de 20" % Combate.total_homens(g2))

	# e o peso funciona: quem é 100% de uma classe pode, sim, limpar tudo
	var fraca := {"campones": 3}
	var forte := {"barbaro": 60}
	var f2 := fraca.duplicate(true)
	Combate.resolver_assalto(forte.duplicate(true), f2, 1.0, 1.0, "cerco")
	ok("exército de uma classe só ainda pode varrer um alvo fraco",
		Combate.total_homens(f2) == 0)

	# ---------------- CONTRA-JOGO (equilíbrio por população) ----------------
	# 20 cav. pesada = 120 pop. 120 lanceiros = 120 pop. A lança tem que ganhar.
	var v_lanca := taxa_vitoria({"cav_pesada": 20}, {"lanceiro": 120})
	ok("a lança segura o cavalo em igualdade de população", v_lanca < 0.15,
		"cavalaria venceu %.0f%%" % (v_lanca * 100))

	# 100 arqueiros vs 100 espadachins (100 pop cada): o contra-arqueiro segura
	var v_arq := taxa_vitoria({"arqueiro": 100}, {"espadachim": 100})
	ok("espadachim segura o arqueiro", v_arq < 0.15,
		"arqueiro venceu %.0f%%" % (v_arq * 100))

	# 100 bárbaros vs 100 espadachins: o muro segura o machado
	var v_barb := taxa_vitoria({"barbaro": 100}, {"espadachim": 100})
	ok("espadachim segura o bárbaro em igualdade", v_barb < 0.25,
		"bárbaro venceu %.0f%%" % (v_barb * 100))

	# mas o bárbaro esmaga uma guarnição fraca — força bruta funciona
	var v_esmaga := taxa_vitoria({"barbaro": 100}, {"lanceiro": 40})
	ok("bárbaro esmaga guarnição anticavalaria (lança não defende de infantaria)",
		v_esmaga > 0.85, "venceu %.0f%%" % (v_esmaga * 100))

	# cavalaria contra guarnição SEM lanças passa por cima
	var v_cav := taxa_vitoria({"cav_leve": 30}, {"barbaro": 100})
	ok("cavalaria atropela quem não tem lança", v_cav > 0.7,
		"venceu %.0f%%" % (v_cav * 100))

	# explorador não é unidade de combate
	ok("explorador não tem poder de ataque",
		is_equal_approx(Combate.ataque_da_classe({"explorador": 50}, "inf"), 0.0))

	# ---------------- RNG por fase ----------------
	var variou := false
	var base := -1
	for i in 30:
		var d := {"espadachim": 50}
		Combate.resolver_assalto({"barbaro": 50}, d, 1.0, 1.0, "cerco")
		var vivos := Combate.total_homens(d)
		if base < 0:
			base = vivos
		elif vivos != base:
			variou = true
			break
	ok("o multiplicador de sorte faz o resultado variar", variou)

	# ---------------- INTENÇÕES ----------------
	var d_saque := {"espadachim": 40, "lanceiro": 40}
	var a_saque := {"arqueiro": 20, "cav_leve": 10, "barbaro": 20}
	var rel_s := Combate.resolver_assalto(a_saque, d_saque, 1.0, 1.0, "saque")
	ok("saque dura UMA fase", rel_s["fases"].size() == 1,
		"%d fases" % rel_s["fases"].size())
	var d_cerco := {"espadachim": 40, "lanceiro": 40}
	var a_cerco := {"arqueiro": 20, "cav_leve": 10, "barbaro": 20}
	var rel_c := Combate.resolver_assalto(a_cerco, d_cerco, 1.0, 1.0, "cerco")
	ok("cerco roda as três fases", rel_c["fases"].size() == 3,
		"%d fases" % rel_c["fases"].size())

	# saque: capacidade vem do stat "saque" dos SOBREVIVENTES
	var cofre := {"trigo": 500, "ferro": 500}
	var levado := Combate.colher_saque({"cav_leve": 10}, cofre)
	ok("saque leva carga proporcional à capacidade",
		int(levado.get("trigo", 0)) == 400,
		"levou %d de trigo (10 × 80 ÷ 2 bens)" % int(levado.get("trigo", 0)))
	ok("o saque sai do cofre do alvo", int(cofre["trigo"]) == 100)
	ok("exército sem capacidade não leva nada",
		Combate.colher_saque({"explorador": 50}, {"trigo": 100}).is_empty())

	# ---------------- BUFFS ----------------
	var s := Jogo.novo_jogo("Buffs")
	s["jogador"]["equip"] = 0
	var b0 := Combate.bonus_de(s, {"lanceiro": 10})
	s["jogador"]["equip"] = 3
	var b3 := Combate.bonus_de(s, {"lanceiro": 10})
	ok("equipamento dá buff permanente", b3 > b0 and is_equal_approx(b3, 1.45),
		"%.2f" % b3)

	# clã mercenário: +20% SÓ na especialidade dele
	s["jogador"]["equip"] = 0
	s["clas_ativos"] = [{"id": "cla_estepe", "meses": 6,
		"contingente": {"cav_leve": 8}, "especialidade": "cav"}]
	ok("clã de cavalaria dá +20% a exército de cavalaria",
		is_equal_approx(Combate.bonus_de(s, {"cav_leve": 10}), 1.20))
	ok("clã de cavalaria NÃO ajuda exército de arqueiros",
		is_equal_approx(Combate.bonus_de(s, {"arqueiro": 10}), 1.00))
	ok("todo clã declara sua especialidade",
		Clas.CLAS.all(func(c): return c.has("especialidade")))

	# ---------------- RELATÓRIO DE BATALHA ----------------
	var sb := Jogo.novo_jogo("Relatorio")
	sb["jogador"]["tropas"]["lanceiro"] = 40
	sb["jogador"]["tropas"]["arqueiro"] = 20
	sb["jogador"]["tropas"]["cav_leve"] = 5
	var rel := Combate.batalhar(sb, Combate.exercito_inimigo(2), "Teste de relatório")
	ok("relatório detalha as fases", rel["fases"].size() >= 1)
	ok("relatório traz baixas dos dois lados",
		rel.has("baixas_jogador") and rel.has("baixas_inimigo"))
	var texto: String = rel["resumo"]
	ok("relatório menciona as fases pelo nome",
		texto.contains("Disparo") or texto.contains("Choque") or texto.contains("Corpo a corpo"),
		texto.split("\n")[1] if texto.split("\n").size() > 1 else "")
	ok("relatório diz vitória ou derrota",
		texto.contains("VITÓRIA") or texto.contains("DERROTA"))
	ok("relatório marca a intenção", texto.contains("CERCO") or texto.contains("SAQUE"))

	# ---------------- PRISÃO POR DERROTA ESMAGADORA ----------------
	var sp := Jogo.novo_jogo("Esmagado")
	sp["jogador"]["tropas"] = Jogo._tropas_zeradas({"campones": 2})
	var rel_p := Combate.batalhar(sp, Combate.exercito_inimigo(4), "Massacre")
	ok("derrota esmagadora é sinalizada no relatório",
		rel_p.has("esmagado") and (rel_p["esmagado"] or rel_p["vitoria"]))

	# ---------------- COMPATIBILIDADE ----------------
	var sc := Jogo.novo_jogo("Compat")
	ok("exército novo tem todas as tropas do catálogo",
		sc["jogador"]["tropas"].size() == Dados.TROPAS.size())
	ok("começa com 5 lanceiros, como antes",
		int(sc["jogador"]["tropas"]["lanceiro"]) == 5)
	var p := Combate.poder(sc["jogador"]["tropas"], 0)
	ok("poder() ainda serve à UI", p.has("atq") and p.has("def")
		and p.has("homens") and p.has("pop"))
	ok("população do exército é contada", int(p["pop"]) == 5)

	# save antigo com "cavaleiro" migra para "cav_leve"
	var velho := Jogo.novo_jogo("Velho")
	velho["jogador"]["tropas"] = {"campones": 0, "lanceiro": 5, "arqueiro": 0, "cavaleiro": 7}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(velho))
	f.close()
	var migrado = Jogo.carregar()
	ok("save antigo: cavaleiro virou cav_leve",
		migrado != null and int(migrado["jogador"]["tropas"].get("cav_leve", 0)) == 7
		and not migrado["jogador"]["tropas"].has("cavaleiro"))
	ok("save antigo ganhou as tropas novas zeradas",
		int(migrado["jogador"]["tropas"].get("cav_pesada", -1)) == 0)
	Jogo.passar_mes(migrado)
	ok("save migrado passa o mês sem quebrar", int(migrado["mes"]) != int(velho["mes"]))
	Jogo.apagar_save()

	# ---------------- INTEGRAÇÃO ----------------
	var full := Jogo.novo_jogo("Integração")
	full["jogador"]["ouro"] = 20000
	full["terra"] = {"nome": "Fim", "nivel": 3, "populacao": 300,
		"alimento": 900, "madeira": 100, "felicidade": 70}
	for tipo in ["espadachim", "barbaro", "arq_cavalo", "cav_pesada"]:
		Jogo.recrutar(full, tipo, 2)
	for i in 24:
		if full["evento_pendente"] != null:
			Jogo.resolver_evento(full, "ignorar")
		if full["fim"] != null:
			break
		Jogo.passar_mes(full)
	ok("24 meses com as tropas novas em jogo",
		int(full["jogador"]["tropas"]["cav_pesada"]) >= 0)
	ok("as tropas novas realmente foram treinadas",
		int(full["jogador"]["tropas"]["espadachim"]) >= 2)

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
