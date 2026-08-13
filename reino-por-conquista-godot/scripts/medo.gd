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

## A CRUELDADE DE UMA CORTE. O mesmo número, do outro lado da mesa.
##
## Os reinos NPC sempre tiveram o campo e nunca o usaram; quem o escreve hoje
## é o Aço, a cada degrau. A régua é a mesma que vale para o jogador — e ter
## uma régua só é justamente o que impede o mundo de julgar o jogador por um
## critério que ele não pode aplicar de volta.
static func nivel_de_reino(state: Dictionary, reino_id: String) -> int:
	if reino_id == "":
		return 0
	for r in state.get("reinos", []):
		if str(r.get("id", "")) == reino_id:
			return clampi(int(r.get("crueldade", 0)), 0, MAXIMO)
	return 0

## O id do reino escondido dentro de uma tag de NPC ("rei_touros" → "touros").
## Devolve vazio para tags que não são de corte (clãs, taverneiros, notáveis).
static func reino_da_tag(npc_id: String) -> String:
	return npc_id.substr(4) if npc_id.begins_with("rei_") else ""

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
## Quanto o teto desce por ponto de crueldade. São DOIS números, e a
## diferença entre eles é a tese:
##
## Gostar de uma pessoa cruel não custa nada a ninguém — é uma questão de
## estômago, e por isso cai devagar (12). Aliar-se a um REINO cruel custa os
## inimigos dele, o julgamento das outras casas e a próxima vila queimada na
## sua fronteira: é política externa, não temperamento, e por isso cai rápido
## (16). Com 16, a corte do Aço cruza o degrau de 60 no SEGUNDO degrau — que
## é o ponto do desenho: a saída por diplomacia tem que morrer enquanto ainda
## há partida pela frente, não no ano em que ele já marchou.
const QUEDA_PESSOA := 12
const QUEDA_REINO := 16

static func teto_de_relacao(state: Dictionary) -> int:
	return _teto_relacao(nivel(state), QUEDA_PESSOA)

static func _teto_relacao(n: int, queda: int) -> int:
	if n < LIMIAR:
		return 100
	return maxi(10, 100 - (n - LIMIAR + 1) * queda)

## O TETO QUE VALE PARA ESTA CORTE, e ele tem DOIS donos.
##
## A fama de quem bate na porta limita o quanto se pode subir; a fama de quem
## mora atrás dela limita o mesmo tanto. Vale o menor dos dois — e é essa
## segunda metade que tira do Aço a saída mais barata que ele tinha: comprar
## relação 60 com o reino que está ficando pronto e desligar o relógio da
## partida com diplomacia de tostão. Ninguém faz aliança de sangue com quem
## queima vila, e isso inclui as vilas que o Aço queima.
static func teto_de_relacao_com(state: Dictionary, npc_id: String) -> int:
	var teto := teto_de_relacao(state)
	var reino := reino_da_tag(npc_id)
	if reino == "":
		return teto
	return mini(teto, _teto_relacao(nivel_de_reino(state, reino), QUEDA_REINO))

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

## Aplica os dois tetos. Ponto único — ficar num lugar só é o que impede os
## tetos de divergirem entre sistemas.
##
## O teto de FELICIDADE só existe se o jogador for cruel: é a vila dele.
## O de RELAÇÃO roda sempre, mesmo com o jogador santo, porque desde que o
## Aço passou a ter crueldade própria o teto pode vir do outro lado da mesa.
static func aplicar_tetos(state: Dictionary) -> void:
	if nivel(state) >= LIMIAR and state.get("terra") != null:
		var t: Dictionary = state["terra"]
		t["felicidade"] = mini(int(t["felicidade"]), teto_de_felicidade(state))
	_aparar_relacoes(state)

## Apara TODA relação pelo teto da corte correspondente. Roda também quando o
## jogador é um santo: o teto pode vir do outro lado da mesa.
static func _aparar_relacoes(state: Dictionary) -> void:
	for chave in state.get("tags", {}):
		var tag = state["tags"][chave]
		if tag is Dictionary and tag.has("relacao"):
			tag["relacao"] = mini(int(tag["relacao"]),
				teto_de_relacao_com(state, str(chave)))

