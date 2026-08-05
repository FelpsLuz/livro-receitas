# ============================================================
# BLOCKOUT N5 — render + VERIFICAÇÃO dos critérios da §B.3 (v3.3).
# Os critérios não são afirmados: são medidos aqui e impressos com ✅/❌.
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/render_blockout.gd
# Salva em user://: blockout_n5{,_2x}.png, blockout_silhueta.png,
#                   blockout_castelo_{centro,medido}.png
# ============================================================
extends SceneTree

const SKYLINE := "res://assets_v2/cenario/base/derivados/skyline.json"
const MACICO := "res://assets_v2/cenario/base/derivados/macico.json"

var falhas := 0


func _initialize() -> void:
	_verificar()

	var vp := SubViewport.new()
	vp.size = Vector2i(Bandas.CANVAS_W, Bandas.CANVAS_H)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cena := BlockoutN5.new()
	vp.add_child(cena)

	# greybox N5 sobre a placa corrigida
	await _salvar(vp, cena, "blockout_n5", true)

	# planta: o mesmo layout SEM a placa — é assim que as trilhas e os
	# agrupamentos ficam legíveis (sobre a placa elas somem sob as peças,
	# que é o correto em cena mas inútil para conferir o traçado)
	cena.mostrar_fundo = false
	await _salvar(vp, cena, "blockout_planta", true)
	cena.mostrar_fundo = true

	# as duas posições de castelo, lado a lado, sem a vila na frente
	cena.nivel = 5
	for par in [["centro", 200], ["medido", LayoutN5.CASTELO["cx"]]]:
		cena.castelo_cx = int(par[1])
		await _salvar(vp, cena, "blockout_castelo_%s" % par[0], true)
	cena.castelo_cx = LayoutN5.CASTELO["cx"]

	# silhueta com a vila COMPLETA — agora o teste é informativo
	cena.silhueta = true
	await _salvar(vp, cena, "blockout_silhueta", true)

	print("\n", "✅ blockout sem falhas" if falhas == 0
			else "❌ %d critério(s) reprovado(s)" % falhas)
	quit(0)


func _salvar(vp: SubViewport, cena: BlockoutN5, nome: String,
		dobro: bool) -> void:
	cena.montar()
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("user://%s.png" % nome)
	if dobro:
		var d := img.duplicate()
		d.resize(Bandas.CANVAS_W * 2, Bandas.CANVAS_H * 2,
				Image.INTERPOLATE_NEAREST)
		d.save_png("user://%s_2x.png" % nome)
	print("💾 ", ProjectSettings.globalize_path("user://%s_2x.png" % nome))


func _ok(cond: bool, nome: String, detalhe: String) -> void:
	if not cond:
		falhas += 1
	print("  %s %s — %s" % ["✅" if cond else "❌", nome, detalhe])


