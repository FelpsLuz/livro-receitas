# ============================================================
# ESTAÇÕES DO ANO — o inverno é o inimigo que não se pode subornar.
#
# Todo sistema que consome ou produz passa por aqui: a fazenda multiplica a
# colheita pela estação, o cerco multiplica o upkeep. Em dezembro, janeiro e
# fevereiro as fazendas PARAM e manter homens acampados custa o dobro — é
# isso que transforma "quando atacar" numa decisão em vez de um detalhe.
#
# Os NPCs leem a mesma tabela, então o mapa inteiro se retrai no frio e
# volta a marchar na primavera. Nenhuma regra especial para o jogador.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

## Qual estação corresponde a um mês (1-12).
static func do_mes(mes: int) -> String:
	# normaliza para 1..12 aceitando mês 0, 13 ou negativo (o relógio soma
	# meses sem se preocupar em virar o ano)
	var m: int = ((int(mes) - 1) % 12 + 12) % 12 + 1
	for id in Dados.ESTACOES:
		if Dados.ESTACOES[id]["meses"].has(m):
			return id
	return "primavera"

static func atual(state: Dictionary) -> String:
	return do_mes(int(state.get("mes", 3)))

static func ficha(state: Dictionary) -> Dictionary:
	return Dados.ESTACOES[atual(state)]

static func nome(state: Dictionary) -> String:
	return str(ficha(state)["nome"])

## Multiplicador da produção de comida. Zero no inverno: a terra não dá nada,
## e quem não encheu o celeiro no verão passa fome com exército e tudo.
static func fator_comida(state: Dictionary) -> float:
	return float(ficha(state)["comida"])

## Multiplicador do custo de MANTER exército em campo (cerco).
## No inverno dobra — somado ao dobro que o cerco já cobra, são quatro vezes.
static func fator_cerco(state: Dictionary) -> float:
	return float(ficha(state)["cerco"])

static func e_inverno(state: Dictionary) -> bool:
	return atual(state) == "inverno"

## Cor de acento da estação, para a UI mudar de temperatura junto com o mundo.
static func cor(state: Dictionary) -> Color:
	return Color(str(ficha(state)["cor"]))

## Aviso curto para a barra de status.
static func nota(state: Dictionary) -> String:
	return str(ficha(state)["nota"])

## Quantos meses faltam para a estação virar — a UI usa para avisar que o
## inverno está chegando, que é quando a decisão de sitiar ainda dá tempo.
static func meses_ate_virar(state: Dictionary) -> int:
	var m: int = int(state.get("mes", 3))
	var e := do_mes(m)
	var n := 0
	while n < 12:
		n += 1
		if do_mes(m + n) != e:
			return n
	return 0

static func proxima(state: Dictionary) -> String:
	return do_mes(int(state.get("mes", 3)) + meses_ate_virar(state))
