# ============================================================
# TESTE DO VISUAL STRIP — a guarda de que o projeto continua sem arte.
#
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/teste_strip.gd
#
# Três coisas, e as três são regressões que não dariam erro sozinhas:
#
#   1. NENHUM arquivo de imagem no projeto. Um PNG que volta sem ninguém
#      notar é exatamente o começo da salada que o strip desfez.
#   2. Nenhum script CARREGA imagem. Um `load("res://...png")` que
#      sobreviveu só quebra quando aquela tela abre — pode levar semanas.
#   3. Todo ponto de estrangulamento de arte devolve um caixote VÁLIDO, do
#      tamanho certo. É a promessa que segura o layout: quem chama nunca
#      recebe null onde antes recebia textura.
#
# O que NÃO se testa aqui é mecânica — disso cuidam teste_nucleo, teste_reino,
# teste_combate, teste_marchas, teste_cerco, teste_fase3, teste_vila e
# teste_overhaul. Este arquivo só garante que a arte não voltou de fininho.
# ============================================================
extends SceneTree

const Arte = preload("res://scripts/arte.gd")
const Icones = preload("res://scripts/icones.gd")
const UIv2 = preload("res://scripts/ui_v2.gd")
const Retratos = preload("res://scripts/retratos.gd")
const SpritesPersonagens = preload("res://scripts/sprites_personagens.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const MapaV2 = preload("res://scripts/mapa_v2.gd")

## As únicas imagens toleradas. Fonte não é arte de cena: é tipografia, e um
## jogo de economia em que não se lê "custo 80" é um jogo quebrado.
const TOLERADO := ["res://assets/fontes/"]
const EXT_IMAGEM := ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga"]

var _v := 0
var _x := 0


func ok(cond: bool, nome: String, obs: String = "") -> void:
	print("  %s %s%s" % ["✅" if cond else "❌", nome,
		("  —  " + obs) if obs != "" else ""])
	if cond:
		_v += 1
	else:
		_x += 1


func _varrer(dir: String, achados: Array, alvo: Callable) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var caminho := dir.path_join(nome)
		if d.current_is_dir():
			if not nome.begins_with("."):
				_varrer(caminho, achados, alvo)
		elif alvo.call(caminho):
			achados.append(caminho)
		nome = d.get_next()
	d.list_dir_end()


func _initialize() -> void:
	print("\n=== VISUAL STRIP ===\n")

	# ---------- 1. nenhum arquivo de imagem ----------
	var imagens: Array = []
	_varrer("res://", imagens, func(c: String) -> bool:
		if not EXT_IMAGEM.has(c.get_extension().to_lower()):
			return false
		for t in TOLERADO:
			if c.begins_with(t):
				return false
		return true)
	ok(imagens.is_empty(), "nenhum arquivo de imagem no projeto",
		"%d encontrado(s)%s" % [imagens.size(),
			("" if imagens.is_empty() else ": " + ", ".join(imagens.slice(0, 5)))])

	# ---------- 2. nenhum script carrega imagem ----------
	var scripts: Array = []
	_varrer("res://", scripts, func(c: String) -> bool:
		return c.get_extension() == "gd")
	var culpados: Array = []
	# monta o padrão em tempo de execução: escrito literal, ele acharia a si
	# mesmo dentro deste arquivo e o teste falharia sempre
	var re := RegEx.new()
	re.compile("(load|exists)\\s*\\(\\s*\"res://[^\"]+\\.(%s)\"" % "|".join(EXT_IMAGEM))
	for s in scripts:
		if s == "res://tests/teste_strip.gd":
			continue
		var f := FileAccess.open(s, FileAccess.READ)
		if f == null:
			continue
		if re.search(f.get_as_text()) != null:
			culpados.append(s)
	ok(culpados.is_empty(), "nenhum script carrega imagem",
		", ".join(culpados) if not culpados.is_empty() else "%d .gd varridos" % scripts.size())

	# ---------- 3. os pontos de estrangulamento devolvem caixote ----------
	print("")
	var cx := Arte.caixa(64)
	ok(cx != null and cx.get_width() == 64 and cx.get_height() == 64,
		"Arte.caixa devolve textura do tamanho pedido",
		"%dx%d" % [cx.get_width(), cx.get_height()] if cx else "null")
	ok(Arte.caixa(64) == Arte.caixa(64), "caixote é cacheado por dimensão",
		"mesma instância nas duas chamadas")

	var sem: Array = []
	for n in Icones.TODOS:
		if Icones.textura(n) == null:
			sem.append(n)
	ok(sem.is_empty(), "os %d ícones resolvem" % Icones.TODOS.size(), ", ".join(sem))
	ok(Icones.slot("trigo", 48) != null, "slot de inventário monta")

	var sem_ui: Array = []
	for n in UIv2.MARGENS.keys():
		var np: NinePatchRect = UIv2.criar_painel(n)
		if np == null or np.texture == null:
			sem_ui.append(str(n))
		elif np.texture.get_width() <= np.patch_margin_left + np.patch_margin_right:
			# 9-slice degenera quando as margens somam mais que a textura:
			# os cantos se atropelam e a moldura vira uma placa só
			sem_ui.append("%s (margens > textura)" % n)
	ok(sem_ui.is_empty(), "as %d peças de UI viram 9-slice sadio" % UIv2.MARGENS.size(),
		", ".join(sem_ui))
	ok(UIv2.estilos_botao().size() >= 4, "botão tem os 4 estados no Theme",
		", ".join(UIv2.estilos_botao().keys()))

	ok(Retratos.textura("rei_touros") != null, "retrato de personagem resolve")
	ok(Retratos.textura_cidadao({"nome": "Alda", "oficio": "ferreiro"}) != null,
		"retrato de cidadão criado em partida resolve")
	ok(Retratos.ilustracao("cerco") != null, "ilustração de evento conhecido resolve")
	ok(Retratos.ilustracao("evento_que_nao_existe") == null,
		"evento desconhecido ainda devolve null",
		"a lista fechada sobreviveu ao strip")
	ok(SpritesPersonagens.textura("rei_touros") != null, "sprite de personagem resolve")

	# a ESTRUTURA de animação é mecânica e tem que ter sobrevivido inteira
	var sf: SpriteFrames = PersonagensV2.quadros("heroi_jogador")
	var faltando: Array = []
	for d in PersonagensV2.DIRECOES:
		if not sf.has_animation(d):
			faltando.append(d)
		if not sf.has_animation(d + "_walk"):
			faltando.append(d + "_walk")
	ok(faltando.is_empty(), "herói mantém as 8 direções paradas e andando",
		", ".join(faltando))
	ok(sf.get_frame_count("south_walk") > 1
		and sf.get_frame_texture("south_walk", 0) != null,
		"caminhada com vários quadros, todos com textura",
		"%d quadros" % sf.get_frame_count("south_walk"))
	ok(sf.get_animation_speed("south_walk") > sf.get_animation_speed("south"),
		"caminhada roda mais rápido que a pose parada")

	# o TileSet é quase todo mecânica: física e navegação não podem ter ido junto
	var ts: TileSet = MapaV2.montar("campo_terra_atlas", 32, [Vector2i(0, 0)])
	ok(ts != null and ts.get_physics_layers_count() > 0
		and ts.get_navigation_layers_count() > 0,
		"TileSet mantém camada de física e de navegação")
	var fonte: TileSetAtlasSource = ts.get_source(0)
	var solido: TileData = fonte.get_tile_data(Vector2i(0, 0), 0)
	var livre: TileData = fonte.get_tile_data(Vector2i(1, 1), 0)
	ok(solido != null and solido.get_collision_polygons_count(0) == 1,
		"tile sólido continua com polígono de colisão")
	ok(livre != null and livre.get_navigation_polygon(0) != null,
		"tile caminhável continua na malha de navegação")

	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)
