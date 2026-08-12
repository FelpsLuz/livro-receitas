# ============================================================
# SONDA DE BALANCEAMENTO — a arbitragem depois do Mapa Comercial.
#
# O teste alfa flagrou: 150 → ~22.000 de ouro em 24 meses comprando
# barato e vendendo caro, sem risco. O Bloco I plantou os freios (mapa
# pago que vence todo mês, viagem que come dias e sofre assalto, oferta
# elástica que sobe o preço de quem compra e derruba o de quem vende).
# Esta sonda MEDE o que sobrou do exploit: um comerciante ganancioso,
# jogando só o jogo do comércio, por 24 meses, cinco vidas.
#
#   godot --headless --path . --script res://tests/medir_arbitragem.gd
#
# Não roda nas suítes: é instrumento de balanceamento, não asserção.
# ============================================================
extends SceneTree

const Jogo = preload("res://scripts/jogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Viagem = preload("res://scripts/viagem.gd")
const Dados = preload("res://scripts/dados.gd")

## O mercador GANANCIOSO compra até o ouro acabar (a estratégia do
## exploit do teste alfa); o SENSATO para quando o lote seguinte deixa de
## pagar. As duas medidas juntas é que respondem a pergunta inteira: o
## exploit morreu E a rota ainda paga a quem sabe negociar?
var ganancioso := false

func _initialize() -> void:
	# três bolsas de partida: o pobre do início, o remediado do meio de
	# jogo e o rico — porque a pergunta não é só "o exploit morreu?", é
	# "o comércio ainda PAGA para quem tem capital de giro?"
	for modo in [false, true]:
		ganancioso = modo
		print("--- mercador %s ---" % ("GANANCIOSO (compra até quebrar)" if modo else "sensato"))
		for bolsa in [150, 1000, 4000]:
			var finais: Array = []
			for vida in 5:
				finais.append(_uma_vida(24, int(bolsa)))
			finais.sort()
			var soma := 0
			for o in finais:
				soma += int(o)
			print("bolsa %d → 24 meses: mediana %d · média %d · pior %d · melhor %d" % [
				int(bolsa), int(finais[2]), soma / finais.size(), int(finais[0]), int(finais[4])])
	quit()

func _uma_vida(meses: int, bolsa: int) -> int:
	var st: Dictionary = Jogo.novo_jogo("Sonda")
	st["jogador"]["ouro"] = bolsa
	var mes0: int = int(st["mes"]) + int(st["ano"]) * 12
	while int(st["mes"]) + int(st["ano"]) * 12 - mes0 < meses and st["fim"] == null:
		st["evento_pendente"] = null
		_mes_de_comercio(st)
	return int(st["jogador"]["ouro"])

## Um mês na vida do comerciante: mapa, melhor rota, carga cheia, estrada.
func _mes_de_comercio(st: Dictionary) -> void:
	# 1) a licença do mês — sem ela nenhum armazém abre
	if not Economia.mapa_valido(st):
		if int(st["jogador"]["ouro"]) >= Taverna.PRECO_ROTA:
			Taverna.comprar_rota(st)
		else:
			_queimar_mes(st)          # quebrou: espera (não é o caso na prática)
			return
	# 2) a melhor rota que ainda cabe no mês (1 dia de estrada + 1 de folga)
	var local: String = str(st["local"])
	var melhor := {"lucro": 0, "g": "", "dest": ""}
	for reino in st["reinos"]:
		var dest: String = str(reino["id"])
		if dest == local:
			continue
		var est: Dictionary = Viagem.estimar(st, dest)
		if not bool(est.get("ok", false)) or int(est["dias"]) + int(st["dia"]) > Jogo.DIAS_POR_MES + 1:
			continue
		for g_id in Dados.MERCADORIAS:
			var lucro: int = Economia.preco_de(st, dest, g_id) - Economia.preco_de(st, local, g_id)
			if lucro > int(melhor["lucro"]):
				melhor = {"lucro": lucro, "g": g_id, "dest": dest}
	if str(melhor["g"]) == "":
		_queimar_mes(st)
		return
	# 3) carga: o mercador SENSATO para quando o lote seguinte deixaria de
	# pagar. Comprar até o ouro acabar é o que fazia a sonda anterior — e
	# como cada lote empurra a própria oferta para baixo (preço para cima),
	# a carga cheia era comprada no fim a 5× e vendida no fim a 1/5.
	var alvo_g: String = str(melhor["g"])
	var dest_g: String = str(melhor["dest"])
	for i in 40:
		if not ganancioso:
			var aqui_p: int = Economia.preco_de(st, local, alvo_g)
			var la_p: int = Economia.preco_de(st, dest_g, alvo_g)
			if la_p <= roundi(aqui_p * 1.15):   # margem mínima de 15%
				break
		var r: Dictionary = Economia.comprar(st, local, alvo_g, 5)
		if not bool(r["ok"]):
			break
	# 4) a estrada, com o que ela guarda
	var rv: Dictionary = Viagem.viajar(st, str(melhor["dest"]))
	if bool(rv.get("ok", false)):
		var enc: Dictionary = rv.get("encontro", {})
		if str(enc.get("tipo", "")) == "assalto":
			Viagem.resolver_assalto(st)
		# caravana: o comerciante honesto deixa passar (sonda mede COMÉRCIO)
	# 5) vende no destino enquanto o preço ainda vale a viagem; o resto
	# volta na carga para o mês seguinte (a venda derruba o próprio preço)
	for i in 40:
		if Economia.preco_de(st, str(st["local"]), alvo_g) <= 1:
			break
		var r2: Dictionary = Economia.vender(st, str(st["local"]), alvo_g, 5)
		if not bool(r2["ok"]):
			break
	_queimar_mes(st)

func _queimar_mes(st: Dictionary) -> void:
	var mes_atual: int = int(st["mes"])
	var guarda := 0
	while int(st["mes"]) == mes_atual and st["fim"] == null and guarda < 6:
		st["evento_pendente"] = null
		Jogo.passar_dia(st, Callable())
		guarda += 1
