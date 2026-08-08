# ============================================================
# RETRATOS — quem aparece na Corte, no Mapa, na marcha e nos modais.
#
# ---- por que este arquivo voltou a desenhar ----
#
# O visual strip trocou os 250 pixels-a-pixel deste arquivo por um caixote
# cinza, e o efeito na tela era o pior defeito visual do jogo: TODA pessoa
# — os seis reis, os quatro chefes de clã, os três fregueses da taverna, os
# notáveis nascidos na partida, o interlocutor da conversa — aparecia como
# um retângulo vazio de 52px. A tela da conversa, que é a peça central do
# jogo, era um quadrado cinza e uma linha de texto.
#
# Um caixote é o placeholder certo para arte que vai chegar. Não é placeholder
# nenhum para arte que não vai chegar: os retratos são combinatórios (um por
# cidadão gerado em partida, e a lista muda a cada saga), então nunca houve
# um PNG possível para eles. Retrato de gente gerada em partida tem que ser
# GERADO, e é isso que este arquivo faz de novo.
#
# ---- por que em código e não em PNG ----
#
# Pelo mesmo motivo da paleta dos ícones estar em `icones.gd` e não assada
# em 38 arquivos: um retrato composto de traços paramétricos cobre um elenco
# infinito com uma tabela de cores, e trocar o tom da pele é uma linha em vez
# de uma pasta regerada. O elenco fixo (reis, clãs) usa o mesmo caminho — o
# id entra no gerador de sementes, e o mesmo id devolve sempre a mesma cara.
#
# ---- o que o retrato tem que fazer, e o que não ----
#
# Ele é lido a 32px numa linha de lista e a 128px na conversa. A 32 o que
# sobrevive é SILHUETA e MASSA DE COR: cabelo, barba, chapéu, cor da roupa.
# O detalhe de rosto existe para a conversa, e é só lá que ele é visto.
# Então a ordem de investimento foi essa, e não a inversa.
#
# `humor` continua sendo o contrato que a UI já usava: a relação vira
# sobrancelha e boca. É o único traço que muda para o MESMO id.
#
# Tamanhos preservados da arte antiga, porque são eles que seguram o layout:
#   retrato de pessoa e de tropa .... 64×64
#   ilustração de evento (faixa) .... 128×128
# ============================================================
extends RefCounted

const Arte = preload("res://scripts/arte.gd")

const PASTA := "res://assets/sprites/"
const LADO_RETRATO := 64
const LADO_EVENTO := 128

## Os eventos que têm ilustração. Continua sendo uma LISTA FECHADA: evento
## desconhecido devolve null e o modal segue só com texto. Não é detalhe de
## estilo — se qualquer string ganhasse arte, um typo apareceria como IMAGEM
## ERRADA no modal, e imagem errada é o defeito que ninguém liga ao typo.
const EVENTOS := ["cerco", "coroacao", "derrota", "emboscada", "fome",
	"inverno", "juramento", "rebeliao", "saque", "traicao"]

# ============================================================
# PALETAS
#
# Todas passam pelo mesmo filtro do resto da interface: nada saturado puro.
# Um retrato de 64px com uma túnica em vermelho cheio salta na frente do
# número que a linha carrega, e a linha existe pelo número.
# ============================================================

## Pele. Seis tons, do mais claro ao mais escuro, cada um com a sua sombra —
## a sombra NÃO é o tom multiplicado por um fator fixo: pele escura sombreia
## para o quente e pele clara para o frio, e usar um fator só devolve
## aquele cinza acinzentado que denuncia retrato gerado.
const PELE := [
	[Color("e8b48c"), Color("c4906c")],
	[Color("d9a077"), Color("b07a55")],
	[Color("c4855c"), Color("9c6440")],
	[Color("a3663f"), Color("7d4a2c")],
	[Color("7d4a2e"), Color("5c341f")],
	[Color("5a3620"), Color("3f2415")],
]

## Cabelo. Preto, castanho escuro, castanho, ruivo, louro escuro, grisalho,
## branco. O grisalho e o branco entram mais no elenco velho (ver `_semente`).
const CABELO := [
	[Color("1f1a17"), Color("120f0d")],
	[Color("3a2a1e"), Color("241a12")],
	[Color("5c4230"), Color("3d2b1f")],
	[Color("8a4a26"), Color("62331a")],
	[Color("a8873f"), Color("7d642c")],
	[Color("8e8578"), Color("6b645a")],
	[Color("d0c8ba"), Color("a49c90")],
]

## Roupa. Tons de reino: lã tingida, não seda de corte. O par é
## [tecido, sombra do tecido].
const ROUPA := [
	[Color("4a5a6b"), Color("35414e")],   # azul-ardósia
	[Color("6b4a4a"), Color("4e3535")],   # vinho apagado
	[Color("4f6b4a"), Color("394e35")],   # verde-musgo
	[Color("6b5c3a"), Color("4e422a")],   # ocre
	[Color("5a4a6b"), Color("41354e")],   # púrpura apagada
	[Color("3f4a4a"), Color("2c3535")],   # cinza-verde
	[Color("6b5a4a"), Color("4e4135")],   # castanho
]

## O fundo do retrato. É o terreno do card (Tema.ELEVADO) com uma vinheta
## radial: o retrato precisa assentar no card, não ser um selo colado nele.
## Não importa `tema.gd` de propósito — este arquivo roda em teste headless,
## onde não há Theme montado.
const FUNDO_A := Color("2b241d")
const FUNDO_B := Color("191512")

const CONTORNO := Color("120f0c")

# ============================================================
# SEMENTE — o mesmo id devolve sempre a mesma cara
# ============================================================

