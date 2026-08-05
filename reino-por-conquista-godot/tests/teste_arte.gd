# ============================================================
# TESTE DA ARTE HI-BIT — a guarda de que a arte está lá e importada certo.
#
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/teste_arte.gd
#
# Este arquivo era `teste_strip.gd` e afirmava o CONTRÁRIO: que não havia
# imagem nenhuma no projeto. O strip cumpriu o papel dele — separar mecânica
# de arte — e terminou quando a arte real entrou. A guarda inverteu junto, e
# é a mesma ideia: travar por MEDIDA o que quebra sem ninguém perceber.
#
#   1. OS ARQUIVOS EXISTEM e carregam como Texture2D no tamanho esperado.
#   2. O .import está com os parâmetros de PIXEL ART. É a parte que some
#      calada: a Godot regenera .import sozinha, e o default de compressão
#      VRAM muda cor de pixel num sprite de 32px sem um erro no console.
#   3. O ALFA É BINÁRIO. Meio-alfa com filtro Nearest não suaviza nada — só
#      deixa borda suja, que aparece contra qualquer fundo.
#   4. Os pontos de estrangulamento devolvem a ARTE, não mais o caixote, e
#      o TileSet manteve física, navegação e o terrain set de auto-tiling.
# ============================================================
extends SceneTree

const MapaV2 = preload("res://scripts/mapa_v2.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")

const PASTA := "res://assets/sprites/"

## O inventário do que a leva de arte entregou, com o tamanho de cada um.
## `VilaCena.TAMANHO_OBJ` espelha estes números; divergir tira a origem dos
## pés do lugar e o Y-Sort passa a ordenar errado.
const ESPERADO := {
	"campo_terra_atlas": Vector2i(128, 128),
	"grama_pedra_atlas": Vector2i(128, 128),
	"praia_agua_atlas": Vector2i(128, 128),
	"prop_arvore_carvalho": Vector2i(64, 80),
	"prop_pedra": Vector2i(48, 40),
	"prop_arbusto": Vector2i(32, 32),
	"prop_tronco": Vector2i(48, 32),
	"aldeao_south": Vector2i(48, 68),
	"aldeao_north": Vector2i(48, 68),
	"aldeao_east": Vector2i(48, 68),
	"aldeao_west": Vector2i(48, 68),
}

const IMPORT_OBRIGATORIO := {
	"compress/mode": "0",
	"process/fix_alpha_border": "false",
	"mipmaps/generate": "false",
	"detect_3d/compress_to": "0",
}

var _v := 0
var _x := 0


func ok(cond: bool, nome: String, obs: String = "") -> void:
	print("  %s %s%s" % ["✅" if cond else "❌", nome,
		("  —  " + obs) if obs != "" else ""])
	if cond:
		_v += 1
	else:
		_x += 1


func _initialize() -> void:
	print("\n=== ARTE HI-BIT ===\n")

	for nome in ESPERADO:
		var caminho: String = PASTA + nome + ".png"
		if not ResourceLoader.exists(caminho):
			ok(false, nome, "ausente")
			continue
		var t = load(caminho)
		var alvo: Vector2i = ESPERADO[nome]
		ok(t is Texture2D and t.get_size() == Vector2(alvo), nome,
			str(t.get_size()) if t is Texture2D else "não é Texture2D")

	print("")
	for nome in ESPERADO:
		var f := FileAccess.open(PASTA + nome + ".png.import", FileAccess.READ)
		if f == null:
			ok(false, "%s: .import presente" % nome, "ausente")
			continue
		var texto := f.get_as_text()
		var faltando: Array = []
		for chave in IMPORT_OBRIGATORIO:
			if not texto.contains("%s=%s" % [chave, IMPORT_OBRIGATORIO[chave]]):
				faltando.append("%s≠%s" % [chave, IMPORT_OBRIGATORIO[chave]])
		ok(faltando.is_empty(), "%s: import de pixel art" % nome,
			", ".join(faltando))

	print("")
	for nome in ESPERADO:
		var t = load(PASTA + nome + ".png")
		if not (t is Texture2D):
			continue
		var img: Image = t.get_image()
		if img == null:
			ok(false, "%s: imagem legível" % nome)
			continue
		var parciais := 0
		for y in img.get_height():
			for x in img.get_width():
				var al := img.get_pixel(x, y).a
				if al > 0.004 and al < 0.996:
					parciais += 1
		ok(parciais == 0, "%s: alfa binário" % nome, "%d px parciais" % parciais)

	print("")
	var ts: TileSet = MapaV2.montar("campo_terra_atlas", 32, [Vector2i(0, 0)])
	ok(ts != null and ts.get_source_count() > 0, "TileSet monta do atlas real")
	var fonte: TileSetAtlasSource = ts.get_source(0)
	ok(fonte.texture.get_size() == Vector2(128, 128),
		"TileSet usa a textura de 128×128", str(fonte.texture.get_size()))
	ok(ts.get_physics_layers_count() > 0 and ts.get_navigation_layers_count() > 0,
		"física e navegação continuam no TileSet")
	ok(ts.get_terrain_sets_count() > 0 and ts.get_terrains_count(0) == 2,
		"terrain set de 2 terrenos para auto-tiling",
		"%d terrenos" % (ts.get_terrains_count(0) if ts.get_terrain_sets_count() > 0 else 0))
	var solido: TileData = fonte.get_tile_data(Vector2i(0, 0), 0)
	ok(solido != null and solido.get_collision_polygons_count(0) == 1,
		"tile sólido com polígono de colisão")

	print("")
	ok(PersonagensV2.tem_arte("aldeao"), "personagem tem as 4 rotações")
	var sf: SpriteFrames = PersonagensV2.quadros("aldeao")
	var faltam: Array = []
	for d in PersonagensV2.DIRECOES:
		if not sf.has_animation(d):
			faltam.append(d)
		if not sf.has_animation(d + "_walk"):
			faltam.append(d + "_walk")
	ok(faltam.is_empty(), "as 8 direções resolvem sobre 4 desenhos",
		", ".join(faltam))
	ok(sf.get_frame_texture("south-east", 0) == sf.get_frame_texture("east", 0),
		"a diagonal cai na LATERAL, não na frontal",
		"de lado o personagem lê como andando; de frente, como parado")

	for caminho in ["res://shaders/vento_folhagem.gdshader",
			"res://shaders/contorno.gdshader",
			"res://shaders/paleta_dinamica.gdshader"]:
		var sh = load(caminho)
		ok(sh is Shader and sh.get_shader_uniform_list().size() > 0,
			"%s compila" % caminho.get_file())

	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)