# ============================================================
# A SAÍDA — porque catraca sem saída não é escolha, é sentença
#
# A redenção sempre existiu: seis meses de vila contente (felicidade 65+)
# apagam um ponto. O problema, medido, é que ela morre sozinha — o teto de
# felicidade cai 10 por ponto, e a partir de crueldade 6 o teto é 60, abaixo
# dos 65 que a redenção exige. Ou seja: quem passa de 5 nunca mais volta,
# por uma interação de dois números que ninguém escreveu de propósito.
#
# Pior: reprimir rebelião liderada dá +2 de uma vez, e rebelião nasce de
# felicidade baixa, que é exatamente o que o teto garante. Pobre → infeliz →
# rebelião → reprimir → teto mais baixo → mais rebelião. O freio era o
# acelerador.
#
# A PEREGRINAÇÃO é a saída que funciona em qualquer nível, e ela cobra a
# única moeda que valida arrependimento neste jogo: DIA. Dois dias e ouro
# por ponto, e os dois dias são o ponto — quem paga só em ouro não se
# arrependeu, comprou uma indulgência.
#
# Os NÚMEROS DA CATRACA, escritos aqui porque são decisão de desenho e não
# emergência de sistema:
#   crueldade 6 → teto de felicidade 60: a redenção pelo bom governo morre
#   crueldade 6 → teto de relação 52: o degrau da aliança morre
#   crueldade 8 → teto de felicidade 40: a vitória por Legitimidade morre
# ============================================================
const CUSTO_PEREGRINACAO := 300
const DIAS_PEREGRINACAO := 2

## Quanto custa apagar um ponto agora. Sobe com o que há para apagar.
static func custo_peregrinacao(state: Dictionary) -> int:
	return CUSTO_PEREGRINACAO * maxi(1, nivel(state))

static func pode_peregrinar(state: Dictionary) -> Dictionary:
	if nivel(state) <= 0:
		return {"ok": false, "msg": "Não há o que expiar."}
	var Jogo = load("res://scripts/jogo.gd")
	if Jogo.acabou(state):
		return Jogo.recusa_fim(state)
	if Jogo.esta_preso(state):
		return Jogo.recusa_preso(state)
	if int(state.get("dia", 1)) + DIAS_PEREGRINACAO > Jogo.DIAS_POR_MES + 1:
		return {"ok": false,
			"msg": "Uma peregrinação leva %d dias, e o mês acabou. Feche o mês antes." % DIAS_PEREGRINACAO}
	var custo := custo_peregrinacao(state)
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false,
			"msg": "A ordem pede %d de ouro em esmola. Você não tem." % custo}
	return {"ok": true}

static func peregrinar(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	var pode := pode_peregrinar(state)
	if not bool(pode.get("ok", false)):
		return pode
	var Jogo = load("res://scripts/jogo.gd")
	var Livro = load("res://scripts/livro.gd")
	var custo := custo_peregrinacao(state)
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) - custo
	Livro.registrar(state, "medo", "ouro", -custo, "Peregrinação")
	state["jogador"]["crueldade"] = maxi(0, nivel(state) - 1)
	state["jogador"]["meses_limpos"] = 0
	for i in DIAS_PEREGRINACAO:
		Jogo.passar_dia(state, log)
		if state.get("fim") != null:
			break
	if log.is_valid():
		log.call("Dois dias de estrada descalço e %d de ouro em esmola. Quem te viu passar não vai contar a mesma história de antes." % custo)
	return {"ok": true, "custo": custo,
		"msg": "Um ponto de crueldade apagado — a pé, e pago. Restam %d." % nivel(state)}

## O texto que a interface mostra. Vazio abaixo do limiar — antes disso a
## crueldade é uma marca no seu nome, não um sistema.
##
## Diz o que o medo DÁ, o que ele COBRA e o que ele já MATOU. Essa terceira
## parte é a que faltava: o jogador cruzava o ponto em que a redenção pelo
## bom governo deixa de ser possível sem nada na tela avisar.
static func descricao(state: Dictionary) -> String:
	var n := nivel(state)
	if n < LIMIAR:
		return ""
	var txt := "Temido (%d). A tropa aguenta soldo atrasado, e você pode cobrar imposto de guerra. Em troca: relação limitada a %d nas cortes e felicidade limitada a %d na sua vila." % [
		n, teto_de_relacao(state), teto_de_felicidade(state)]
	var mortos: Array = []
	if teto_de_felicidade(state) < 65:
		mortos.append("o bom governo não apaga mais nada (a vila não chega aos 65 exigidos)")
	if teto_de_relacao(state) < 60:
		mortos.append("nenhuma corte fecha aliança com você")
	if teto_de_felicidade(state) < 50:
		mortos.append("a vitória por Legitimidade está fora de alcance")
	if not mortos.is_empty():
		txt += " Neste ponto, %s. Só a peregrinação ainda tira." % ", e ".join(mortos)
	return txt
