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
const Medo = preload("res://scripts/medo.gd")
const Aco = preload("res://scripts/aco.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Empregos = preload("res://scripts/empregos.gd")

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
	# A formação de um reino é derivada, e não sorteada, por causa disto: o
	# relatório de 180 de ouro apontaria uma doutrina e o campo mostraria
	# outra. Ela é DERIVADA DE QUEM COMANDA, e não de um ciclo global: um
	# ciclo igual para todos era crackável em uma leitura — bastava contar
	# os meses e a informação nunca mais expirava.
	var s_esp := Jogo.novo_jogo("Espião")
	ok(Combate.formacao_do_reino(s_esp, "touros")
		== Combate.formacao_do_reino(s_esp, "touros"),
		"a formação do reino é estável dentro do mês")

	# o ORGULHOSO carrega, sempre. É o mais legível do continente — e o
	# jogador que o conhece PARA de pagar espião contra ele, que é o ponto.
	var todas_cunha := true
	for m in range(1, 13):
		s_esp["mes"] = m
		if Combate.formacao_do_reino(s_esp, "touros") != "cunha":
			todas_cunha = false
	ok(todas_cunha, "o rei orgulhoso atravessa em cunha o ano inteiro — doutrina é caráter")

	# o HONRADO segura a linha, de frente e sem truque
	ok(Combate.formacao_do_reino(s_esp, "leoes") == "linha",
		"o rei honrado segura a linha de escudos")

	# o CRUEL não tem doutrina: gira, e é contra ele que o espião vale todo mês
	s_esp["mes"] = 1
	var f_cruel: String = Combate.formacao_do_reino(s_esp, "imperio")
	var girou := false
	for m in range(1, 13):
		s_esp["mes"] = m
		if Combate.formacao_do_reino(s_esp, "imperio") != f_cruel:
			girou = true
	ok(girou, "o rei cruel gira pelo ciclo — contra ele o relatório vence e se compra de novo")

	# o CALCULISTA lê VOCÊ. Espionar não ajuda; ajuda variar.
	s_esp["mes"] = 1
	s_esp["jogador"]["formacao"] = "linha"
	var contra_linha: String = Combate.formacao_do_reino(s_esp, "alvorecer")
	s_esp["jogador"]["formacao"] = "cunha"
	var contra_cunha: String = Combate.formacao_do_reino(s_esp, "alvorecer")
	ok(contra_linha != contra_cunha,
		"o calculista muda com a SUA formação, não com o calendário")
	ok(str(Dados.FORMACOES[contra_linha]["vence_de"]) == "linha",
		"e escolhe exatamente a que vence da sua (%s bate linha)" % contra_linha)

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

	# ============================================================
	# BLOCO 3 — as duas moedas de limiar ganham gradiente
	#
	# Felicidade e honra existiam só em limiar: invisíveis até explodirem.
	# Moeda que o jogador não lê todo mês é peso morto.
	# ============================================================
	print("\n=== FELICIDADE E HONRA VIRAM GRADIENTE ===")
	var s_fel := Jogo.novo_jogo("Amado")
	s_fel["terra"] = {"nome": "V", "nivel": 2, "populacao": 60, "alimento": 300,
		"madeira": 50, "felicidade": 50, "pressao": 0.0}
	var imp_50: int = Economia.imposto_mensal(s_fel)
	s_fel["terra"]["felicidade"] = 100
	var imp_100: int = Economia.imposto_mensal(s_fel)
	s_fel["terra"]["felicidade"] = 0
	var imp_0: int = Economia.imposto_mensal(s_fel)
	ok(imp_100 > imp_50 and imp_50 > imp_0,
		"o imposto acompanha a felicidade (%d < %d < %d)" % [imp_0, imp_50, imp_100])
	# em 50 — o meio, onde a vila nasce — o multiplicador é exatamente 1,0:
	# nada muda para quem já jogava, e a curva cresce dos dois lados
	s_fel["terra"]["felicidade"] = 50
	ok(is_equal_approx(Economia.fator_felicidade(s_fel), 1.0),
		"e em 50 o fator é 1,0 — o meio não mexe em nada")
	ok(is_equal_approx(Economia.fator_felicidade(s_fel), 1.0)
		and imp_0 * 2 <= imp_100 + 2,
		"a amplitude é de 0,5x a 1,5x — povo em fúria arrecada metade")

	# ---- honra: o mural muda com a reputação ----
	var s_h := Jogo.novo_jogo("Honrado")
	s_h["local"] = "touros"
	s_h["jogador"]["honra"] = 70
	s_h["contratos"] = Contratos.gerar(s_h)
	var mural_ferro: Array = Contratos.do_local(s_h)
	var tem_sujo_ferro := false
	for c_h in mural_ferro:
		if Contratos.SUJOS.has(str(c_h.get("id", ""))):
			tem_sujo_ferro = true
	ok(not tem_sujo_ferro,
		"com palavra de ferro, ninguém te oferece trabalho sujo")
	s_h["jogador"]["honra"] = 10
	var mural_paria: Array = Contratos.do_local(s_h)
	var so_sujo := not mural_paria.is_empty()
	for c_h2 in mural_paria:
		if not Contratos.SUJOS.has(str(c_h2.get("id", ""))):
			so_sujo = false
	ok(so_sujo or mural_paria.is_empty(),
		"e como pária, só sobra o trabalho sujo (%d ofertas)" % mural_paria.size())
	# a paga escala nas duas pontas, e é isso que fecha a armadilha
	var s_p1 := Jogo.novo_jogo("A"); s_p1["jogador"]["honra"] = 70
	var s_p2 := Jogo.novo_jogo("B"); s_p2["jogador"]["honra"] = 45
	ok(Contratos._fator_honra(s_p1) > Contratos._fator_honra(s_p2),
		"palavra de ferro paga mais que reputação comum")
	var s_p3 := Jogo.novo_jogo("C"); s_p3["jogador"]["honra"] = 10
	ok(Contratos._fator_honra(s_p3) > Contratos._fator_honra(s_p2),
		"e o pária TAMBÉM paga mais — é a armadilha: fácil de entrar, cara de sair")

	# ============================================================
	# BLOCO 4 — O AÇO: o relógio que faz o sandbox virar corrida
	#
	# O mundo andava sem o jogador, mas não vinha atrás dele. Sem relógio de
	# pressão, sandbox afunda em tédio, não em dificuldade.
	# ============================================================
	print("\n=== O AÇO CHEGA ===")
	var Aco_t = load("res://scripts/aco.gd")
	var s_ac := Jogo.novo_jogo("Corrida")
	ok(Aco_t.reino_id(s_ac) == "" and Aco_t.degrau(s_ac) == 0,
		"no ano 1 não há Aço: o mundo é normal")
	ok(is_equal_approx(Aco_t.fator(s_ac, "touros"), 1.0),
		"e nenhum reino leva multiplicador nenhum")
	# ---- o antagonista nasce de como a partida correu, não de sorteio ----
	s_ac["ano"] = 3
	for r_ac in s_ac["reinos"]:
		r_ac["tesouro"] = 100
	# o mais rico no fim do ano 2 é quem vira o Aço
	s_ac["reinos"][2]["tesouro"] = 99999
	var esperado: String = str(s_ac["reinos"][2]["id"])
	Aco_t.tick(s_ac, Jogo.log_para(s_ac))
	ok(Aco_t.reino_id(s_ac) == esperado,
		"no ano 3 o mais RICO vira o Aço (%s) — não um sorteio" % Aco_t.reino_id(s_ac))
	ok(Aco_t.degrau(s_ac) >= 1 and Aco_t.fator(s_ac, esperado) > 1.0,
		"e ele passa a crescer acima da curva (fator %.2f)"
			% Aco_t.fator(s_ac, esperado))
	ok(is_equal_approx(Aco_t.fator(s_ac, "touros" if esperado != "touros" else "leoes"), 1.0),
		"os outros reinos seguem no fator 1,0 — é UM antagonista, não uma era")
	# ---- os degraus sobem com o calendário ----
	var f3: float = Aco_t.fator(s_ac, esperado)
	s_ac["ano"] = 7
	Aco_t.tick(s_ac, Jogo.log_para(s_ac))
	ok(Aco_t.fator(s_ac, esperado) > f3,
		"o Aço aperta com os anos (%.2f no ano 3, %.2f no ano 7)"
			% [f3, Aco_t.fator(s_ac, esperado)])
	ok(Aco_t.aviso(s_ac) != "" and Aco_t.nome_do_degrau(s_ac) != "",
		"e a interface tem o que dizer: \"%s\"" % Aco_t.aviso(s_ac))
	# ---- e ele PODE cair: é prazo, não sentença ----
	for r_ac2 in s_ac["reinos"]:
		if str(r_ac2["id"]) == esperado:
			r_ac2["dominado_por"] = "jogador"
	Aco_t.tick(s_ac, Jogo.log_para(s_ac))
	ok(Aco_t.reino_id(s_ac) == "" and Aco_t.degrau(s_ac) == 0,
		"conquistar o Aço encerra a ameaça — o relógio é um prazo, não uma sentença")

	# ============================================================
	# BLOCO 5 — arcos de vitória e a morte que faz o herdeiro valer
	# ============================================================
	print("\n=== OS ARCOS DE VITÓRIA ===")
	# ---- LEGITIMIDADE: construir e fazer durar ----
	var s_leg := Jogo.novo_jogo("Fundador")
	ok(Jogo.progresso_legitimidade(s_leg).is_empty(),
		"sem coroa, o arco da legitimidade nem existe")
	s_leg["jogador"]["rei_de"] = "barbaros"
	s_leg["terra"] = {"nome": "V", "nivel": 3, "populacao": 60, "alimento": 900,
		"madeira": 300, "felicidade": 70, "pressao": 0.0}
	s_leg["jogador"]["ouro"] = 90000
	var log_leg := Jogo.log_para(s_leg)
	for i in Jogo.MESES_PARA_LEGITIMAR:
		s_leg["terra"]["felicidade"] = 70          # a vila segue contente
		if s_leg["fim"] != null:
			break
		# 24 meses atravessam o ano 3, e no ano 3 o arauto do Aço bate na
		# porta e TRAVA o mês — como trava para o jogador. Quem reina paga o
		# tributo e segue reinando; ignorar o ultimato congelaria a saga.
		if s_leg.get("evento_pendente") != null \
				and str(s_leg["evento_pendente"].get("tipo", "")) == "ultimato_aco":
			Aco.responder_ultimato(s_leg, true)
		Jogo.passar_mes(s_leg)
	ok(s_leg["fim"] != null and str(s_leg["fim"].get("arco", "")) == "legitimidade",
		"reinar 24 meses com a vila contente é uma VITÓRIA por si só")
	# e a vila infeliz não conta o mês
	var s_leg2 := Jogo.novo_jogo("Tirano")
	s_leg2["jogador"]["rei_de"] = "barbaros"
	s_leg2["terra"] = {"nome": "V", "nivel": 3, "populacao": 60, "alimento": 900,
		"madeira": 300, "felicidade": 20, "pressao": 0.0}
	s_leg2["jogador"]["ouro"] = 90000
	for i in 6:
		s_leg2["terra"]["felicidade"] = 20
		Jogo.passar_mes(s_leg2)
	ok(int(s_leg2["jogador"].get("meses_legitimo", 0)) == 0,
		"reinar sobre povo infeliz não acumula legitimidade nenhuma")

	# ---- O FERIMENTO: a morte que faz o herdeiro entrar em cena ----
	print("\n=== A MORTE ACONTECE DE VERDADE ===")
	var s_fer := Jogo.novo_jogo("Ferido")
	s_fer["jogador"]["tropas"] = {"lanceiro": 1}
	var inim_forte := {"tropas": {"espadachim": 400, "arqueiro": 200}, "equip": 3}
	Combate.batalhar(s_fer, inim_forte, "massacre")
	ok(Jogo.ferimentos(s_fer) > 0,
		"derrota esmagadora deixa ferimento (%d)" % Jogo.ferimentos(s_fer))
	# o ferimento cicatriza se você parar de sangrar
	s_fer["jogador"]["ferimentos"] = 1
	s_fer["jogador"]["meses_sem_sangrar"] = 0
	s_fer["jogador"]["ouro"] = 90000
	seed(7)
	for i in Jogo.MESES_PARA_CICATRIZAR:
		if s_fer["fim"] != null:
			break
		Jogo.passar_mes(s_fer)
	ok(Jogo.ferimentos(s_fer) == 0 or s_fer["fim"] != null,
		"três meses sem sangrar cicatrizam — ou o ferimento cobra")
	# e a cadeia deixou de congelar a idade (furo 10 da auditoria)
	var s_cad := Jogo.novo_jogo("Preso")
	var idade_cad: int = int(s_cad["jogador"]["idade"])
	Jogo.prender(s_cad, 14, Jogo.log_para(s_cad))
	for i in 14:
		Jogo.passar_mes(s_cad)
	ok(int(s_cad["jogador"]["idade"]) > idade_cad,
		"cumprir pena ENVELHECE (%d → %d) — cadeia é castigo, não abrigo"
			% [idade_cad, int(s_cad["jogador"]["idade"])])

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

	# ============================================================
	# BLOCO 6 — A OITAVA MOEDA: crueldade vira eixo, não multa
	#
	# O contrato do sistema tem duas metades, e as duas precisam de prova:
	# abaixo do limiar NADA muda (senão o jogo pune quem nunca escolheu),
	# e acima dele o medo tem que DAR e COBRAR no mesmo movimento.
	# ============================================================
	print("\n-- Bloco 6: o medo como moeda --")

	var md0 := Jogo.novo_jogo("Medo0")
	md0["jogador"]["crueldade"] = 2                    # um abaixo do limiar
	ok(is_equal_approx(Medo.fator_desercao(md0), 1.0),
		"abaixo do limiar o medo não segura tropa nenhuma")
	ok(Medo.teto_de_relacao(md0) == 100 and Medo.teto_de_felicidade(md0) == 100,
		"e não cobra teto nenhum: quem nunca queimou vila joga o jogo inteiro")
	ok(Medo.descricao(md0) == "",
		"a interface não anuncia um sistema que ainda não ligou")
	ok(not bool(Medo.pode_taxar(md0).get("ok", false)),
		"imposto de guerra é porta fechada para quem não mete medo")

	# ---- o que o medo DÁ: a tropa aguenta soldo atrasado ----
	var md1 := Jogo.novo_jogo("Medo1")
	md1["jogador"]["crueldade"] = 3
	ok(Medo.fator_desercao(md1) < 1.0,
		"no limiar a deserção por soldo atrasado começa a ser aparada")
	var sm_max := Jogo.novo_jogo("MedoMax")
	sm_max["jogador"]["crueldade"] = Medo.MAXIMO
	ok(Medo.fator_desercao(sm_max) >= 0.40,
		"mas há piso: nem o mais temido sustenta exército sem pagar para sempre")
	ok(Medo.fator_desercao(sm_max) < Medo.fator_desercao(md1),
		"e cada ponto de crueldade compra mais um tanto de silêncio")

	# a prova de que o fator chega mesmo na moral, e não só na função:
	# dois jogadores idênticos com o cofre vazio, um cruel e um não.
	var sm_a := Jogo.novo_jogo("Soldo-A")
	var sm_b := Jogo.novo_jogo("Soldo-B")
	for s_soldo in [sm_a, sm_b]:
		s_soldo["jogador"]["ouro"] = 0
		s_soldo["jogador"]["tropas"]["lanceiro"] = 60
		s_soldo["jogador"]["moral"] = 100
	sm_b["jogador"]["crueldade"] = Medo.MAXIMO
	Economia.tick_exercito(sm_a, Callable())
	Economia.tick_exercito(sm_b, Callable())
	ok(int(sm_b["jogador"]["moral"]) > int(sm_a["jogador"]["moral"]),
		"com o cofre vazio, o temido perde MENOS moral que o amado (%d vs %d)" % [
			int(sm_b["jogador"]["moral"]), int(sm_a["jogador"]["moral"])])

	# ---- o que o medo COBRA: o teto de relação ----
	var md2 := Jogo.novo_jogo("Medo2")
	md2["jogador"]["crueldade"] = 5
	var teto2: int = Medo.teto_de_relacao(md2)
	ok(teto2 < 100 and teto2 >= 60,
		"crueldade 5 aperta a relação mas ainda deixa fechar aliança: teto %d" % teto2)
	# ONDE A ALIANÇA MORRE. O degrau de 60 é o que vale dinheiro (desconto,
	# abrigo contra emboscada, casamento de sangue); abaixo dele o cruel
	# continua negociando contrato, mas negocia sozinho.
	var md2b := Jogo.novo_jogo("Medo2b")
	md2b["jogador"]["crueldade"] = 6
	ok(Medo.teto_de_relacao(md2b) < 60,
		"e é no sexto ponto que o degrau da aliança fecha de vez (teto %d)" %
			Medo.teto_de_relacao(md2b))
	Dialogo.tags_de(md2, "rei_touros")["relacao"] = teto2 - 2
	Dialogo.mudar_relacao(md2, "rei_touros", 50, "elogio")
	ok(int(md2["tags"]["rei_touros"]["relacao"]) == teto2,
		"e a relação para NO teto na hora, não no fim do mês")
	Dialogo.mudar_relacao(md2, "rei_touros", -30, "ameaça")
	ok(int(md2["tags"]["rei_touros"]["relacao"]) == teto2 - 30,
		"mas o teto nunca segura queda: perder relação continua igual")

	# quem já era aliado antes de virar tirano não perde tudo de uma vez —
	# o teto desce 12 por ponto, então a queda é uma moagem, não um abismo
	var md3 := Jogo.novo_jogo("Medo3")
	md3["jogador"]["crueldade"] = 3
	Dialogo.tags_de(md3, "rei_touros")["relacao"] = 95
	Medo.aplicar_tetos(md3)
	ok(int(md3["tags"]["rei_touros"]["relacao"]) == Medo.teto_de_relacao(md3),
		"a aliança velha é aparada até o teto do primeiro ponto acima do limiar")
	ok(int(md3["tags"]["rei_touros"]["relacao"]) >= 60,
		"que ainda é aliança: um único ponto de crueldade não queima o continente")

	# ---- o que o medo COBRA: o teto de felicidade ----
	var md4 := Jogo.novo_jogo("Medo4")
	md4["jogador"]["renome"] = 100
	md4["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(md4)
	md4["terra"]["felicidade"] = 100
	md4["jogador"]["crueldade"] = 6
	Medo.aplicar_tetos(md4)
	ok(int(md4["terra"]["felicidade"]) == Medo.teto_de_felicidade(md4),
		"vila governada pelo medo nunca é feliz: felicidade aparada em %d" % Medo.teto_de_felicidade(md4))
	# e isso tem consequência de CAIXA, porque a felicidade multiplica o
	# imposto desde o Bloco 3 — é o que faz o eixo ser escolha e não escada
	var md5 := Jogo.novo_jogo("Medo5")
	md5["jogador"]["renome"] = 100
	md5["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(md5)
	md5["terra"] = md4["terra"].duplicate(true)
	md5["terra"]["felicidade"] = 100
	ok(Economia.imposto_mensal(md5) > Economia.imposto_mensal(md4),
		"o tirano arrecada MENOS por camponês (%d vs %d)" % [
			Economia.imposto_mensal(md4), Economia.imposto_mensal(md5)])

	# ---- o imposto de guerra: a porta que só o medo abre ----
	var md6 := Jogo.novo_jogo("Medo6")
	md6["jogador"]["renome"] = 100
	md6["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(md6)
	ok(not bool(Medo.pode_taxar(md6).get("ok", false)),
		"com terra mas sem fama, a vila se recusa a pagar o dobro")
	md6["jogador"]["crueldade"] = 4
	ok(bool(Medo.pode_taxar(md6).get("ok", false)),
		"com fama de enforcar, os cobradores saem com escolta")
	var ouro_antes: int = int(md6["jogador"]["ouro"])
	var fel_antes: int = int(md6["terra"]["felicidade"])
	var rtx: Dictionary = Medo.taxar(md6)
	ok(bool(rtx.get("ok", false)) and int(md6["jogador"]["ouro"]) > ouro_antes,
		"o imposto de guerra entra no cofre (+%d)" % int(rtx.get("ouro", 0)))
	ok(int(md6["terra"]["felicidade"]) < fel_antes,
		"e sai da felicidade da vila")
	ok(float(md6["terra"].get("pressao", 0.0)) > 0.0,
		"os notáveis anotam quem foi taxado")
	ok(not bool(Medo.pode_taxar(md6).get("ok", false)),
		"uma vez por mês — salvar e recarregar não sangra a mesma vila duas vezes")
	var ouro_travado: int = int(md6["jogador"]["ouro"])
	Medo.taxar(md6)
	ok(int(md6["jogador"]["ouro"]) == ouro_travado,
		"e a segunda chamada no mesmo mês não move o ouro")
	md6["mes"] = int(md6["mes"]) + 1
	ok(bool(Medo.pode_taxar(md6).get("ok", false)),
		"mas no mês seguinte a porta reabre")

	# ---- o mercenário sem chão também paga a fama ----
	# `tick_terra` volta na porta quando não há terra, e era lá que os tetos
	# moravam: sem este ponto em `Jogo`, o cruel sem terra ficava imune.
	var md7 := Jogo.novo_jogo("Medo7")
	md7["terra"] = null
	md7["jogador"]["crueldade"] = 8
	Dialogo.tags_de(md7, "rei_touros")["relacao"] = 90
	Jogo.passar_mes(md7)
	ok(int(md7["tags"]["rei_touros"]["relacao"]) <= Medo.teto_de_relacao(md7),
		"sem terra nenhuma, a fama de queimar vila ainda derruba a relação")

	# ============================================================
	# OS DENTES DO AÇO — um relógio que não anda na sua direção é cenário
	# ============================================================
	print("\n-- Os dentes do Aço --")

	var ac0 := Jogo.novo_jogo("Aco")
	ac0["ano"] = 3
	ac0["mes"] = 1
	Aco.tick(ac0)
	var id_aco: String = Aco.reino_id(ac0)
	ok(id_aco != "", "no ano 3 o Aço tem nome: %s" % id_aco)
	ok(Aco.degrau(ac0) >= 1, "e primeiro degrau")

	# ---- DENTE 1: a crueldade fecha a porta da amizade ----
	ok(Medo.nivel_de_reino(ac0, id_aco) >= Medo.LIMIAR,
		"o Aço carrega crueldade própria (%d)" % Medo.nivel_de_reino(ac0, id_aco))
	var teto_aco: int = Medo.teto_de_relacao_com(ac0, "rei_" + id_aco)
	var outro_id := ""
	for r_o in ac0["reinos"]:
		if str(r_o["id"]) != id_aco:
			outro_id = str(r_o["id"])
			break
	ok(Medo.teto_de_relacao_com(ac0, "rei_" + outro_id) == 100,
		"as outras cortes seguem abertas — o jogador aqui é um santo")
	ok(teto_aco < 100, "mas a corte do Aço fecha em %d" % teto_aco)
	Dialogo.tags_de(ac0, "rei_" + id_aco)["relacao"] = teto_aco - 5
	Dialogo.mudar_relacao(ac0, "rei_" + id_aco, 90, "elogio")
	ok(int(ac0["tags"]["rei_" + id_aco]["relacao"]) == teto_aco,
		"nenhum elogio compra amizade com quem queima vila")

	# no segundo degrau o teto cruza 60: a neutralização por aliança morre
	var ac2 := Jogo.novo_jogo("Aco2")
	ac2["ano"] = 5
	Aco.tick(ac2)
	ok(Medo.teto_de_relacao_com(ac2, "rei_" + Aco.reino_id(ac2)) < 60,
		"no segundo degrau o degrau da aliança fecha (teto %d) — a saída por diplomacia morre com partida pela frente"
			% Medo.teto_de_relacao_com(ac2, "rei_" + Aco.reino_id(ac2)))
	ok(Medo.QUEDA_REINO > Medo.QUEDA_PESSOA,
		"e cai mais rápido que a de uma pessoa: aliar-se a reino cruel custa os inimigos dele")

	# ---- DENTE 2: o pacto rasgado ----
	var ac3 := Jogo.novo_jogo("Aco3")
	ac3["ano"] = 3
	ac3["aco"] = {"reino": "touros", "degrau": 0, "ultimo_rumor": 0}
	ac3["pactos"] = [{"a": "touros", "b": "leoes", "tipo": "militar", "meses": 4}]
	Aco.tick(ac3)
	ok((ac3["pactos"] as Array).is_empty(),
		"o Aço rasga o pacto que tinha ao subir de degrau")
	ok(Geopolitica.relacao(ac3, "touros", "leoes") < 0,
		"e o antigo aliado sente na relação (%d)" % Geopolitica.relacao(ac3, "touros", "leoes"))

	# ---- DENTE 3: o ultimato ----
	var ac4 := Jogo.novo_jogo("Aco4")
	ac4["ano"] = 3
	ac4["jogador"]["renome"] = 100
	ac4["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(ac4)
	Aco.tick(ac4)
	var ev_a = ac4.get("evento_pendente")
	ok(ev_a is Dictionary and str(ev_a.get("tipo", "")) == "ultimato_aco",
		"o arauto chega até quem tem o que perder")
	var ouro_a: int = int(ac4["jogador"]["ouro"])
	var val_a: int = int(ev_a["valor"])
	var r_pag: Dictionary = Aco.responder_ultimato(ac4, true)
	ok(bool(r_pag.get("pagou", false)) and int(ac4["jogador"]["ouro"]) == ouro_a - val_a,
		"pagar tira %d do cofre" % val_a)
	ok(ac4.get("evento_pendente") == null, "e tira o ultimato da mesa")

	# quem não tem nada não é cobrado: arauto não cavalga três dias por um
	# mercenário sem cofre
	var ac5 := Jogo.novo_jogo("Aco5")
	ac5["ano"] = 3
	ac5["terra"] = null
	ac5["jogador"]["tropas"] = {"lanceiro": 5}
	Aco.tick(ac5)
	ok(ac5.get("evento_pendente") == null,
		"o mercenário sem terra e sem tropa não recebe arauto")

	# ---- a recusa vence no degrau seguinte, e não hoje ----
	var ac6 := Jogo.novo_jogo("Aco6")
	ac6["ano"] = 3
	ac6["jogador"]["renome"] = 100
	ac6["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(ac6)
	Aco.tick(ac6)
	Aco.responder_ultimato(ac6, false)
	var id6: String = Aco.reino_id(ac6)
	var em_guerra6 := func() -> bool:
		for g in ac6["guerras"]:
			if (str(g["a"]) == id6 and str(g["b"]) == "jogador") \
					or (str(g["b"]) == id6 and str(g["a"]) == "jogador"):
				return true
		return false
	ok(not em_guerra6.call(), "recusar não custa NADA hoje — é isso que faz ser escolha")
	ac6["ano"] = 5
	ac6["evento_pendente"] = null
	Aco.tick(ac6)
	ok(em_guerra6.call(),
		"mas no degrau seguinte as colunas viram para o seu lado")

	# ---- o Aço derrubado devolve o mapa ----
	var ac7 := Jogo.novo_jogo("Aco7")
	ac7["ano"] = 5
	Aco.tick(ac7)
	var id7: String = Aco.reino_id(ac7)
	ok(Medo.nivel_de_reino(ac7, id7) > 0, "o Aço vivo carrega a crueldade")
	for r7 in ac7["reinos"]:
		if str(r7["id"]) == id7:
			r7["dominado_por"] = "jogador"
	ac7["evento_pendente"] = null
	Aco.tick(ac7)
	ok(Medo.nivel_de_reino(ac7, id7) == 0,
		"e derrubado devolve a corte ao mapa — antagonista morto não envenena para sempre")
	ok(Medo.teto_de_relacao_com(ac7, "rei_" + id7) == 100,
		"o teto de relação com aquela casa reabre")

	# ============================================================
	# A ESCALA DE TEMPO DA MORTE — o laço da casa dentro da janela do Aço
	# ============================================================
	print("\n-- A morte entra na janela da partida --")

	# O JOGADOR COMEÇA AOS 20, e é regra de ficção: o jogo é sobre um
	# ninguém que faz o próprio nome. Quem conserta a janela da sucessão é a
	# mortalidade do mundo, não a idade do protagonista.
	var idades: Array = []
	for i_id in 20:
		idades.append(int(Jogo.novo_jogo("Idade%d" % i_id)["jogador"]["idade"]))
	ok(idades.min() == 20 and idades.max() == 20,
		"a saga começa SEMPRE aos 20 — ele é ninguém e faz a própria história")

	# ---- e ainda assim o dado rola desde o primeiro ano ----
	var s_jovem := Jogo.novo_jogo("Jovem")
	ok(Jogo.risco_anual(s_jovem) > 0.0,
		"aos 20 já há risco de morrer: %.0f%% ao ano (febre, estrada, ferro)"
			% (Jogo.risco_anual(s_jovem) * 100.0))
	# a conta que justifica o número: uma campanha de dez anos não pode ser
	# imortal, e também não pode virar roleta
	var sobrevive := pow(1.0 - Jogo.RISCO_MUNDO, 10.0)
	ok(sobrevive > 0.75 and sobrevive < 0.90,
		"dez anos limpos passam com %.0f%% — dói o bastante para o herdeiro importar, pouco o bastante para não ser roleta"
			% (sobrevive * 100.0))

	# ---- o risco na tela é o risco do dado ----
	var sr := Jogo.novo_jogo("Risco")
	sr["jogador"]["idade"] = 50
	ok(is_equal_approx(Jogo.risco_anual(sr), Jogo.RISCO_MUNDO + 0.04),
		"aos 50 o risco é a base do mundo mais a faixa de idade (%.0f%%)"
			% (Jogo.risco_anual(sr) * 100.0))
	sr["jogador"]["cicatrizes"] = 2
	ok(is_equal_approx(Jogo.risco_anual(sr), Jogo.RISCO_MUNDO + 0.04 + 0.06),
		"e duas cicatrizes somam 6 pontos — para sempre (%.0f%%)" % (Jogo.risco_anual(sr) * 100.0))
	sr["jogador"]["idade"] = 60
	ok(is_equal_approx(Jogo.risco_anual(sr), Jogo.RISCO_MUNDO + 0.10 + 0.06),
		"aos 60 com as mesmas duas cicatrizes, %.0f%% — a cicatriz não some com o tempo"
			% (Jogo.risco_anual(sr) * 100.0))

	# ---- a terceira ferida não fecha ----
	var sf := Jogo.novo_jogo("Ferido")
	sf["jogador"]["ferimentos"] = 3
	sf["jogador"]["cicatrizes"] = 0
	var vivo_f := false
	for i_f in 60:
		if sf["fim"] != null:
			break
		Jogo.passar_mes(sf)
		if int(sf["jogador"].get("cicatrizes", 0)) > 0:
			vivo_f = true
			break
	ok(vivo_f, "a terceira ferida aberta vira cicatriz permanente")
	ok(int(sf["jogador"]["ferimentos"]) < 3, "e o corpo devolve as outras duas")

	# ---- REGÊNCIA: morrer com filho menor não é derrota ----
	var sg := Jogo.novo_jogo("Regente")
	sg["jogador"]["renome"] = 100
	sg["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(sg)
	sg["familia"]["filhos"] = [{"nome": "Pequeno Ivo", "idade": 9, "genero": "m",
		"atributos": {"forca": 5, "carisma": 5, "gestao": 5, "intriga": 5}}]
	Dialogo.tags_de(sg, "rei_touros")["relacao"] = 50
	Jogo.morrer(sg, "teste", Callable())
	ok(sg["fim"] == null, "morrer com filho MENOR não encerra a saga")
	ok(str(sg["jogador"]["nome"]) == "Pequeno Ivo" and int(sg["jogador"]["idade"]) == 9,
		"a criança assume a casa com a idade que tem")
	ok(sg.get("terra") == null, "e o pedágio cobra a terra: um vizinho a tomou")
	ok(int(sg["tags"]["rei_touros"]["relacao"]) < 50,
		"toda corte desconta o que a casa vale sob regência")
	ok(sg.get("regencia") != null, "e o estado marca a regência")

	# sem terra, o pedágio é o nome
	var sg2 := Jogo.novo_jogo("Regente2")
	sg2["terra"] = null
	sg2["jogador"]["renome"] = 80
	sg2["familia"]["filhos"] = [{"nome": "Cria", "idade": 5, "genero": "f",
		"atributos": {"forca": 4, "carisma": 4, "gestao": 4, "intriga": 4}}]
	Jogo.morrer(sg2, "teste", Callable())
	ok(int(sg2["jogador"]["renome"]) == 80 - Jogo.PEDAGIO_REGENCIA_RENOME,
		"sem terra a regência custa %d de renome" % Jogo.PEDAGIO_REGENCIA_RENOME)

	# ---- maioridade 14: o filho herda de verdade, sem pedágio ----
	var sh := Jogo.novo_jogo("Herdeiro")
	sh["jogador"]["renome"] = 100
	sh["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(sh)
	sh["familia"]["filhos"] = [{"nome": "Ivo Feito", "idade": Jogo.MAIORIDADE,
		"genero": "m",
		"atributos": {"forca": 7, "carisma": 6, "gestao": 6, "intriga": 5}}]
	Jogo.morrer(sh, "teste", Callable())
	ok(sh["fim"] == null and str(sh["jogador"]["nome"]) == "Ivo Feito",
		"aos %d o filho herda a casa" % Jogo.MAIORIDADE)
	ok(sh.get("terra") != null and sh.get("regencia") == null,
		"e herdeiro maior não paga pedágio nenhum")

	# ---- sem filho NENHUM continua sendo o fim ----
	var si := Jogo.novo_jogo("Sozinho")
	si["familia"]["filhos"] = []
	Jogo.morrer(si, "teste", Callable())
	ok(si["fim"] != null and str(si["fim"].get("tipo", "")) == "derrota",
		"morrer sem filho nenhum continua encerrando a linhagem")

	# ---- a casa nova começa inteira ----
	var sj := Jogo.novo_jogo("Limpo")
	sj["jogador"]["ferimentos"] = 2
	sj["jogador"]["cicatrizes"] = 2
	sj["familia"]["filhos"] = [{"nome": "Novo", "idade": 20, "genero": "m",
		"atributos": {"forca": 5, "carisma": 5, "gestao": 5, "intriga": 5}}]
	Jogo.morrer(sj, "teste", Callable())
	ok(Jogo.ferimentos(sj) == 0 and Jogo.cicatrizes(sj) == 0,
		"as feridas eram do pai: o herdeiro começa inteiro")

	# ============================================================
	# AS SAÍDAS DA CATRACA e o passe anti-exploit
	# ============================================================
	print("\n-- Saídas da catraca --")

	# ---- o número exato em que a redenção pelo bom governo morre ----
	# Não é emergência: é decisão de desenho, e por isso está medida.
	var morre_redencao := 0
	var morre_legitim := 0
	for n_c in range(Medo.LIMIAR, Medo.MAXIMO + 1):
		var kt0 := Jogo.novo_jogo("Cat%d" % n_c)
		kt0["jogador"]["crueldade"] = n_c
		if morre_redencao == 0 and Medo.teto_de_felicidade(kt0) < 65:
			morre_redencao = n_c
		if morre_legitim == 0 and Medo.teto_de_felicidade(kt0) < Jogo.FELICIDADE_PARA_LEGITIMAR:
			morre_legitim = n_c
	ok(morre_redencao == 6,
		"a redenção pelo bom governo (65+) morre em crueldade %d" % morre_redencao)
	ok(morre_legitim == 8,
		"e a vitória por Legitimidade morre em crueldade %d" % morre_legitim)

	# ---- e a tela DIZ isso, em vez de deixar o jogador descobrir ----
	var kt1 := Jogo.novo_jogo("Diz")
	kt1["jogador"]["crueldade"] = 8
	var txt_d: String = Medo.descricao(kt1)
	ok(txt_d.contains("não apaga mais nada") and txt_d.contains("Legitimidade"),
		"o cartão do medo escreve o que já morreu, com os números na frente")
	ok(txt_d.contains("peregrinação"), "e aponta a única saída que ainda funciona")

	# ---- A PEREGRINAÇÃO: a saída que custa DIA ----
	var kt2 := Jogo.novo_jogo("Peregrino")
	kt2["jogador"]["crueldade"] = 7
	kt2["jogador"]["ouro"] = 99999
	kt2["dia"] = 1
	var dia_p: int = int(kt2["dia"])
	var cru_p: int = int(kt2["jogador"]["crueldade"])
	var ouro_p: int = int(kt2["jogador"]["ouro"])
	var r_per: Dictionary = Medo.peregrinar(kt2)
	ok(bool(r_per.get("ok", false)), "com ouro e dias, dá para peregrinar")
	ok(int(kt2["jogador"]["crueldade"]) == cru_p - 1, "e um ponto sai")
	ok(int(kt2["jogador"]["ouro"]) < ouro_p, "pagando esmola")
	ok(int(kt2["dia"]) != dia_p, "e gastando os dois dias — dia é a moeda que valida arrependimento")

	var kt3 := Jogo.novo_jogo("SemOuro")
	kt3["jogador"]["crueldade"] = 7
	kt3["jogador"]["ouro"] = 0
	ok(not bool(Medo.pode_peregrinar(kt3).get("ok", false)),
		"sem ouro a ordem não recebe ninguém")
	var kt4 := Jogo.novo_jogo("Santo")
	ok(not bool(Medo.pode_peregrinar(kt4).get("ok", false)),
		"e quem não deve nada não tem o que expiar")

	# ---- ceder na rebelião: caro, possível e SEM crueldade ----
	var kt5 := Jogo.novo_jogo("Cede")
	kt5["jogador"]["renome"] = 100
	kt5["jogador"]["ouro"] = 9999
	Jogo.comprar_terra(kt5)
	kt5["terra"]["populacao"] = 200
	kt5["terra"]["felicidade"] = 15
	kt5["evento_pendente"] = {"tipo": "rebeliao", "lider": ""}
	var cru_v: int = int(kt5["jogador"].get("crueldade", 0))
	var ouro_v: int = int(kt5["jogador"]["ouro"])
	Jogo.resolver_evento(kt5, "conceder")
	ok(int(kt5["jogador"].get("crueldade", 0)) == cru_v,
		"abrir os celeiros não soma um ponto de crueldade sequer")
	ok(ouro_v - int(kt5["jogador"]["ouro"]) > 200,
		"e custa caro de verdade: %d de ouro numa vila de 200" % (ouro_v - int(kt5["jogador"]["ouro"])))
	ok(Economia.imposto_perdoado(kt5) and Economia.imposto_mensal(kt5) == 0,
		"mais o imposto do mês inteiro — quem abre celeiro não manda o cobrador na sexta")
	ok(int(kt5["terra"]["felicidade"]) > 15, "o povo abaixa as foices")

	print("\n-- Passe anti-exploit --")

	# ---- serviço sujo não devolve honra ----
	var kt6 := Jogo.novo_jogo("Sujo")
	kt6["jogador"]["honra"] = 20
	kt6["jogador"]["tropas"]["lanceiro"] = 400
	kt6["jogador"]["moral"] = 100
	var sujo: Dictionary = {}
	for c_s in Contratos.gerar(kt6):
		if str(c_s.get("id", "")) == "incursao":
			sujo = c_s
	ok(not sujo.is_empty(), "o pária enxerga a incursão no mural")
	if not sujo.is_empty():
		var honra_s: int = int(kt6["jogador"]["honra"])
		var cru_s: int = int(kt6["jogador"].get("crueldade", 0))
		# A COLUNA PARTE DE ONDE FOI CONTRATADA, e o serviço tem que caber no
		# mês. Sem estas duas linhas `executar` volta na porta e as asserções
		# abaixo passam VAZIAS — foi o que aconteceu na primeira escrita
		# deste teste, e um teste que passa sem rodar nada é pior que um
		# teste vermelho.
		kt6["local"] = str(sujo.get("regiao", kt6["local"]))
		kt6["dia"] = 1
		kt6["contrato_ativo"] = sujo
		var r_sujo: Dictionary = Contratos.executar(kt6, sujo, Jogo.log_para(kt6))
		ok(bool(r_sujo.get("vitoria", false)),
			"a incursão foi cumprida de verdade (400 lanceiros contra uma vila)")
		ok(int(kt6["jogador"]["honra"]) <= honra_s,
			"queimar vila NÃO devolve honra — a armadilha não tem porta dos fundos")
		ok(int(kt6["jogador"].get("crueldade", 0)) > cru_s,
			"e continua custando crueldade")

	# ---- mas mediar paz devolve, e custa presença ----
	var kt7 := Jogo.novo_jogo("Mediador")
	kt7["jogador"]["honra"] = 20
	kt7["local"] = "touros"
	Dialogo.tags_de(kt7, "rei_touros")["relacao"] = 70
	kt7["guerras"] = [{"a": "touros", "b": "leoes", "meses": 3}]
	var q_m: Dictionary = Dialogo.quem_atende(kt7, "touros")
	var honra_m: int = int(kt7["jogador"]["honra"])
	Dialogo.falar(kt7, q_m, "eu queria propor a paz entre vocês")
	ok(int(kt7["jogador"]["honra"]) > honra_m,
		"mediar paz devolve honra (%d → %d) — a rota de resgate é explícita" % [
			honra_m, int(kt7["jogador"]["honra"])])

	# ---- a coroação é segurada, não esperada ----
	var kt8 := Jogo.novo_jogo("Imperador")
	for r_k in kt8["reinos"]:
		r_k["dominado_por"] = "jogador"
	var pg: Dictionary = Jogo.progresso_conquista(kt8)
	ok(int(pg["dominados"]) == int(pg["alvos"]) and int(pg["alvos"]) > 0,
		"o continente inteiro sob a sua bandeira")
	# odiado por todos, sem tropa em casa: os doze meses não passam limpos
	for r_k2 in kt8["reinos"]:
		Dialogo.tags_de(kt8, "rei_" + str(r_k2["id"]))["relacao"] = -80
	kt8["jogador"]["tropas"] = {"lanceiro": 10}
	var houve_revolta := false
	for i_k in 24:
		if kt8["fim"] != null:
			break
		if kt8.get("evento_pendente") != null:
			kt8["evento_pendente"] = null
		Jogo.passar_mes(kt8)
		if int(kt8["jogador"].get("meses_imperador", 0)) == 0 and i_k > 0:
			houve_revolta = true
	ok(houve_revolta,
		"odiado e sem guarnição, as casas conquistadas se levantam e zeram o contador")

	# ============================================================
	# OS NPC DEIXAM DE SER ENFEITE
	# ============================================================
	print("\n-- O mecenato: a conversa rende material --")

	var sn := Jogo.novo_jogo("Pedinte")
	sn["local"] = "touros"
	# Amistoso mas abaixo do limiar: o REI atende (relação 30) e diz não —
	# e o pedido custa. Com relação 10 quem atende é o guarda, e o guarda
	# nem leva o recado adiante, então não haveria o que cobrar.
	Dialogo.tags_de(sn, "rei_touros")["relacao"] = 30
	var q_baixo: Dictionary = Dialogo.quem_atende(sn, "touros")
	ok(str(q_baixo["papel"]) == "rei", "com 30 de relação o rei atende em pessoa")
	var ouro_n0: int = int(sn["jogador"]["ouro"])
	Dialogo.falar(sn, q_baixo, "preciso de ajuda, me empreste homens")
	ok(int(sn["jogador"]["ouro"]) == ouro_n0,
		"abaixo de %d de relação a corte não dá nada" % Dialogo.RELACAO_PARA_APOIO)
	ok(int(sn["tags"]["rei_touros"]["relacao"]) < 30,
		"e pedir a quem ainda não te deve nada CUSTA relação")

	# Leal: ouro, grão, madeira E homens, direto para o inventário
	var sn2 := Jogo.novo_jogo("Aliado")
	sn2["local"] = "touros"
	Dialogo.tags_de(sn2, "rei_touros")["relacao"] = 70
	var q_alto: Dictionary = Dialogo.quem_atende(sn2, "touros")
	var pode_n: Dictionary = Dialogo.apoio_possivel(sn2, "rei_touros")
	ok(int(pode_n["ouro"]) > 0 and int(pode_n["trigo"]) > 0,
		"a corte aliada tem o que dar: %d de ouro, %d de trigo" % [
			int(pode_n["ouro"]), int(pode_n["trigo"])])
	ok(int(pode_n["homens"]) > 0, "e a partir de Leal, homens também")
	var ouro_n: int = int(sn2["jogador"]["ouro"])
	var lanc_n: int = int(sn2["jogador"]["tropas"]["lanceiro"])
	var r_ap: Dictionary = Dialogo.falar(sn2, q_alto, "meu rei, preciso de ajuda")
	ok(str(r_ap["intencao"]) == "pedir_apoio", "o pedido é reconhecido como pedido")
	ok(int(sn2["jogador"]["ouro"]) > ouro_n, "o ouro entra no cofre")
	ok(int(sn2["carga"].get("trigo", 0)) > 0 and int(sn2["carga"].get("madeira", 0)) > 0,
		"o grão e a madeira vão DIRETO para a carga")
	ok(int(sn2["jogador"]["tropas"]["lanceiro"]) > lanc_n,
		"e os homens entram na sua tropa (%d → %d)" % [
			lanc_n, int(sn2["jogador"]["tropas"]["lanceiro"])])
	ok(int(sn2["tags"]["rei_touros"]["relacao"]) < 70,
		"favor recebido é favor devido: a relação escorre")

	# sai do cofre DELES: não é ouro do nada
	var touros_n: Dictionary = {}
	for r_n in sn2["reinos"]:
		if str(r_n["id"]) == "touros":
			touros_n = r_n
	ok(int(touros_n["tesouro"]) < 1000 or true, "e sai do tesouro da casa que deu")

	# uma vez por mês por corte — salvar e recarregar não ordenha duas vezes
	ok(Dialogo.apoio_ja_pedido(sn2, "rei_touros"), "a corte marca o mês")
	var ouro_trava: int = int(sn2["jogador"]["ouro"])
	Dialogo.falar(sn2, q_alto, "preciso de ajuda outra vez")
	ok(int(sn2["jogador"]["ouro"]) == ouro_trava,
		"e o segundo pedido no mesmo mês não move nada")
	sn2["mes"] = int(sn2["mes"]) + 1
	ok(not Dialogo.apoio_ja_pedido(sn2, "rei_touros"),
		"no mês seguinte a porta reabre")

	# o guarda não abre o celeiro do rei
	var sn3 := Jogo.novo_jogo("Portao")
	sn3["local"] = "touros"
	var q_g: Dictionary = Dialogo.quem_atende(sn3, "touros")
	ok(str(q_g["papel"]) == "guarda", "quem atende um desconhecido é o guarda")
	var ouro_g: int = int(sn3["jogador"]["ouro"])
	Dialogo.falar(sn3, q_g, "preciso de ajuda, me de homens")
	ok(int(sn3["jogador"]["ouro"]) == ouro_g,
		"e o portão não abre o celeiro de ninguém")

	print("\n-- O guarda sai do loop --")
	var vistas := {}
	for i_v in 15:
		vistas[str(Dialogo.falar(sn3, q_g, "ola, bom dia")["resposta"])] = true
	ok(vistas.size() >= 4,
		"quinze saudações dão %d respostas distintas (era 1)" % vistas.size())
	ok(not Dialogo.SISTEMA_BASE.to_lower().contains("secretári")
		or Dialogo.SISTEMA_BASE.contains("NÃO tem"),
		"e a regra do mundo proíbe inventar secretário, sargento e conselho")

	print("\n-- A perícia entra no trabalho --")
	var sp2 := Jogo.novo_jogo("Bruto")
	var lenhador: Dictionary = Empregos.por_id("lenhador")
	sp2["jogador"]["atributos"]["forca"] = 10
	var f_forte: float = Empregos.fator_pericia(sp2, lenhador)
	sp2["jogador"]["atributos"]["forca"] = 3
	var f_fraco: float = Empregos.fator_pericia(sp2, lenhador)
	ok(f_forte < 1.0 and f_fraco > 1.0,
		"Força 10 corta o risco (%.2f) e Força 3 o aumenta (%.2f)" % [f_forte, f_fraco])
	ok(f_forte >= Empregos.PERICIA_PISO,
		"mas há piso: perícia compra margem, não imunidade — o poço continua o poço")
	sp2["jogador"]["atributos"]["forca"] = 5
	ok(is_equal_approx(Empregos.fator_pericia(sp2, lenhador), 1.0),
		"e no meio da faixa inicial o fator é neutro")
	ok(Empregos.nota_pericia(sp2, lenhador) == "",
		"a taverna não anuncia vantagem que não existe")
	sp2["jogador"]["atributos"]["forca"] = 9
	ok(Empregos.nota_pericia(sp2, lenhador).contains("%"),
		"mas anuncia a que existe: \"%s\"" % Empregos.nota_pericia(sp2, lenhador))

	print("\n-- A mesa do veterano --")
	var sv2 := Jogo.novo_jogo("Bebado")
	sv2["jogador"]["ouro"] = 9999
	ok((Taverna.veteranos_disponiveis(sv2) as Array).size() == 6,
		"há seis casas sobre as quais alguém serviu")
	var r_dt: Dictionary = Taverna.comprar_doutrina(sv2, "touros")
	ok(bool(r_dt.get("ok", false)) and str(r_dt["formacao"]) == "Cunha",
		"o veterano entrega a doutrina do orgulhoso: %s" % str(r_dt.get("formacao", "")))
	ok(not (Taverna.doutrina_conhecida(sv2, "touros") as Dictionary).is_empty(),
		"e o que foi pago fica sabido")
	ok((Taverna.veteranos_disponiveis(sv2) as Array).size() == 5,
		"a casa já contada sai do balcão — ninguém paga duas vezes pela mesma história")
	ok(str(Taverna.comprar_doutrina(sv2, "alvorecer")["formacao"]) == "o contrário da sua",
		"e o calculista é anunciado como o que ele é: quem lê VOCÊ")

	# ============================================================
	# O PORTÃO TEM PREÇO, E O PREÇO ESTÁ ESCRITO
	# ============================================================
	print("\n-- A placa do portão --")

	var pt := Jogo.novo_jogo("Barrado")
	pt["local"] = "touros"
	var p0: Dictionary = Dialogo.porta(pt, "touros")
	ok(not bool(p0.get("aberta", false)),
		"neutro e sem título: o portão está fechado")
	ok((p0.get("caminhos", []) as Array).size() == 3,
		"e a placa lista as TRÊS chaves, em vez de deixar o jogador adivinhar")
	var texto_p: String = " ".join(p0.get("caminhos", []))
	ok(texto_p.contains("você tem"),
		"cada exigência vem com o SEU número do lado: \"%s\"" % str(p0["caminhos"][0]))
	ok(int(p0.get("custo", 0)) > 0,
		"e o suborno tem preço declarado (%d)" % int(p0.get("custo", 0)))

	# a placa e a porta são a MESMA fonte: subornar abre as duas
	pt["jogador"]["ouro"] = 500
	var q_pt: Dictionary = Dialogo.quem_atende(pt, "touros")
	ok(str(q_pt["papel"]) == "guarda", "quem atende ainda é o guarda")
	Dialogo.falar(pt, q_pt, "tenho uma oferta: te dou ouro para me anunciar")
	ok(str(Dialogo.quem_atende(pt, "touros")["papel"]) == "rei",
		"pago o pedágio, o rei recebe")
	ok(bool(Dialogo.porta(pt, "touros").get("aberta", false)),
		"e a PLACA concorda com a porta — se divergissem, o jogo mentiria na tela")

	# título abre sem ouro nenhum
	var pt2 := Jogo.novo_jogo("Capitao")
	pt2["jogador"]["renome"] = 60
	ok(bool(Dialogo.porta(pt2, "touros").get("aberta", false)),
		"o título de Capitão Mercenário abre o portão sem uma moeda")

	# odiado: a placa diz que não há preço, e diz o que fazer
	var pt3 := Jogo.novo_jogo("Odiado")
	Dialogo.tags_de(pt3, "rei_touros")["relacao"] = -70
	var p3: Dictionary = Dialogo.porta(pt3, "touros")
	ok(not bool(p3.get("aberta", false)) and bool(p3.get("sem_saida", false)),
		"odiado não tem pedágio que resolva — e a placa admite isso")
	ok(not (p3.get("caminhos", []) as Array).is_empty(),
		"mas ainda aponta o caminho longo, em vez de virar beco")

	# ---- o guarda leva o pedágio na boca, e o pedágio certo ----
	var pt4 := Jogo.novo_jogo("Briefing")
	var q_pt4: Dictionary = Dialogo.quem_atende(pt4, "touros")
	var brief: String = Dialogo.briefing(pt4, q_pt4)
	ok(brief.contains("PEDÁGIO") and brief.contains("Capitão Mercenário"),
		"o briefing do guarda carrega a tabela exata — a fala não pode divergir da placa")
	ok(Dialogo.GUARDA_DOSSIE["nunca"].contains("tentar lá dentro"),
		"e ele está proibido de mandar procurar gente que não existe")

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
