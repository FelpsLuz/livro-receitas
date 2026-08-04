# ============================================================
# FILA DE RECRUTAMENTO — treino cronometrado, com Timer.
#
# A fila é FIFO e mora INTEIRA no `state`: um Timer é um nó da cena e o save
# é um Dictionary em JSON. Se o tempo restante vivesse no Timer, quem salvasse
# no meio do treino perderia o lote. Aqui o Timer só empurra o relógio —
# a verdade está sempre no dicionário, e por isso atravessa save/load intacta.
#
# Quem avança o tempo:
#   · o Timer da cena, 1 minuto de jogo por segundo real
#   · o turno mensal do jogo, 600 minutos de uma vez
# Ambos entram por Relogio.avancar(), que também empurra as marchas.
# Os dois passam pelo MESMO caminho, então o comportamento é idêntico nos dois
# modos de jogo e os testes exercitam o código de verdade.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Compatibilidade: o mundo agora tem um relógio só (relogio.gd) e a unidade
## é o MINUTO DE JOGO. Mantido para quem ainda referencia a constante antiga.
const SEG_POR_MES := 600

## Quartel melhor treina mais rápido: -8% por nível de terra, com piso.
static func tempo_de(state: Dictionary, tipo: String) -> int:
	var base: int = int(Dados.TEMPO_TREINO.get(tipo, 60))
	var nivel: int = 0
	if state.get("terra") != null:
		nivel = int(state["terra"]["nivel"])
	return maxi(5, roundi(base * (1.0 - nivel * 0.08)))

## População já comprometida: tropas prontas MAIS tudo que está na fila.
## Sem contar a fila, o jogador enfileira 500 cavaleiros com 20 camponeses.
static func pop_usada(state: Dictionary) -> int:
	var t := 0
	# `.get` e não índice direto: um save antigo pode carregar uma chave de
	# tropa que não existe mais no catálogo, e isso não pode derrubar o jogo
	for tipo in state["jogador"]["tropas"]:
		var d = Dados.TROPAS.get(tipo)
		if d != null:
			t += int(state["jogador"]["tropas"][tipo]) * int(d.get("pop", 1))
	for item in fila(state):
		var d2 = Dados.TROPAS.get(item["tipo"])
		if d2 != null:
			t += int(item["restantes"]) * int(d2.get("pop", 1))
	return t

## Teto de população: sem terra, o mercenário sustenta um bando pequeno.
static func pop_maxima(state: Dictionary) -> int:
	if state.get("terra") == null:
		return 30
	return int(state["terra"]["populacao"])

static func fila(state: Dictionary) -> Array:
	if not state.has("fila_recrutamento"):
		state["fila_recrutamento"] = []
	return state["fila_recrutamento"]

## Coloca um lote na fila. O ouro sai AGORA (o quartel compra o aço na hora).
static func enfileirar(state: Dictionary, tipo: String, qtd: int) -> Dictionary:
	if qtd <= 0:
		return {"ok": false, "msg": "Quantidade inválida."}
	if not Dados.TROPAS.has(tipo):
		return {"ok": false, "msg": "Tropa desconhecida."}
	var custo: int = int(Dados.TROPAS[tipo]["custo"]) * qtd
	if int(state["jogador"]["ouro"]) < custo:
		return {"ok": false, "msg": "Custa %d de ouro." % custo}
	if tipo == "campones" and state.get("terra") == null:
		return {"ok": false, "msg": "Camponeses vêm da SUA terra — e você não tem uma."}
	var precisa: int = int(Dados.TROPAS[tipo].get("pop", 1)) * qtd
	var teto := pop_maxima(state)
	if pop_usada(state) + precisa > teto:
		return {"ok": false, "msg": "Sua terra não sustenta tanta gente (%d/%d)."
			% [pop_usada(state) + precisa, teto]}

	state["jogador"]["ouro"] -= custo
	var f := fila(state)
	# `restante` é o que falta para a PRÓXIMA unidade sair. Só o lote da
	# frente tem cronômetro andando; os de trás esperam a vez (um quartel só).
	f.append({"tipo": tipo, "restantes": qtd, "restante": tempo_de(state, tipo)})
	return {"ok": true, "msg": "%d× %s em treinamento (%d min cada)."
		% [qtd, Dados.TROPAS[tipo]["nome"], tempo_de(state, tipo)]}

