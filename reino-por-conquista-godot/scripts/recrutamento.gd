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
## Minutos por LOTE de cinco recrutas (é assim que o quartel contrata) —
## não por homem. Terra evoluída treina mais rápido: quartel de verdade,
## instrutor de verdade.
const POR_LOTE := 5

static func tempo_de(state: Dictionary, tipo: String) -> int:
	var base: int = int(Dados.TEMPO_TREINO.get(tipo, 25))
	var nivel: int = 0
	if state.get("terra") != null:
		nivel = int(state["terra"]["nivel"])
	return maxi(3, roundi(base * (1.0 - nivel * 0.08)))

## A terra dá (ou não) o que a tropa exige. Cavalo pede pasto e cocheira:
## sem Aldeia não há cavalaria leve, sem Burgo não há cavalaria pesada.
static func nivel_exigido(tipo: String) -> int:
	return int(Dados.NIVEL_MINIMO_TROPA.get(tipo, 0))

static func pode_recrutar(state: Dictionary, tipo: String) -> Dictionary:
	var exige := nivel_exigido(tipo)
	if exige <= 0:
		return {"ok": true}
	var t = state.get("terra")
	if t == null:
		return {"ok": false,
			"msg": "Cavalo não se cria em acampamento: compre terras primeiro."}
	if int(t["nivel"]) < exige:
		return {"ok": false,
			"msg": "%s exige %s — a sua terra ainda é %s." % [
				str(Dados.TROPAS[tipo]["nome"]),
				str(Dados.NIVEIS_TERRA[exige]["nome"]),
				str(Dados.NIVEIS_TERRA[int(t["nivel"])]["nome"])]}
	return {"ok": true}

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

## PORTÃO DE PROGRESSÃO: o teto do exército sai do NÍVEL da terra, não da
## população. Construir é o que libera exército — sem isso, nada impede
## enfileirar dez mil homens no segundo dia. A população continua limitando
## por outro caminho: quem vira soldado deixa de pagar imposto.
static func pop_maxima(state: Dictionary) -> int:
	if state.get("terra") == null:
		return 20                      # o bando que um mercenário sem terra sustenta
	var nivel: int = clampi(int(state["terra"]["nivel"]), 0, Dados.NIVEIS_TERRA.size() - 1)
	# o teto é o menor entre o que a infraestrutura comporta e o que há de gente
	return mini(int(Dados.NIVEIS_TERRA[nivel]["cap"]), int(state["terra"]["populacao"]))

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
	var porta := pode_recrutar(state, tipo)
	if not bool(porta["ok"]):
		return porta
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
	var Relogio = load("res://scripts/relogio.gd")
	return {"ok": true, "msg": "%d× %s em treinamento — o lote sai em %s."
		% [qtd, Dados.TROPAS[tipo]["nome"],
			Relogio.texto_dias(tempo_de(state, tipo) * maxi(1, ceili(float(qtd) / POR_LOTE)))]}

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
		_diz(log, "O quartel entregou %d recruta(s)." % entregues)
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

## Fala com o diário do jogo SÓ se houver diário. A assinatura
## `log: Callable = Callable()` prometia log opcional, e 71 das 100
## chamadas ignoravam a promessa: qualquer chamador sem log (teste,
## sonda, ferramenta) morria no meio da função, deixando o estado
## pela metade. Uma porta só, e ela confere.
static func _diz(log: Callable, msg: String) -> void:
	if log.is_valid():
		log.call(msg)
