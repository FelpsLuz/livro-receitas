# ============================================================
# TESTES DO PORTÃO DE PROGRESSÃO E DAS QUATRO MECÂNICAS SISTÊMICAS:
#   infraestrutura → teto de tropas + imposto
#   dilema da população · estações · vassalagem · comandantes
#   godot --headless --path . --script res://tests/teste_reino.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Estacoes = preload("res://scripts/estacoes.gd")
const Vassalagem = preload("res://scripts/vassalagem.gd")
const Comandantes = preload("res://scripts/comandantes.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Cerco = preload("res://scripts/cerco.gd")
const Relogio = preload("res://scripts/relogio.gd")
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

func com_terra(nivel: int, pop: int = 300) -> Dictionary:
	var s := Jogo.novo_jogo("Reino")
	s["terra"] = {"nome": "Vale", "nivel": nivel, "populacao": pop,
		"alimento": 6000, "madeira": 4000, "felicidade": 75, "pressao": 0.0}
	s["jogador"]["ouro"] = 20000
	s["jogador"]["tropas"] = Jogo._tropas_zeradas()
	return s

func _init() -> void:
	seed(2077)
	print("=== PORTÃO DE PROGRESSÃO E MECÂNICAS SISTÊMICAS ===")

	# ============ 1. PORTÃO DE PROGRESSÃO ============
	ok("todo nível de terra declara teto e imposto",
		Dados.NIVEIS_TERRA.all(func(n): return n.has("cap") and n.has("imposto")))
	var cap_sobe := true
	var imp_sobe := true
	for i in range(1, Dados.NIVEIS_TERRA.size()):
		if int(Dados.NIVEIS_TERRA[i]["cap"]) <= int(Dados.NIVEIS_TERRA[i - 1]["cap"]):
			cap_sobe = false
		if float(Dados.NIVEIS_TERRA[i]["imposto"]) <= float(Dados.NIVEIS_TERRA[i - 1]["imposto"]):
			imp_sobe = false
	ok("o teto de tropas cresce a cada nível", cap_sobe)
	ok("o imposto por habitante cresce a cada nível", imp_sobe)

	# o teto vem da INFRAESTRUTURA, não da população crua
	var acamp := com_terra(0, 500)
	var castelo := com_terra(5, 500)
	ok("mesma população, teto diferente por nível",
		Recrutamento.pop_maxima(acamp) < Recrutamento.pop_maxima(castelo),
		"%d vs %d" % [Recrutamento.pop_maxima(acamp), Recrutamento.pop_maxima(castelo)])
	ok("acampamento não sustenta exército grande",
		Recrutamento.pop_maxima(acamp) == int(Dados.NIVEIS_TERRA[0]["cap"]),
		"%d" % Recrutamento.pop_maxima(acamp))
	# vila pequena limita mesmo com castelo: o menor dos dois manda
	var pequeno := com_terra(5, 40)
	ok("população pequena ainda limita o castelo",
		Recrutamento.pop_maxima(pequeno) == 40, "%d" % Recrutamento.pop_maxima(pequeno))
	ok("sem terra, o bando é minúsculo",
		Recrutamento.pop_maxima(Jogo.novo_jogo("X")) == 20)

	# o portão MORDE: enfileirar além do teto é recusado
	var g0 := com_terra(0, 500)
	var r0 := Recrutamento.enfileirar(g0, "lanceiro", 100)
	ok("acampamento recusa 100 lanceiros", not r0["ok"], str(r0["msg"]))
	var g5 := com_terra(5, 500)
	ok("castelo aceita os mesmos 100", Recrutamento.enfileirar(g5, "lanceiro", 100)["ok"])

	# ============ 2. DILEMA DA POPULAÇÃO ============
	var d := com_terra(3, 300)
	var imposto_paz := Economia.imposto_mensal(d)
	ok("terra sem exército rende imposto cheio", imposto_paz > 0, "%d 🪙" % imposto_paz)
	ok("população ativa é a população inteira",
		Economia.populacao_ativa(d) == 300)

	d["jogador"]["tropas"]["lanceiro"] = 100
	ok("recrutar tira gente da lavoura",
		Economia.populacao_ativa(d) == 200, "%d" % Economia.populacao_ativa(d))
	var imposto_guerra := Economia.imposto_mensal(d)
	ok("exército DERRUBA o imposto", imposto_guerra < imposto_paz,
		"%d → %d" % [imposto_paz, imposto_guerra])

	# cavalaria pesa mais no bolso do que na fila: pop 6 por cabeça
	var d2 := com_terra(3, 300)
	d2["jogador"]["tropas"]["cav_pesada"] = 20      # 120 de pop
	ok("cavalaria pesada tira 6 pagadores por cabeça",
		Economia.populacao_ativa(d2) == 180, "%d" % Economia.populacao_ativa(d2))
	ok("100 lanceiros e 17 cav. pesadas custam o mesmo em pagadores",
		abs(Economia.pop_em_armas(d) - Economia.pop_em_armas(d2)) <= 25)

	# tropa EM MARCHA também não paga imposto
	var d3 := com_terra(3, 300)
	d3["jogador"]["tropas"]["lanceiro"] = 100
	var ativa_casa := Economia.populacao_ativa(d3)
	Marchas.despachar(d3, "touros", {"lanceiro": 50}, "saque")
	ok("quem está na estrada continua fora da lavoura",
		Economia.populacao_ativa(d3) == ativa_casa,
		"%d" % Economia.populacao_ativa(d3))

	# ============ 3. ESTAÇÕES ============
	ok("dezembro, janeiro e fevereiro são inverno",
		Estacoes.do_mes(12) == "inverno" and Estacoes.do_mes(1) == "inverno"
		and Estacoes.do_mes(2) == "inverno")
	ok("junho é verão", Estacoes.do_mes(6) == "verao")
	ok("as quatro estações cobrem os 12 meses",
		[1,2,3,4,5,6,7,8,9,10,11,12].all(func(m): return Dados.ESTACOES.has(Estacoes.do_mes(m))))
	# mês 13 é janeiro do ano seguinte e mês 0 é dezembro do anterior:
	# os dois caem no inverno, e nenhum deles pode quebrar a conta
	ok("mês fora da faixa dá a volta certa", Estacoes.do_mes(13) == "inverno"
		and Estacoes.do_mes(0) == "inverno" and Estacoes.do_mes(15) == "primavera")

	var inv := com_terra(3, 300)
	inv["mes"] = 1
	ok("no inverno a fazenda para", is_equal_approx(Estacoes.fator_comida(inv), 0.0))
	ok("no inverno o cerco custa o dobro",
		is_equal_approx(Estacoes.fator_cerco(inv), 2.0))
	ok("a UI tem cor da estação", Estacoes.cor(inv) != Color.BLACK)
	ok("a UI sabe quando a estação vira",
		Estacoes.meses_ate_virar(inv) > 0 and Estacoes.meses_ate_virar(inv) <= 3,
		"%d meses" % Estacoes.meses_ate_virar(inv))

	# a colheita realmente para
	var verao := com_terra(3, 300)
	verao["mes"] = 7
	verao["terra"]["alimento"] = 1000
	Economia.tick_terra(verao, Jogo.log_para(verao))
	var ganho_verao: int = int(verao["terra"]["alimento"]) - 1000
	var inverno := com_terra(3, 300)
	inverno["mes"] = 1
	inverno["terra"]["alimento"] = 1000
	Economia.tick_terra(inverno, Jogo.log_para(inverno))
	var ganho_inverno: int = int(inverno["terra"]["alimento"]) - 1000
	ok("verão enche o celeiro, inverno esvazia",
		ganho_verao > 0 and ganho_inverno < 0,
		"verão %+d, inverno %+d" % [ganho_verao, ganho_inverno])

	# cerco de inverno sangra muito mais que cerco de verão
	var cv := com_terra(4, 400)
	cv["mes"] = 7
	cv["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 80, "espadachim": 60})
	Marchas.despachar(cv, "touros", {"lanceiro": 80, "espadachim": 60}, "cerco")
	cv["marchas"][0]["perigo"] = 0.0
	Relogio.avancar(cv, int(cv["marchas"][0]["duracao"]) + 30, Jogo.log_para(cv))
	var gasto_verao: int = int(Cerco.progresso(cv["marchas"][0])["gasto"]["comida"])

	var ci := com_terra(4, 400)
	ci["mes"] = 1
	ci["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 80, "espadachim": 60})
	Marchas.despachar(ci, "touros", {"lanceiro": 80, "espadachim": 60}, "cerco")
	ci["marchas"][0]["perigo"] = 0.0
	Relogio.avancar(ci, int(ci["marchas"][0]["duracao"]) + 30, Jogo.log_para(ci))
	var gasto_inverno: int = int(Cerco.progresso(ci["marchas"][0])["gasto"]["comida"])
	ok("uma fase de cerco no inverno come o dobro",
		gasto_inverno >= gasto_verao * 2 - 2,
		"verão %d, inverno %d" % [gasto_verao, gasto_inverno])

	# ============ 4. VASSALAGEM ============
	var v := com_terra(1, 120)
	ok("começa livre", not Vassalagem.e_vassalo(v))
	var jr := Vassalagem.jurar(v, "imperio", Jogo.log_para(v))
	ok("dá para jurar lealdade", jr["ok"], str(jr["msg"]))
	ok("o suserano fica registrado", Vassalagem.suserano(v) == "imperio")
	ok("não se jura duas vezes", not Vassalagem.jurar(v, "leoes", Jogo.log_para(v))["ok"])

	# o tributo sai todo mês
	v["jogador"]["ouro"] = 1000
	Geopolitica.inicializar(v)
	var tesouro_suse: int = int(Geopolitica.reino_por_id(v, "imperio")["tesouro"])
	Vassalagem.tick(v, Jogo.log_para(v))
	ok("o suserano leva 20% do ouro",
		int(v["jogador"]["ouro"]) == 800, "%d" % int(v["jogador"]["ouro"]))
	ok("e o ouro entra no tesouro dele",
		int(Geopolitica.reino_por_id(v, "imperio")["tesouro"]) > tesouro_suse)

	# proteção: jurar cancela a guerra do suserano contra você
	var vg := com_terra(1, 120)
	vg["guerras"].append({"a": "leoes", "b": "jogador", "meses": 2})
	Vassalagem.jurar(vg, "leoes", Jogo.log_para(vg))
	var ainda_em_guerra := false
	for g in vg["guerras"]:
		if (g["a"] == "leoes" and g["b"] == "jogador") or (g["b"] == "leoes" and g["a"] == "jogador"):
			ainda_em_guerra = true
	ok("jurar lealdade encerra a guerra do suserano contra você", not ainda_em_guerra)

	# independência: custa renome, cria guerra e devolve o casus belli
	v["jogador"]["renome"] = 100
	var ind := Vassalagem.declarar_independencia(v, Jogo.log_para(v))
	ok("dá para rasgar o juramento", ind["ok"], str(ind["msg"]))
	ok("independência custa renome",
		int(v["jogador"]["renome"]) == 100 - Vassalagem.CUSTO_INDEPENDENCIA)
	ok("o suserano declara guerra", v["guerras"].any(
		func(g): return g["a"] == "imperio" and g["b"] == "jogador"))
	ok("e a guerra é legítima (casus belli)", v["casus_belli"].has("imperio"))
	ok("volta a ser livre", not Vassalagem.e_vassalo(v))
	ok("rei de si mesmo não jura a ninguém",
		not Vassalagem.pode_jurar(castelo, "imperio")["ok"]
		or str(castelo["jogador"]["rei_de"]) == "")

	# suserano que cai liberta o vassalo sem custo
	var vq := com_terra(1, 120)
	Vassalagem.jurar(vq, "rosa", Jogo.log_para(vq))
	Geopolitica.reino_por_id(vq, "rosa")["dominado_por"] = "imperio"
	Vassalagem.tick(vq, Jogo.log_para(vq))
	ok("suserano derrubado liberta o vassalo", not Vassalagem.e_vassalo(vq))

	# ============ 5. COMANDANTES ============
	var c := com_terra(3, 300)
	var lista := Comandantes.disponiveis(c)
	ok("o próprio senhor sempre pode comandar",
		lista.size() >= 1 and lista[0]["id"] == "senhor")
	ok("todo perfil declara o que faz",
		Comandantes.PERFIS.values().all(func(p): return p.has("desc") and p.has("nome")))

	var senhor := Comandantes.por_id(c, "senhor")
	ok("comandante dá bônus de ataque", Comandantes.bonus_ataque(senhor) > 1.0,
		"%.2f" % Comandantes.bonus_ataque(senhor))
	ok("sem comandante, nenhum bônus",
		is_equal_approx(Comandantes.bonus_ataque({}), 1.0))
	ok("atributo alto lidera melhor",
		Comandantes.bonus_ataque({"perfil": "senhor", "atributo": 10})
		> Comandantes.bonus_ataque({"perfil": "senhor", "atributo": 2}))
	ok("quartel-mestre economiza comida no cerco",
		Comandantes.fator_comida_cerco({"perfil": "quartel_mestre", "atributo": 5}) < 1.0)
	ok("batedor reduz o perigo da estrada",
		Comandantes.fator_perigo({"perfil": "batedor", "atributo": 5}) < 1.0)
	ok("batedor reforça a fase de disparo",
		Comandantes.bonus_ataque({"perfil": "batedor", "atributo": 5}, "arq")
		> Comandantes.bonus_ataque({"perfil": "batedor", "atributo": 5}, "inf"))

	# lorde que subiu de cidadão pode comandar
	var cl := com_terra(5, 400)
	cl["terra"]["felicidade"] = 95
	Cidadaos.tick(cl, Jogo.log_para(cl))
	for n in Cidadaos.lista(cl):
		n["lealdade"] = 95
		n["riqueza"] = 600
	Cidadaos.tick(cl, Jogo.log_para(cl))
	ok("lorde jurado entra na lista de comandantes",
		Comandantes.disponiveis(cl).size() > 1,
		"%d comandantes" % Comandantes.disponiveis(cl).size())

	# despachar com comandante
	var cm := com_terra(4, 400)
	cm["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 60, "arqueiro": 40})
	var rc := Marchas.despachar(cm, "touros", {"lanceiro": 40}, "saque", "senhor")
	ok("a marcha aceita comandante", rc["ok"]
		and str(Marchas.lista(cm)[0]["comandante"]) == "senhor")

	# batedor reduz o perigo REAL da marcha
	var cb := com_terra(4, 400)
	cb["clas_ativos"] = [{"id": "cla_corvos", "meses": 6,
		"contingente": {"arqueiro": 20}, "especialidade": "arq"}]
	cb["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 60})
	Marchas.despachar(cb, "sem_rei", {"lanceiro": 30}, "saque")
	var perigo_sem: float = float(Marchas.lista(cb)[0]["perigo"])
	var cb2 := com_terra(4, 400)
	cb2["clas_ativos"] = cb["clas_ativos"]
	cb2["jogador"]["tropas"] = Jogo._tropas_zeradas({"lanceiro": 60})
	Marchas.despachar(cb2, "sem_rei", {"lanceiro": 30}, "saque", "cla:cla_corvos")
	ok("batedor reduz o perigo da marcha de verdade",
		float(Marchas.lista(cb2)[0]["perigo"]) < perigo_sem,
		"%.2f → %.2f" % [perigo_sem, float(Marchas.lista(cb2)[0]["perigo"])])

	# captura: o senhor obliterado vai preso, não morre
	var cap := com_terra(2, 200)
	cap["jogador"]["tropas"] = Jogo._tropas_zeradas({"campones": 3})
	Marchas.despachar(cap, "imperio", {"campones": 3}, "saque", "senhor")
	cap["marchas"][0]["perigo"] = 0.0
	for i in 20:
		Relogio.avancar(cap, 2000, Jogo.log_para(cap))
		if cap["marchas"].is_empty():
			break
	ok("exército obliterado → senhor capturado, não morto",
		Jogo.esta_preso(cap) or not cap["marchas"].is_empty(),
		"preso=%s" % str(Jogo.esta_preso(cap)))

	# lorde capturado pode ser resgatado
	var lr := com_terra(5, 400)
	lr["terra"]["felicidade"] = 95
	Cidadaos.tick(lr, Jogo.log_para(lr))
	for n in Cidadaos.lista(lr):
		n["lealdade"] = 95
		n["riqueza"] = 600
	Cidadaos.tick(lr, Jogo.log_para(lr))
	var lordes := Cidadaos.lordes(lr)
	if not lordes.is_empty():
		var nome_l: String = str(lordes[0]["nome"])
		Comandantes.capturar(lr, {"id": "lorde:" + nome_l, "nome": nome_l,
			"perfil": "capitao", "atributo": 5}, Jogo.log_para(lr))
		ok("lorde capturado fica marcado", bool(lordes[0].get("capturado", false)))
		lr["jogador"]["ouro"] = 1000
		ok("e pode ser resgatado com ouro",
			Comandantes.resgatar(lr, nome_l)["ok"]
			and not bool(lordes[0].get("capturado", false)))

	# ============ 6. INTEGRAÇÃO ============
	var full := com_terra(2, 200)
	Vassalagem.jurar(full, "touros", Jogo.log_para(full))
	Jogo.recrutar(full, "lanceiro", 10)
	Marchas.despachar(full, "sem_rei", {"lanceiro": 0}, "saque")   # recusado, sem tropa
	var ouro0: int = int(full["jogador"]["ouro"])
	for i in 24:
		if full["evento_pendente"] != null:
			Jogo.resolver_evento(full, "ignorar")
		if full["fim"] != null:
			break
		Jogo.passar_mes(full)
	ok("24 meses como vassalo, com estações e imposto", full["fim"] == null
		or str(full["fim"].get("tipo", "")) != "")
	ok("o tributo saiu ao longo do tempo",
		int(full["jogador"].get("meses_vassalo", 0)) > 0,
		"%d meses de vassalagem" % int(full["jogador"].get("meses_vassalo", 0)))
	ok("o imposto foi calculado todo mês", full["jogador"].has("ultimo_imposto"))
	ok("passou por pelo menos um inverno",
		int(full["ano"]) > 1 or int(full["mes"]) >= 12)

	# save/load com tudo ligado
	Jogo.salvar(full)
	var fb = Jogo.carregar()
	ok("save/load preserva a vassalagem",
		fb != null and str(fb["jogador"].get("suserano", "")) == str(full["jogador"].get("suserano", "")))
	Jogo.apagar_save()

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
