# ============================================================
# TESTES DO NÚCLEO — roda headless:
#   godot --headless --path . --script res://tests/teste_nucleo.gd
# Valida os sistemas portados: diálogo/tags, economia, combate,
# clãs via mensageiro, intriga, dinastia e o loop de 36 meses.
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Dados = preload("res://scripts/dados.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Clas = preload("res://scripts/clas.gd")
const Intriga = preload("res://scripts/intriga.gd")
const Contratos = preload("res://scripts/contratos.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")

var passou := 0
var falhou := 0

func ok(cond: bool, nome: String) -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome)
	else:
		falhou += 1
		print("  ❌ FALHOU: ", nome)

func _init() -> void:
	seed(42)
	print("=== TESTES DO NÚCLEO (port Godot) ===")

	# ---------- estado inicial ----------
	var s := Jogo.novo_jogo("Teste da Silva")
	ok(s["jogador"]["ouro"] == 150, "ouro inicial 150")
	ok(s["jogador"]["tropas"]["lanceiro"] == 5, "5 lanceiros iniciais")
	ok(s["reinos"].size() == 6, "6 reinos")
	ok(s["mercados"].has("touros"), "mercados inicializados")

	# ---------- diálogo: insulto derruba relação e sobe preços ----------
	var rei: Dictionary = s["reinos"][1]["rei"]
	var preco_antes := Economia.preco_de(s, "touros", "trigo")
	var r1 := Dialogo.falar(s, rei, "seu porco covarde e idiota")
	ok(r1["intencao"] == "insulto", "intenção de insulto detectada")
	ok(Dialogo.tags_de(s, "rei_touros")["relacao"] < 0, "relação caiu após insulto")
	var r2 := Dialogo.falar(s, rei, "seu verme patetico")
	ok(Dialogo.tags_de(s, "rei_touros")["relacao"] <= -40, "insulto repetido agrava (grave)")
	ok(r2["resposta"].length() > 10, "resposta gerada")
	# hostil => preço sobe para o jogador
	var preco_depois := Economia.preco_de(s, "touros", "trigo")
	ok(preco_depois > preco_antes, "preço subiu para o odiado (%d > %d)" % [preco_depois, preco_antes])

	# ---------- diálogo: elogio com retorno decrescente ----------
	var s2 := Jogo.novo_jogo("B")
	var rei2: Dictionary = s2["reinos"][1]["rei"]
	Dialogo.falar(s2, rei2, "vossa sabedoria é lendária e gloriosa")
	var rel1: int = Dialogo.tags_de(s2, "rei_touros")["relacao"]
	Dialogo.falar(s2, rei2, "sois magnífico e brilhante")
	Dialogo.falar(s2, rei2, "que rei tão nobre e poderoso")
	var rel3: int = Dialogo.tags_de(s2, "rei_touros")["relacao"]
	ok(rel1 > 0, "elogio sobe relação")
	ok(rel3 - rel1 < rel1 * 2, "bajulação tem retorno decrescente")

	# ---------- economia: compra/venda e guerra ----------
	var s3 := Jogo.novo_jogo("C")
	s3["jogador"]["ouro"] = 1000
	# negociar exige o Mapa Comercial (o freio da arbitragem infinita) —
	# aqui o que se testa é a compra em si, então o mapa vem selado
	Economia.renovar_mapa(s3, 1)
	var rc := Economia.comprar(s3, "touros", "trigo", 5)
	ok(rc["ok"] and s3["carga"]["trigo"] == 5, "compra adiciona carga")
	var rv := Economia.vender(s3, "touros", "trigo", 5)
	ok(rv["ok"] or s3["carga"]["trigo"] < 5, "venda executa (ou patrulha em guerra)")
	# guerra queima campos: oferta de trigo cai => preço sobe
	s3["guerras"].append({"a": "touros", "b": "alvorecer", "meses": 0})
	var p_antes := Economia.preco_de(s3, "touros", "trigo")
	var log3 := Jogo.log_para(s3)
	for i in 3:
		Economia.tick_guerras(s3, log3)
	var p_guerra := Economia.preco_de(s3, "touros", "trigo")
	ok(p_guerra > p_antes, "guerra dispara preço do trigo (%d > %d)" % [p_guerra, p_antes])

	# ---------- fadiga de guerra: convocados demais => fome ----------
	var s4 := Jogo.novo_jogo("D")
	s4["terra"] = {"nome": "Vale Teste", "nivel": 0, "populacao": 20, "alimento": 10,
		"madeira": 0, "felicidade": 60}
	s4["jogador"]["tropas"]["campones"] = 15
	var log4 := Jogo.log_para(s4)
	Economia.tick_terra(s4, log4)
	ok(s4["terra"]["alimento"] <= 10, "camponeses convocados não plantam")

	# ---------- combate: formação certa dá vantagem ----------
	var s5 := Jogo.novo_jogo("E")
	s5["jogador"]["tropas"] = {"campones": 0, "lanceiro": 30, "arqueiro": 20, "cavaleiro": 5}
	s5["jogador"]["formacao"] = "linha"
	var inimigo := {"tropas": {"lanceiro": 5}, "equip": 0, "formacao": "cunha"}
	var rel_bat := Combate.batalhar(s5, inimigo, "teste")
	ok(rel_bat["vitoria"], "exército forte vence escaramuça")
	ok(rel_bat["baixas_inimigo"] > 0, "baixas inimigas registradas")

	# ---------- clãs: oferta generosa contrata via mensageiro ----------
	var s6 := Jogo.novo_jogo("F")
	s6["jogador"]["ouro"] = 2000
	s6["jogador"]["renome"] = 40
	var rm := Clas.enviar_mensageiro(s6, "cla_lobos", 600)  # 1.7x o preço-base
	ok(rm["ok"], "mensageiro despachado")
	var log6 := Jogo.log_para(s6)
	var lanceiros_antes: int = s6["jogador"]["tropas"]["lanceiro"]
	Clas.tick(s6, log6)  # sem guerra => sem interceptação; chance >= 0.9
	var contratou: bool = not Clas.ativo(s6, "cla_lobos").is_empty()
	ok(contratou, "clã aceitou oferta generosa")
	if contratou:
		ok(s6["jogador"]["tropas"]["lanceiro"] == lanceiros_antes + 25, "25 lanceiros somados")
		# calote: zera o ouro => clã vai embora
		s6["jogador"]["ouro"] = 0
		Clas.tick(s6, log6)
		ok(Clas.ativo(s6, "cla_lobos").is_empty(), "calote encerra contrato")
		ok(s6["jogador"]["traiu_clas"] == true, "má fama de caloteiro registrada")
		ok(s6["jogador"]["tropas"]["lanceiro"] <= lanceiros_antes, "clã levou seus homens")

	# ---------- intriga: renome baixo bloqueia; casamento dá casus belli ----------
	var s7 := Jogo.novo_jogo("G")
	Intriga.realizar_casamento(s7, "rosa", false)
	ok(s7["familia"]["conjuge"] != null, "casamento realizado")
	ok(s7["casus_belli"].has("rosa"), "casamento gera reivindicação dinástica")
	# chantagem sem segredo = blefe
	var rch := Intriga.chantagear(s7, s7["reinos"][1]["rei"])
	ok(rch["efeitos"].has("[Blefe falhou]"), "chantagem sem segredo falha")
	# com segredo funciona
	s7["segredos"].append({"reino": "touros", "usado": false})
	var rch2 := Intriga.chantagear(s7, s7["reinos"][1]["rei"])
	ok(s7["chantagem_pendente"] != null, "chantagem com segredo abre exigência")
	Intriga.resolver_chantagem(s7, "casusbelli")
	ok(s7["casus_belli"].has("touros"), "exigência de casus belli atendida")

	# ---------- dinastia: herdeiro assume ----------
	var s8 := Jogo.novo_jogo("H")
	s8["familia"]["filhos"].append({"nome": "Edmund", "genero": "m", "idade": 17,
		"educacao": "", "atributos": {"forca": 6, "carisma": 5, "gestao": 7, "intriga": 4},
		"mimado": false})
	Jogo.morrer(s8, "idade", Jogo.log_para(s8))
	ok(s8["fim"] == null, "com herdeiro adulto o jogo continua")
	ok(s8["jogador"]["nome"] == "Edmund", "herdeiro assumiu")
	var s9 := Jogo.novo_jogo("I")
	Jogo.morrer(s9, "idade", Jogo.log_para(s9))
	ok(s9["fim"] != null and s9["fim"]["tipo"] == "derrota", "sem herdeiro = fim da linhagem")

	# ---------- simulação longa: 36 meses sem crash ----------
	var s10 := Jogo.novo_jogo("J")
	s10["jogador"]["ouro"] = 5000
	s10["jogador"]["renome"] = 30
	Jogo.comprar_terra(s10)
	for i in 36:
		s10["evento_pendente"] = null  # auto-resolve eventos para o teste
		Jogo.passar_mes(s10)
	ok(s10["ano"] >= 3, "36 meses simulados (ano %d)" % s10["ano"])
	ok(s10["cronica"].size() > 0, "crônica registrou eventos")

	# ---------- conquista ----------
	var s11 := Jogo.novo_jogo("K")
	s11["jogador"]["tropas"] = {"campones": 0, "lanceiro": 60, "arqueiro": 40, "cavaleiro": 20}
	s11["jogador"]["equip"] = 3
	s11["casus_belli"].append("touros")
	var rg := Intriga.declarar_guerra(s11, "touros", Jogo.log_para(s11))
	ok(rg["vitoria"] and s11["jogador"]["rei_de"] == "touros", "conquista com exército esmagador")

	# ---------- matriz de reação por personalidade (documento "Era do Aço") ----------
	# honrado (Ignis) não acumula: um insulto leve já é definitivo
	var sm1 := Jogo.novo_jogo("Matriz1")
	Dialogo.falar(sm1, sm1["reinos"][3]["rei"], "fraco")
	ok(Dialogo.tags_de(sm1, "rei_leoes")["relacao"] == -30,
		"insulto leve já é grave contra o honrado (Ignis)")

	# orgulhoso (Frederico, Bjorne) cai mais fundo que o padrão mesmo sem "grave"
	var sm2 := Jogo.novo_jogo("Matriz2")
	Dialogo.falar(sm2, sm2["reinos"][4]["rei"], "fraco")
	ok(Dialogo.tags_de(sm2, "rei_aguias")["relacao"] == -25,
		"insulto leve já cai -25 contra o orgulhoso (padrão seria -15)")

	# honrado (Ignis) trata ameaça como declaração de guerra de verdade
	var sm3 := Jogo.novo_jogo("Matriz3")
	Dialogo.falar(sm3, sm3["reinos"][3]["rei"], "vou te matar")
	var guerra_com_leoes := false
	for g in sm3["guerras"]:
		if (g["a"] == "leoes" and g["b"] == "jogador") or (g["b"] == "leoes" and g["a"] == "jogador"):
			guerra_com_leoes = true
	ok(guerra_com_leoes, "ameaçar o honrado (Ignis) declara guerra de verdade")

	# orgulhoso marca para morte na hora, não só quando a relação afunda
	var sm4 := Jogo.novo_jogo("Matriz4")
	Dialogo.falar(sm4, sm4["reinos"][1]["rei"], "vou te matar")
	ok(bool(Dialogo.tags_de(sm4, "rei_touros")["flags"].get("marcado_para_morte", false)),
		"ameaçar o orgulhoso (Bjorne) marca para morte na hora")

	# Felippe: ameaça arrisca prisão de verdade, OU rende renome na 1ª vez que
	# o jogador sai vivo — as duas ramificações são mutuamente exclusivas e
	# cobrem 100% dos casos, então uma chamada já basta
	var sm5 := Jogo.novo_jogo("Matriz5")
	Dialogo.falar(sm5, sm5["reinos"][0]["rei"], "vou te matar")
	ok(Jogo.esta_preso(sm5) or int(sm5["jogador"]["renome"]) > 0,
		"ameaçar Felippe arrisca prisão OU rende renome na 1ª vez")

	# suborno: Frederico falha por orgulho (não por honestidade — já coberto
	# noutro teste pelo Ignis); Bjorne ACEITA mas fica com rancor
	var ssb1 := Jogo.novo_jogo("Suborno1")
	ssb1["jogador"]["ouro"] = 500
	Dialogo.falar(ssb1, ssb1["reinos"][4]["rei"], "aceite este ouro, um presente")
	ok(int(ssb1["jogador"]["ouro"]) == 500, "suborno não custa ouro quando falha (Frederico)")
	ok(int(Dialogo.tags_de(ssb1, "rei_aguias")["relacao"]) < 0, "e a relação cai (orgulho ferido)")

	var ssb2 := Jogo.novo_jogo("Suborno2")
	ssb2["jogador"]["ouro"] = 500
	Dialogo.falar(ssb2, ssb2["reinos"][1]["rei"], "aceite este ouro, um presente")
	ok(int(ssb2["jogador"]["ouro"]) < 500, "Bjorne ACEITA o suborno — ele não tem luxo de recusar")
	ok(int(Dialogo.tags_de(ssb2, "rei_touros")["relacao"]) < 0,
		"mas a relação CAI mesmo aceitando — ele guarda rancor")

	# ---------- chantagem por rei (documento "Era do Aço", Parte 5) ----------
	# cooldown: 1x por rei por ano — a segunda tentativa falha mesmo com segredo novo
	var sc1 := Jogo.novo_jogo("Chant1")
	sc1["segredos"].append({"reino": "imperio", "usado": false})
	Intriga.chantagear(sc1, sc1["reinos"][0]["rei"])
	ok(sc1["chantagem_pendente"] != null, "primeira chantagem do ano abre a exigência")
	Intriga.resolver_chantagem(sc1, "casusbelli")
	sc1["segredos"].append({"reino": "imperio", "usado": false})
	var c1b := Intriga.chantagear(sc1, sc1["reinos"][0]["rei"])
	ok(c1b["efeitos"].has("[Chantagem esgotada este ano]"),
		"segunda chantagem ao mesmo rei no mesmo ano é recusada, mesmo com segredo novo")

	# Ignis: não paga nada, expõe o próprio segredo e marca para morte
	var sc2 := Jogo.novo_jogo("Chant2")
	sc2["segredos"].append({"reino": "leoes", "usado": false})
	Intriga.chantagear(sc2, sc2["reinos"][3]["rei"])
	ok(sc2["chantagem_pendente"] == null, "Ignis não abre exigência — resolve na hora")
	ok(int(Dialogo.tags_de(sc2, "rei_leoes")["relacao"]) == -60, "relação -60 com Ignis")
	ok(bool(Dialogo.tags_de(sc2, "rei_leoes")["flags"].get("marcado_para_morte", false)),
		"marcado para morte por tentar chantagear o honrado")
	ok(sc2["segredos"][0]["usado"], "segredo consumido mesmo sem pagamento")

	# Felippe: paga em ferro, do PRÓPRIO tesouro, e marca para morte mesmo pagando
	var sc3 := Jogo.novo_jogo("Chant3")
	Geopolitica.inicializar(sc3)
	sc3["segredos"].append({"reino": "imperio", "usado": false})
	var tesouro_antes_ch: int = int(Geopolitica.reino_por_id(sc3, "imperio")["tesouro"])
	Intriga.chantagear(sc3, sc3["reinos"][0]["rei"])
	Intriga.resolver_chantagem(sc3, "ouro")
	ok(int(Geopolitica.reino_por_id(sc3, "imperio")["tesouro"]) < tesouro_antes_ch,
		"o pagamento sai do tesouro REAL do Império")
	ok(int(sc3["carga"].get("ferro", 0)) > 0, "o jogador recebe ferro de verdade")
	ok(bool(Dialogo.tags_de(sc3, "rei_imperio")["flags"].get("marcado_para_morte", false)),
		"Felippe marca para morte mesmo pagando")

	# Bjorne: paga em força/tropas de verdade — ele não tem sobra de tesouro
	var sc4 := Jogo.novo_jogo("Chant4")
	Geopolitica.inicializar(sc4)
	sc4["segredos"].append({"reino": "touros", "usado": false})
	var forca_antes_ch: int = int(Geopolitica.reino_por_id(sc4, "touros")["forca"])
	Intriga.chantagear(sc4, sc4["reinos"][1]["rei"])
	Intriga.resolver_chantagem(sc4, "ouro")
	ok(int(Geopolitica.reino_por_id(sc4, "touros")["forca"]) < forca_antes_ch,
		"Bjorne perde força de verdade — é o exploit que a Parte 5 avisa")
	ok(int(sc4["carga"].get("pedra", 0)) > 0, "o jogador leva pedra como saque")

	# Frederico: nunca mais contrata — Contratos.gerar() para de sorteá-lo
	var sc5 := Jogo.novo_jogo("Chant5")
	Geopolitica.inicializar(sc5)
	sc5["segredos"].append({"reino": "aguias", "usado": false})
	Intriga.chantagear(sc5, sc5["reinos"][4]["rei"])
	Intriga.resolver_chantagem(sc5, "ouro")
	ok(bool(Dialogo.tags_de(sc5, "rei_aguias")["flags"].get("nunca_mais_contrata", false)),
		"Frederico jura nunca mais contratar")
	var apareceu_aguias := false
	for tentativa in 40:
		for c in Contratos.gerar(sc5):
			if c["contratante"] == "aguias":
				apareceu_aguias = true
	ok(not apareceu_aguias, "e some do sorteio de contratante de verdade")

	# Eva: contra-ataca na mesma moeda — custa renome ao jogador
	var sc6 := Jogo.novo_jogo("Chant6")
	sc6["jogador"]["renome"] = 50
	Geopolitica.inicializar(sc6)
	sc6["segredos"].append({"reino": "rosa", "usado": false})
	Intriga.chantagear(sc6, sc6["reinos"][5]["rei"])
	Intriga.resolver_chantagem(sc6, "ouro")
	ok(int(sc6["jogador"]["renome"]) == 40, "Eva planta intriga — renome -10")

	# pagamento parcial dobra a queda de relação (Trava 4): o teto é
	# fotografado NA AMEAÇA (tesouro normal), e o reino se arruína antes de
	# pagar (guerra, upkeep, os meses passando) — paga só o que sobrou
	var sc7 := Jogo.novo_jogo("Chant7")
	Geopolitica.inicializar(sc7)
	Geopolitica.reino_por_id(sc7, "alvorecer")["tesouro"] = 500
	sc7["segredos"].append({"reino": "alvorecer", "usado": false})
	Intriga.chantagear(sc7, sc7["reinos"][2]["rei"])
	Geopolitica.reino_por_id(sc7, "alvorecer")["tesouro"] = 1
	var rel_antes_pagto := int(Dialogo.tags_de(sc7, "rei_alvorecer")["relacao"])
	Intriga.resolver_chantagem(sc7, "ouro")
	ok(int(Dialogo.tags_de(sc7, "rei_alvorecer")["relacao"]) == rel_antes_pagto - 20,
		"tesouro esvaziado antes de pagar: paga o que tem e a queda de relação DOBRA")

	# e o CASO NORMAL — paga o teto inteiro — cai só a metade disso (-10)
	var sc7b := Jogo.novo_jogo("Chant7b")
	Geopolitica.inicializar(sc7b)
	sc7b["segredos"].append({"reino": "alvorecer", "usado": false})
	Intriga.chantagear(sc7b, sc7b["reinos"][2]["rei"])
	var rel_antes_pagto_b := int(Dialogo.tags_de(sc7b, "rei_alvorecer")["relacao"])
	Intriga.resolver_chantagem(sc7b, "ouro")
	ok(int(Dialogo.tags_de(sc7b, "rei_alvorecer")["relacao"]) == rel_antes_pagto_b - 10,
		"pagamento cheio: a queda extra é só -10, não dobrada")

	# Ignis paga o dobro em contrato, Frederico paga 30% a mais (Parte 4)
	var sc8 := Jogo.novo_jogo("Contrato1")
	sc8["jogador"]["tropas"] = {"espadachim": 500}
	sc8["jogador"]["equip"] = 3
	var contrato_leoes := {"id": "escolta", "nome": "teste", "forca": 1,
		"pagamento": 100, "renome": 5, "contratante": "leoes", "alvo": ""}
	var ouro_antes_c := int(sc8["jogador"]["ouro"])
	Contratos.executar(sc8, contrato_leoes, Jogo.log_para(sc8))
	ok(int(sc8["jogador"]["ouro"]) == ouro_antes_c + 200, "Ignis paga o DOBRO do contrato combinado")

	var sc9 := Jogo.novo_jogo("Contrato2")
	sc9["jogador"]["tropas"] = {"espadachim": 500}
	sc9["jogador"]["equip"] = 3
	var contrato_aguias := {"id": "escolta", "nome": "teste", "forca": 1,
		"pagamento": 100, "renome": 5, "contratante": "aguias", "alvo": ""}
	var ouro_antes_c2 := int(sc9["jogador"]["ouro"])
	Contratos.executar(sc9, contrato_aguias, Jogo.log_para(sc9))
	ok(int(sc9["jogador"]["ouro"]) == ouro_antes_c2 + 130, "Frederico paga 30% a mais — o melhor contratante do mapa")

	# ---------- escada de acesso (documento "Era do Aço", Parte 2) ----------
	# Odiado: o guarda barra tudo, mesmo pedido banal — e o texto ameaça prisão
	var sa1 := Jogo.novo_jogo("Acesso1")
	Dialogo.tags_de(sa1, "rei_touros")["relacao"] = -80
	var qa1 := Dialogo.quem_atende(sa1, "touros")
	ok(qa1["papel"] == "guarda", "Odiado: quem atende é o guarda, nunca o rei")
	var ra1 := Dialogo.falar(sa1, qa1, "quanto custa o trigo?")
	ok(ra1["resposta"].contains("cadeia"), "Odiado: recusa até um pedido banal, com ameaça de prisão")

	# insultar/ameaçar continua valendo mesmo com o portão fechado — é ação
	# do jogador, não um favor pedido
	var sa1b := Jogo.novo_jogo("Acesso1b")
	Dialogo.tags_de(sa1b, "rei_touros")["relacao"] = -80
	var qa1b := Dialogo.quem_atende(sa1b, "touros")
	Dialogo.falar(sa1b, qa1b, "seu porco idiota")
	ok(int(Dialogo.tags_de(sa1b, "rei_touros")["relacao"]) < -80,
		"mas insultar o guarda ainda derruba a relação com o reino inteiro")

	# Hostil com renome baixo: mesma recusa do guarda
	var sa2 := Jogo.novo_jogo("Acesso2")
	Dialogo.tags_de(sa2, "rei_touros")["relacao"] = -30
	sa2["jogador"]["renome"] = 10
	var qa2 := Dialogo.quem_atende(sa2, "touros")
	ok(qa2["papel"] == "guarda" and qa2["intencoes_permitidas"] == [],
		"Hostil com renome baixo: guarda recusa tudo")

	# Hostil com renome ≥50: o guarda "anuncia" — libera o pedido, mas
	# continua sendo ELE quem responde, não o rei
	var sa3 := Jogo.novo_jogo("Acesso3")
	Dialogo.tags_de(sa3, "rei_touros")["relacao"] = -30
	sa3["jogador"]["renome"] = 60
	var qa3 := Dialogo.quem_atende(sa3, "touros")
	ok(qa3["papel"] == "guarda" and qa3["intencoes_permitidas"] == null,
		"Hostil com renome ≥50: ainda o guarda, mas sem restrição de intenção")
	var ra3 := Dialogo.falar(sa3, qa3, "conte-me sobre a guerra")
	ok(not ra3["resposta"].contains("Isso não é comigo"), "e o pedido passa de verdade")

	# Neutro sem título: guarda, intenções bem curtas
	var sa4 := Jogo.novo_jogo("Acesso4")
	var qa4 := Dialogo.quem_atende(sa4, "touros")
	ok(qa4["papel"] == "guarda" and qa4["intencoes_permitidas"] == ["perguntar_preco"],
		"Neutro sem título: guarda, só pergunta de preço")
	var ra4 := Dialogo.falar(sa4, qa4, "quero um contrato de trabalho")
	ok(ra4["resposta"].contains("coroa"), "contrato é negado pelo guarda sem título")

	# Neutro com título (Capitão Mercenário+): rei em pessoa, mas seco e limitado
	var sa5 := Jogo.novo_jogo("Acesso5")
	sa5["jogador"]["renome"] = 50
	var qa5 := Dialogo.quem_atende(sa5, "touros")
	ok(qa5["papel"] == "rei", "Neutro com título ≥ Capitão Mercenário: o rei atende em pessoa")
	ok((qa5["intencoes_permitidas"] as Array).has("pedir_contrato")
		and not (qa5["intencoes_permitidas"] as Array).has("pedir_paz"),
		"mas só pra intenções liberadas — paz continua fora de alcance")

	# Amistoso e Leal: rei sem restrição alguma
	var sa6 := Jogo.novo_jogo("Acesso6")
	Dialogo.tags_de(sa6, "rei_touros")["relacao"] = 30
	var qa6 := Dialogo.quem_atende(sa6, "touros")
	ok(qa6["papel"] == "rei" and qa6["intencoes_permitidas"] == null,
		"Amistoso: rei em pessoa, todas as intenções")

	var sa7 := Jogo.novo_jogo("Acesso7")
	Dialogo.tags_de(sa7, "rei_touros")["relacao"] = 65
	var qa7 := Dialogo.quem_atende(sa7, "touros")
	var ra7 := Dialogo.falar(sa7, qa7, "quero saber dos preços por aqui")
	ok(ra7["efeitos"].has("[Leal: ele compartilha algo sem você precisar perguntar]"),
		"Leal: o rei oferece informação extra sem ser perguntado")

	# Parte 7, risco 5: rei conquistado por OUTRO reino não dá audiência —
	# nem o guarda dele. Conquistado pelo JOGADOR é um caso diferente (o
	# trono é dele agora) e não entra nesse bloqueio.
	var sa8 := Jogo.novo_jogo("Acesso8")
	Dialogo.tags_de(sa8, "rei_touros")["relacao"] = 80  # bem além de Leal
	for r in sa8["reinos"]:
		if r["id"] == "touros":
			r["dominado_por"] = "imperio"
	var qa8 := Dialogo.quem_atende(sa8, "touros")
	ok(qa8["papel"] == "conquistado", "reino conquistado por outro reino não tem mais rei nem guarda")
	var ra8 := Dialogo.falar(sa8, qa8, "quero um contrato de trabalho")
	ok(ra8["resposta"].contains("Império Central"), "a recusa nomeia quem tomou o trono")

	var sa9 := Jogo.novo_jogo("Acesso9")
	for r in sa9["reinos"]:
		if r["id"] == "touros":
			r["dominado_por"] = "jogador"
	var qa9 := Dialogo.quem_atende(sa9, "touros")
	ok(qa9["papel"] != "conquistado", "mas conquistado PELO jogador não bloqueia — o trono é dele agora")

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
