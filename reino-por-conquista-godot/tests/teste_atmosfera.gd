# ============================================================
# TESTE — atmosfera e a escada nível→cena, headless.
#
# Roda com --script (sem renderer, sem autoload), então NÃO testa shader
# compilado nem partícula na tela — testa o que dá para provar sem GPU:
# os dados medidos são coerentes com a arte, a máscara de água encontra
# água de verdade, e as texturas geradas nascem com o tamanho prometido.
#   godot --headless --path . --script res://tests/teste_atmosfera.gd
# ============================================================
extends SceneTree

var _v := 0
var _x := 0

func ok(cond: bool, nome: String, extra: String = "") -> void:
	if cond:
		_v += 1
		print("  ✅ %s%s" % [nome, ("  —  " + extra) if extra != "" else ""])
	else:
		_x += 1
		print("  ❌ %s%s" % [nome, ("  —  " + extra) if extra != "" else ""])

func _initialize() -> void:
	var Atm = load("res://scripts/atmosfera.gd")
	var Cena = load("res://scripts/cenario_v3_cena.gd")
	var Vista = load("res://scripts/cenario_v3_view.gd")

	print("\n=== DADOS MEDIDOS × ARTE ===")
	var dados: Dictionary = Atm.DADOS_ESTAGIO
	ok(dados.size() == Cena.NOMES.size(),
		"há dados medidos para cada cena", "%d de %d" % [dados.size(), Cena.NOMES.size()])
	for i in Cena.NOMES.size():
		var d: Dictionary = dados.get(i, {})
		if d.is_empty():
			ok(false, "estágio %d tem dados" % i)
			continue
		var horiz: int = int(d.get("y_horizonte", -1))
		ok(horiz > 0 and horiz < 224, "estágio %d: horizonte dentro da arte" % i,
			"y=%d" % horiz)
		for grupo in ["chamines", "fogueiras", "janelas"]:
			for p in d.get(grupo, []):
				if int(p[0]) < 0 or int(p[0]) >= 400 or int(p[1]) < 0 or int(p[1]) >= 224:
					ok(false, "estágio %d: %s fora da arte" % [i, grupo], str(p))

	print("\n=== MÁSCARA DE ÁGUA ===")
	for i in Cena.NOMES.size():
		var d: Dictionary = dados.get(i, {})
		if not bool(d.get("agua_presente", false)):
			continue
		var m: Texture2D = Atm.mascara_de(i)
		ok(m != null, "estágio %d: máscara existe" % i)
		if m == null:
			continue
		var img := m.get_image()
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).r > 0.5:
					n += 1
		# a água de um rio na base da cena: entre 1% e 30% da imagem.
		# Menos que isso é máscara furada (cores erradas); mais é vazamento.
		var frac := float(n) / float(img.get_width() * img.get_height())
		ok(frac > 0.01 and frac < 0.30,
			"estágio %d: máscara pega água plausível" % i, "%.1f%%" % (frac * 100.0))

	print("\n=== TEXTURAS GERADAS ===")
	ok(Atm._textura_janela() != null, "luz de janela nasce")
	ok(Atm._textura_glow().get_width() == 24, "glow de fogueira nasce")
	ok(Atm._textura_nuvem(1000).get_width() >= 34, "nuvem nasce com corpo")
	ok(Atm._shader() != null and Atm._shader().code.length() > 100,
		"o shader de água tem código")

	print("\n=== ÍCONES GERADOS (pedra, prata) ===")
	var Icones = load("res://scripts/icones.gd")
	for nome in ["pedra", "prata"]:
		var t: Texture2D = Icones.textura(nome)
		ok(t != null and t.get_width() == 192,
			"ícone gerado de %s no contrato de 192px" % nome)
		var img2 := t.get_image()
		var opacos := 0
		for y in range(0, img2.get_height(), 3):
			for x in range(0, img2.get_width(), 3):
				if img2.get_pixel(x, y).a > 0.5:
					opacos += 1
		ok(opacos > 200, "ícone de %s tem silhueta de verdade" % nome,
			"%d amostras opacas" % opacos)

	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)
