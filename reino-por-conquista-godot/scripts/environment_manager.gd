# ============================================================
# ENVIRONMENT MANAGER — a atmosfera Hi-Bit, por CanvasModulate.
#
# Autoload. Guarda a HORA e a ESTAÇÃO do mundo e devolve a cor do ambiente;
# cada cena que quiser ser tingida se REGISTRA e ganha um CanvasModulate no
# seu próprio viewport.
#
# Por que registrar em vez de tingir tudo
# ---------------------------------------
# CanvasModulate multiplica TODO o CanvasLayer em que vive. A interface deste
# jogo é uma tela de pergaminho com onze abas de texto; um autoload que põe um
# CanvasModulate na raiz deixaria a interface azul às 3h da manhã e ilegível.
# Isso já tinha sido aprendido antes: a cena antiga da cidade empacotava a luz
# num SubViewport próprio exatamente "sem tingir a interface de pergaminho".
# Aqui o gerente é global, mas o EFEITO é por viewport, e quem manda é a cena.
#
#   EnvironmentManager.registrar(meu_subviewport)
#   EnvironmentManager.definir_mes(estado["mes"])
#
# Por que a hora vem do JOGO e não do relógio
# -------------------------------------------
# O turno aqui é MENSAL. Um ciclo de dia/noite amarrado ao relógio de parede
# faria o sol nascer e se pôr enquanto o jogador lê um contrato, sem relação
# nenhuma com a partida. A hora padrão vem do MÊS: o inverno é escuro e frio,
# o verão é claro e quente. `ciclo_automatico` existe para vitrine e teste.
#
# Como os testes alcançam isto
# ----------------------------
# Igual ao barramento de sinais (ver scripts/sinais.gd): os testes rodam com
# `godot --script`, e NESSE MODO O AUTOLOAD NÃO É REGISTRADO. Citar o nome
# global como identificador derruba a suíte inteira em tempo de COMPILAÇÃO.
# Por isso nada no jogo escreve `EnvironmentManager` como identificador —
# usa-se `Ambiente.gerente()`, que resolve o nó em runtime e devolve null
# quando não há. A própria classe funciona instanciada à mão, e é assim que
# o teste a exercita.
# ============================================================
extends Node

## Cor do ambiente em cada fase do dia. Multiplicam a cena, então o BRANCO é
## o neutro: qualquer valor abaixo de 1 escurece aquele canal.
##
## Os valores não são estéticos por acaso — é a regra clássica de pixel art
## de que a noite não é "a mesma imagem mais escura", é a mesma imagem mais
## escura E deslocada para o azul, porque o olho perde sensibilidade ao
## vermelho no escuro (efeito Purkinje).
const DIA := Color(1.00, 1.00, 1.00)
const AURORA := Color(0.86, 0.78, 0.86)
const TARDE := Color(1.00, 0.86, 0.70)
const CREPUSCULO := Color(0.72, 0.62, 0.78)
const NOITE := Color(0.40, 0.46, 0.72)

## Tinta de estação, aplicada POR CIMA da hora. O inverno lava o croma e
## esfria; o outono aquece. Multiplicativo, como o resto.
const ESTACAO := {
	"primavera": Color(1.00, 1.00, 0.98),
	"verao": Color(1.04, 1.00, 0.92),
	"outono": Color(1.02, 0.94, 0.86),
	# O inverno esfria MAIS que as outras estações mudam, de propósito: a
	# arte da vila é de verão (grama verde, telhado seco), e a tinta é o
	# único agente que a leva para o frio — 0.90 no vermelho lavava tão
	# pouco que a neve caía sobre um gramado de julho. 0.82 dessatura o
	# verde de verdade sem afogar a leitura.
	"inverno": Color(0.82, 0.90, 1.08),
}

## Meses de cada estação — espelha Dados.ESTACOES, mas sem depender dele:
## este nó é de apresentação e não deve puxar a regra de jogo para dentro.
const MESES_ESTACAO := {
	3: "primavera", 4: "primavera", 5: "primavera",
	6: "verao", 7: "verao", 8: "verao",
	9: "outono", 10: "outono", 11: "outono",
	12: "inverno", 1: "inverno", 2: "inverno",
}

## Quanto tempo leva a transição quando a hora muda de uma vez (passar o mês).
const TRANSICAO := 0.9

signal ambiente_mudou(cor: Color)

## 0.0 = meia-noite · 0.25 = amanhecer · 0.5 = meio-dia · 0.75 = anoitecer
var hora: float = 0.5:
	set(v):
		hora = fposmod(v, 1.0)
		_aplicar()

var estacao: String = "verao":
	set(v):
		estacao = v if ESTACAO.has(v) else "verao"
		_aplicar()

## Só para vitrine e depuração: faz a hora correr sozinha.
var ciclo_automatico := false
var velocidade_ciclo := 0.05

## 0 desliga o efeito por completo (a cena fica com a cor crua da arte).
var intensidade: float = 1.0:
	set(v):
		intensidade = clampf(v, 0.0, 1.0)
		_aplicar()

