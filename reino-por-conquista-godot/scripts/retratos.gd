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
static func _pintar(sem: Semente, op: Dictionary) -> Image:
	var t := Tela.new(LADO_RETRATO)

	# ---- fundo: vinheta radial, escura nos cantos ----
	# um fundo chapado atrás de um rosto faz o rosto parecer recortado e
	# colado; a vinheta o assenta no card, e custa 4096 lerps uma vez só
	var c := (LADO_RETRATO - 1) * 0.5
	for y in LADO_RETRATO:
		for x in LADO_RETRATO:
			var d: float = Vector2(x - c, y - c).length() / (c * 1.42)
			t.img.set_pixel(x, y, FUNDO_A.lerp(FUNDO_B, clampf(d * 1.15, 0.0, 1.0)))

	var pele: Array = PELE[sem.proximo(PELE.size())]
	var idoso: bool = bool(op.get("idoso", false))
	# grisalho e branco (índices 5 e 6) só entram no elenco velho: um rei de
	# 22 anos de cabelo branco é o tipo de detalhe que faz o gerador parecer
	# aleatório em vez de povoado
	var i_cab: int = sem.proximo(CABELO.size() - 2)
	if idoso and sem.chance(70):
		i_cab = 5 + sem.proximo(2)
	var cabelo: Array = CABELO[i_cab]
	var roupa: Array = ROUPA[int(op.get("roupa", sem.proximo(ROUPA.size())))]

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
	var estilo: int = sem.proximo(4)
	var calvo: bool = idoso and sem.chance(35)
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
	if bool(op.get("barba", false)):
		var comprida: bool = sem.chance(45)
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

## Traços que vêm do ID em vez do acaso: um rei usa coroa, um espião usa
## capuz. O gerador não adivinha papel — quem chama sabe, e o id carrega.
static func _opcoes_de(id: String, humor: String) -> Dictionary:
	var s := id.to_lower()
	var op := {"humor": humor}
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

## Retrato de um personagem do elenco fixo (reis, NPCs, chefes de clã).
static func textura(id: String, humor: String = "neutro") -> Texture2D:
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
	var grande := _pintar(Semente.new(_hash(id)), _opcoes_de(id, humor))
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

## Retrato de um cidadão/lorde criado durante a partida.
## `n` é o dicionário de cidadaos.gd (nome, genero, oficio, riqueza…).
##
## A semente é o NOME, então o mesmo notável mantém a cara enquanto vive; o
## ofício escolhe o toucado e a cor da roupa, e a riqueza escolhe se a roupa
## é a boa ou a surrada. É o que faz a lista da Corte parecer um elenco em
## vez de sete variações do mesmo homem.
static func textura_cidadao(n: Dictionary, pequena: bool = false) -> Texture2D:
	var nome := str(n.get("nome", "?"))
	var oficio := str(n.get("oficio", ""))
	var rico: bool = int(n.get("riqueza", 0)) >= 280
	var chave := "cid|%s|%s|%s" % [nome, oficio, "p" if pequena else "g"]
	if _cache.has(chave):
		return _cache[chave]
	var op := {
		"humor": "feliz" if int(n.get("lealdade", 50)) >= 70
			else ("raiva" if int(n.get("lealdade", 50)) < 40 else "neutro"),
		"barba": str(n.get("genero", "m")) == "m"
			and (_hash(nome + "|barba") % 100) < 60,
		"idoso": (_hash(nome + "|idade") % 100) < 30,
		"roupa": _hash(oficio + "|roupa") % ROUPA.size(),
	}
	if bool(n.get("lorde", false)):
		op["toucado"] = "touca"
	elif oficio == "ferreiro":
		op["toucado"] = "elmo"
	elif oficio == "mercador" or oficio == "taverneiro" or oficio == "moleiro":
		op["toucado"] = "touca"
	if bool(n.get("capturado", false)):
		# a ferros: sem toucado, humor de raiva. O estado aparece na CARA,
		# não só no texto "a ferros em terra inimiga" ao lado
		op["toucado"] = ""
		op["humor"] = "raiva"
	if not rico:
		op["roupa"] = (int(op["roupa"]) + 5) % ROUPA.size()
	var img := _pintar(Semente.new(_hash(nome)), op)
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
static func textura_comandante(_state: Dictionary, cmd: Dictionary) -> Texture2D:
	if cmd.is_empty():
		return null
	var nome := str(cmd.get("nome", ""))
	if nome == "":
		return textura(str(cmd.get("id", "senhor")))
	return textura_cidadao({"nome": nome, "oficio": str(cmd.get("perfil", "senhor")),
		"riqueza": 400, "genero": "m", "lealdade": 60})

## Um sprite qualquer pedido pelo id (cartógrafo, informante). Sem PNG, o id
## vira semente e a pessoa ganha uma cara — é o mesmo caminho de todo mundo.
static func sprite_gerado(id: String) -> Texture2D:
	return textura(id)
