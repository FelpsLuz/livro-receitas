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
const Equipar = preload("res://scripts/equipar.gd")
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
	#
	# Este teste se anunciava assim e NÃO media isso: ele montava um exército
	# oito vezes maior e verificava que ele venceu — o que aconteceria com
	# qualquer formação, inclusive nenhuma, porque `combate.gd` não lia o
	# campo. O triângulo estava escrito em `Dados.FORMACOES`, prometido em
	# três botões da aba Tropas, e ausente do motor.
	var s5 := Jogo.novo_jogo("E")
	s5["jogador"]["tropas"] = {"campones": 0, "lanceiro": 30, "arqueiro": 20, "cavaleiro": 5}
	s5["jogador"]["formacao"] = "linha"
	var inimigo := {"tropas": {"lanceiro": 5}, "equip": 0, "formacao": "cunha"}
	var rel_bat := Combate.batalhar(s5, inimigo, "teste")
	ok(rel_bat["vitoria"], "exército forte vence escaramuça")
	ok(rel_bat["baixas_inimigo"] > 0, "baixas inimigas registradas")

	# ---- o triângulo, agora medido de verdade ----
	ok(Combate.fator_formacao("linha", "cunha") > 1.0
		and Combate.fator_formacao("cunha", "cerco") > 1.0
		and Combate.fator_formacao("cerco", "linha") > 1.0,
		"o triângulo fecha: linha vence cunha, cunha vence cerco, cerco vence linha")
	ok(Combate.fator_formacao("cunha", "linha") < 1.0,
		"e quem escolhe errado PAGA, não só deixa de ganhar")
	ok(is_equal_approx(Combate.fator_formacao("linha", "linha"), 1.0)
		and is_equal_approx(Combate.fator_formacao("linha", ""), 1.0),
		"formação igual, ou desconhecida, não move nada")
	# a batalha inteira carrega o resultado para o relatório: uma vantagem
	# que o jogador não consegue LER depois é uma que ele não aprende a usar
	ok(str(rel_bat.get("formacao", "")) == "linha"
		and str(rel_bat.get("formacao_inimigo", "")) == "cunha"
		and float(rel_bat.get("vantagem_formacao", 0.0)) > 1.0,
		"o relatório de batalha diz qual formação encontrou qual")
	ok(str(rel_bat.get("resumo", "")).contains("formação era a certa"),
		"e o texto do relatório explica o bônus em vez de só aplicá-lo")

	# ---- o espião e o campo têm que CONCORDAR ----
	#
	# A formação de um reino é derivada de (id, mês, ano), e não sorteada, por
	# causa disto: o relatório de 80 de ouro apontaria uma doutrina e o campo
	# mostraria outra. Também muda todo mês, que é o prazo de validade da
	# informação comprada.
	var s_esp := Jogo.novo_jogo("Espião")
	var f_mes1: String = Combate.formacao_do_reino(s_esp, "touros")
	ok(f_mes1 == Combate.formacao_do_reino(s_esp, "touros"),
		"a formação do reino é estável dentro do mês")
	var mudou_algum := false
	for m in range(1, 13):
		s_esp["mes"] = m
		if Combate.formacao_do_reino(s_esp, "touros") != f_mes1:
			mudou_algum = true
	ok(mudou_algum, "e muda ao longo do ano — o relatório do espião vence")

	# ---- EQUIPAMENTO: um sistema só, e um botão que o move ----
	#
	# Havia dois: o contador `jogador.equip` de 0 a 3, exibido no Quartel e
	# lido pelo combate, que NENHUM botão movia; e a tabela por unidade da
	# Ferraria, que funcionava e não tinha contador.
	var s_eq := Jogo.novo_jogo("Ferreiro")
	s_eq["jogador"]["tropas"] = {"lanceiro": 10}
	s_eq["jogador"]["ouro"] = 5000
	ok(Equipar.nivel_do_exercito(s_eq) == 0, "exército sem aço começa em 0/3")
	var forca_antes := Combate.bonus_de(s_eq, s_eq["jogador"]["tropas"], 100)
	var r_eq: Dictionary = Jogo.melhorar_equip(s_eq)
	ok(bool(r_eq.get("ok", false)),
		"o botão de vestir o exército responde: %s" % str(r_eq.get("msg", "")))
	# a bigorna leva tempo — o degrau não sobe no mesmo instante
	Equipar.avancar(s_eq, 9999)
	ok(Equipar.nivel_do_exercito(s_eq) == 1,
		"e depois da forja o contador SAI de zero (%d/3)"
			% Equipar.nivel_do_exercito(s_eq))
	ok(Combate.bonus_de(s_eq, s_eq["jogador"]["tropas"], 100) > forca_antes,
		"o degrau novo vale força de verdade no combate")

	# ---- A PRESSÃO DA VILA passou a ser lida ----
	#
	# Ignorar o cidadão ambicioso somava 15 de pressão com o texto "ele
	# sorriu, e isso foi pior". Mecanicamente era MELHOR: nenhuma linha do
	# projeto consultava o campo, e havia até um sinal declarado sem emissor.
	var Cidadaos_p = load("res://scripts/cidadaos.gd")
	var s_pr := Jogo.novo_jogo("Pressionado")
	s_pr["terra"] = {"nome": "Vila Teste", "nivel": 2, "populacao": 40,
		"alimento": 200, "madeira": 50, "felicidade": 70, "pressao": 0.0}
	var log_pr := Jogo.log_para(s_pr)
	# abaixo de 40 ela esfria sozinha
	s_pr["terra"]["pressao"] = 20.0
	Cidadaos_p.tick(s_pr, log_pr)
	ok(Cidadaos_p.pressao(s_pr) < 20.0,
		"pressão baixa esfria sozinha (%.0f)" % Cidadaos_p.pressao(s_pr))
	# na faixa do meio ela já custa felicidade
	s_pr["terra"]["pressao"] = 55.0
	var fel_pr: int = int(s_pr["terra"]["felicidade"])
	Cidadaos_p.tick(s_pr, log_pr)
	ok(int(s_pr["terra"]["felicidade"]) < fel_pr,
		"pressão média já cobra felicidade todo mês")
	# no teto ela vira EVENTO, não rolagem escondida
	s_pr["terra"]["pressao"] = 80.0
	s_pr["evento_pendente"] = null
	Cidadaos_p.tick(s_pr, log_pr)
	ok(s_pr["evento_pendente"] != null
		and str(s_pr["evento_pendente"]["tipo"]) == "exigencia_notaveis",
		"acima de 70 os notáveis exigem, e é o jogador que decide")
	# ceder gasta ouro e zera; peitar mantém o cofre e o problema volta
	var ouro_pr: int = int(s_pr["jogador"]["ouro"])
	var r_ceder: Dictionary = Cidadaos_p.resolver_exigencia(s_pr, true, log_pr)
	ok(bool(r_ceder.get("ok", false)) and int(s_pr["jogador"]["ouro"]) < ouro_pr
		and Cidadaos_p.pressao(s_pr) == 0.0,
		"ceder custa ouro e zera a pressão")
	s_pr["terra"]["pressao"] = 80.0
	s_pr["evento_pendente"] = null
	Cidadaos_p.tick(s_pr, log_pr)
	var ouro_pr2: int = int(s_pr["jogador"]["ouro"])
	var fel_pr2: int = int(s_pr["terra"]["felicidade"])
	Cidadaos_p.resolver_exigencia(s_pr, false, log_pr)
	ok(int(s_pr["jogador"]["ouro"]) == ouro_pr2
		and int(s_pr["terra"]["felicidade"]) < fel_pr2
		and Cidadaos_p.pressao(s_pr) >= 70.0,
		"peitar não custa ouro, custa felicidade — e eles voltam")

	# ============================================================
	# LIVRO-RAZÃO — o mês deixa de ser caixa-preta
	#
	# O terceiro clique roda vinte e um passos e o jogador via só o
	# resultado. O projeto já tinha a regra escrita ("a virada nunca pode
	# ser surpresa") e a aplicava só no TEXTO do botão.
	# ============================================================
	print("\n=== O LIVRO-RAZÃO ===")
	var Livro_t = load("res://scripts/livro.gd")
	var s_lv := Jogo.novo_jogo("Contador")
	s_lv["terra"] = {"nome": "Vila Livro", "nivel": 2, "populacao": 40,
		"alimento": 300, "madeira": 80, "felicidade": 70, "pressao": 0.0}
	s_lv["jogador"]["ouro"] = 3000

	# ---- a PREVISÃO não pode tocar no estado ----
	var antes_lv: String = JSON.stringify(s_lv)
	var prev: Dictionary = Livro_t.previsao(s_lv)
	ok(JSON.stringify(s_lv) == antes_lv,
		"a previsão do mês NÃO escreve no estado")
	ok(not (prev.get("linhas", []) as Array).is_empty(),
		"e ela tem o que dizer: %d lançamentos previstos"
			% (prev.get("linhas", []) as Array).size())
	var tem_soldo := false
	var tem_imposto := false
	for l_p in prev["linhas"]:
		if str(l_p["motivo"]).contains("Soldo"):
			tem_soldo = true
		if str(l_p["motivo"]).contains("Imposto da vila"):
			tem_imposto = true
	ok(tem_soldo and tem_imposto,
		"a previsão traz o soldo E o imposto — as duas pontas do mês")

	# ---- o mês real bate com o que o livro registrou ----
	var ouro_lv: int = int(s_lv["jogador"]["ouro"])
	Jogo.passar_mes(s_lv)
	var bal: Dictionary = s_lv.get("ultimo_balanco", {})
	ok(not bal.is_empty(), "passar o mês fecha o livro e deixa o balanço pronto")
	var bloco_ouro: Dictionary = bal.get("ouro", {})
	ok(not (bloco_ouro.get("linhas", []) as Array).is_empty(),
		"o balanço tem linhas de ouro itemizadas")
	# a soma dos lançamentos tem que bater com o que o cofre de fato mudou
	var delta_real: int = int(s_lv["jogador"]["ouro"]) - ouro_lv
	ok(int(bloco_ouro.get("saldo", 0)) == delta_real,
		"e a soma do livro bate com o cofre (livro %d, cofre %d)"
			% [int(bloco_ouro.get("saldo", 0)), delta_real])
	# fechar o mês limpa os lançamentos e guarda o resumo
	ok((s_lv.get("livro", []) as Array).is_empty(),
		"os lançamentos do mês são zerados na virada")
	ok((s_lv.get("livro_meses", []) as Array).size() == 1,
		"e o mês fechado vira uma linha de histórico")

	# ---- telemetria ----
	for i in 4:
		Jogo.passar_mes(s_lv)
	var csv: String = Livro_t.csv(s_lv)
	ok(csv.begins_with("ano;mes;ouro_saldo"),
		"o CSV sai com cabeçalho")
	ok(csv.split("\n").size() == (s_lv["livro_meses"] as Array).size() + 1,
		"uma linha por mês fechado, mais o cabeçalho (%d meses)"
			% (s_lv["livro_meses"] as Array).size())
	# o histórico não pode crescer para sempre dentro do save
	ok(Livro_t.MESES_GUARDADOS <= 120,
		"o histórico tem teto — o save não vira arquivo de log")

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

	# ---- O ROSTO do guarda não é o rosto do rei ----
	#
	# O `id` do guarda é "rei_<reino>" DE PROPÓSITO: a simpatia ganha no
	# portão é simpatia da casa, e tem que ser a mesma chave que o rei
	# consulta lá dentro. Só que quem desenhava o retrato usava o mesmo
	# campo — e o monarca de coroa e arminho aparecia dizendo "não anuncio,
	# volte quando seu nome valer alguma coisa".
	#
	# `retrato` separa as duas coisas. As três asserções cobrem o contrato
	# inteiro: o guarda tem rosto próprio, a chave de relação NÃO mudou, e
	# quando a porta abre o rosto volta a ser o do rei.
	ok(str(qa4.get("retrato", "")) != "" and str(qa4["retrato"]) != str(qa4["id"]),
		"o guarda do portão tem rosto PRÓPRIO, não o do rei (retrato=%s · id=%s)"
			% [qa4.get("retrato", "(ausente)"), qa4["id"]])
	ok(str(qa4["id"]) == "rei_touros",
		"e a chave de relação continua a da casa — o portão dá simpatia ao rei")
	# o mesmo reino com título já conquistado: o rei atende, e o rosto
	# volta a ser o dele (sem campo `retrato`, o desenho cai no `id`)
	var s_rosto := Jogo.novo_jogo("Rosto")
	s_rosto["jogador"]["renome"] = 50
	var qa_rei := Dialogo.quem_atende(s_rosto, "touros")
	ok(str(qa_rei["papel"]) == "rei"
		and str(qa_rei.get("retrato", str(qa_rei["id"]))) == str(qa_rei["id"]),
		"quando o rei atende em pessoa, o rosto volta a ser o dele")
	var Retratos = load("res://scripts/retratos.gd")
	var tex_guarda: Texture2D = Retratos.textura(str(qa4["retrato"]))
	var tex_rei: Texture2D = Retratos.textura("rei_touros")
	ok(tex_guarda != null and tex_rei != null
		and tex_guarda.get_image().get_data() != tex_rei.get_image().get_data(),
		"e as duas artes são de fato diferentes em disco")
	# o rosto do portão é sorteado entre dois veteranos pelo id do reino:
	# a arte tem que existir para QUALQUER reino, não só para o testado
	var faltando_guarda: Array[String] = []
	for rid in ["imperio", "touros", "leoes", "aguias", "rosa", "alvorecer"]:
		var q_r: Dictionary = Dialogo.quem_atende(Jogo.novo_jogo("R"), rid)
		if Retratos.textura(str(q_r.get("retrato", ""))) == null:
			faltando_guarda.append(rid)
	ok(faltando_guarda.is_empty(),
		"todo portão tem rosto em disco (sem arte: %s)"
			% ("nenhum" if faltando_guarda.is_empty() else ", ".join(faltando_guarda)))

	# ============================================================
	# A DIPLOMACIA É PRESENCIAL
	#
	# O furo mais grave da auditoria: `_reino_local()` devolvia o Império
	# quando o jogador não estava em nenhum dos seis reinos, e a aba Corte
	# entregava a conversa com Felippe no meio das Terras Bárbaras. Dali dava
	# para chantageá-lo, subornar o portão dele, casar na casa dele e mediar
	# a paz dele — à distância, num jogo em que todo o resto exige presença.
	#
	# A tranca da interface (a aba Corte) não dá para testar aqui, porque é
	# cena. O que dá — e é a tranca que vale para qualquer porta futura — é
	# a de `Dialogo.falar`.
	# ============================================================
	print("\n=== A DIPLOMACIA É PRESENCIAL ===")
	var s_pres := Jogo.novo_jogo("Ausente")
	s_pres["local"] = "barbaros"                  # fora dos seis reinos
	var rei_pres: Dictionary = Dialogo.quem_atende(s_pres, "touros")
	Dialogo.tags_de(s_pres, "rei_touros")["relacao"] = 80
	var ouro_pres: int = int(s_pres["jogador"]["ouro"])
	# As frases são escolhidas para cair numa intenção SÓ. "eu juro lealdade
	# a você, meu rei" empata jurar_lealdade com saudação (por causa do "meu
	# rei") e a saudação vence o desempate — o guarda estaria certo em deixar
	# passar, e o teste é que estaria medindo a coisa errada.
	for frase in ["quero propor casamento com sua filha",
			"te dou ouro para abrir o portão",
			"juro lealdade a esta casa"]:
		var rp: Dictionary = Dialogo.falar(s_pres, rei_pres, frase)
		ok(str(rp["resposta"]).contains("na minha frente"),
			"de longe, '%s' é recusada com o convite de vir em pessoa" % frase.substr(0, 24))
	ok(int(s_pres["jogador"]["ouro"]) == ouro_pres,
		"e nenhuma delas mexeu no cofre")
	var Vassalagem_p = load("res://scripts/vassalagem.gd")
	ok(not Vassalagem_p.e_vassalo(s_pres),
		"jurar lealdade por recado não sela juramento nenhum")
	# e o contrário: as intenções que SEMPRE puderam viajar continuam viajando
	var r_elogio: Dictionary = Dialogo.falar(s_pres, rei_pres, "você é um grande rei")
	ok(not str(r_elogio["resposta"]).contains("na minha frente"),
		"elogio continua passando de longe — recado sempre existiu")

	# ============================================================
	# A CONVERSA DEIXOU DE SER FÁBRICA DE RENOME
	# ============================================================
	print("\n=== A CONVERSA NÃO IMPRIME MAIS RENOME ===")
	var s_farm := Jogo.novo_jogo("Bajulador")
	var rei_farm: Dictionary = Dialogo.quem_atende(s_farm, str(s_farm["local"]))
	for i in 30:
		Dialogo.falar(s_farm, rei_farm, "você é magnífico, meu senhor")
	var rel_farm: int = int(Dialogo.tags_de(s_farm, rei_farm["id"])["relacao"])
	ok(rel_farm < 60,
		"trinta elogios não chegam à relação 60 (deu %d)" % rel_farm)
	var rel_antes_s: int = int(Dialogo.tags_de(s_farm, rei_farm["id"])["relacao"])
	for i in 10:
		Dialogo.falar(s_farm, rei_farm, "olá")
	ok(int(Dialogo.tags_de(s_farm, rei_farm["id"])["relacao"]) - rel_antes_s <= 3,
		"e dez saudações rendem no máximo três de cortesia")

	# a mediação de paz: vale sempre, mas o RENOME é uma vez por casa
	var s_paz := Jogo.novo_jogo("Mediador")
	var alvo_paz: String = str(s_paz["local"])
	Dialogo.tags_de(s_paz, "rei_" + alvo_paz)["relacao"] = 60
	var rei_paz: Dictionary = Dialogo.quem_atende(s_paz, alvo_paz)
	var renome_0: int = int(s_paz["jogador"]["renome"])
	var guerras_encerradas := 0
	for i in 3:
		s_paz["guerras"] = [{"a": alvo_paz, "b": "aguias", "meses": 4}]
		Dialogo.falar(s_paz, rei_paz, "venho pedir paz entre vocês")
		if (s_paz["guerras"] as Array).is_empty():
			guerras_encerradas += 1
	ok(guerras_encerradas == 3,
		"mediar continua encerrando a guerra todas as vezes")
	ok(int(s_paz["jogador"]["renome"]) - renome_0 == 15,
		"mas o renome sai UMA vez por casa (ganhou %d)"
			% (int(s_paz["jogador"]["renome"]) - renome_0))

	# ============================================================
	# O CHEAT SAIU E NÃO PODE VOLTAR
	# ============================================================
	ok(not ("CAMAFEUS" in Dialogo),
		"a tabela de códigos de teste não existe mais em Dialogo")

	# ============================================================
	# A INIMIZADE MORDE QUEM AGE
	#
	# `Jogo.passar_dia` tem sete chamadores e só o botão lia o retorno. O
	# acontecimento agora fica parado numa fila no estado, e a interface a
	# drena depois de qualquer ação.
	# ============================================================
	print("\n=== A INIMIZADE ALCANÇA QUEM AGE ===")
	var s_ini := Jogo.novo_jogo("Caçado")
	s_ini["guerras"] = [{"a": "jogador", "b": "touros", "meses": 1}]
	s_ini["local"] = "touros"                 # capital inimiga: 75% ao dia
	seed(99)
	var achou_fila := false
	for i in 12:
		s_ini["dia"] = 1
		Jogo.passar_dia(s_ini)                # sem ninguém ler o retorno
		if not (s_ini.get("inimizade_fila", []) as Array).is_empty():
			achou_fila = true
			break
	ok(achou_fila,
		"o acontecimento fica no estado mesmo quando o chamador ignora o retorno")
	var ev_ini: Dictionary = Jogo.puxar_inimizade(s_ini)
	ok(not ev_ini.is_empty() and str(ev_ini.get("tipo", "")) != "",
		"e a interface consegue puxá-lo da fila")
	ok((s_ini.get("inimizade_fila", []) as Array).is_empty(),
		"puxar esvazia — o mesmo encontro não abre dois modais")
	ok(Jogo.puxar_inimizade(s_ini).is_empty(),
		"e a fila vazia devolve vazio, sem quebrar")

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