func _verificar() -> void:
	print("=== CRITÉRIOS DE ACEITE DO BLOCKOUT (v3.3 §B.3) ===")

	# ---- 1. castelo x pico (v3.3 §B.2 pergunta 1) ----
	var sky: Array = _skyline()
	var c: Dictionary = LayoutN5.CASTELO
	var topo_castelo: int = c["base"] - c["h"]
	# controle: a posição ingênua (centro do quadro). NÃO é critério — é o
	# diagnóstico que justifica ter movido o castelo.
	print("  ℹ️  controle x=200 (centro): %s"
			% _folga_em(sky, 200, int(c["w"]), topo_castelo))
	_ok(_folga(sky, int(c["cx"]), int(c["w"]), topo_castelo) > 0,
			"castelo em x=%d não pousa sobre pico" % int(c["cx"]),
			_folga_em(sky, int(c["cx"]), int(c["w"]), topo_castelo))

	# folga contra o CUME DO MACIÇO — o critério do v3.4 §B.1 (alvo 16px,
	# mínimo 15 pela §F). Vem de macico.json, emitido pelo mesmo detector
	# que moveu o maciço: check e transformação não podem divergir.
	var mac := _macico()
	var folga_cume: int = int(mac["cume_y"]) - topo_castelo
	_ok(folga_cume >= 15, "folga castelo × cume do maciço ≥ 15px",
			"cume y=%d, castelo y=%d → %dpx (alvo 16 ±1)"
			% [int(mac["cume_y"]), topo_castelo, folga_cume])
	# a razão é contra a CASA PADRÃO. O sobrado (casa_camponesa_2, 42px)
	# existe para o dente de serra da §D.1 e não é a régua da §B.3.
	var casa_h := 0
	var sobrado_h := 0
	for p0 in LayoutN5.PECAS:
		if String(p0["n"]) == "casa_camponesa":
			casa_h = int(p0["h"])
		elif String(p0["n"]) == "casa_camponesa_2":
			sobrado_h = int(p0["h"])
	var razao: float = float(c["h"]) / maxf(1.0, float(casa_h))
	_ok(razao >= 2.0, "castelo ÷ casa padrão (altura)",
			"%.1f× contra casa de %dpx (%.1f× contra o sobrado de %dpx) · referência 4,4× · teto do formato 2:1 ~2,3×"
			% [razao, casa_h, float(c["h"]) / maxf(1.0, float(sobrado_h)), sobrado_h])

	# hierarquia global: na referência o castelo é a silhueta MAIS ALTA do
	# quadro (topo y=41 contra pico y=60, 19px acima). Aqui o maciço tem
	# topo y=32 — some as duas medidas e o sujeito perde para o fundo.
	var mais_alto := 999
	var onde := 0
	for x in Bandas.CANVAS_W:
		if int(sky[x]) < mais_alto:
			mais_alto = int(sky[x])
			onde = x
	var texto := "castelo y=%d vs cume y=%d em x=%d → %s por %dpx" % [
			topo_castelo, mais_alto, onde,
			"acima" if topo_castelo < mais_alto else "ABAIXO",
			absi(mais_alto - topo_castelo)]
	_ok(topo_castelo < mais_alto, "castelo é a silhueta mais alta do quadro",
			texto + " (referência: castelo 19px ACIMA do cume)")

	# ---- 2. agrupamento: ninguém isolado ----
	var pecas: Array = LayoutN5.pecas_do_nivel(5)
	var isolados: Array = []
	var vizinhos_ok := 0
	var pares := 0
	for a in pecas:
		var perto := false
		for b in pecas:
			if a == b:
				continue
			var ea: float = float(a["cx"]) - float(a["w"]) / 2.0
			var da: float = float(a["cx"]) + float(a["w"]) / 2.0
			var eb: float = float(b["cx"]) - float(b["w"]) / 2.0
			var db: float = float(b["cx"]) + float(b["w"]) / 2.0
			var sobre: float = minf(da, db) - maxf(ea, eb)
			if sobre > 0.0:
				perto = true
				# a faixa de 10–45% é critério de MASSA: só entre peças
				# grandes. Adereço de 8px (galinha, porco) contra casa de
				# 44 dá fração sem sentido — para eles vale só o "não está
				# isolado" acima.
				if int(a["w"]) >= 24 and int(b["w"]) >= 24 \
						and float(a["cx"]) < float(b["cx"]):
					pares += 1
					var frac: float = sobre / minf(float(a["w"]),
							float(b["w"]))
					if frac >= 0.10 and frac <= 0.45:
						vizinhos_ok += 1
		if not perto:
			isolados.append(a["n"])
	_ok(isolados.is_empty(), "nenhuma peça isolada",
			"%d/%d com vizinho sobreposto%s"
			% [pecas.size() - isolados.size(), pecas.size(),
			   "" if isolados.is_empty() else " — soltas: %s" % str(isolados)])
	_ok(pares > 0 and float(vizinhos_ok) / float(pares) >= 0.6,
			"sobreposição na faixa 10–45% (peças ≥24px)",
			"%d de %d pares" % [vizinhos_ok, pares])

	# ---- 2b. RUAS: o que separa massa de barra (medido na silhueta) ----
	var ocupado := []
	ocupado.resize(Bandas.CANVAS_W)
	ocupado.fill(false)
	for p in pecas:
		var e: int = maxi(0, int(p["cx"]) - int(p["w"]) / 2)
		var d: int = mini(Bandas.CANVAS_W, int(p["cx"]) + int(p["w"]) / 2)
		for x in range(e, d):
			ocupado[x] = true
	var ruas: Array = []
	var rua_ini := -1
	for x in Bandas.CANVAS_W:
		if not ocupado[x] and rua_ini < 0:
			rua_ini = x
		elif ocupado[x] and rua_ini >= 0:
			if x - rua_ini >= 10:
				ruas.append("%d..%d" % [rua_ini, x])
			rua_ini = -1
	_ok(ruas.size() >= 2, "ruas entre agrupamentos (≥2 de ≥10px)",
			"%d ruas: %s" % [ruas.size(), str(ruas)])

	# ---- 2c. §D.1 do v3.4: perfil em dente de serra ----
	var alta := 0
	var media := 0
	var baixa := 0
	for p in pecas:
		var h: int = int(p["h"])
		if h >= 40:
			alta += 1
		elif h >= 26:
			media += 1
		else:
			baixa += 1
	var nota := " (a tabela da spec pressupõe ~18 construções; o elenco tem"
	nota += " 10 + 7 adereços + 3 árvores)"
	_ok(alta >= 3 and alta <= 4, "peças altas (≥40px): 3–4",
			("alta %d · média %d · baixa %d" % [alta, media, baixa]) + nota)
	var vizinhas_altas: Array = []
	for a in pecas:
		if int(a["h"]) < 40:
			continue
		for b in pecas:
			if b == a or int(b["h"]) < 40 or int(b["cx"]) <= int(a["cx"]):
				continue
			var sobre: float = minf(float(a["cx"]) + float(a["w"]) / 2.0,
					float(b["cx"]) + float(b["w"]) / 2.0) \
					- maxf(float(a["cx"]) - float(a["w"]) / 2.0,
					float(b["cx"]) - float(b["w"]) / 2.0)
			if sobre > 0.0:
				vizinhas_altas.append("%s+%s" % [a["n"], b["n"]])
	_ok(vizinhas_altas.is_empty(), "nenhuma alta adjacente a outra alta",
			"0 pares" if vizinhas_altas.is_empty() else str(vizinhas_altas))

	# ---- 2d. §D.3: aldeões em profundidade, não em fileira ----
	var ys: Array = []
	for a in LayoutN5.ALDEOES:
		ys.append(a.y)
	ys.sort()
	var espalho: int = ys[ys.size() - 1] - ys[0]
	var fundo := 0
	var frente := 0
	for a in LayoutN5.ALDEOES:
		if a.y <= 135:
			fundo += 1
		elif a.y >= 162:
			frente += 1
	_ok(espalho >= 30 and fundo >= 3 and frente >= 3,
			"aldeões em profundidade",
			"espalhamento de Y %dpx, %d ao fundo, %d à frente" % [espalho, fundo, frente])
	var alturas_aldeao := {}
	for a in LayoutN5.ALDEOES:
		alturas_aldeao[a.z] = true
	_ok(alturas_aldeao.size() >= 2, "escala menor nos aldeões do fundo",
			"%d alturas distintas: %s" % [alturas_aldeao.size(),
			str(alturas_aldeao.keys())])

	# ---- 3. escalonamento de Y ----
	var bases: Array = []
	for p in pecas:
		bases.append(int(p["base"]))
	bases.sort()
	var iguais := 0
	for i in range(1, bases.size()):
		if bases[i] == bases[i - 1]:
			iguais += 1
	_ok(iguais <= 2, "escalonamento de Y",
			"%d bases repetidas, faixa %d..%d"
			% [iguais, bases[0], bases[bases.size() - 1]])

	# ---- 4. trilha liga ponte → praça → portão ----
	var t: Array = LayoutN5.TRILHA
	var ini: Vector2i = t[0]
	var fim: Vector2i = t[t.size() - 1]
	var na_ponte: bool = absi(ini.x - int(LayoutN5.PONTE["cx"])) <= 8 \
			and ini.y >= Bandas.BANDAS["rio"].x - 4
	var no_portao: bool = absi(fim.x - int(LayoutN5.PORTAO["cx"])) <= 6 \
			and absi(fim.y - int(LayoutN5.PORTAO["base"])) <= 4
	var passa_praca := false
	for p in t:
		if absi(p.x - int(LayoutN5.PRACA["cx"])) <= 12 \
				and absi(p.y - int(LayoutN5.PRACA["base"])) <= 10:
			passa_praca = true
	_ok(na_ponte and passa_praca and no_portao, "trilha ponte→praça→portão",
			"início (%d,%d), fim (%d,%d), passa na praça: %s"
			% [ini.x, ini.y, fim.x, fim.y, str(passa_praca)])
	_ok(LayoutN5.RAMAIS.size() >= 2, "ramais para os agrupamentos",
			"%d ramais" % LayoutN5.RAMAIS.size())

	# ---- 5. banda de campo preservada ----
	var campo: Vector2i = Bandas.BANDAS["campo"]
	_ok(campo.y - campo.x >= Bandas.CAMPO_MINIMO, "banda de campo",
			"%dpx ≥ mínimo %d" % [campo.y - campo.x, Bandas.CAMPO_MINIMO])
	var fora := 0
	for p in pecas:
		if int(p["base"]) < campo.x or int(p["base"]) > Bandas.BANDAS["rio"].x:
			fora += 1
	_ok(fora == 0, "pés dentro da banda de campo", "%d fora" % fora)

	# ---- 6. densidade de aldeões ----
	_ok(LayoutN5.ALDEOES.size() == LayoutN5.ALDEOES_POR_NIVEL[5],
			"aldeões no N5",
			"%d postados, tabela pede %d"
			% [LayoutN5.ALDEOES.size(), LayoutN5.ALDEOES_POR_NIVEL[5]])

	# ---- 7. muralha respeita o teto da banda ----
	var mur: Vector2i = Bandas.BANDAS["muralha"]
	_ok(mur.x >= 98, "topo da muralha", "y=%d (nunca acima de 98)" % mur.x)
	var uniforme := true
	for i in range(2, LayoutN5.TORRES.size()):
		if LayoutN5.TORRES[i] - LayoutN5.TORRES[i - 1] \
				== LayoutN5.TORRES[i - 1] - LayoutN5.TORRES[i - 2]:
			uniforme = false
	_ok(uniforme, "torres em intervalo não uniforme", str(LayoutN5.TORRES))
	print("")


func _folga(sky: Array, cx: int, w: int, topo: int) -> int:
	var crista := 999
	for x in range(maxi(0, cx - w / 2), mini(Bandas.CANVAS_W, cx + w / 2)):
		crista = mini(crista, int(sky[x]))
	return crista - topo


func _folga_em(sky: Array, cx: int, w: int, topo: int) -> String:
	var f: int = _folga(sky, cx, w, topo)
	return "topo y=%d, crista atrás y=%d → %s de %dpx" % [
			topo, topo + f, "folga" if f > 0 else "ENTERRADO", absi(f)]


func _macico() -> Dictionary:
	var f := FileAccess.open(MACICO, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _skyline() -> Array:
	var f := FileAccess.open(SKYLINE, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	return d["skyline"]
