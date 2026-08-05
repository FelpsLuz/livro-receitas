# ============================================================
# AI VISUAL BRIDGE — geração de textura em tempo de execução (PixelLab v2).
#
# Ferramenta de DESENVOLVIMENTO: monta o prompt a partir do estado da
# entidade, chama a API, e devolve um ImageTexture pronto para pôr num
# Sprite2D sem passar pelo disco nem pelo importador da Godot.
#
#   var ponte := AIVisualBridge.novo(self)
#   ponte.pronto.connect(func(id, tex): sprite.texture = tex)
#   ponte.pedir("heroi", {"tipo": "character", "acao": "walking down",
#           "descricao": "young knight, leather armor", "tamanho": 32})
#
# ------------------------------------------------------------
# A CHAVE NÃO PODE IR NO JOGO
# ------------------------------------------------------------
# Isto é o ponto que decide se esta classe é útil ou é um vazamento. Uma
# chave de API embutida num binário de cliente é uma chave PÚBLICA: qualquer
# um extrai a string do executável ou do .pck com um editor hexadecimal, e
# a partir daí gasta a sua cota. Não existe ofuscação que resolva — só não
# embarcar.
#
# Por isso `chave()` lê, nesta ordem:
#   1. a variável de ambiente PIXELLAB_SECRET
#   2. user://pixellab.key, que é fora do projeto e nunca vai para o build
# e NUNCA um literal no código. Se as duas faltarem, `disponivel()` devolve
# false e todo pedido falha limpo, sem chamar nada.
#
# `_ready` também barra a execução numa build exportada (`OS.has_feature
# ("template")`): mesmo com a chave presente na máquina de quem joga, esta
# ponte não roda fora do editor/dev. Geração de arte é etapa de produção, não
# de partida — o jogador não deve esperar a rede para ver um sprite.
#
# ------------------------------------------------------------
# CUSTO
# ------------------------------------------------------------
# Cada chamada gasta crédito de verdade. `teto_usd` é um freio local: a ponte
# soma o custo estimado e recusa o pedido que passaria do teto, em vez de
# descobrir isso na fatura. `--simular` do lado Python tem o mesmo papel;
# aqui é `simular = true`, que devolve um caixote sem tocar na rede.
# ============================================================
class_name AIVisualBridge
extends Node

const Arte = preload("res://scripts/arte.gd")

const BASE := "https://api.pixellab.ai/v2"
const ENDPOINT_IMAGEM := "/generate-image-pixflux"
const ARQUIVO_CHAVE := "user://pixellab.key"

## Estimativa por chamada, para o freio de custo. O valor real vem na
## resposta (`usage.usd`) e substitui a estimativa no acumulado.
const CUSTO_ESTIMADO := 0.01

signal pronto(id: String, textura: ImageTexture)
signal falhou(id: String, motivo: String)

## Teto de gasto desta sessão, em dólares. Estourou, a ponte para.
var teto_usd := 0.25
var gasto_usd := 0.0
## Devolve caixote sem tocar na rede — para testar o fluxo de graça.
var simular := false

var _http: HTTPRequest
var _fila: Array = []
var _atual: Dictionary = {}
var _cache: Dictionary = {}


static func novo(pai: Node) -> AIVisualBridge:
	var b := AIVisualBridge.new()
	b.name = "AIVisualBridge"
	pai.add_child(b)
	return b


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	add_child(_http)
	_http.request_completed.connect(_recebeu)


