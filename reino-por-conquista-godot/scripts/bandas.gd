# GERADO por ferramentas/cenario_v2/bandas.py — NÃO EDITAR À MÃO.
# Fonte única do orçamento vertical (spec §1). Para mudar um Y,
# mude bandas.py e rode: python3 ferramentas/cenario_v2/bandas.py --gd
class_name Bandas

const CANVAS_W := 400
const CANVAS_H := 200
const CASTELO_BASE := 116
const CASTELO_TOPO := 44
const CAMPO_MINIMO := 53

const BANDAS := {
	"ceu": Vector2i(0, 58),
	"montanhas": Vector2i(47, 82),
	"floresta": Vector2i(78, 107),
	"muralha": Vector2i(98, 116),
	"campo": Vector2i(111, 169),
	"rio": Vector2i(167, 189),
	"margem": Vector2i(187, 200),
}

const FATIAS := {
	"fundo": Vector2i(0, 78),
	"floresta": Vector2i(78, 111),
	"campo": Vector2i(111, 167),
	"rio": Vector2i(167, 187),
	"margem": Vector2i(187, 200),
}
