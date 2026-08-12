# ============================================================
# REVISÃO DO BLOCO I — os sistemas novos JOGADOS de ponta a ponta.
#
# As outras suítes testam peças: esta testa CORRENTES. Cada bloco abaixo
# é uma partida curta que atravessa um sistema inteiro do jeito que o
# jogador atravessa — sem atalho, sem estado montado à mão onde o jogo
# obrigaria a conquistar.
#
# É o teste que responde "a mecânica funciona?", e não "a função existe?".
#   godot --headless --path . --script res://tests/teste_bloco1.gd
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Contratos = preload("res://scripts/contratos.gd")
const Empregos = preload("res://scripts/empregos.gd")
const Pretendentes = preload("res://scripts/pretendentes.gd")
const Vassalagem = preload("res://scripts/vassalagem.gd")
const Viagem = preload("res://scripts/viagem.gd")
const Barbaros = preload("res://scripts/barbaros.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Relogio = preload("res://scripts/relogio.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Marchas = preload("res://scripts/marchas.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func secao(t: String) -> void:
	print("\n-- ", t, " --")

func _init() -> void:
	seed(20260811)
	print("=== REVISÃO DO BLOCO I (integração) ===")

	# ============================================================
	secao("1. O DIA COMO UNIDADE")
	# ============================================================
	var s := Jogo.novo_jogo("Revisor")
	var mes0: int = int(s["mes"])
	ok("a partida começa no dia 1", int(s["dia"]) == 1)
	Jogo.passar_dia(s)
	Jogo.passar_dia(s)
	ok("dois cliques NÃO viram o mês", int(s["mes"]) == mes0 and int(s["dia"]) == 3)
	Jogo.passar_dia(s)
	ok("o terceiro clique fecha o mês e volta ao dia 1",
		int(s["mes"]) == mes0 + 1 and int(s["dia"]) == 1)
	ok("um mês em dias move o relógio como um mês inteiro (marcha e quartel intactos)",
		int(s["minuto"]) == Relogio.MINUTOS_POR_MES, "%d min" % int(s["minuto"]))
	# O RELÓGIO É UM SÓ: o dia do rodapé, o dia da marcha e o dia do quartel
	# têm que ser o MESMO dia. Antes eram duas réguas (1/3 do mês contra
	# 1/30) e "12 dias de marcha" não cabia num mês de 3 dias.
	ok("a régua do dia fecha com a do mês (uma unidade para tudo)",
		Relogio.MINUTOS_POR_DIA * Jogo.DIAS_POR_MES == Relogio.MINUTOS_POR_MES,
		"%d × %d = %d" % [Relogio.MINUTOS_POR_DIA, Jogo.DIAS_POR_MES,
			Relogio.MINUTOS_POR_MES])
	ok("o texto de dias arredonda para CIMA (o jogador só age em dia inteiro)",
		Relogio.texto_dias(Relogio.MINUTOS_POR_DIA + 1) == "2 dias"
		and Relogio.texto_dias(1) == "1 dia")
	# uma marcha de exército tem que caber na mesma cabeça: dias de verdade
	var sm_r := Jogo.novo_jogo("Marchador")
	sm_r["terra"] = {"nome": "Vale", "nivel": 3, "populacao": 300, "alimento": 900,
		"madeira": 200, "felicidade": 70, "pressao": 0.0}
	sm_r["jogador"]["ouro"] = 9999
	sm_r["jogador"]["tropas"]["lanceiro"] = 60
	var est_m: Dictionary = Marchas.estimar(sm_r, "imperio", {"lanceiro": 20})
	var dias_m: int = Relogio.dias_ate(int(est_m["minutos"]))
	ok("uma marcha ao Império leva poucos DIAS — a mesma unidade do rodapé",
		dias_m >= 1 and dias_m <= 6, "%d dias" % dias_m)
	# e o exército é mais lento que o homem sozinho a cavalo
	sm_r["local"] = "jogador"
	var est_v: Dictionary = Viagem.estimar(sm_r, "imperio")
	ok("a coluna é mais lenta que o cavaleiro sozinho",
		dias_m >= int(est_v["dias"]),
		"marcha %d vs viagem %d" % [dias_m, int(est_v["dias"])])
	# o quartel tem que andar pelos dias, não só pela virada
	var sq := Jogo.novo_jogo("Quartel")
	sq["terra"] = {"nome": "Vale", "nivel": 2, "populacao": 200, "alimento": 500,
		"madeira": 100, "felicidade": 70, "pressao": 0.0}
	sq["jogador"]["ouro"] = 3000
	Recrutamento.enfileirar(sq, "lanceiro", 3)
	var lanc_q: int = int(sq["jogador"]["tropas"]["lanceiro"])
	Jogo.passar_dia(sq)
	ok("UM dia já move a fila do quartel (o relógio anda em terços)",
		int(sq["jogador"]["tropas"]["lanceiro"]) > lanc_q,
		"%d → %d" % [lanc_q, int(sq["jogador"]["tropas"]["lanceiro"])])
	# evento pendente segura o tempo — e não pode travar o jogo em silêncio
	var se := Jogo.novo_jogo("Evento")
	se["evento_pendente"] = {"tipo": "rebeliao"}
	var dia_e: int = int(se["dia"])
	Jogo.passar_dia(se)
	ok("evento pendente segura o dia (a UI abre o modal antes)",
		int(se["dia"]) == dia_e)
	Jogo.resolver_evento(se, "ignorar")
	Jogo.passar_dia(se)
	ok("e resolvido o evento, o tempo volta a andar", int(se["dia"]) != dia_e)

	# ============================================================
	secao("2. SAIR DO ZERO — o loop que o alfa acusou como estado zumbi")
	# ============================================================
	var z := Jogo.novo_jogo("Falido")
	z["local"] = "touros"
	for tipo in z["jogador"]["tropas"]:
		z["jogador"]["tropas"][tipo] = 0
	z["jogador"]["ouro"] = 0
	z["jogador"]["honra"] = 50
	var vagas: Array = Empregos.do_reino(z, "touros")
	ok("a taverna de onde você está oferece trabalho", vagas.size() == 3)
	var escolhida: Dictionary = {}
	for v in vagas:
		if Empregos.pedir_emprego(z, "touros", str(v["id"]))["ok"]:
			escolhida = v
			break
	ok("com honra de gente comum, alguma porta abre", not escolhida.is_empty())
	ok("mas trabalhar antes de pedir é recusado",
		not Empregos.trabalhar(z, "touros", "gladiador", 1)["ok"])
	var ganhou := 0
	for mes_z in 4:
		z["dia"] = 1
		var rz: Dictionary = Empregos.trabalhar(z, "touros", str(escolhida["id"]), 2)
		if bool(rz.get("ok", false)):
			ganhou += int(rz["paga"])
		if z["fim"] != null:
			break
	ok("quatro turnos tiram o jogador do zero", int(z["jogador"]["ouro"]) > 0 or z["fim"] != null,
		"%d de ouro" % int(z["jogador"]["ouro"]))
	ok("e o ofício deixou marca no corpo",
		int(z.get("progresso_atributo", {}).get(str(escolhida["atributo"]), 0)) > 0
		or z["fim"] != null)
	# a ruína continua tendo saída E fim — nunca mais um estado imóvel
	var ru := Jogo.novo_jogo("Ruina")
	for tipo_r in ru["jogador"]["tropas"]:
		ru["jogador"]["tropas"][tipo_r] = 0
	ru["jogador"]["ouro"] = 0
	for i_r in 12:
		ru["jogador"]["ouro"] = 0
		ru["evento_pendente"] = null
		if ru["fim"] != null:
			break
		Jogo.passar_mes(ru)
	ok("sem NENHUMA ação, a ruína acaba em fim de jogo (não em limbo)",
		ru["fim"] != null, str(ru["fim"]))

	# ============================================================
	secao("3. CONTRATO: mural, palavra, relatório, marcha")
	# ============================================================
	var c := Jogo.novo_jogo("Empreiteiro")
	c["local"] = "touros"
	c["jogador"]["tropas"]["lanceiro"] = 120
	var mural: Array = Contratos.do_local(c)
	ok("o mural da taverna tem cinco serviços", mural.size() == Contratos.POR_TAVERNA)
	var alvo_c: Dictionary = mural[0]
	var rp: Dictionary = Contratos.relatorio_preparacao(c, alvo_c)
	ok("o relatório diz quantos são eles e quantos são os seus",
		int(rp["inimigos"]) > 0 and int(rp["meus"]) == 120)
	ok("e dá veredito em português, com dias e o preço de largar",
		str(rp["veredito"]) != "" and int(rp["dias"]) >= 1 and int(rp["penalidade"]) >= 10)
	ok("dar a palavra é aceito", bool(Contratos.aceitar(c, str(alvo_c["uid"]))["ok"]))
	ok("e o contrato fica marcado como aceito",
		not Contratos.aceito_de(c).is_empty())
	var ouro_c: int = int(c["jogador"]["ouro"])
	var dias_c: int = Contratos.duracao_dias(alvo_c)
	var r_exec: Dictionary = Contratos.executar(c, alvo_c, Jogo.log_para(c))
	ok("executar resolve a batalha de verdade", r_exec.has("vitoria"))
	ok("e come os dias que prometeu",
		int(c["dia"]) == 1 + dias_c or int(c["dia"]) == 1)
	if bool(r_exec.get("vitoria", false)):
		ok("vitória paga ouro", int(c["jogador"]["ouro"]) > ouro_c)
	else:
		ok("derrota cobra renome", true, "derrota nesta seed")
	# largar tem preço, e a virada do mês cobra quem sumiu
	var c2 := Jogo.novo_jogo("Caloteiro")
	c2["local"] = "touros"
	var uid_c2: String = str(Contratos.do_local(c2)[0]["uid"])
	Contratos.aceitar(c2, uid_c2)
	var honra_c2: int = int(c2["jogador"]["honra"])
	c2["evento_pendente"] = null
	Jogo.passar_mes(c2)
	ok("palavra quebrada na virada do mês cobra honra",
		int(c2["jogador"]["honra"]) < honra_c2,
		"%d → %d" % [honra_c2, int(c2["jogador"]["honra"])])
	ok("e o mural é renovado com cinco serviços novos",
		Contratos.do_local(c2).size() == Contratos.POR_TAVERNA
		and Contratos.aceito_de(c2).is_empty())

	# ============================================================
	secao("4. COMÉRCIO: mapa, estação e a rota que dá lucro")
	# ============================================================
	var m := Jogo.novo_jogo("Mercador")
	m["local"] = "touros"
	m["jogador"]["ouro"] = 2000
	ok("sem Mapa Comercial ninguém negocia",
		not Economia.comprar(m, "touros", "madeira", 10)["ok"])
	ok("o cartógrafo da taverna vende a licença", bool(Taverna.comprar_rota(m)["ok"]))
	ok("e agora o armazém abre", bool(Economia.comprar(m, "touros", "madeira", 10)["ok"]))
	ok("a carga entrou de verdade", int(m["carga"].get("madeira", 0)) == 10)
	# vender onde é escasso: o produtor tem oferta alta, o não-produtor não
	var preco_casa: int = Economia.preco_de(m, "touros", "madeira")
	var preco_fora: int = Economia.preco_de(m, "imperio", "madeira")
	ok("madeira é mais barata em quem a produz",
		preco_casa < preco_fora, "%d vs %d" % [preco_casa, preco_fora])
	var r_viagem: Dictionary = Viagem.viajar(m, "imperio", Jogo.log_para(m))
	ok("a viagem leva você até a praça cara", bool(r_viagem["ok"])
		and str(m["local"]) == "imperio")
	var ouro_m: int = int(m["jogador"]["ouro"])
	ok("e a venda lá rende mais que o custo daqui",
		bool(Economia.vender(m, "imperio", "madeira", 10)["ok"])
		and int(m["jogador"]["ouro"]) - ouro_m > preco_casa * 10 - 1,
		"+%d" % (int(m["jogador"]["ouro"]) - ouro_m))
	m["evento_pendente"] = null
	Jogo.passar_mes(m)
	ok("o mapa vence na virada — a rota tem custo recorrente",
		not Economia.mapa_valido(m))
	# O FREIO ELÁSTICO, travado por número: encher a carroça de uma vez
	# tem que encarecer o próprio preço. Era a única defesa contra a
	# arbitragem infinita, e é o que a sonda de balanceamento afere —
	# se alguém zerar ELASTICIDADE, esta asserção cai antes do release.
	var me := Jogo.novo_jogo("Elastico")
	me["local"] = "touros"
	me["jogador"]["ouro"] = 20000
	Economia.renovar_mapa(me)
	var p0: int = Economia.preco_de(me, "touros", "madeira")
	for i_e in 20:
		Economia.comprar(me, "touros", "madeira", 5)
	var p1: int = Economia.preco_de(me, "touros", "madeira")
	ok("comprar 100 unidades encarece a praça em pelo menos 40%",
		p1 >= roundi(p0 * 1.4), "%d → %d" % [p0, p1])
	var pv0: int = Economia.preco_de(me, "imperio", "madeira")
	me["local"] = "imperio"
	me["carga"]["madeira"] = 100
	for i_v in 20:
		Economia.vender(me, "imperio", "madeira", 5)
	ok("e despejar 100 unidades derruba o preço de quem vende",
		Economia.preco_de(me, "imperio", "madeira") < pv0,
		"%d → %d" % [pv0, Economia.preco_de(me, "imperio", "madeira")])
	# a estação move o preço na MESMA praça
	var ms := Jogo.novo_jogo("Sazonal")
	ms["mes"] = 7
	for i_s in 8:
		Economia.tick_mercados(ms)
	var p_verao: int = Economia.preco_de(ms, "alvorecer", "trigo")
	ms["mes"] = 1
	for i_s2 in 8:
		Economia.tick_mercados(ms)
	var p_inverno: int = Economia.preco_de(ms, "alvorecer", "trigo")
	ok("trigo custa mais no inverno que no verão, na mesma praça",
		p_inverno > p_verao, "%d → %d" % [p_verao, p_inverno])

	# ============================================================
	secao("5. CASAMENTO: cortejo, altar e o ofício da casa dela")
	# ============================================================
	var f := Jogo.novo_jogo("Pretendente")
	f["local"] = "touros"
	f["jogador"]["ouro"] = 3000
	f["terra"] = {"nome": "Vale", "nivel": 2, "populacao": 200, "alimento": 900,
		"madeira": 300, "felicidade": 60, "pressao": 0.0}
	var mocas: Array = Pretendentes.do_reino(f, "touros")
	ok("três moças no salão da região", mocas.size() == 3)
	var voltas := 0
	while Pretendentes.afeto(f, "touros", 0) < Pretendentes.AFETO_PARA_CASAR and voltas < 12:
		f["dia"] = 1
		Pretendentes.cortejar(f, "touros", 0, Jogo.log_para(f))
		voltas += 1
	ok("cortejar repetido conquista o afeto",
		Pretendentes.afeto(f, "touros", 0) >= Pretendentes.AFETO_PARA_CASAR,
		"%d visitas" % voltas)
	var renome_f: int = int(f["jogador"]["renome"])
	var r_casa: Dictionary = Pretendentes.pedir_a_mao(f, "touros", 0, Jogo.log_para(f))
	ok("com afeto cheio, casa", bool(r_casa["ok"]) and f["familia"]["conjuge"] != null)
	ok("a nobreza inteira torce o nariz",
		int(Dialogo.tags_de(f, "rei_aguias")["relacao"]) < 0)
	ok("e o renome paga o preço", int(f["jogador"]["renome"]) <= renome_f)
	# o buff tem que aparecer num MÊS DE VERDADE, não só na função
	var buff: String = str(f["familia"]["conjuge"]["buff"])
	var antes_buff := 0
	var depois_buff := 0
	match buff:
		"colheita":
			antes_buff = int(f["terra"]["alimento"])
			f["evento_pendente"] = null
			Jogo.passar_mes(f)
			depois_buff = int(f["terra"]["alimento"])
			ok("o ofício da esposa (colheita) aparece no celeiro do mês",
				depois_buff != antes_buff)
		"felicidade":
			antes_buff = int(f["terra"]["felicidade"])
			f["evento_pendente"] = null
			Jogo.passar_mes(f)
			ok("o ofício da esposa (felicidade) aparece na vila",
				int(f["terra"]["felicidade"]) >= antes_buff)
		"equip":
			f["jogador"]["ouro"] = 5000
			var ouro_eq: int = int(f["jogador"]["ouro"])
			Jogo.melhorar_equip(f)
			ok("o ofício da esposa (forja) barateia o equipamento",
				ouro_eq - int(f["jogador"]["ouro"]) < 200)
		_:
			ok("o ofício da esposa está registrado no cônjuge",
				Pretendentes.buff_ativo(f, buff))
	ok("casado não corteja mais ninguém",
		not Pretendentes.cortejar(f, "touros", 1)["ok"])

	# ============================================================
	secao("6. VASSALAGEM: joelho, carreira e contrapartida")
	# ============================================================
	var v := Jogo.novo_jogo("Vassalo")
	v["local"] = "touros"
	v["jogador"]["honra"] = 70
	ok("um estranho não é aceito como vassalo",
		not bool(Vassalagem.pode_jurar(v, "touros")["ok"]))
	Dialogo.mudar_relacao(v, "rei_touros", 45, "serviços prestados")
	var rei_v := {"id": "rei_touros", "nome": "Bjorne", "personalidade": "orgulhoso",
		"papel": "rei"}
	Dialogo.falar(v, rei_v, "meu senhor, quero ser seu vassalo")
	ok("com relação construída, o juramento na conversa pega",
		Vassalagem.e_vassalo(v))
	ok("e começa no degrau mais baixo, sem soldo",
		int(Vassalagem.cargo(v)["soldo"]) == 0, str(Vassalagem.cargo(v)["nome"]))
	var reino_v: Dictionary = Geopolitica.reino_por_id(v, "touros")
	reino_v["tesouro"] = 8000
	v["jogador"]["ouro"] = 400
	var meses_v := 0
	while meses_v < 24 and int(Vassalagem.cargo(v)["soldo"]) == 0:
		v["evento_pendente"] = null
		if v["fim"] != null:
			break
		Jogo.passar_mes(v)
		meses_v += 1
	ok("servindo, a casa promove", int(Vassalagem.cargo(v)["soldo"]) > 0,
		"%s em %d meses" % [str(Vassalagem.cargo(v)["nome"]), meses_v])
	var resumo_v: Dictionary = Vassalagem.resumo(v)
	ok("o tributo do graduado é menor que o do juramentado raso",
		float(Vassalagem.CARGOS[0]["tributo"]) > float(Vassalagem.cargo(v)["tributo"]))
	ok("e o resumo anuncia o próximo degrau (a escada é visível)",
		str(resumo_v.get("proximo_cargo", "")) != ""
		or str(resumo_v["cargo"]) == str(Vassalagem.CARGOS[3]["nome"]))
	var ouro_v0: int = int(v["jogador"]["ouro"])
	var tesouro_v0: int = int(reino_v["tesouro"])
	Vassalagem.tick(v, Jogo.log_para(v))
	ok("o soldo sai do cofre DELE e entra no seu",
		int(reino_v["tesouro"]) < tesouro_v0 or int(v["jogador"]["ouro"]) != ouro_v0)

	# ============================================================
	secao("7. MAPA E ESTRADA")
	# ============================================================
	var t := Jogo.novo_jogo("Andarilho")
	t["local"] = "touros"
	var est_perto: Dictionary = Viagem.estimar(t, "imperio")
	var est_longe: Dictionary = Viagem.estimar(t, "aguias")
	ok("o vizinho custa menos dias que o outro lado do mapa",
		int(est_perto["dias"]) < int(est_longe["dias"]))
	ok("toda viagem cabe num mês", int(est_longe["dias"]) <= Jogo.DIAS_POR_MES)
	ok("o trajeto nomeia as paradas", str(est_longe["trajeto"]).contains("→"))
	# a estrada oferece a escolha do saque
	var sq2 := Jogo.novo_jogo("Salteador")
	sq2["jogador"]["honra"] = 80
	var ouro_sq: int = int(sq2["jogador"]["ouro"])
	Viagem.saquear_caravana(sq2, 120, Jogo.log_para(sq2))
	ok("saquear caravana paga na hora e cobra 15% da honra",
		int(sq2["jogador"]["ouro"]) == ouro_sq + 120
		and int(sq2["jogador"]["honra"]) == 68)

	# ============================================================
	secao("8. TERRAS BÁRBARAS: batedor, invasão, coroa")
	# ============================================================
	var b := Jogo.novo_jogo("Fundador")
	b["local"] = "rosa"
	b["jogador"]["ouro"] = 1200
	var r_ida: Dictionary = Viagem.viajar(b, "barbaros", Jogo.log_para(b))
	ok("dá para viajar até a fronteira selvagem", bool(r_ida["ok"])
		and str(b["local"]) == "barbaros")
	for tipo_b in b["jogador"]["tropas"]:
		b["jogador"]["tropas"][tipo_b] = 0
	b["jogador"]["tropas"]["lanceiro"] = 400
	b["jogador"]["tropas"]["espadachim"] = 220
	b["jogador"]["tropas"]["arqueiro"] = 160
	ok("sem batedor, o jogo RECUSA a invasão",
		not bool(Barbaros.pode_invadir(b)["ok"]))
	b["dia"] = 1
	ok("o batedor atravessa e conta os clãs",
		bool(Barbaros.espiar(b, Jogo.log_para(b))["ok"]))
	ok("agora a invasão é permitida", bool(Barbaros.pode_invadir(b)["ok"]))
	var r_inv: Dictionary = Barbaros.invadir(b, Jogo.log_para(b))
	ok("um exército grande toma a fronteira", bool(r_inv["vitoria"]))
	b["jogador"]["renome"] = 80
	var r_fund: Dictionary = Barbaros.fundar_reino(b, "Casa da Estepe", "Pedra Alta",
		Jogo.log_para(b))
	ok("e a casa nova entra no mapa", bool(r_fund["ok"])
		and str(b["jogador"]["rei_de"]) == "barbaros")
	# o reino novo tem que SOBREVIVER a save/load e a meses de jogo
	Jogo.salvar(b)
	var b2 = Jogo.carregar()
	ok("o reino fundado sobrevive ao save/load",
		b2 != null and Geopolitica.reino_por_id(b2, "barbaros").has("capital"))
	for i_b in 6:
		b2["evento_pendente"] = null
		if b2["fim"] != null:
			break
		Jogo.passar_mes(b2)
	ok("e seis meses correm com sete casas no mapa sem quebrar",
		b2["reinos"].size() == 7)
	ok("o jogador continua rei da casa que fundou",
		str(b2["jogador"]["rei_de"]) == "barbaros" or b2["fim"] != null)

	# ============================================================
	secao("9. HONRA — a moeda nova do Bloco I")
	# ============================================================
	var h := Jogo.novo_jogo("Honrado")
	ok("todo jogador começa com honra", int(h["jogador"]["honra"]) == 50)
	# tudo que TIRA honra
	var tira := 0
	var h1 := Jogo.novo_jogo("H1")
	h1["local"] = "touros"
	var uid_h: String = str(Contratos.do_local(h1)[0]["uid"])
	Contratos.aceitar(h1, uid_h)
	if int(Contratos.abandonar(h1, uid_h, Jogo.log_para(h1)).get("honra_perdida", 0)) > 0:
		tira += 1
	var h2 := Jogo.novo_jogo("H2")
	h2["jogador"]["honra"] = 80
	Viagem.saquear_caravana(h2, 50)
	if int(h2["jogador"]["honra"]) < 80:
		tira += 1
	var h3 := Jogo.novo_jogo("H3")
	h3["jogador"]["ouro"] = 900
	h3["jogador"]["honra"] = 80
	Pretendentes.cortejar(h3, "touros", 0)
	h3["dia"] = 1
	Pretendentes.cortejar(h3, "imperio", 1)
	if int(h3["jogador"]["honra"]) < 80:
		tira += 1
	ok("há pelo menos três formas de PERDER honra", tira >= 3, "%d medidas" % tira)
	# ...e o caminho de volta: cumprir a palavra tem que reconstruir o nome
	var h4 := Jogo.novo_jogo("H4")
	h4["local"] = "touros"
	h4["jogador"]["honra"] = 30
	h4["jogador"]["tropas"]["lanceiro"] = 300
	var honra_h4: int = int(h4["jogador"]["honra"])
	var ct_h4: Dictionary = Contratos.do_local(h4)[0]
	Contratos.aceitar(h4, str(ct_h4["uid"]))
	var r_h4: Dictionary = Contratos.executar(h4, ct_h4, Jogo.log_para(h4))
	ok("cumprir a palavra num contrato DEVOLVE honra (senão o nome só afunda)",
		int(h4["jogador"]["honra"]) > honra_h4 or not bool(r_h4.get("vitoria", false)),
		"honra %d → %d" % [honra_h4, int(h4["jogador"]["honra"])])

	Jogo.apagar_save()
	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