var _modulates: Array[CanvasModulate] = []
var _tweens: Array[Tween] = []


# ------------------------------------------------------------
# ACESSO SEGURO — o jeito que o resto do jogo fala com este nó
# ------------------------------------------------------------
## Resolve o autoload em runtime. Devolve null nos testes com `--script`.
## Ver o cabeçalho: escrever o nome como identificador quebraria a suíte.
static func gerente() -> Node:
	var laco := Engine.get_main_loop()
	if laco is SceneTree and laco.root != null:
		return laco.root.get_node_or_null("EnvironmentManager")
	return null


# ------------------------------------------------------------
func _process(delta: float) -> void:
	if ciclo_automatico:
		hora = hora + delta * velocidade_ciclo


## Dá a este viewport um CanvasModulate ligado ao ciclo, e devolve o nó.
## Chamar duas vezes com o mesmo viewport não duplica nada.
func registrar(alvo: Node) -> CanvasModulate:
	if alvo == null:
		return null
	for m in _modulates:
		if is_instance_valid(m) and m.get_parent() == alvo:
			return m
	var cm := CanvasModulate.new()
	cm.name = "AmbienteHiBit"
	cm.color = cor_atual()
	alvo.add_child(cm)
	_modulates.append(cm)
	return cm


## Solta um viewport do ciclo (a cena saiu da árvore).
func esquecer(alvo: Node) -> void:
	for i in range(_modulates.size() - 1, -1, -1):
		var m := _modulates[i]
		if not is_instance_valid(m) or m.get_parent() == alvo:
			if is_instance_valid(m):
				m.queue_free()
			_modulates.remove_at(i)


## A hora e a estação a partir do MÊS do jogo. É o acoplamento certo: a
## partida anda de mês em mês, e a atmosfera anda junto.
func definir_mes(mes: int) -> void:
	var m := ((int(mes) - 1) % 12 + 12) % 12 + 1
	estacao = str(MESES_ESTACAO.get(m, "verao"))
	# O inverno tem dia CURTO: o "meio-dia" dele é mais fraco que o do verão.
	#
	# Os valores precisam cair na RAMPA (0.30→0.40), não no platô de DIA
	# (0.40→0.62). A primeira versão usava 0.42/0.46/0.50/0.52 — quatro
	# números diferentes, todos dentro do platô, então as estações só
	# trocavam de tinta e a luz não mudava nada. Medido: inverno e verão
	# davam a mesma luminância.
	match estacao:
		"inverno": hora = 0.345
		"outono": hora = 0.375
		"primavera": hora = 0.42
		_: hora = 0.50


## A cor do ambiente agora: hora × estação × intensidade.
func cor_atual() -> Color:
	var base := _cor_da_hora(hora)
	var tint: Color = ESTACAO.get(estacao, Color.WHITE)
	var c := Color(base.r * tint.r, base.g * tint.g, base.b * tint.b)
	# `intensidade` interpola de volta ao branco, que é o neutro do multiply
	return Color.WHITE.lerp(c, intensidade)


## Quão CLARA está a cena, em luminância percebida.
##
## `Color.v` não serve para esta pergunta: `v` é o canal MÁXIMO, então a
## tinta de inverno (0.90, 0.94, 1.06) devolve 1.06 e o inverno parece mais
## claro que o verão. Luminância pondera os canais como o olho pondera, e é
## ela que responde "está mais escuro?".
func luminancia() -> float:
	var c := cor_atual()
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## A rampa do dia, em cinco paradas. `lerp` entre elas e não uma curva:
## as paradas são o que um artista de pixel art escolheria, e interpolar
## entre elas mantém a intenção; uma senoide inventaria tons no meio.
func _cor_da_hora(h: float) -> Color:
	var paradas := [
		[0.00, NOITE], [0.22, NOITE], [0.30, AURORA], [0.40, DIA],
		[0.62, DIA], [0.72, TARDE], [0.82, CREPUSCULO], [0.90, NOITE],
		[1.00, NOITE],
	]
	for i in range(paradas.size() - 1):
		var a = paradas[i]
		var b = paradas[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var vao: float = float(b[0]) - float(a[0])
			var t: float = 0.0 if vao <= 0.0 else (h - float(a[0])) / vao
			return Color(a[1]).lerp(Color(b[1]), t)
	return DIA


func _aplicar() -> void:
	var c := cor_atual()
	for m in _modulates:
		if is_instance_valid(m):
			m.color = c
	ambiente_mudou.emit(c)


## Transição suave até uma hora nova — para o "passar o mês" não dar um
## corte seco de cor na tela.
func transitar_para_mes(mes: int) -> void:
	var antes := cor_atual()
	definir_mes(mes)
	var depois := cor_atual()
	if antes.is_equal_approx(depois):
		return
	for t in _tweens:
		if is_instance_valid(t):
			t.kill()
	_tweens.clear()
	for m in _modulates:
		if not is_instance_valid(m):
			continue
		m.color = antes
		var tw := create_tween()
		tw.tween_property(m, "color", depois, TRANSICAO)
		_tweens.append(tw)
