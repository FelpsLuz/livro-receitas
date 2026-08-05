# ============================================================
# GRADE DE ESTAÇÃO — o passe que devolve a cena à paleta (spec v4 §C.2).
# Arquitetura: a cena vive num SubViewport; este nó mostra a textura dele
# através do shader de grade+snap, e é DELE que sai o pixel final.
# Amostrar SCREEN_TEXTURE seria o outro caminho, mas amarra o passe à
# hierarquia de CanvasLayer e não sobrevive a render headless.
# ============================================================
class_name GradeEstacao
extends TextureRect

const PALETAS := "res://assets_v2/cenario/paletas/"

# Presets do v3 §D.3. A paleta de cada estação JÁ nasce passada por este
# mesmo grade (paleta_mestra.py), então a cor de saída cai exatamente numa
# entrada — o grade e o snap não brigam.
const PRESETS := {
	"verao": {"tint": Color(1.00, 1.00, 1.00), "sat": 1.00, "lum": 1.00},
	"entardecer": {"tint": Color(1.12, 0.94, 0.80), "sat": 1.05, "lum": 0.95},
	"tempestade": {"tint": Color(0.88, 0.92, 1.05), "sat": 0.70, "lum": 0.85},
	"outono": {"tint": Color(1.08, 0.96, 0.82), "sat": 1.10, "lum": 1.00},
	"inverno": {"tint": Color(0.92, 0.96, 1.06), "sat": 0.65, "lum": 1.05},
}

var estacao := "verao":
	set(v):
		estacao = v
		_aplicar()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = load("res://shaders/grade_estacao.gdshader")


func _ready() -> void:
	_aplicar()


func _aplicar() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	var pal: Texture2D = load(PALETAS + estacao + ".png")
	mat.set_shader_parameter("paleta", pal)
	mat.set_shader_parameter("paleta_n", pal.get_width())
	var p: Dictionary = PRESETS.get(estacao, PRESETS["verao"])
	mat.set_shader_parameter("tint", Vector3(p["tint"].r, p["tint"].g,
			p["tint"].b))
	mat.set_shader_parameter("saturacao", float(p["sat"]))
	mat.set_shader_parameter("luminancia", float(p["lum"]))


# Transição de estação animada (v3 §D.3): os uniforms são interpoláveis,
# então a mudança vira feedback de progressão em vez de troca seca de PNG.
# A paleta ALVO entra no começo do tween; `mistura` sobe de 0 a 1.
func trocar_com_tween(nova: String, segundos: float = 1.2) -> Tween:
	var mat := material as ShaderMaterial
	estacao = nova
	mat.set_shader_parameter("mistura", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float):
			mat.set_shader_parameter("mistura", v), 0.0, 1.0, segundos)
	return tw