# ------------------------------------------------------------
# CHAVE E DISPONIBILIDADE
# ------------------------------------------------------------
## A chave, de ambiente ou de user://. Nunca de literal — ver o cabeçalho.
static func chave() -> String:
	var k := OS.get_environment("PIXELLAB_SECRET").strip_edges()
	if k != "":
		return k
	if FileAccess.file_exists(ARQUIVO_CHAVE):
		var f := FileAccess.open(ARQUIVO_CHAVE, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return ""


## Dá para chamar a API agora? Falso numa build exportada, sempre.
static func disponivel() -> bool:
	if OS.has_feature("template"):
		return false      # build exportada: geração é etapa de produção
	return chave() != ""


func motivo_indisponivel() -> String:
	if OS.has_feature("template"):
		return "build exportada — a ponte só roda no editor/dev"
	if chave() == "":
		return "sem PIXELLAB_SECRET no ambiente nem " + ARQUIVO_CHAVE
	return ""


# ------------------------------------------------------------
# PROMPT
# ------------------------------------------------------------
## Monta o prompt a partir do ESTADO da entidade. É aqui que a estética
## Hi-Bit fica gravada num lugar só: mudar o estilo é mudar esta função,
## não caçar strings espalhadas por dez cenas.
static func montar_prompt(estado: Dictionary) -> String:
	var tamanho := int(estado.get("tamanho", 32))
	var partes: Array[String] = ["%dx%d pixel art" % [tamanho, tamanho]]
	var tipo := str(estado.get("tipo", "object"))
	if tipo == "character":
		partes.append("character sprite")
	elif tipo == "tile":
		partes.append("seamless terrain tile")
	else:
		partes.append("game object")
	if estado.has("descricao"):
		partes.append(str(estado["descricao"]))
	if estado.has("acao"):
		partes.append(str(estado["acao"]))
	if estado.has("quadro"):
		partes.append("frame %d" % int(estado["quadro"]))
	if estado.has("estacao"):
		partes.append("%s season lighting" % str(estado["estacao"]))
	# a assinatura de estilo vai no FIM: o modelo pesa mais o começo do
	# prompt para o assunto, e o fim para o acabamento
	partes.append("hi-bit pixel art, Stardew Valley style, vibrant saturated "
		+ "palette, soft top-down lighting, clean readable silhouette, "
		+ "transparent background, no text, no frame")
	return ", ".join(partes)


# ------------------------------------------------------------
# PEDIDO
# ------------------------------------------------------------
## Enfileira um pedido. `id` volta nos sinais para o chamador saber qual é.
func pedir(id: String, estado: Dictionary) -> bool:
	if _cache.has(id):
		pronto.emit(id, _cache[id])
		return true
	var tamanho := int(estado.get("tamanho", 32))
	if simular:
		var t := _caixote(tamanho)
		_cache[id] = t
		pronto.emit(id, t)
		return true
	if not disponivel():
		falhou.emit(id, motivo_indisponivel())
		return false
	if gasto_usd + CUSTO_ESTIMADO > teto_usd:
		falhou.emit(id, "teto de US$ %.2f alcançado (gasto US$ %.4f)"
			% [teto_usd, gasto_usd])
		return false
	_fila.append({"id": id, "estado": estado, "tamanho": tamanho})
	_bombear()
	return true


func _bombear() -> void:
	if not _atual.is_empty() or _fila.is_empty() or _http == null:
		return
	_atual = _fila.pop_front()
	var tamanho: int = _atual["tamanho"]
	var corpo := {
		"description": montar_prompt(_atual["estado"]),
		"image_size": {"width": tamanho, "height": tamanho},
		"no_background": true,
	}
	var cabecalhos := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + chave(),
	])
	var err := _http.request(BASE + ENDPOINT_IMAGEM, cabecalhos,
		HTTPClient.METHOD_POST, JSON.stringify(corpo))
	if err != OK:
		var id: String = _atual["id"]
		_atual = {}
		falhou.emit(id, "HTTPRequest recusou o pedido (erro %d)" % err)
		_bombear()


func _recebeu(resultado: int, codigo: int, _cab: PackedStringArray,
		corpo: PackedByteArray) -> void:
	var pedido := _atual
	_atual = {}
	if pedido.is_empty():
		return
	var id: String = pedido["id"]

	if resultado != HTTPRequest.RESULT_SUCCESS:
		falhou.emit(id, "falha de transporte (resultado %d)" % resultado)
		_bombear()
		return
	if codigo < 200 or codigo >= 300:
		# o corpo do erro costuma trazer a razão; 402 é cota, 422 é parâmetro
		falhou.emit(id, "HTTP %d — %s" % [codigo,
			corpo.get_string_from_utf8().substr(0, 200)])
		_bombear()
		return

	var dados = JSON.parse_string(corpo.get_string_from_utf8())
	if not (dados is Dictionary):
		falhou.emit(id, "resposta não é JSON")
		_bombear()
		return

	# custo REAL, quando a API informa; senão fica a estimativa
	var uso = dados.get("usage")
	if uso is Dictionary:
		gasto_usd += float(uso.get("usd", CUSTO_ESTIMADO))
	else:
		gasto_usd += CUSTO_ESTIMADO

	var tex := _textura_de(dados)
	if tex == null:
		falhou.emit(id, "resposta sem imagem base64 reconhecível")
		_bombear()
		return
	_cache[id] = tex
	pronto.emit(id, tex)
	_bombear()


## A imagem vem em base64 dentro de `image.base64`. Aceita o data-URI
## completo também, porque a API já devolveu das duas formas.
func _textura_de(dados: Dictionary) -> ImageTexture:
	var img_campo = dados.get("image")
	var b64 := ""
	if img_campo is Dictionary:
		b64 = str(img_campo.get("base64", ""))
	elif img_campo is String:
		b64 = str(img_campo)
	if b64 == "":
		return null
	if b64.begins_with("data:"):
		var virgula := b64.find(",")
		if virgula < 0:
			return null
		b64 = b64.substr(virgula + 1)
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(img)


## Caixote do modo simulado — a mesma fonte do resto do jogo.
func _caixote(tamanho: int) -> ImageTexture:
	var t: Texture2D = Arte.caixa(tamanho)
	if t is ImageTexture:
		return t
	return ImageTexture.new()


## Relatório para depuração e para o teste.
func resumo() -> Dictionary:
	return {
		"disponivel": disponivel(),
		"motivo": motivo_indisponivel(),
		"gasto_usd": gasto_usd,
		"teto_usd": teto_usd,
		"em_cache": _cache.size(),
		"na_fila": _fila.size(),
	}
