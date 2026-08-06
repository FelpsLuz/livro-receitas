# ============================================================
# CIDADE EM PIXEL ART (port de js/city.js para _draw())
# 480×270 lógicos com estações, rio, moinho, muralhas, castelo,
# fumaça e NPCs — escala junto com o Control.
# ============================================================
extends Control

var estado: Dictionary = {}
var anim := 0.0
var npcs: Array = []

const PALETAS := {
	"primavera": {"ceu_a": "8fc3e8", "ceu_b": "dcecc8", "grama": "79a655", "arvore": "4d7c3a", "campo": "7fa050", "colina": "6b9455", "neve": false},
	"verao":     {"ceu_a": "7ab5e0", "ceu_b": "f0e2b0", "grama": "8aa64f", "arvore": "48753a", "campo": "c9a94f", "colina": "7a9a50", "neve": false},
	"outono":    {"ceu_a": "a8b4c8", "ceu_b": "e8cfa0", "grama": "9a9050", "arvore": "a5622d", "campo": "8a7440", "colina": "8a8a55", "neve": false},
	"inverno":   {"ceu_a": "b8c4d0", "ceu_b": "e8ecf0", "grama": "dfe4e8", "arvore": "5a5248", "campo": "d8dde2", "colina": "c8d0d8", "neve": true},
}

func _ready() -> void:
	custom_minimum_size = Vector2(480, 270)
	semear_npcs()