## Hash estável de string. `String.hash()` serve, mas mudou entre versões da
## engine no passado; um FNV-1a de quatro linhas não muda nunca, e um save
## antigo continua abrindo com os mesmos rostos.
static func _hash(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h

## Um gerador determinístico barato: cada chamada avança e devolve `n` valores.
class Semente extends RefCounted:
	var _e: int
	func _init(s: int) -> void:
		_e = s | 1
	func proximo(n: int) -> int:
		# xorshift32: distribuição boa o bastante para escolher entre sete
		# cabelos, e cabe em quatro linhas
		_e ^= (_e << 13) & 0xFFFFFFFF
		_e ^= _e >> 17
		_e ^= (_e << 5) & 0xFFFFFFFF
		_e &= 0xFFFFFFFF
		return (_e % maxi(1, n))
	func chance(pct: int) -> bool:
		return proximo(100) < pct

# ============================================================
# DESENHO — primitivas
# ============================================================

class Tela extends RefCounted:
	var img: Image
	func _init(lado: int) -> void:
		img = Image.create(lado, lado, false, Image.FORMAT_RGBA8)

	func ponto(x: int, y: int, cor: Color) -> void:
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			return
		# alfa compõe sobre o que já está lá: é o que deixa a vinheta e as
		# sombras somarem em vez de recortarem
		if cor.a >= 1.0:
			img.set_pixel(x, y, cor)
			return
		var b := img.get_pixel(x, y)
		img.set_pixel(x, y, b.lerp(cor, cor.a))

	func retangulo(x0: int, y0: int, w: int, h: int, cor: Color) -> void:
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				ponto(x, y, cor)

	## Elipse cheia. `cx, cy` é o centro, `rx, ry` os raios.
	##
	## `ymin` corta tudo acima daquela linha. Existe por causa do cabelo: a
	## maneira de desenhar um penteado que não é um chapéu é pintar a massa
	## de cabelo por cima do crânio inteiro e depois DEVOLVER o rosto a
	## partir da linha do cabelo. Sem esse corte, ou o cabelo é uma faixa
	## reta na testa (que lê como viseira) ou ele não encosta no crânio.
	func elipse(cx: float, cy: float, rx: float, ry: float, cor: Color,
			ymin: int = -9999) -> void:
		var x0 := int(floor(cx - rx))
		var x1 := int(ceil(cx + rx))
		var y0 := maxi(int(floor(cy - ry)), ymin)
		var y1 := int(ceil(cy + ry))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var dx := (x - cx) / maxf(0.001, rx)
				var dy := (y - cy) / maxf(0.001, ry)
				if dx * dx + dy * dy <= 1.0:
					ponto(x, y, cor)

	## Só a metade de baixo (ou de cima) de uma elipse — é como se faz ombro,
	## franja e queixo sem escrever três funções.
	func meia_elipse(cx: float, cy: float, rx: float, ry: float, cor: Color,
			baixo: bool) -> void:
		var y0 := int(cy) if baixo else int(floor(cy - ry))
		var y1 := int(ceil(cy + ry)) if baixo else int(cy)
		for y in range(y0, y1 + 1):
			for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
				var dx := (x - cx) / maxf(0.001, rx)
				var dy := (y - cy) / maxf(0.001, ry)
				if dx * dx + dy * dy <= 1.0:
					ponto(x, y, cor)

	## Contorno de 1px em volta de tudo que é opaco: é ele que faz a silhueta
	## sobreviver a 32px, e sem ele o retrato vira uma mancha no card.
	func contornar(cor: Color) -> void:
		var w := img.get_width()
		var h := img.get_height()
		var alvo: Array = []
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.5:
					continue
				var vizinho := false
				var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]
				for d in dirs:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h \
							and img.get_pixel(nx, ny).a > 0.5:
						vizinho = true
				if vizinho:
					alvo.append(Vector2i(x, y))
		for p in alvo:
			img.set_pixel(p.x, p.y, cor)

# ============================================================
# O RETRATO
# ============================================================

static var _cache: Dictionary = {}

## O rosto: crânio, mandíbula e a sombra do lado direito, numa chamada só.
##
## `ymin` corta o desenho acima daquela linha — é assim que o rosto volta
## por baixo do cabelo sem apagar o cabelo, e é por isso que existe como
## função em vez de estar escrito de uma vez no meio de `_pintar`.
static func _rosto(t: Tela, pele: Array, cy: float, ymin: int = -9999) -> void:
	t.elipse(32, cy, 13, 15, pele[0], ymin)
	# a mandíbula é mais estreita que o crânio
	t.elipse(32, cy + 9, 10, 8, pele[0], ymin)
	# uma fonte de luz só, vinda da esquerda-alta, em TODO o retrato: é o que
	# impede as peças de parecerem adesivos empilhados
	for y in range(maxi(int(cy - 15), ymin), int(cy + 18)):
		for x in range(33, 47):
			if t.img.get_pixel(x, y).is_equal_approx(pele[0]) and x > 36:
				t.img.set_pixel(x, y, pele[1])

## O desenho completo. `op` traz o que a chamada sabe e o gerador não
## adivinharia: gênero, ofício, coroa, capuz.
## A vinheta radial que assenta qualquer retrato no card — escura nos
## cantos, na cor da FACÇÃO quando há uma (`fundo` hex). Vive separada do
## gerador porque os bustos hi-bit também se sentam nela: é o que mantém
## a heráldica viva sob o rosto ilustrado.
static func _fundo_vinheta(fundo: String) -> Image:
	var img := Image.create(LADO_RETRATO, LADO_RETRATO, false, Image.FORMAT_RGBA8)
	var c := (LADO_RETRATO - 1) * 0.5
	var f_a := FUNDO_A
	var f_b := FUNDO_B
	if fundo != "":
		var base_f := Color(fundo)
		f_a = base_f.darkened(0.30)
		f_b = base_f.darkened(0.62)
	for y in LADO_RETRATO:
		for x in LADO_RETRATO:
			var d: float = Vector2(x - c, y - c).length() / (c * 1.42)
			img.set_pixel(x, y, f_a.lerp(f_b, clampf(d * 1.15, 0.0, 1.0)))
	return img

