# ============================================================
# CICLO DIA / TARDE / NOITE — DirectionalLight2D
# Hue-shifting automático do ambiente: o sol muda de cor,
# energia e ângulo; as sombras dos LightOccluder2D acompanham.
# (Baseado no roteiro de design; corrigido para a API do Godot 4:
#  o enum de filtro vive em Light2D, não em "ShadowFilter".)
# ============================================================
extends DirectionalLight2D

@export var cor_dia: Color = Color(1.0, 0.95, 0.85)    # amarelo/branco quente
@export var cor_tarde: Color = Color(0.9, 0.5, 0.3)    # laranja/avermelhado
@export var cor_noite: Color = Color(0.15, 0.15, 0.35) # azul escuro/roxo
@export var velocidade_ciclo: float = 0.08             # bem lento por padrão
@export var ciclo_automatico: bool = true
## Multiplicador da energia. Cenário com muita cor fria (rio, praia) fica
## acinzentado quando a luz quente entra a plena força — a soma de laranja com
## ciano dá cinza. Baixar a força mantém a hora do dia sem lavar a água.
@export var forca: float = 1.0

var tempo: float = 0.0

func _ready() -> void:
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5          # suaviza a borda da sombra
	blend_mode = Light2D.BLEND_MODE_MIX

func _process(delta: float) -> void:
	if not ciclo_automatico:
		return
	tempo += delta * velocidade_ciclo
	aplicar_ciclo((sin(tempo) + 1.0) / 2.0)

# ciclo: 0 = noite fechada, 0.5 = tarde, 1 = meio-dia
func aplicar_ciclo(ciclo: float) -> void:
	if ciclo > 0.5:
		var peso := (ciclo - 0.5) * 2.0                  # tarde → dia
		color = cor_tarde.lerp(cor_dia, peso)
		energy = lerpf(0.7, 1.2, peso) * forca
		rotation_degrees = lerpf(-45.0, -135.0, peso)    # o sol caminha no céu
	else:
		var peso := ciclo * 2.0                          # noite → tarde
		color = cor_noite.lerp(cor_tarde, peso)
		energy = lerpf(0.3, 0.7, peso) * forca
		rotation_degrees = lerpf(-135.0, -45.0, peso)

# permite amarrar a luz à hora do MUNDO do jogo (mês/estação) em vez
# do relógio: meio-dia no verão, sol baixo no inverno.
func definir_pelo_mes(mes: int) -> void:
	ciclo_automatico = false
	var fator: float = 0.85 if (mes >= 6 and mes <= 8) else (0.62 if (mes >= 3 and mes <= 11) else 0.55)
	aplicar_ciclo(fator)
