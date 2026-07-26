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

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