static func _pintar(sem: Semente, op: Dictionary) -> Image:
	var t := Tela.new(LADO_RETRATO)

	# ---- fundo: vinheta radial, escura nos cantos ----
	# um fundo chapado atrás de um rosto faz o rosto parecer recortado e
	# colado; a vinheta o assenta no card. Um rei traz o FUNDO na cor do
	# seu reino (op["fundo"]) — o traço que agrupa o retrato à facção.
	t.img.blit_rect(_fundo_vinheta(str(op.get("fundo", ""))),
		Rect2i(0, 0, LADO_RETRATO, LADO_RETRATO), Vector2i.ZERO)

	# ---- os traços: da FICHA quando há (reis), da semente quando não ----
	var pele: Array
	if op.has("pele"):
		pele = [Color(str(op["pele"][0])), Color(str(op["pele"][1]))]
	elif op.has("pele_idx"):
		pele = PELE[int(op["pele_idx"])]
	else:
		pele = PELE[sem.proximo(PELE.size())]
	var idoso: bool = bool(op.get("idoso", false))
	# grisalho e branco (índices 5 e 6) só entram no elenco velho: um rei de
	# 22 anos de cabelo branco é o tipo de detalhe que faz o gerador parecer
	# aleatório em vez de povoado
	var i_cab: int = sem.proximo(CABELO.size() - 2)
	if idoso and sem.chance(70):
		i_cab = 5 + sem.proximo(2)
	if op.has("cabelo_idx"):
		i_cab = int(op["cabelo_idx"])
	var cabelo: Array
	if op.has("cabelo"):
		cabelo = [Color(str(op["cabelo"][0])), Color(str(op["cabelo"][1]))]
	else:
		cabelo = CABELO[i_cab]
	var roupa: Array
	if op.has("roupa_cor"):
		roupa = [Color(str(op["roupa_cor"][0])), Color(str(op["roupa_cor"][1]))]
	else:
		roupa = ROUPA[int(op.get("roupa", sem.proximo(ROUPA.size())))]

	# ---- capa, ATRÁS dos ombros ----
	# uma meia-elipse maior por trás do busto: só as bordas externas
	# aparecem, que é como uma capa lê num busto de 64px
	if op.has("capa"):
		t.meia_elipse(32, 80, 34, 42, Color(str(op["capa"])), false)

	# ---- ombros ----
	# a meia-elipse baixa é o busto. Ela nasce fora do quadro (cy = 78) para
	# a curva que aparece ser só o topo do ombro — busto inteiro dentro de
	# 64px vira boneco de cabeça grande
	t.meia_elipse(32, 78, 30, 36, roupa[0], false)
	# sombra do lado direito: uma fonte de luz só, vinda da esquerda-alta,
	# em TODO o retrato. É o que impede as peças de parecerem adesivos
	for y in range(44, LADO_RETRATO):
		for x in range(34, LADO_RETRATO):
			if t.img.get_pixel(x, y).is_equal_approx(roupa[0]) and x > 36 + (y - 44) * 0.2:
				t.img.set_pixel(x, y, roupa[1])
	# gola: um V de pele entre os ombros, senão a túnica encosta no queixo
	t.elipse(32, 47, 7, 5, pele[0])

	# ---- pescoço ----
	t.retangulo(27, 36, 10, 12, pele[0])
	t.retangulo(34, 36, 3, 12, pele[1])
	# sombra do queixo sobre o pescoço: dois pixels que dão a única
	# profundidade que 64px comportam
	t.retangulo(27, 36, 10, 2, pele[1])

	# ---- cabeça ----
	#
	# A régua vertical do rosto, e ela é a peça que mais importa: crânio no
	# 11, LINHA DO CABELO no 18, sobrancelha no 22, olho no 25, nariz no 29,
	# boca no 36, queixo no 42. Toda peça de cabeça (cabelo, elmo, capuz,
	# touca) tem que terminar ANTES do 22, senão ela cobre a sobrancelha e o
	# retrato inteiro passa a ler como alguém de viseira — que foi
	# exatamente o defeito da primeira versão deste gerador.
	var cy := 26.0
	_rosto(t, pele, cy)
	var estilo: int = int(op["estilo"]) if op.has("estilo") else sem.proximo(4)
	var calvo: bool = idoso and sem.chance(35) and not op.has("estilo")
	# a linha do cabelo é o que diferencia os penteados de verdade; a forma
	# da massa muda pouco a 32px, a altura da testa muda tudo
	var y_cabelo: int = 18
	match estilo:
		0: y_cabelo = 18    # curto
		1: y_cabelo = 17    # comprido
		2: y_cabelo = 20    # franja baixa
		_: y_cabelo = 14    # penteado para trás, testa alta
	if calvo:
		y_cabelo = 11       # só o que sobra nas laterais

	# ---- cabelo ----
	if not calvo:
		# a massa: uma elipse um pouco MAIOR que o crânio, metade de cima. É
		# ela que dá volume — cabelo colado no crânio parece pintado nele
		t.meia_elipse(32, cy, 14.5, 16.5, cabelo[0], false)
		# mecha de luz no lado iluminado, antes da sombra da direita
		t.retangulo(22, int(cy) - 13, 7, 2, cabelo[0].lightened(0.2))
		for y in range(int(cy) - 17, int(cy) + 2):
			for x in range(37, 48):
				if t.img.get_pixel(x, y).is_equal_approx(cabelo[0]):
					t.img.set_pixel(x, y, cabelo[1])
	elif sem.chance(60):
		# coroa de cabelo em volta da careca: só as laterais e a nuca
		t.meia_elipse(32, cy + 1, 14.5, 15.5, cabelo[0], false)
		t.elipse(32, cy - 4, 12, 11, pele[0])

	# O ROSTO VOLTA, da linha do cabelo para baixo. É esta chamada que
	# transforma uma touca de cabelo numa cabeleira.
	_rosto(t, pele, cy, y_cabelo)

	# mechas laterais por CIMA do rosto: só o cabelo comprido as tem, e é o
	# que emoldura a cara em vez de virar um capacete
	if estilo == 1 and not calvo:
		t.retangulo(17, y_cabelo, 4, 22, cabelo[0])
		t.retangulo(43, y_cabelo, 4, 22, cabelo[1])

	# orelhas, depois do rosto para não serem apagadas por ele
	t.elipse(19, cy + 3, 2, 3, pele[0])
	t.elipse(45, cy + 3, 2, 3, pele[1])

	# ---- toucado ----
	#
	# O toucado vem ANTES dos olhos, e a ordem não é arbitrária: o capuz
	# precisa REDESENHAR o rosto para abrir a sua abertura, e desenhar
	# depois dos traços apagava olho, nariz e boca — os três encapuzados do
	# elenco (o Corvo, o informante, o clã) saíam como uma mancha escura sem
	# cara. Chapéu é camada de CABEÇA; traço de rosto vem sempre por cima.
	match str(op.get("toucado", "")):
		"coroa":
			# ouro. É o único lugar do retrato onde uma cor saturada é
			# permitida, e é permitida porque é a informação: este é um rei
			t.retangulo(20, 11, 24, 4, Color("e8b04b"))
			t.retangulo(20, 14, 24, 1, Color("8a6524"))
			for px2 in [21, 27, 31, 37, 42]:
				t.retangulo(px2, 8, 2, 3, Color("e8b04b"))
				t.ponto(px2, 7, Color("f5c86b"))
			t.retangulo(30, 12, 3, 2, Color("6fbfb4"))    # a pedra
		"capuz":
			# o capuz cobre o crânio inteiro e desce pelos ombros; o rosto
			# volta a partir do 17 para a ABERTURA existir
			t.meia_elipse(32, cy + 1, 17, 18, Color("2e2a33"), false)
			t.retangulo(15, 20, 6, 26, Color("2e2a33"))
			t.retangulo(43, 20, 6, 26, Color("221f28"))
			_rosto(t, pele, cy, 17)
			# a sombra da aba sobre a testa. Fica em 0,3 e em três linhas: o
			# encapuzado precisa ler como encapuzado, mas sombra que desce
			# até a sobrancelha apaga a única coisa que carrega o humor
			t.retangulo(20, 17, 24, 3, Color(0, 0, 0, 0.3))
		"touca":
			t.meia_elipse(32, 19, 14, 11, roupa[1], false)
			t.retangulo(18, 17, 28, 3, roupa[0])
		"elmo":
			t.meia_elipse(32, 20, 14, 12, Color("8d949b"), false)
			t.retangulo(18, 18, 28, 3, Color("6f767d"))
			# o nasal desce entre os olhos: é o traço que faz um domo de
			# metal virar um elmo, e ele só cabe porque os olhos estão em
			# x 26–29 e 35–38, com a coluna central livre
			t.retangulo(31, 12, 2, 19, Color("aab4bd"))
		# ---- os toucados dos SEIS REIS (ver a tabela REIS) ----
		"coroa_ferro":
			# a coroa do Sangrento: ferro escuro, pontas largas, dois rubis
			t.retangulo(19, 11, 26, 5, Color("5a5a64"))
			t.retangulo(19, 15, 26, 1, Color("3a3a42"))
			for px3 in [20, 30, 40]:
				t.retangulo(px3, 6, 4, 5, Color("5a5a64"))
				t.ponto(px3 + 1, 5, Color("74747e"))
			for px4 in [24, 37]:
				t.retangulo(px4, 12, 2, 2, Color("c23030"))
		"elmo_chifres":
			# o elmo do norte: domo escuro, banda, e os chifres curvos
			t.meia_elipse(32, 20, 14, 13, Color("6f767d"), false)
			t.retangulo(18, 17, 28, 3, Color("565c62"))
			for lado3 in [-1, 1]:
				var bx3: int = 32 + int(lado3) * 15
				# o chifre sobe em três segmentos, curvando para fora
				t.retangulo(bx3 - 1, 10, 3, 5, Color("e8e0d0"))
				t.retangulo(bx3 + int(lado3) - 1, 6, 3, 5, Color("e8e0d0"))
				t.retangulo(bx3 + int(lado3) * 2 - 1, 3, 3, 4, Color("d4c8b0"))
		"coroa_bronze":
			# o aro fino do Sol de Bronze, três pontas baixas e a pedra
			t.retangulo(20, 13, 24, 3, Color("a5722c"))
			t.retangulo(20, 13, 24, 1, Color("c9964a"))
			for px5 in [22, 31, 40]:
				t.retangulo(px5, 10, 2, 3, Color("a5722c"))
			t.retangulo(31, 13, 2, 2, Color("3a3a42"))
		"coroa_cervo":
			# o aro prata com a GALHADA escarlate: duas hastes com ramos
			t.retangulo(20, 12, 24, 3, Color("aab4bd"))
			t.retangulo(20, 12, 24, 1, Color("d0d8de"))
			for lado4 in [-1, 1]:
				var hx: int = 32 + int(lado4) * 9
				t.retangulo(hx, 3, 2, 9, Color("b03030"))
				t.retangulo(hx + int(lado4) * 3, 1, 2, 4, Color("b03030"))
				t.retangulo(hx - int(lado4) * 2, 5, 2, 3, Color("8b2020"))
		"coroa_alada":
			# o aro das Garças: prata, ponta central e asas nas têmporas
			t.retangulo(20, 12, 24, 3, Color("aab4bd"))
			t.retangulo(20, 12, 24, 1, Color("e0e6ea"))
			t.retangulo(30, 7, 4, 5, Color("d0d8de"))
			for lado5 in [-1, 1]:
				var ax: int = 32 + int(lado5) * 13
				# três penas em leque, subindo para fora
				t.retangulo(ax, 8, 2, 6, Color("d8dee4"))
				t.retangulo(ax + int(lado5) * 2, 6, 2, 7, Color("e8ecf0"))
				t.retangulo(ax + int(lado5) * 4, 5, 2, 7, Color("c4ccd4"))
		"tiara":
			# a tiara da Víbora: arco fino que desce nas pontas, safiras
			t.retangulo(22, 13, 20, 2, Color("aab4bd"))
			t.retangulo(20, 14, 2, 3, Color("aab4bd"))
			t.retangulo(42, 14, 2, 3, Color("aab4bd"))
			t.retangulo(31, 11, 2, 3, Color("d0d8de"))
			for px6 in [26, 31, 37]:
				t.ponto(px6, 13, Color("3a6ac8"))
			t.ponto(31, 12, Color("5a8ae8"))

	# ---- olhos ----
	var humor: String = str(op.get("humor", "neutro"))
	for lado in [0, 1]:
		var ox: int = 26 if lado == 0 else 35
		# a esclera é creme e não branco puro: branco puro num rosto de 64px
		# é o pixel mais claro da tela inteira e o olhar vira farol
		t.retangulo(ox, 26, 4, 3, Color("ded3c2"))
		var px: int = ox + (1 if lado == 0 else 2)
		t.retangulo(px, 26, 2, 3, Color("2a2018"))
		t.ponto(px, 26, Color("4a3a2c"))
	# sobrancelhas: o traço que carrega o humor. Inclinada para dentro e
	# baixa = raiva; alta e reta = simpatia; reta = neutro
	for lado2 in [0, 1]:
		var bx: int = 25 if lado2 == 0 else 35
		var dentro: int = 1 if lado2 == 0 else -1
		match humor:
			"raiva":
				for i in 5:
					var yy: int = 23 + int(i * 0.6) * (1 if lado2 == 0 else 0)
					if lado2 == 1:
						yy = 23 + int((4 - i) * 0.6)
					t.retangulo(bx + i, yy, 1, 2, cabelo[1])
			"feliz":
				t.retangulo(bx, 21, 5, 1, cabelo[1])
				t.ponto(bx + (0 if lado2 == 0 else 4), 22, cabelo[1])
			_:
				t.retangulo(bx, 22, 5, 2, cabelo[1])
		var _ignorar := dentro

	# ---- nariz ----
	t.retangulo(31, 29, 2, 4, pele[1])
	t.ponto(33, 32, pele[1])

	# ---- boca ----
	match humor:
		"raiva":
			t.retangulo(28, 37, 8, 1, Color("6b3a30"))
			t.ponto(28, 36, Color("6b3a30"))
			t.ponto(35, 36, Color("6b3a30"))
		"feliz":
			t.retangulo(29, 36, 6, 1, Color("8a4a3c"))
			t.ponto(28, 35, Color("8a4a3c"))
			t.ponto(35, 35, Color("8a4a3c"))
			t.retangulo(30, 37, 4, 1, Color("6b3a30"))
		_:
			t.retangulo(29, 36, 6, 1, Color("7a4034"))

	# ---- barba ----
	# `barba_estilo` (ficha de rei) manda; sem ele, vale o sorteio antigo.
	var tem_barba: bool = bool(op.get("barba", false))
	var barba_estilo: String = str(op.get("barba_estilo", ""))
	if barba_estilo == "nenhuma":
		tem_barba = false
	elif barba_estilo != "":
		tem_barba = true
	if barba_estilo == "cavanhaque":
		# só o queixo, estreito, mais o bigode fino: a barba de corte
		t.meia_elipse(32, 38, 5, 6, cabelo[0], true)
		t.retangulo(28, 34, 8, 2, cabelo[1])
		t.retangulo(29, 36, 6, 1, Color("7a4034"))
	elif tem_barba:
		var comprida: bool = barba_estilo == "cheia" or sem.chance(45)
		# a barba segue o queixo, então é meia-elipse baixa — retângulo aqui
		# dava aquele "queixo de caixa" que denuncia gerador
		t.meia_elipse(32, 34, 11, 10 if comprida else 7, cabelo[0], true)
		# recorta a boca de volta: barba por cima da boca some com a expressão,
		# e a expressão é a única coisa que muda com a relação
		if humor == "feliz":
			t.retangulo(28, 35, 8, 3, Color("6b3a30"))
		else:
			t.retangulo(29, 36, 6, 1, Color("7a4034"))
		# bigode
		t.retangulo(28, 34, 8, 2, cabelo[1])
		for y in range(30, 48):
			for x in range(37, 47):
				if t.img.get_pixel(x, y).is_equal_approx(cabelo[0]):
					t.img.set_pixel(x, y, cabelo[1])

	t.contornar(CONTORNO)
	return t.img