func semear_npcs() -> void:
	npcs.clear()
	var nivel := _nivel()
	var n: int = 18 if nivel >= 5 else (12 if nivel >= 3 else (5 if nivel >= 1 else 3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cores := ["b03a3a", "3a5a8c", "c9a227", "4a7a4a", "7d4a8c", "8a5a3a"]
	for i in n:
		npcs.append({"x": 70.0 + rng.randf() * 330.0, "y": 196.0 + rng.randf() * 40.0,
			"vx": (rng.randf() - 0.5) * 0.5, "cor": Color(cores[i % cores.size()])})

func _process(delta: float) -> void:
	anim += delta * 60.0
	for npc in npcs:
		npc["x"] += npc["vx"]
		if npc["x"] < 55.0 or npc["x"] > 420.0:
			npc["vx"] = -npc["vx"]
		if npc["y"] > 222.0 and npc["y"] < 250.0:
			npc["y"] = 218.0
	queue_redraw()

func _nivel() -> int:
	if estado.is_empty() or estado.get("terra") == null:
		return -1
	return int(estado["terra"]["nivel"])

func _estacao() -> String:
	var mes: int = int(estado.get("mes", 6))
	if mes >= 3 and mes <= 5: return "primavera"
	if mes >= 6 and mes <= 8: return "verao"
	if mes >= 9 and mes <= 11: return "outono"
	return "inverno"

func _p(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)

func _esc(hex: String, f: float) -> Color:
	var c := Color(hex)
	return Color(c.r * f, c.g * f, c.b * f)

func _draw() -> void:
	var s: float = minf(size.x / 480.0, size.y / 270.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var pal: Dictionary = PALETAS[_estacao()]
	var nivel := _nivel()

	# céu e sol
	for i in 30:
		var t := i / 30.0
		_p(0, t * 150.0, 480, 5.5, Color(pal["ceu_a"]).lerp(Color(pal["ceu_b"]), t))
	_p(391, 29, 18, 18, Color("fdf3c0"))
	_p(394, 26, 12, 24, Color("fdf3c0"))
	_p(388, 32, 24, 12, Color("fdf3c0"))
	# nuvens
	var nx := fmod(anim * 0.10, 600.0) - 100.0
	_p(nx, 30, 46, 9, Color(0.98, 0.97, 0.94, 0.92))
	_p(nx + 8, 24, 26, 8, Color(0.98, 0.97, 0.94, 0.92))
	_p(fmod(anim * 0.16 + 200.0, 600.0) - 100.0, 58, 34, 7, Color(0.95, 0.94, 0.9, 0.85))

	# montanhas e colinas
	for x in range(0, 480, 4):
		var ym := 104.0 + sin(x * 0.021 + 2.0) * 14.0
		_p(x, ym, 4, 132.0 - ym, Color("8a94a8"))
	for x in range(0, 480, 4):
		var yc := 128.0 + sin(x * 0.014 + 5.0) * 9.0
		_p(x, yc, 4, 152.0 - yc, Color(pal["colina"]))
	# linha de floresta
	for i in 40:
		var fx := i * 12.0 + fposmod(i * 37.0, 8.0)
		var fy := 128.0 + sin(fx * 0.014 + 5.0) * 9.0
		var cor_arv: Color = Color(pal["arvore"]) if i % 2 == 0 else _esc(pal["arvore"], 0.85)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, fy + 2), Vector2(fx, fy - 9), Vector2(fx + 4, fy + 2)]), cor_arv)

	# chão
	_p(0, 144, 480, 126, Color(pal["grama"]))
	for i in 60:
		_p(fposmod(i * 53.0, 480.0), 146.0 + fposmod(i * 37.0, 120.0), 4, 2, _esc(pal["grama"], 0.88))

	# castelo (atrás do muro)
	if nivel >= 5:
		_castelo(195, 78, pal["neve"])

	# rio e ponte
	_p(0, 228, 480, 16, Color("9fb8cc") if pal["neve"] else Color("3f6e94"))
	for i in 12:
		var bx := fposmod(i * 41.0 + anim * (0.4 + (i % 3) * 0.2), 510.0) - 15.0
		_p(bx, 231.0 + (i % 4) * 3.0, 10, 1, Color("e0ecf4") if pal["neve"] else Color("7fb0d0"))
	_p(214, 224, 52, 5, Color("8a7a62"))
	for i in 6:
		_p(216 + i * 9, 229, 3, 13, Color("6b5d48"))

	# estrada
	var topo_y := 150.0 if nivel >= 1 else 158.0
	var meia := 14.0 if nivel >= 1 else 5.0
	var cor_rua := Color("a09788") if nivel >= 3 else Color("b09468")
	draw_colored_polygon(PackedVector2Array([
		Vector2(240 - meia, topo_y), Vector2(240 + meia, topo_y),
		Vector2(262, 226), Vector2(218, 226)]), cor_rua)
	draw_colored_polygon(PackedVector2Array([
		Vector2(214, 244), Vector2(266, 244), Vector2(282, 270), Vector2(198, 270)]), cor_rua)

	# árvores
	_arvore(30, 168, pal)
	_arvore(452, 172, pal)
	if nivel < 3:
		_arvore(120, 160, pal)
		_arvore(372, 162, pal)

	if nivel < 0:
		_tenda(130, 178, Color("8a6b45"))
		_tenda(300, 192, Color("7a6248"))
		_tenda(92, 204, Color("93765a"))
		_fogueira(200, 200)
		_npcs()
		return

	# campos
	if nivel >= 1:
		for c in [[16, 196], [66, 206], [380, 194], [424, 210]]:
			_campo(c[0], c[1], 44, 16, pal)

	if nivel == 0:
		_tenda(120, 176, Color("b0925f"))
		_tenda(310, 188, Color("a08a5c"))
		_fogueira(250, 196)

	# muralhas
	if nivel == 1 or nivel == 2:
		_palicada(152, pal["neve"])
	elif nivel >= 3:
		_muro_pedra(148, nivel >= 4, pal["neve"])

	# construções
	if nivel >= 1:
		_casa(96, 178, 38, 22, false, true, pal["neve"])
		_casa(326, 186, 34, 20, false, false, pal["neve"])
		_casa(144, 204, 32, 19, false, false, pal["neve"])
	if nivel >= 2:
		_moinho(44, 152)
		_casa(292, 212, 34, 20, false, true, pal["neve"])
	if nivel >= 3:
		_casa(96, 178, 38, 22, true, true, pal["neve"])
		_casa(326, 186, 34, 20, true, false, pal["neve"])
		_barraca(178, 196, Color("a03a3a"))
		_barraca(284, 190, Color("2d4a6b"))
	if nivel >= 4:
		_casa(56, 210, 32, 19, true, false, pal["neve"])
		_casa(390, 212, 32, 19, true, true, pal["neve"])
	_npcs()

func _arvore(x: float, y: float, pal: Dictionary) -> void:
	_p(x - 2, y - 8, 4, 10, Color("5d4428"))
	var c := Color(pal["arvore"])
	if pal["neve"]:
		_p(x - 1, y - 20, 2, 12, Color("5d4428"))
		_p(x - 7, y - 13, 6, 1, Color("5d4428"))
		_p(x + 1, y - 16, 7, 1, Color("5d4428"))
		return
	_p(x - 8, y - 16, 16, 8, c)
	_p(x - 6, y - 21, 12, 7, c)
	_p(x - 3, y - 24, 7, 5, c)

