# ============================================================
# CRUELDADE — a oitava moeda, que o código já contava e o design ignorava
#
# O número existia: saquear caravana subia, executar subia, seis meses de
# povo contente apagavam um ponto. Rastreado, salvo, migrado — e lido em
# exatamente dois lugares: os notáveis reagem a partir de 3, e o herdeiro
# nasce mimado. Fora isso era só um contador que subia e fechava portas.
#
# Punição sem contrapartida não é uma moeda: é um imposto sobre uma escolha
# que o jogo oferece. Ou vira sistema, ou é entulho.
#
# ---- o eixo: governar pelo amor ou pelo medo ----
#
# DESTRAVA (o que só o medo dá)
#   · a guarnição obedece com o soldo atrasado. Quem manda enforcar um
#     desertor não precisa pagar em dia — a moral cai menos por soldo não
#     pago, e é a única forma de sustentar exército acima da renda.
#   · imposto de guerra: cobrar acima da taxa sem revolta imediata. A
#     felicidade cai do mesmo jeito, mas a rebelião demora.
#
# ENVENENA (o que o medo cobra)
#   · teto de relação nas cortes. Ninguém quer aliança de sangue com quem
#     queima vila: acima de 3 de crueldade a relação para de subir num teto
#     que desce a cada ponto.
#   · teto de felicidade. Uma vila governada pelo medo nunca é feliz — e
#     como a felicidade agora multiplica o imposto (Bloco 3), o tirano
#     arrecada menos por camponês e compensa no volume e no chicote.
#
# É por isso que o eixo é uma ESCOLHA e não uma escada: o cruel sustenta
# mais homens com menos ouro e nunca terá aliados nem uma vila próspera; o
# amado arrecada mais por cabeça e depende de pagar o soldo em dia.
# ============================================================
extends RefCounted

## A partir daqui o medo começa a funcionar — e a cobrar.
const LIMIAR := 3
const MAXIMO := 10

static func nivel(state: Dictionary) -> int:
	return clampi(int(state["jogador"].get("crueldade", 0)), 0, MAXIMO)

## Quanto o medo segura a tropa quando o soldo não sai.
##
## `Economia.tick_exercito` derruba 12 de moral por item que faltou. Cada
## ponto de crueldade acima do limiar apara 8% dessa queda, até um piso de
## 40%: mesmo o tirano mais temido não sustenta exército sem pagar para
## sempre, ele só compra tempo. E tempo é exatamente o que falta a quem está
# com o cofre no fundo.
static func fator_desercao(state: Dictionary) -> float:
	var n := nivel(state)
	if n < LIMIAR:
		return 1.0
	return maxf(0.40, 1.0 - (n - LIMIAR + 1) * 0.08)

## O TETO DE RELAÇÃO. Ninguém quer aliança de sangue com quem queima vila.
##
## Devolve o valor máximo que a relação com uma corte pode alcançar: 88 no
## limiar, caindo 12 por ponto. O degrau de 60 — onde moram a aliança, o
## desconto e o abrigo contra emboscada — só fecha no SEXTO ponto (teto 52),
## e até lá o cruel ainda negocia, ainda pega contrato, ainda entra no salão.
## Três pontos de folga é o que separa o homem duro do monstro.
static func teto_de_relacao(state: Dictionary) -> int:
	var n := nivel(state)
	if n < LIMIAR:
		return 100
	return maxi(10, 100 - (n - LIMIAR + 1) * 12)

## O TETO DE FELICIDADE. Vila governada pelo medo não é feliz.
##
## E como a felicidade multiplica o imposto desde o Bloco 3, este teto tem
## consequência de caixa: o tirano arrecada menos por camponês. Ele compensa
## no imposto de guerra e no soldo que não precisa pagar.
static func teto_de_felicidade(state: Dictionary) -> int:
	var n := nivel(state)
	if n < LIMIAR:
		return 100
	return maxi(25, 100 - (n - LIMIAR + 1) * 10)

## O IMPOSTO DE GUERRA — a porta que só o medo abre.
##
## Cobra o dobro do imposto do mês e derruba felicidade. Sem crueldade
## suficiente, a vila simplesmente se recusa: quem não tem fama de enforcar
## ninguém não consegue arrancar o dobro de uma aldeia com fome.
##
## Uma vez por mês, e é o `state["mes"]` que guarda — assim não dá para
## bater o mesmo mês duas vezes salvando e recarregando.
static func pode_taxar(state: Dictionary) -> Dictionary:
	if state.get("terra") == null:
		return {"ok": false, "msg": "Sem terra, não há quem taxar."}
	if nivel(state) < LIMIAR:
		return {"ok": false,
			"msg": "A vila não teme você o bastante. Imposto de guerra se cobra de quem já viu do que você é capaz."}
	var marca: String = "%d/%d" % [int(state.get("ano", 1)), int(state.get("mes", 1))]
	if str(state["jogador"].get("taxou_em", "")) == marca:
		return {"ok": false, "msg": "Você já sangrou esta vila neste mês."}
	return {"ok": true}

static func taxar(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	var pode := pode_taxar(state)
	if not bool(pode.get("ok", false)):
		return pode
	var Economia = load("res://scripts/economia.gd")
	var Livro = load("res://scripts/livro.gd")
	var extra: int = Economia.imposto_mensal(state)
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + extra
	state["jogador"]["taxou_em"] = "%d/%d" % [int(state.get("ano", 1)),
		int(state.get("mes", 1))]
	Livro.registrar(state, "medo", "ouro", extra, "Imposto de guerra")
	var t: Dictionary = state["terra"]
	t["felicidade"] = clampi(int(t["felicidade"]) - 15, 0, 100)
	# a pressão sobe: os notáveis não esquecem quem foi taxado duas vezes
	t["pressao"] = minf(100.0, float(t.get("pressao", 0.0)) + 12.0)
	if log.is_valid():
		log.call("Os cobradores saíram com escolta. Voltaram com %d de ouro e com o silêncio da vila." % extra)
	return {"ok": true, "ouro": extra,
		"msg": "Imposto de guerra: %d de ouro. A vila perdeu 15 de felicidade e não esqueceu." % extra}

## Aplica os dois tetos. Chamado no tique da terra e no de relação — é o
## ponto único que faz o medo COBRAR, e ficar num lugar só é o que impede
## os tetos de divergirem entre sistemas.
static func aplicar_tetos(state: Dictionary) -> void:
	var n := nivel(state)
	if n < LIMIAR:
		return
	if state.get("terra") != null:
		var t: Dictionary = state["terra"]
		t["felicidade"] = mini(int(t["felicidade"]), teto_de_felicidade(state))
	var teto := teto_de_relacao(state)
	for chave in state.get("tags", {}):
		var tag = state["tags"][chave]
		if tag is Dictionary and tag.has("relacao"):
			tag["relacao"] = mini(int(tag["relacao"]), teto)

## O texto que a interface mostra. Vazio abaixo do limiar — antes disso a
## crueldade é uma marca no seu nome, não um sistema.
static func descricao(state: Dictionary) -> String:
	var n := nivel(state)
	if n < LIMIAR:
		return ""
	return "Temido (%d). A tropa aguenta soldo atrasado, e você pode cobrar imposto de guerra. Em troca: relação limitada a %d nas cortes e felicidade limitada a %d na sua vila." % [
		n, teto_de_relacao(state), teto_de_felicidade(state)]