# ============================================================
# OS SEIS REIS — identidade FIXA, da referência de arte.
#
# Todo o resto do elenco sai da semente; os reis não. A referência visual
# do projeto define cada um por três traços que sobrevivem a 32px — o
# TOUCADO, a CABELEIRA e a COR do reino no fundo — e é isso que esta
# tabela fixa. Sorteio aqui seria jogar fora a única direção de arte
# explícita que o elenco tem:
#
#   Felippe, o Sangrento   coroa de FERRO, barba cheia escura, capa rubra
#   Bjorne, o Orgulhoso    ELMO DE CHIFRES, ruivo, barba enorme, peles
#   Enzo Tenebris          coroa de BRONZE fina, cavanhaque, traje escuro
#   Ignis, o Escarlate     coroa com GALHADA de cervo, jovem, prata
#   Frederico Silver       coroa ALADA, loiro longo, capa clara
#   Eva, a Víbora          TIARA de safiras, pálida, cabelo negro
#
# O FUNDO do retrato leva a cor do reino (igual ao painel de lordes da
# referência): é o traço que agrupa qualquer vassalo futuro ao seu senhor.
# ============================================================
const REIS := {
	"rei_imperio": {
		"toucado": "coroa_ferro", "barba_estilo": "cheia", "cabelo_idx": 1,
		"estilo": 0, "pele_idx": 1, "roupa_cor": ["3a3a42", "26262c"],
		"capa": "8b2030", "fundo": "1a4a2a",
	},
	"rei_touros": {
		"toucado": "elmo_chifres", "barba_estilo": "cheia", "cabelo_idx": 3,
		"estilo": 1, "pele_idx": 0, "roupa_cor": ["7a5a3a", "584028"],
		"fundo": "1c1c22",
	},
	"rei_alvorecer": {
		"toucado": "coroa_bronze", "barba_estilo": "cavanhaque", "cabelo_idx": 1,
		"estilo": 3, "pele_idx": 1, "roupa_cor": ["4a3a2c", "33291e"],
		"fundo": "6b5314",
	},
	"rei_leoes": {
		"toucado": "coroa_cervo", "barba_estilo": "nenhuma", "cabelo_idx": 2,
		"estilo": 0, "pele_idx": 1, "roupa_cor": ["b8c2cc", "8a95a0"],
		"fundo": "8b1a1a",
	},
	"rei_aguias": {
		"toucado": "coroa_alada", "barba_estilo": "nenhuma",
		"cabelo": ["d4b358", "a08238"], "estilo": 1, "pele_idx": 0,
		"roupa_cor": ["aab4bd", "7e8890"], "capa": "d8dee4", "fundo": "4a545e",
	},
	"rei_rosa": {
		"toucado": "tiara", "barba_estilo": "nenhuma", "cabelo_idx": 0,
		"estilo": 1, "pele": ["ece0da", "c8b4ac"],
		"roupa_cor": ["2c3a5e", "1e2a44"], "fundo": "2d4a8a",
	},
}