# ------------------------------------------------------------
# NÚCLEO GENÉRICO DA FILA
# O jogador e os reis NPCs treinam pelas MESMAS regras. A diferença é só de
# onde sai o tempo de treino e para onde vai o recruta — então isso vira
# parâmetro, e não uma segunda implementação que diverge com o tempo.
# ------------------------------------------------------------
## `tempo_fn(tipo) -> int` e `entregar_fn(tipo) -> void`.
static func avancar_fila(f: Array, minutos: int, tempo_fn: Callable,
		entregar_fn: Callable) -> int:
	var entregues := 0
	var restante := minutos
	while restante > 0 and not f.is_empty():
		var item: Dictionary = f[0]
		var falta: int = int(item["restante"])
		if restante < falta:
			item["restante"] = falta - restante
			restante = 0
			break
		restante -= falta
		var tipo: String = item["tipo"]
		entregar_fn.call(tipo)
		item["restantes"] = int(item["restantes"]) - 1
		entregues += 1
		if int(item["restantes"]) <= 0:
			f.pop_front()
			if not f.is_empty():
				f[0]["restante"] = int(tempo_fn.call(f[0]["tipo"]))
		else:
			item["restante"] = int(tempo_fn.call(tipo))
	return entregues

## Empurra o cronômetro. É o único ponto que entrega tropa.
##
## O laço tem que ser `while`: avançar um mês de uma vez (600 min) precisa
## entregar o LOTE INTEIRO, não uma unidade. E o excedente de cada entrega
## é reaproveitado na próxima — senão a fila anda em passo de tartaruga
## sempre que o jogador pula vários turnos.
static func avancar(state: Dictionary, minutos: int, log: Callable = Callable()) -> int:
	var f := fila(state)
	var entregues := 0
	var restante := minutos
	while restante > 0 and not f.is_empty():
		var item: Dictionary = f[0]
		var falta: int = int(item["restante"])
		if restante < falta:
			item["restante"] = falta - restante
			restante = 0
			break
		# a unidade da frente ficou pronta
		restante -= falta
		var tipo: String = item["tipo"]
		state["jogador"]["tropas"][tipo] = int(state["jogador"]["tropas"].get(tipo, 0)) + 1
		item["restantes"] = int(item["restantes"]) - 1
		entregues += 1
		Sinais.emitir(&"tropa_pronta", {"tipo": tipo, "restantes": int(item["restantes"])})
		if int(item["restantes"]) <= 0:
			f.pop_front()
			if f.is_empty():
				Sinais.emitir(&"fila_vazia")
			else:
				f[0]["restante"] = tempo_de(state, f[0]["tipo"])
		else:
			item["restante"] = tempo_de(state, tipo)
	if entregues > 0 and log.is_valid():
		log.call("O quartel entregou %d recruta(s)." % entregues)
	return entregues

## Cancelar devolve METADE do ouro do que ainda não saiu — a fila não pode
## virar cofre sem risco.
static func cancelar(state: Dictionary, indice: int) -> Dictionary:
	var f := fila(state)
	if indice < 0 or indice >= f.size():
		return {"ok": false, "msg": "Nada nessa posição da fila."}
	var item: Dictionary = f[indice]
	var volta: int = int(int(Dados.TROPAS[item["tipo"]]["custo"]) * int(item["restantes"]) * 0.5)
	state["jogador"]["ouro"] = int(state["jogador"]["ouro"]) + volta
	f.remove_at(indice)
	if indice == 0 and not f.is_empty():
		f[0]["restante"] = tempo_de(state, f[0]["tipo"])
	return {"ok": true, "msg": "Treinamento cancelado. %d de ouro devolvidos." % volta}

## Minutos de jogo até a fila inteira acabar — para a barra de progresso.
static func minutos_restantes(state: Dictionary) -> int:
	var t := 0
	var primeiro := true
	for item in fila(state):
		var unitario := tempo_de(state, item["tipo"])
		if primeiro:
			t += int(item["restante"]) + unitario * (int(item["restantes"]) - 1)
			primeiro = false
		else:
			t += unitario * int(item["restantes"])
	return t
