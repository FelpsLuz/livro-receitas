# ============================================================
# RETRATOS 64×64 (port de js/portraits.js para Image/Texture)
# Gerados pixel a pixel em código; humor muda com a relação.
# ============================================================
extends RefCounted

const PELES := ["e8c39a", "d9a97c", "c68e5e", "a86f47", "8a5632"]
const CABELOS := ["2d2018", "4a3421", "6b4a2d", "8a6b45", "b0925f", "c9c2b8", "e8e2d4", "7d3b2d", "d8b040"]

const FICHAS := {
	"rei_imperio":   {"pele": 2, "cabelo": 0, "estilo": "curto", "barba": "cheia", "chapeu": "coroa_espinho", "roupa": "1a4a2a", "cicatriz": true},
	"rei_touros":    {"pele": 2, "cabelo": 0, "estilo": "curto", "barba": "rala", "chapeu": "", "roupa": "1c1c22"},
	"rei_alvorecer": {"pele": 0, "cabelo": 2, "estilo": "medio", "barba": "", "chapeu": "coroa", "roupa": "c9a227"},
	"rei_leoes":     {"pele": 0, "cabelo": 4, "estilo": "longo", "barba": "cheia", "chapeu": "coroa", "roupa": "8b1a1a"},
	"rei_aguias":    {"pele": 0, "cabelo": 8, "estilo": "longo", "barba": "", "chapeu": "coroa", "roupa": "9aa4ae"},
	"rei_rosa":      {"pele": 0, "cabelo": 3, "estilo": "longo", "barba": "", "chapeu": "tiara", "roupa": "2d4a8a"},
	"taverneiro":   {"pele": 1, "cabelo": 3, "estilo": "careca", "barba": "bigode", "chapeu": "", "roupa": "6b4a2d", "gordo": true},
	"capitao":      {"pele": 1, "cabelo": 0, "estilo": "coque", "barba": "", "chapeu": "elmo", "roupa": "5a5f66", "cicatriz": true},
	"espiao":       {"pele": 3, "cabelo": 0, "estilo": "curto", "barba": "rala", "chapeu": "capuz", "roupa": "2d2a33"},
	"cla_lobos":    {"pele": 0, "cabelo": 4, "estilo": "longo", "barba": "trancada", "chapeu": "pelo", "roupa": "5a4a3a", "cicatriz": true},
	"cla_corvos":   {"pele": 2, "cabelo": 0, "estilo": "longo", "barba": "", "chapeu": "capuz", "roupa": "33383f"},
	"cla_estepe":   {"pele": 3, "cabelo": 0, "estilo": "rabo", "barba": "bigode_longo", "chapeu": "", "roupa": "7a5a30"},
	"cla_machados": {"pele": 0, "cabelo": 6, "estilo": "longo", "barba": "gelo", "chapeu": "elmo_chifre", "roupa": "4a5560"},
}

static var _cache := {}

static func _ficha(id: String) -> Dictionary:
	if FICHAS.has(id):
		return FICHAS[id]
	var h := hash(id)
	return {"pele": h % PELES.size(), "cabelo": (h >> 2) % CABELOS.size(),
		"estilo": ["curto", "medio", "longo"][(h >> 4) % 3],
		"barba": "cheia" if (h >> 6) % 3 == 0 else "", "chapeu": "",
		"roupa": "%06x" % ((h & 0x7f7f7f) | 0x303030)}

static func _esc(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f)

## Pasta onde generate_assets.py grava os sprites do PixelLab.
const PASTA_SPRITES := "res://assets/sprites/"

## Carrega o sprite gerado, se existir. É o mesmo princípio usado no build web:
## a arte de verdade entra por cima e o desenho procedural fica só como reserva,
## então o jogo nunca quebra por falta de um arquivo.
static func sprite_gerado(id: String) -> Texture2D:
	var caminho := PASTA_SPRITES + id + ".png"
	if not ResourceLoader.exists(caminho):
		return null
	var tex := load(caminho)
	return tex if tex is Texture2D else null