## Traços que vêm do ID em vez do acaso: um rei usa coroa, um espião usa
## capuz. O gerador não adivinha papel — quem chama sabe, e o id carrega.
static func _opcoes_de(id: String, humor: String) -> Dictionary:
	var s := id.to_lower()
	var op := {"humor": humor}
	# os seis reis têm ficha própria; qualquer outro "rei_" cai na coroa
	# genérica de sempre
	if REIS.has(s):
		op.merge(REIS[s])
		return op
	if s.begins_with("rei_") or s == "lorde" or s.contains("rainha"):
		op["toucado"] = "coroa"
		op["idoso"] = true
	elif s.contains("espiao") or s.contains("corvo") or s.contains("informante"):
		op["toucado"] = "capuz"
	elif s.contains("guarda") or s.contains("capita") or s.contains("capitao"):
		op["toucado"] = "elmo"
	elif s.contains("taverneiro") or s.contains("mercador") or s.contains("cartografo"):
		op["toucado"] = "touca"
	elif s.begins_with("cla_") or s.contains("chefe"):
		op["toucado"] = "elmo" if _hash(id) % 2 == 0 else ""
		op["idoso"] = true
	# barba por sorteio, mas o sorteio é do MESMO id: a barba faz parte da
	# identidade da pessoa, não do quadro em que ela aparece
	op["barba"] = (_hash(id + "|barba") % 100) < 55
	return op