func _campo(x: float, y: float, w: float, h: float, pal: Dictionary) -> void:
	_p(x, y, w, h, Color("6b5638") if not pal["neve"] else Color("cfd6dc"))
	for ry in range(2, int(h) - 1, 3):
		_p(x + 1, y + ry, w - 2, 1, _esc(pal["campo"], 0.9))

func _tenda(x: float, y: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y + 15), Vector2(x + 11, y), Vector2(x + 22, y + 15)]), cor)
	_p(x + 8, y + 7, 5, 8, Color("4a3826"))

func _fogueira(x: float, y: float) -> void:
	_p(x - 3, y + 2, 4, 2, Color("6b4f30"))
	_p(x + 2, y + 2, 4, 2, Color("6b4f30"))
	var fl := sin(anim * 0.3) * 1.5
	_p(x, y - 2.0 + fl * 0.3, 4, 4, Color("d86a2d"))
	_p(x + 1, y - 4.0 + fl * 0.5, 2, 4, Color("f5a03c"))

func _fumaca(x: float, y: float, semente: float) -> void:
	for i in 4:
		var t := fposmod(anim * 0.5 + i * 22.0 + semente * 13.0, 88.0) / 88.0
		var fx: float = x + sin((t * 6.0 + semente) * 1.8) * (2.0 + t * 5.0)
		var fy: float = y - t * 26.0
		var tam := 1.0 + t * 3.2
		draw_rect(Rect2(fx - tam / 2.0, fy - tam / 2.0, tam, tam), Color(0.91, 0.9, 0.88, 0.55 * (1.0 - t)))

func _casa(x: float, y: float, w: float, h: float, pedra: bool, chamine: bool, neve: bool) -> void:
	var parede := Color("a8a095") if pedra else Color("e2d4b0")
	var viga := Color("5a4228")
	_p(x + 2, y + h, w, 3, Color(0.16, 0.12, 0.08, 0.25))
	_p(x, y, w, h, parede)
	if not pedra:
		_p(x, y, w, 2, viga)
		_p(x, y + h - 2, w, 2, viga)
		_p(x, y, 2, h, viga)
		_p(x + w - 2, y, 2, h, viga)
		_p(x + w / 2.0 - 1, y, 2, h, viga)
	var telha := Color("7d4a3a") if pedra else Color("a9862d")
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 3, y + 1), Vector2(x + w / 2.0, y - h * 0.6), Vector2(x + w + 3, y + 1)]), telha)
	if neve:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3, y), Vector2(x + w / 2.0, y - h * 0.6 - 1),
			Vector2(x + w + 3, y), Vector2(x + w, y), Vector2(x + w / 2.0, y - h * 0.6 + 2), Vector2(x, y)]), Color("eef2f6"))
	_p(x + w / 2.0 - 3, y + h - 8, 6, 8, Color("3a2d1d"))
	_p(x + 4, y + 6, 3, 4, Color("f5d060"))
	if w >= 30:
		_p(x + w - 8, y + 6, 3, 4, Color("f5d060"))
	if chamine:
		_p(x + w - 7, y - h * 0.45, 4, h * 0.35, Color("8a8078"))
		_fumaca(x + w - 5, y - h * 0.45 - 3.0, x)

func _moinho(x: float, y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y + 34), Vector2(x + 4, y), Vector2(x + 18, y), Vector2(x + 22, y + 34)]), Color("9a9288"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 1, y + 1), Vector2(x + 11, y - 9), Vector2(x + 23, y + 1)]), Color("7d4a3a"))
	_p(x + 8, y + 26, 6, 8, Color("3a2d1d"))
	# pás girando
	var centro := Vector2(x + 11, y + 2)
	for i in 4:
		var ang := anim * 0.018 + i * PI / 2.0
		var ponta := centro + Vector2(cos(ang), sin(ang)) * 24.0
		draw_line(centro, ponta, Color("e8dcc0"), 3.0)

