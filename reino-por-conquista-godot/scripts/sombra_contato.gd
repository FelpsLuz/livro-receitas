# ============================================================
# SOMBRA DE CONTATO — addendum v3 §C. Sombra é NÓ, não asset de IA.
# O classificador L-ratio foi rejeitado (a "sombra extraída" era ruído);
# aqui a consistência vem por construção: mesma direção, mesmo alpha,
# custo zero, e funciona sobre grama/neve/terra/pedra sem alteração.
# ============================================================
class_name SombraContato

# Sol no canto superior-DIREITO (SUFIXO_LUZ) -> sombra para baixo-ESQUERDA.
# Calibrar UMA vez contra docs/referencia.png e congelar: 100% dos objetos
# usam estas constantes, a cena inteira concorda sobre a luz por construção.
# NEGATIVO: em Node2D, skew positivo entorta o eixo Y para a DIREITA — o
# render de calibração provou que baixo-esquerda pede sinal negativo.
const SKEW := -0.55
const ACHATAMENTO := -0.28
const ALPHA_CONSTRUCAO := 0.35
const ALPHA_PEQUENO := 0.30

const ELIPSE := "res://assets_v2/fx/sombra_elipse.png"   # 16x6, radial


# Construções: cópia do sprite achatada e espelhada a partir da base.
static func criar_sombra(sprite: Sprite2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = sprite.name + "Sombra"
	s.texture = sprite.texture
	s.centered = sprite.centered
	s.offset = sprite.offset
	s.position = sprite.position
	s.modulate = Color(0.0, 0.0, 0.0, ALPHA_CONSTRUCAO)
	s.scale = Vector2(1.0, ACHATAMENTO)     # achata e espelha para baixo
	s.skew = SKEW
	s.z_index = sprite.z_index - 1
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


# Objetos pequenos (aldeões, barris, poço): cópia achatada de sprite de 8px
# vira borrão — usa elipse única escalada pela largura do pé.
static func criar_elipse(sprite: Sprite2D, largura_pe: float) -> Sprite2D:
	var e := Sprite2D.new()
	e.name = sprite.name + "Sombra"
	e.texture = load(ELIPSE)
	e.position = sprite.position
	e.modulate = Color(0.0, 0.0, 0.0, ALPHA_PEQUENO)
	e.scale.x = largura_pe / 16.0
	e.z_index = sprite.z_index - 1
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return e