## A leva de retratos HI-BIT (PixelLab): um PNG por id do elenco fixo, em
## assets/sprites/hibit/retrato_<id>.png. Quando existe, vence o gerador —
## e carrega SEM depender do .import do editor, para a peça aparecer no
## instante em que o arquivo chega.
const PASTA_HIBIT := "res://assets/sprites/hibit/"
static var _hibit: Dictionary = {}

## Lê um PNG da leva pelo filesystem VIRTUAL (bytes do pacote), nunca por
## caminho globalizado: dentro de um PCK/APK exportado o res:// não é uma
## pasta real, e é isso que mantém a arte viva no build final.
static func _png_hibit(arquivo: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(PASTA_HIBIT + arquivo)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return img

static func _retrato_hibit(id: String) -> Texture2D:
	if _hibit.has(id):
		return _hibit[id]
	var img := _png_hibit("retrato_" + id + ".png")
	if img == null:
		_hibit[id] = null
		return null
	var tex := ImageTexture.create_from_image(img)
	_hibit[id] = tex
	return tex

## Retrato de um personagem do elenco fixo (reis, NPCs, chefes de clã).
##
## O hi-bit não tem variação de humor — a expressão está pintada. É uma
## troca consciente: a leva ilustrada ganha em riqueza o que perde em
## reatividade, e a relação continua legível no medidor ao lado.
static func textura(id: String, humor: String = "neutro") -> Texture2D:
	var pronto := _retrato_hibit(id)
	if pronto != null:
		return pronto
	var chave := "%s|%s" % [id, humor]
	if _cache.has(chave):
		return _cache[chave]
	var sem := Semente.new(_hash(id))
	var tex := ImageTexture.create_from_image(_pintar(sem, _opcoes_de(id, humor)))
	_cache[chave] = tex
	return tex

## A versão de 32×32, para lista e linha de tabela.
##
## Não é o mesmo retrato num TextureRect menor: reduzir 64→32 com filtro
## NEAREST joga fora um pixel em cada dois e destrói justamente os traços de
## 1px (olho, boca, contorno) que carregam a leitura. Aqui a redução é uma
## MÉDIA de blocos 2×2, que é o único jeito correto de reduzir pixel art
## por fator inteiro — e o resultado ainda é nítido porque o fator é 2.
static func textura_pequena(id: String, humor: String = "neutro") -> Texture2D:
	var chave := "p|%s|%s" % [id, humor]
	if _cache.has(chave):
		return _cache[chave]
	var pronto := _retrato_hibit(id)
	var grande: Image
	if pronto != null:
		grande = pronto.get_image().duplicate()
		grande.convert(Image.FORMAT_RGBA8)
	else:
		grande = _pintar(Semente.new(_hash(id)), _opcoes_de(id, humor))
	_cache[chave] = ImageTexture.create_from_image(_reduzir(grande))
	return _cache[chave]

static func _reduzir(src: Image) -> Image:
	var lado := src.get_width() / 2
	var out := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var s := Color(0, 0, 0, 0)
			for dy in 2:
				for dx in 2:
					var p := src.get_pixel(x * 2 + dx, y * 2 + dy)
					s += Color(p.r, p.g, p.b, p.a)
			out.set_pixel(x, y, Color(s.r / 4.0, s.g / 4.0, s.b / 4.0, s.a / 4.0))
	return out

## Humor pela relação — LÓGICA DE ESTADO, não arte. Fica.
static func humor_de(state: Dictionary, id: String) -> String:
	var rel: int = state["tags"].get(id, {"relacao": 0})["relacao"]
	if rel <= -25:
		return "raiva"
	if rel >= 25:
		return "feliz"
	return "neutro"

## A cor que agrupa um retrato à CASA DO JOGADOR — o mesmo traço que agrupa
## cada rei ao seu reino no painel de referência. Sem coroa, a casa usa o
## latão-úmbria do próprio jogo (nenhum dos seis reinos é dono dele);
## coroado, o jogador herda o fundo do reino que tomou, e a corte inteira
## troca de estandarte junto.
static func fundo_da_casa(state: Dictionary) -> String:
	var j: Dictionary = state.get("jogador", {})
	var rei_de := str(j.get("rei_de", ""))
	if rei_de != "" and REIS.has("rei_" + rei_de):
		return str(REIS["rei_" + rei_de]["fundo"])
	return "5e4420"

## ---- o ELENCO ILUSTRADO dos cidadãos ----
## Bustos hi-bit TRANSPARENTES por arquétipo (ofício+gênero), em
## assets/sprites/hibit/cidadao_<arquetipo><n>.png. O jogo compõe o busto
## sobre a vinheta em runtime — a heráldica da casa fica viva SOB o rosto
## ilustrado — e o NOME escolhe a variação, então a pessoa mantém a cara
## enquanto vive. Contagens casadas com os arquivos gerados; arquivo
## ausente = gerador procedural de sempre, nunca um buraco.
const POOL_CIDADAO := {
	"lorde_m": 3, "lorde_f": 2, "mercador_m": 2, "mercador_f": 2,
	"ferreiro_m": 2, "ferreiro_f": 1, "moleiro_m": 1, "moleiro_f": 1,
	"taverneiro_m": 1, "taverneiro_f": 1, "capataz_m": 1, "capataz_f": 1,
	"senhor_m": 2, "herdeiro_m": 1, "herdeiro_f": 1,
}

static func _arquetipo_de(n: Dictionary) -> String:
	var g := "f" if str(n.get("genero", "m")) == "f" else "m"
	if bool(n.get("lorde", false)):
		return "lorde_" + g
	var oficio := str(n.get("oficio", ""))
	if POOL_CIDADAO.has(oficio + "_" + g):
		return oficio + "_" + g
	if POOL_CIDADAO.has(oficio + "_m"):
		return oficio + "_m"
	# ofício fora do catálogo cai no rosto de gente comum, não num buraco
	return "mercador_" + g

static var _bustos: Dictionary = {}

static func _busto_cidadao(arquivo: String) -> Image:
	if _bustos.has(arquivo):
		return _bustos[arquivo]
	var img := _png_hibit(arquivo)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != LADO_RETRATO or img.get_height() != LADO_RETRATO:
			img.resize(LADO_RETRATO, LADO_RETRATO, Image.INTERPOLATE_NEAREST)
	_bustos[arquivo] = img
	return img

## Retrato de um cidadão/lorde criado durante a partida.
## `n` é o dicionário de cidadaos.gd (nome, genero, oficio, riqueza…).
##
## Com a leva ilustrada no lugar, o ARQUÉTIPO (ofício+gênero) escolhe o
## busto e o NOME escolhe a variação. Sem a leva, vale o gerador: a
## semente é o nome, o ofício escolhe toucado e roupa, a riqueza escolhe
## se a roupa é a boa ou a surrada.
##
## `fundo` é a cor de facção (fundo_da_casa): o chamador decide QUEM a
## carrega — lordes jurados, a família, comandantes — porque é ele quem
## sabe o que a linha significa. Cidadão comum fica na vinheta neutra.
static func textura_cidadao(n: Dictionary, pequena: bool = false, fundo: String = "") -> Texture2D:
	var nome := str(n.get("nome", "?"))
	var oficio := str(n.get("oficio", ""))
	var rico: bool = int(n.get("riqueza", 0)) >= 280
	var lorde := bool(n.get("lorde", false))
	var preso := bool(n.get("capturado", false))
	# lorde e capturado mudam o DESENHO (busto nobre, ferros): fora da
	# chave, a promoção a lorde devolvia o retrato velho do cache
	var chave := "cid|%s|%s|%s|%s|%s%s" % [nome, oficio,
		"p" if pequena else "g", fundo, "l" if lorde else "", "c" if preso else ""]
	if _cache.has(chave):
		return _cache[chave]

	# ---- busto ilustrado do arquétipo, composto sobre a vinheta ----
	var img: Image = null
	var arq := _arquetipo_de(n)
	var tam := int(POOL_CIDADAO.get(arq, 0))
	if tam > 0:
		var busto := _busto_cidadao("cidadao_%s%d.png"
			% [arq, 1 + _hash(nome + "|busto") % tam])
		if busto != null:
			img = _fundo_vinheta(fundo)
			img.blend_rect(busto,
				Rect2i(0, 0, LADO_RETRATO, LADO_RETRATO), Vector2i.ZERO)
	if img != null:
		if pequena:
			img = _reduzir(img)
		var pronto := ImageTexture.create_from_image(img)
		_cache[chave] = pronto
		return pronto

	var op := {
		"humor": "feliz" if int(n.get("lealdade", 50)) >= 70
			else ("raiva" if int(n.get("lealdade", 50)) < 40 else "neutro"),
		"barba": str(n.get("genero", "m")) == "m"
			and (_hash(nome + "|barba") % 100) < 60,
		"idoso": (_hash(nome + "|idade") % 100) < 30,
		"roupa": _hash(oficio + "|roupa") % ROUPA.size(),
	}
	if lorde:
		op["toucado"] = "touca"
	elif oficio == "ferreiro":
		op["toucado"] = "elmo"
	elif oficio == "mercador" or oficio == "taverneiro" or oficio == "moleiro":
		op["toucado"] = "touca"
	if preso:
		# a ferros: sem toucado, humor de raiva. O estado aparece na CARA,
		# não só no texto "a ferros em terra inimiga" ao lado
		op["toucado"] = ""
		op["humor"] = "raiva"
	if not rico:
		op["roupa"] = (int(op["roupa"]) + 5) % ROUPA.size()
	if fundo != "":
		op["fundo"] = fundo
	img = _pintar(Semente.new(_hash(nome)), op)
	if pequena:
		img = _reduzir(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[chave] = tex
	return tex

## Retrato da tropa. O id da arte é SEMPRE "tropa_" + a chave de Dados.TROPAS,
## então a UI acha a imagem por cálculo — sem tabela paralela que envelhece
## toda vez que uma unidade nova entra no catálogo.
##
## Estes nove EXISTEM como PNG. São opacos e já vêm com o fundo na cor do
## painel: o retrato é um quadro pendurado na linha do quartel, não um sprite
## recortado. Unidade nova no catálogo cai no retrato gerado, com elmo — que
## é melhor que um caixote e continua dizendo "isto é um soldado".
static func textura_tropa(tipo: String) -> Texture2D:
	var caminho := PASTA + "tropa_" + tipo + ".png"
	if ResourceLoader.exists(caminho):
		var t = load(caminho)
		if t is Texture2D:
			return t
	return textura("tropa_" + tipo)

## Ilustração de evento para os modais (cerco, emboscada, inverno…).
static func ilustracao(evento: String) -> Texture2D:
	if not EVENTOS.has(evento):
		return null
	var caminho := PASTA + "evento_" + evento + ".png"
	if ResourceLoader.exists(caminho):
		var t = load(caminho)
		if t is Texture2D:
			return t
	return Arte.caixa(LADO_EVENTO)

## Retrato de quem lidera a marcha. Resolve pela IDENTIDADE primeiro — um
## lorde que subiu de cidadão leva a cara que ele já tinha na Corte — e só
## cai no perfil quando não há pessoa por trás do cargo.
##
## O CONTRATO de "comandante vazio não tem retrato" é do chamador, não da
## arte: o card do comandante esconde o slot quando isto devolve null.
static func textura_comandante(state: Dictionary, cmd: Dictionary) -> Texture2D:
	if cmd.is_empty():
		return null
	var id := str(cmd.get("id", ""))
	# um chefe de clã no comando leva o retrato DO CLÃ — a pessoa já
	# existe no elenco fixo, inventar um busto seria trocar a cara dela
	if id.begins_with("cla:"):
		return textura(id.trim_prefix("cla:"))
	var nome := str(cmd.get("nome", ""))
	if nome == "":
		return textura(id if id != "" else "senhor")
	# um LORDE no comando leva a cara que ele já tem na Corte: mesma flag
	# de lorde e o gênero DO CENSO — sem isso, a marcha sortearia outro
	# busto para a mesma pessoa e a identidade quebraria entre abas
	var lorde := id.begins_with("lorde:")
	var genero := "m"
	# terra pode ser NULL no save (sem terra), não só ausente
	var terra_v: Variant = state.get("terra")
	if terra_v is Dictionary:
		for n in terra_v.get("notaveis", []):
			if str(n.get("nome", "")) == nome:
				genero = str(n.get("genero", "m"))
	# quem marcha, marcha SOB A SUA BANDEIRA: o comandante leva o fundo da
	# casa, como os lordes da Corte
	return textura_cidadao({"nome": nome, "oficio": str(cmd.get("perfil", "senhor")),
		"riqueza": 400, "genero": genero, "lealdade": 60, "lorde": lorde},
		false, fundo_da_casa(state))

## Um sprite qualquer pedido pelo id (cartógrafo, informante). Sem PNG, o id
## vira semente e a pessoa ganha uma cara — é o mesmo caminho de todo mundo.
static func sprite_gerado(id: String) -> Texture2D:
	return textura(id)
