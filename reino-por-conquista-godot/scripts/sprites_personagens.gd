# ============================================================
# SPRITES DE PERSONAGEM — ponte entre os PNG gerados pelo PixelLab
# (generate_assets.py → res://assets/sprites/) e os nós da cena.
#
# Toda a arte de personagem passa por aqui: se o PNG existe, ele é usado;
# senão, cai no retrato desenhado em código. Assim o jogo roda igual antes
# de gerar qualquer sprite, e vai ficando melhor conforme os PNG chegam.
# ============================================================
extends RefCounted

const Retratos = preload("res://scripts/retratos.gd")
const PASTA := "res://assets/sprites/"

## IDs que o generate_assets.py sabe gerar (espelha o dicionário APARENCIA).
const ELENCO := {
	"reis": ["rei_imperio", "rei_touros", "rei_alvorecer", "rei_leoes", "rei_aguias", "rei_rosa"],
	"npcs": ["taverneiro", "capitao", "espiao"],
	"barbaros": ["cla_lobos", "cla_corvos", "cla_estepe", "cla_machados"],
	"tropas": ["tropa_campones", "tropa_lanceiro", "tropa_arqueiro", "tropa_cavaleiro", "inimigo_bandido"],
}

static func todos_os_ids() -> Array:
	var saida: Array = []
	for grupo in ELENCO.values():
		saida.append_array(grupo)
	return saida

## Existe sprite gerado para este personagem?
static func tem_sprite(id: String) -> bool:
	return ResourceLoader.exists(PASTA + id + ".png")

## Textura do personagem: sprite gerado quando houver, retrato procedural senão.
static func textura(id: String, humor: String = "neutro") -> Texture2D:
	return Retratos.textura(id, humor)

## Cria um Sprite2D já configurado para pixel art (sem filtro, escala inteira).
## É este nó que as cenas devem usar para mostrar um personagem no mundo.
static func criar_sprite(id: String, escala: int = 2, humor: String = "neutro") -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Sprite_" + id
	s.texture = textura(id, humor)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel nítido, nunca borrado
	s.scale = Vector2(escala, escala)                       # múltiplo inteiro: sem tremida
	s.centered = true
	return s

## Aponta um Sprite2D existente para o sprite de um personagem.
## Use quando o nó já vem da cena (.tscn) e você só quer trocar a arte.
static func aplicar_em(sprite: Sprite2D, id: String, humor: String = "neutro") -> bool:
	if sprite == null:
		return false
	sprite.texture = textura(id, humor)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return tem_sprite(id)

## Relatório do que já foi gerado — útil no editor e nos testes.
static func faltando() -> Array:
	var falta: Array = []
	for id in todos_os_ids():
		if not tem_sprite(id):
			falta.append(id)
	return falta