func _barraca(x: float, y: float, cor: Color) -> void:
	_p(x, y, 2, 12, Color("6b4f30"))
	_p(x + 16, y, 2, 12, Color("6b4f30"))
	for i in range(0, 18, 3):
		_p(x - 1 + i, y - 4, 3, 5, Color("efe6cf") if (i / 3) % 2 == 0 else cor)
	_p(x + 1, y + 6, 16, 5, Color("8a6b45"))

func _palicada(y: float, neve: bool) -> void:
	for x in range(2, 476, 7):
		if x > 216 and x < 262:
			continue
		var hh := 16.0 + (x % 3)
		_p(x, y - hh + 14.0, 5, hh, Color("7a5c38"))
		if neve:
			_p(x, y - hh + 13.0, 5, 1, Color("eef2f6"))
	_p(216, y - 8, 47, 3, Color("6b4f30"))
	_p(222, y - 4, 35, 18, Color("7a5c38"))

func _muro_pedra(y: float, torres: bool, neve: bool) -> void:
	var base := Color("96918a")
	_p(0, y, 480, 18, base)
	for x in range(0, 480, 10):
		if x > 210 and x < 268:
			continue
		_p(x, y - 5, 6, 5, base)
		if neve:
			_p(x, y - 6, 6, 1, Color("eef2f6"))
	_p(212, y - 14, 56, 32, _esc("96918a", 0.9))
	_p(224, y - 2, 32, 20, Color("2d261e"))
	for gx in range(227, 256, 6):
		_p(gx, y - 6, 2, 24, Color("5a4a35"))
	if torres:
		for tx in [196, 268]:
			_p(tx, y - 26, 16, 44, Color("9a958d"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx - 3, y - 25), Vector2(tx + 8, y - 40), Vector2(tx + 19, y - 25)]), Color("7d3b3b"))
			_p(tx + 6, y - 14, 4, 6, Color("f5d060"))
			# estandarte
			_p(tx + 7, y - 52, 1, 12, Color("4a3826"))
			var ond := sin(anim * 0.09 + tx) * 2.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx + 8, y - 52), Vector2(tx + 20 + ond, y - 50), Vector2(tx + 8, y - 46)]), Color("8b2635"))

func _castelo(x: float, y: float, neve: bool) -> void:
	var pedra := Color("b0aca3")
	_p(x, y + 14, 90, 44, pedra)
	for i in range(0, 90, 9):
		_p(x + i, y + 10, 5, 5, pedra)
	for t in [[x - 16.0, 66.0], [x + 84.0, 66.0]]:
		_p(t[0], y + 72.0 - t[1], 22, t[1], Color("a5a198"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(t[0] - 4, y + 73.0 - t[1]), Vector2(t[0] + 11, y + 52.0 - t[1]),
			Vector2(t[0] + 26, y + 73.0 - t[1])]), Color("4a5568"))
		_p(t[0] + 9, y + 81.0 - t[1], 3, 5, Color("f5d060"))
	_p(x + 30, y - 18, 30, 34, Color("bab6ad"))
	for i in range(0, 30, 7):
		_p(x + 30 + i, y - 23, 4, 5, Color("bab6ad"))
	_p(x + 42, y - 11, 4, 6, Color("f5d060"))
	# estandarte real
	_p(x + 44, y - 40, 2, 17, Color("4a3826"))
	var ond := sin(anim * 0.08) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 46, y - 40), Vector2(x + 62 + ond, y - 36), Vector2(x + 46, y - 31)]), Color("c9a227"))
	_p(x + 36, y + 42, 18, 16, Color("2d261e"))
	for wx in [x + 10.0, x + 24.0, x + 66.0, x + 78.0]:
		_p(wx, y + 24, 5, 8, Color("f5d060"))
	if neve:
		_p(x, y + 13, 90, 2, Color("eef2f6"))

func _npcs() -> void:
	for npc in npcs:
		var passo := int(anim / 9.0 + npc["x"]) % 2
		_p(npc["x"], npc["y"] + 8, 5, 1, Color(0.16, 0.12, 0.08, 0.3))
		_p(npc["x"] + 1, npc["y"], 3, 3, Color("d8b090"))
		_p(npc["x"], npc["y"] + 3, 5, 4, npc["cor"])
		_p(npc["x"] + passo, npc["y"] + 7, 2, 2, Color("3a2d1d"))
		_p(npc["x"] + 3 - passo, npc["y"] + 7, 2, 2, Color("3a2d1d"))