static func textura(id: String, humor: String = "neutro") -> Texture2D:
	var chave := id + "|" + humor
	if _cache.has(chave):
		return _cache[chave]
	# 1) sprite do PixelLab, quando disponível (mesma textura para todo humor:
	#    a expressão vem da arte, e a relação já é mostrada no texto da UI)
	var pronta := sprite_gerado(id)
	if pronta != null:
		_cache[chave] = pronta
		return pronta
	# 2) reserva: retrato desenhado em código
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	_desenhar(img, id, humor)
	var tex := ImageTexture.create_from_image(img)
	_cache[chave] = tex
	return tex

static func _p(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(maxi(0, y), mini(64, y + h)):
		for px in range(maxi(0, x), mini(64, x + w)):
			img.set_pixel(px, py, c)

static func _desenhar(img: Image, id: String, humor: String) -> void:
	_desenhar_ficha(img, _ficha(id), humor)

## O desenho de verdade, a partir de uma ficha já montada — é o que permite
## um cidadão gerado em jogo usar o mesmo pincel dos personagens fixos.
static func _desenhar_ficha(img: Image, f: Dictionary, humor: String) -> void:
	var pele := Color(PELES[f["pele"]])
	var cab := Color(CABELOS[f["cabelo"]])
	var roupa := Color(f["roupa"])
	var sombra := _esc(pele, 0.8)
	var gordo: bool = f.get("gordo", false)
	var gx := 2 if gordo else 0

	# fundo: cortina na cor da roupa
	_p(img, 0, 0, 64, 64, _esc(roupa, 0.45))
	for i in 8:
		_p(img, i * 8 + 2, 0, 3, 64, _esc(roupa, 0.38))

	# ombros
	var larg := 56 if gordo else 48
	_p(img, (64 - larg) / 2, 50, larg, 14, roupa)
	_p(img, (64 - larg) / 2 + 2, 52, 3, 12, _esc(roupa, 0.75))

	# pescoço e cabeça
	_p(img, 27, 44, 10, 8, sombra)
	_p(img, 20 - gx, 14, 24 + gx * 2, 30, pele)
	_p(img, 44 + gx, 18, 2, 18, sombra)
	_p(img, 20 - gx, 40, 24 + gx * 2, 4, sombra)

	if f.get("cicatriz", false):
		_p(img, 38, 20, 2, 10, Color("b06050"))

	# olhos e sobrancelhas (humor)
	_p(img, 24, 26, 5, 4, Color("f5f0e0"))
	_p(img, 35, 26, 5, 4, Color("f5f0e0"))
	_p(img, 26, 27, 2, 3, Color("3a3a42"))
	_p(img, 37, 27, 2, 3, Color("3a3a42"))
	if humor == "raiva":
		_p(img, 23, 22, 7, 2, cab)
		_p(img, 34, 22, 7, 2, cab)
		_p(img, 28, 23, 2, 2, cab)
		_p(img, 34, 23, 2, 2, cab)
	else:
		_p(img, 24, 23, 6, 2, cab)
		_p(img, 35, 23, 6, 2, cab)

	# nariz e boca
	_p(img, 30, 30, 3, 4, sombra)
	if humor == "raiva":
		_p(img, 27, 38, 9, 2, Color("7a3a30"))
	elif humor == "feliz":
		_p(img, 27, 37, 9, 2, Color("8a4a3d"))
		_p(img, 26, 36, 2, 1, Color("8a4a3d"))
		_p(img, 35, 36, 2, 1, Color("8a4a3d"))
	else:
		_p(img, 28, 38, 8, 2, Color("8a4a3d"))

	# barba
	match f["barba"]:
		"cheia":
			_p(img, 20 - gx, 33, 24 + gx * 2, 11, cab)
			_p(img, 22, 44, 20, 4, cab)
			if humor != "raiva":
				_p(img, 28, 38, 8, 2, Color("8a4a3d"))
		"cavanhaque":
			_p(img, 27, 40, 10, 6, cab)
		"bigode":
			_p(img, 25, 35, 14, 3, cab)
		"bigode_longo":
			_p(img, 25, 35, 14, 2, cab)
			_p(img, 24, 36, 3, 8, cab)
			_p(img, 37, 36, 3, 8, cab)
		"rala":
			for i in range(0, 14, 3):
				_p(img, 24 + i, 41 + (i % 2), 2, 1, _esc(cab, 0.9))
		"trancada":
			_p(img, 21, 34, 22, 10, cab)
			_p(img, 26, 44, 4, 7, cab)
			_p(img, 34, 44, 4, 7, cab)
		"gelo":
			_p(img, 21, 34, 22, 10, Color("e8e2d4"))
			_p(img, 24, 44, 16, 8, Color("e8e2d4"))

	# cabelo
	match f["estilo"]:
		"curto":
			_p(img, 19 - gx, 10, 26 + gx * 2, 8, cab)
		"medio":
			_p(img, 18 - gx, 10, 28 + gx * 2, 8, cab)
			_p(img, 18 - gx, 14, 4, 14, cab)
			_p(img, 42 + gx, 14, 4, 14, cab)
		"longo":
			_p(img, 17 - gx, 10, 30 + gx * 2, 8, cab)
			_p(img, 16 - gx, 14, 5, 30, cab)
			_p(img, 43 + gx, 14, 5, 30, cab)
		"rabo":
			_p(img, 20, 10, 24, 6, cab)
			_p(img, 43, 10, 4, 16, cab)
		"coque":
			_p(img, 20, 11, 24, 6, cab)
			_p(img, 27, 6, 10, 6, cab)
		"careca":
			_p(img, 19, 15, 3, 8, cab)
			_p(img, 42, 15, 3, 8, cab)
		"raspado":
			_p(img, 20, 12, 24, 5, _esc(pele, 0.72))

	# chapéus (por cima do cabelo)
	var ouro := Color("c9a227")
	match f["chapeu"]:
		"coroa":
			_p(img, 19, 6, 26, 6, ouro)
			for i in 5:
				_p(img, 20 + i * 6, 2, 3, 5, ouro)
			_p(img, 27, 4, 1, 1, Color("8b2635"))
		"coroa_espinho":
			_p(img, 19, 7, 26, 5, Color("4a4540"))
			for i in 6:
				_p(img, 20 + i * 5, 1, 2, 7, Color("4a4540"))
			_p(img, 30, 8, 4, 3, Color("8b2635"))
		"tiara":
			_p(img, 20, 9, 24, 3, Color("d4d0c8"))
			_p(img, 30, 6, 4, 4, Color("d4d0c8"))
			_p(img, 31, 7, 2, 2, Color("5a8ab0"))
		"capuz":
			_p(img, 16, 4, 32, 12, roupa)
			_p(img, 14, 10, 6, 30, roupa)
			_p(img, 44, 10, 6, 30, roupa)
			_p(img, 20, 14, 24, 3, _esc(roupa, 0.6))
		"elmo":
			_p(img, 18, 6, 28, 12, Color("b0b4ba"))
			_p(img, 30, 2, 4, 6, Color("8b2635"))
		"elmo_chifre":
			_p(img, 18, 6, 28, 10, Color("7a7e85"))
			_p(img, 12, 2, 6, 10, Color("d8d0c0"))
			_p(img, 46, 2, 6, 10, Color("d8d0c0"))
		"pelo":
			_p(img, 16, 4, 32, 10, Color("6b5a45"))
			for i in range(0, 30, 3):
				_p(img, 17 + i, 2 + (i % 3), 2, 4, Color("7d6b52") if i % 2 == 1 else Color("5a4a38"))

	# moldura
	_p(img, 0, 0, 64, 1, Color("1d1309"))
	_p(img, 0, 63, 64, 1, Color("1d1309"))
	_p(img, 0, 0, 1, 64, Color("1d1309"))
	_p(img, 63, 0, 1, 64, Color("1d1309"))

static func humor_de(state: Dictionary, id: String) -> String:
	var rel: int = state["tags"].get(id, {"relacao": 0})["relacao"]
	if rel <= -25:
		return "raiva"
	if rel >= 25:
		return "feliz"
	return "neutro"

# ============================================================
# RETRATOS DINÂMICOS — para quem NASCE durante a partida.
#
# Um cidadão que enriquece vira Lorde no meio do jogo. Não existe PNG dele,
# e chamar a API do PixelLab em tempo de execução está fora de questão (é
# rede, é dinheiro e é lento). A saída tem três degraus, do melhor para o
# pior, e nenhum deles deixa buraco na interface:
#
#   1. PNG próprio, se por acaso existir (assets/sprites/<nome>.png)
#   2. base genérica de nobre RECOLORIDA para a cor daquela pessoa —
#      preserva luz e sombra, troca só o tecido
#   3. retrato procedural, agora semeado pelos dados REAIS do cidadão
#      (ofício, gênero, riqueza) em vez de um hash cego
# ============================================================

## Bases recolorívies geradas uma vez pelo PixelLab.
const BASE_LORDE := {"m": "lorde_generico", "f": "lorde_generica"}

## O ofício vira cor de roupa e leitura: um ferreiro não se veste como um
## mercador. É o que faz dois lordes gerados parecerem pessoas diferentes.
const PALETA_OFICIO := {
	# o próprio senhor: vermelho-sangue, a cor da casa
	"senhor":     {"cor": "8b2635", "estilo": "medio",  "barba": "rala"},
	"mercador":   {"cor": "2d4a8a", "estilo": "medio",  "barba": "cavanhaque"},
	"ferreiro":   {"cor": "6b4a2d", "estilo": "curto",  "barba": "cheia"},
	"moleiro":    {"cor": "b0925f", "estilo": "curto",  "barba": "rala"},
	"taverneiro": {"cor": "7a5c38", "estilo": "careca", "barba": "bigode"},
	"capataz":    {"cor": "5a5f66", "estilo": "coque",  "barba": ""},
}

## Ficha de aparência derivada dos dados do cidadão — nada de hash cego.
static func ficha_de_cidadao(n: Dictionary) -> Dictionary:
	var oficio: String = str(n.get("oficio", "mercador"))
	var base: Dictionary = PALETA_OFICIO.get(oficio, PALETA_OFICIO["mercador"])
	var h := hash(str(n.get("nome", "?")))
	var rico: bool = int(n.get("riqueza", 0)) >= 400
	return {
		"pele": h % PELES.size(),
		"cabelo": (h >> 3) % CABELOS.size(),
		"estilo": str(base["estilo"]) if str(n.get("genero", "m")) == "m" else "longo",
		"barba": str(base["barba"]) if str(n.get("genero", "m")) == "m" else "",
		# lorde jurado ganha o colar de ofício; cidadão comum, nada
		"chapeu": "tiara" if bool(n.get("lorde", false)) and str(n.get("genero", "m")) == "f" else "",
		"roupa": str(base["cor"]),
		# quem enriqueceu se veste melhor, e a UI mostra isso sem uma palavra
		"cicatriz": bool(n.get("capturado", false)),
		"gordo": rico and oficio == "taverneiro",
	}

## Cor pessoal de um cidadão: estável (mesma pessoa, mesma cor sempre) e
## derivada do ofício, para o recolorido não sair aleatório.
static func cor_de_cidadao(n: Dictionary) -> Color:
	var oficio: String = str(n.get("oficio", "mercador"))
	var base := Color(str(PALETA_OFICIO.get(oficio, PALETA_OFICIO["mercador"])["cor"]))
	# um empurrãozinho de matiz por nome, para dois ferreiros não se confundirem
	var desvio: float = float(absi(hash(str(n.get("nome", "?")))) % 60) / 600.0 - 0.05
	return Color.from_hsv(fposmod(base.h + desvio, 1.0),
		clampf(base.s + 0.1, 0.2, 0.9), clampf(base.v + 0.05, 0.25, 0.9))

## Recolore uma base preservando LUZ e SOMBRA: troca o matiz do tecido e
## deixa pele, metal e preto/branco em paz. Pintar tudo por cima achataria
## o sprite e destruiria o trabalho do sombreamento.
static func _recolorir(origem: Texture2D, alvo: Color) -> Texture2D:
	var img: Image = origem.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			# cinzas e quase-pretos são metal, couro e contorno: não mexer
			if c.s < 0.18:
				continue
			# faixa de pele: deixar o rosto em paz
			if c.h >= 0.02 and c.h <= 0.11 and c.s < 0.62:
				continue
			img.set_pixel(x, y, Color.from_hsv(alvo.h,
				clampf(c.s * 0.55 + alvo.s * 0.45, 0.15, 0.95), c.v, c.a))
	return ImageTexture.create_from_image(img)

## Retrato de um cidadão/lorde criado durante a partida.
## `n` é o dicionário de cidadaos.gd (nome, genero, oficio, riqueza, lorde…).
static func textura_cidadao(n: Dictionary) -> Texture2D:
	var nome: String = str(n.get("nome", "?"))
	# a chave carrega tudo o que MUDA o desenho. Só o nome não bastava: dois
	# cidadãos homônimos de ofícios diferentes recebiam a mesma cara, porque o
	# primeiro a ser desenhado ficava no cache pelos dois.
	var chave := "cidadao|%s|%s|%s|%s|%s" % [nome, str(n.get("oficio", "")),
		str(n.get("genero", "m")), str(n.get("lorde", false)),
		str(n.get("capturado", false))]
	if _cache.has(chave):
		return _cache[chave]

	# 1) PNG próprio, se um dia alguém gerar um para este nome
	var proprio := sprite_gerado(nome.to_lower().replace(" ", "_"))
	if proprio != null:
		_cache[chave] = proprio
		return proprio

	# 2) base genérica recolorida para a cor pessoal dele
	var genero: String = str(n.get("genero", "m"))
	var base := sprite_gerado(str(BASE_LORDE.get(genero, BASE_LORDE["m"])))
	if base != null:
		var tex := _recolorir(base, cor_de_cidadao(n))
		_cache[chave] = tex
		return tex

	# 3) reserva final: retrato desenhado em código, semeado pelos dados dele
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	_desenhar_ficha(img, ficha_de_cidadao(n), "neutro")
	var proc := ImageTexture.create_from_image(img)
	_cache[chave] = proc
	return proc

## Retrato da tropa. O id da arte é SEMPRE "tropa_" + a chave de Dados.TROPAS,
## então a UI acha a imagem por cálculo — sem tabela paralela que envelhece
## toda vez que uma unidade nova entra no catálogo.
static func textura_tropa(tipo: String) -> Texture2D:
	return textura("tropa_" + tipo)

## Ilustração de evento para os modais (cerco, emboscada, inverno…).
## Devolve null quando a arte não existe: o modal segue só com texto.
static func ilustracao(evento: String) -> Texture2D:
	return sprite_gerado("evento_" + evento)

## Arte de reserva por PERFIL de comandante — usada só quando a pessoa por trás
## do cargo não tem retrato próprio (o capitão contratado não é um cidadão).
const ARTE_PERFIL := {
	"capitao": "mercenario_lanca",
	"batedor": "mercenario_arco",
	"quartel_mestre": "cartografo",
}

## Retrato de quem lidera a marcha. Resolve pela IDENTIDADE primeiro — um lorde
## que subiu de cidadão leva a cara que ele já tinha na Corte — e só cai no
## perfil quando não há pessoa: aí é a arte do ofício que responde.
static func textura_comandante(state: Dictionary, cmd: Dictionary) -> Texture2D:
	if cmd.is_empty():
		return null
	var id: String = str(cmd.get("id", ""))
	if id == "senhor":
		# o jogador também não tem PNG próprio: passa pelo mesmo recolorido dos
		# lordes, para o card do comandante não misturar arte gerada com o
		# desenho procedural cru bem ao lado dela
		return textura_cidadao({"nome": str(cmd.get("nome", "senhor")),
			"genero": str(state["jogador"].get("genero", "m")),
			"oficio": "senhor", "lorde": true})
	if id.begins_with("lorde:"):
		var nome := id.substr(6)
		var Cidadaos = load("res://scripts/cidadaos.gd")
		for n in Cidadaos.lista(state):
			if str(n.get("nome", "")) == nome:
				return textura_cidadao(n)
	elif id.begins_with("cla:"):
		# os clãs têm ficha própria em FICHAS; textura() já sabe achá-la
		return textura(id.substr(4))
	return sprite_gerado(str(ARTE_PERFIL.get(str(cmd.get("perfil", "")), "")))
