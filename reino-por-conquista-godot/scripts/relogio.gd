# ============================================================
# RELÓGIO — a única fonte de "que horas são".
#
# Antes havia dois contadores: segundos no quartel e meses no mundo. Dois
# relógios sempre acabam discordando sobre quando algo terminou. Aqui existe
# UMA unidade — o minuto de jogo — e tudo que tem prazo se pendura nela:
#
#   1 dia  =  20 minutos de jogo
#   1 mês  = 600 minutos = 30 dias
#
# A escala não é acidental: `vel` das tropas é minutos-por-campo (escala
# Tribal Wars), então marchar 12 campos com lanceiros (vel 18) custa 216
# minutos ≈ 11 dias. O tempo de viagem sai da tabela de tropas sem conversão.
#
# Quem empurra o relógio:
#   · o Timer da cena, 1 minuto por segundo real  → sensação de tempo correndo
#   · o turno mensal (`passar_mes`), 600 de uma vez
# Os dois passam pelo MESMO `avancar()`, então nada se comporta diferente
# entre o modo com relógio e o modo turno a turno.
# ============================================================
extends RefCounted

const Recrutamento = preload("res://scripts/recrutamento.gd")
const Marchas = preload("res://scripts/marchas.gd")

## UM RELÓGIO SÓ, e o DIA é o átomo dele.
##
## Antes havia duas réguas: o dia do jogador (um terço do mês) e o "dia"
## das marchas e do quartel (um trigésimo). Um exército atravessava o
## continente em "12 dias" que não eram os 3 dias do mês — e por isso a
## conta nunca fechava na cabeça de ninguém.
##
## Agora MINUTOS_POR_DIA × Jogo.DIAS_POR_MES == MINUTOS_POR_MES, e um teste
## trava essa igualdade. Marcha, treino, viagem, trabalho e prisão medem o
## tempo na MESMA unidade que o botão do rodapé.
const MINUTOS_POR_DIA := 200
const MINUTOS_POR_MES := 600      # 3 dias de jogo

static func agora(state: Dictionary) -> int:
	return int(state.get("minuto", 0))

## Avança o tempo e deixa cada sistema com prazo se resolver.
## Devolve o que aconteceu, para a UI decidir se precisa redesenhar.
static func avancar(state: Dictionary, minutos: int, log: Callable = Callable()) -> Dictionary:
	if minutos <= 0:
		return {"recrutas": 0, "marchas": []}
	state["minuto"] = agora(state) + minutos
	var recrutas := Recrutamento.avancar(state, minutos, log)
	var eventos := Marchas.avancar(state, minutos, log)
	return {"recrutas": recrutas, "marchas": eventos}

## Conversões para a UI — o jogador pensa em dias, não em minutos.
static func em_dias(minutos: int) -> float:
	return minutos / float(MINUTOS_POR_DIA)

## O jogador só age em dias INTEIROS, então o texto arredonda para CIMA:
## "chega em 1 dia" tem que significar "no próximo clique", nunca "quase".
static func texto_dias(minutos: int) -> String:
	if minutos <= 0:
		return "agora"
	var d := ceili(em_dias(minutos))
	return "1 dia" if d <= 1 else "%d dias" % d

## Quantos cliques de "Passar o dia" faltam para isto terminar.
static func dias_ate(minutos: int) -> int:
	return maxi(0, ceili(em_dias(minutos)))
