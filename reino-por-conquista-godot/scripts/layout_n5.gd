# ============================================================
# LAYOUT N5 — onde cada peça fica, em pixels nativos (addendum v3.3 §B).
# Fonte única do POSICIONAMENTO: o blockout desenha ColorRects daqui, e os
# sprites reais entram nas MESMAS coordenadas quando o lote for aprovado.
# É esta tabela que a trilha do terreno vai ligar — por isso ela existe
# antes de qualquer asset (v3.3 §H: "trilha tem que ligar coisa").
#
# Convenção: x = CENTRO horizontal, base = linha do PÉ (Y do chão).
# `de`/`ate` = níveis em que a peça existe (herda o esquema do v1).
# O elenco é o do panorama v1 (19 construções + natureza), reposicionado
# em AGRUPAMENTOS com sobreposição e escalonamento — o v1 espalhava as
# peças em fileira, que é exatamente o que a §B.2 manda testar.
# ============================================================
class_name LayoutN5

# Castelo: a posição foi DECIDIDA por medida contra a crista da placa
# espelhada (ver tests/render_blockout.gd, que reimprime a conta). O maciço
# ocupa x=137..219 com topo em y=32; centrar o castelo em 200 o enterraria
# no ombro do maciço. Em cx=272 a borda esquerda (224) limpa o maciço e o
# topo do castelo fura a linha do horizonte lateral.
# h=80 (topo y=36, v3.4 §B): ~2,3× a altura de uma casa. Ainda abaixo dos
# 4,4× da referência, que é o teto do que o formato 2:1 comporta sem comer
# o céu — registrado como divergência conhecida, não como acerto.
const CASTELO := {"cx": 272, "base": 116, "w": 96, "h": 80}
const PORTAO := {"cx": 272, "base": 116, "w": 28, "h": 18}
# Torres da muralha em intervalos NÃO uniformes (v3 §C / v3.1). Sobem
# acima da cortina: são os acentos verticais que quebram a barra de 400px
# na silhueta — sem eles a muralha lê como fileira (medido no blockout).
const TORRES := [96, 208, 356]
const TORRE_ALTURA := 30
const MURALHA_ALTURA := 12

# Ponte no centro do rio; a trilha sobe até a praça e vira para o portão —
# é o vetor de valor claro que conduz o olho até o castelo (v3 §F.1).
const PONTE := {"cx": 200, "base": 190, "w": 34, "h": 14}
const PRACA := {"cx": 198, "base": 158, "w": 46, "h": 20}   # ≥40×20 (v4 §C.3)
const TRILHA := [
	Vector2i(200, 180), Vector2i(199, 168), Vector2i(198, 158),
	Vector2i(214, 150), Vector2i(240, 138), Vector2i(262, 126),
	Vector2i(272, 118),
]
# Ramais curtos da praça para os agrupamentos laterais.
const RAMAIS := [
	[Vector2i(198, 158), Vector2i(160, 152), Vector2i(120, 146)],
	[Vector2i(214, 150), Vector2i(260, 156), Vector2i(300, 152)],
]

# grupo: só para a verificação de agrupamento (nenhuma peça pode ficar só)
const PECAS := [
	# --- agrupamento OESTE: moinho, horta, casa ---
	{"n": "arvore_carvalho", "g": "oeste", "cx": 24, "base": 153, "w": 30, "h": 38, "de": 0},
	{"n": "arvore_pinheiro", "g": "oeste", "cx": 44, "base": 137, "w": 22, "h": 30, "de": 0},
	{"n": "moinho_vento", "g": "oeste", "cx": 68, "base": 145, "w": 34, "h": 46, "de": 4},
	{"n": "pan_horta", "g": "oeste", "cx": 88, "base": 161, "w": 34, "h": 12, "de": 1},
	{"n": "casa_camponesa", "g": "oeste", "cx": 108, "base": 139, "w": 44, "h": 36, "de": 1},
	{"n": "pan_galinha", "g": "oeste", "cx": 104, "base": 165, "w": 8, "h": 8, "de": 1},
	{"n": "carroca", "g": "oeste", "cx": 126, "base": 157, "w": 22, "h": 14, "de": 2},

	# --- agrupamento CENTRO: a praça e a feira ---
	{"n": "pan_tenda_circo", "g": "centro", "cx": 167, "base": 163, "w": 30, "h": 24, "de": 2},
	{"n": "barraca_mercado", "g": "centro", "cx": 186, "base": 149, "w": 26, "h": 20, "de": 2},
	{"n": "poco_pedra", "g": "centro", "cx": 198, "base": 159, "w": 16, "h": 18, "de": 1},
	{"n": "pan_tenda_verde", "g": "centro", "cx": 214, "base": 166, "w": 26, "h": 22, "de": 2},
	{"n": "casa_camponesa_2", "g": "centro", "cx": 218, "base": 143, "w": 44, "h": 42, "de": 1},

	# --- agrupamento LESTE: ofícios, academia, estábulo ---
	{"n": "pan_casa_vermelha", "g": "leste", "cx": 280, "base": 155, "w": 40, "h": 32, "de": 4},
	{"n": "ferraria", "g": "leste", "cx": 312, "base": 141, "w": 40, "h": 42, "de": 3},
	{"n": "pan_porco", "g": "leste", "cx": 306, "base": 164, "w": 12, "h": 10, "de": 2},
	{"n": "pan_academia_pedra", "g": "leste", "cx": 346, "base": 147, "w": 48, "h": 34, "de": 4},
	{"n": "pan_horta_2", "g": "leste", "cx": 352, "base": 162, "w": 34, "h": 12, "de": 2},
	{"n": "pan_estabulo", "g": "leste", "cx": 378, "base": 138, "w": 44, "h": 28, "de": 3},
	{"n": "pan_cavalo", "g": "leste", "cx": 384, "base": 158, "w": 18, "h": 16, "de": 3},
	{"n": "arvore_pinheiro_2", "g": "leste", "cx": 394, "base": 151, "w": 22, "h": 44, "de": 0},
]

# Aldeões (v3 §4): a RÉGUA DE ESCALA da cena, 6×10px. N5 = 15, na tabela de
# densidade da spec (N0:2 … N5:15). Postados na praça, nas trilhas e nos
# agrupamentos — nenhum solto no vazio.
const ALDEOES_POR_NIVEL := [2, 4, 6, 9, 12, 15]
const ALDEOES := [
	# fundo, junto à muralha — 8px de altura (perspectiva)
	Vector3i(96, 128, 8), Vector3i(150, 126, 8),
	Vector3i(238, 125, 8), Vector3i(300, 129, 8),
	# meio, na praça e nas trilhas — 9px
	Vector3i(190, 152, 9), Vector3i(204, 155, 9), Vector3i(198, 148, 9),
	Vector3i(212, 158, 9), Vector3i(176, 156, 9), Vector3i(166, 161, 9),
	Vector3i(276, 150, 9),
	# frente, perto da margem — 10px, o tamanho de régua da spec
	Vector3i(128, 166, 10), Vector3i(250, 164, 10),
	Vector3i(330, 167, 10), Vector3i(356, 163, 10),
]


static func pecas_do_nivel(nivel: int) -> Array:
	var saida: Array = []
	for p in PECAS:
		if nivel >= int(p["de"]) and nivel <= int(p.get("ate", 99)):
			saida.append(p)
	return saida
