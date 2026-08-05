# ============================================================
# TESTE DA VILA EM NÓS NATIVOS
# Prova que a aba "Terra" virou cena de verdade: TileMapLayer no chão,
# objetos do PixelLab como Sprite2D, herói animado caminhando e — o ponto
# que mais quebra na prática — Y-Sort ordenando pela BASE de cada sprite.
#   godot --headless --path . --script res://tests/teste_vila.gd
# ============================================================
extends SceneTree

const VilaCena = preload("res://scripts/vila_cena.gd")
const PersonagensV2 = preload("res://scripts/personagens_v2.gd")
const MapaV2 = preload("res://scripts/mapa_v2.gd")
const Icones = preload("res://scripts/icones.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func _initialize() -> void:
	print("=== VILA EM NÓS NATIVOS ===")

	ok("vila montável (caixotes sempre disponíveis)", VilaCena.disponivel())

	# ---------- direção a partir do vetor de movimento ----------
	# o Y da tela cresce para BAIXO: descer é "south", não "north"
	var casos := {
		"east": Vector2(1, 0), "south": Vector2(0, 1),
		"west": Vector2(-1, 0), "north": Vector2(0, -1),
		"south-east": Vector2(1, 1), "north-west": Vector2(-1, -1),
		"south-west": Vector2(-1, 1), "north-east": Vector2(1, -1),
	}
	var erradas: Array = []
	for esperado in casos:
		var achou: String = VilaCena.direcao_de(casos[esperado])
		if achou != esperado:
			erradas.append("%s→%s" % [esperado, achou])
	ok("as 8 direções saem certas do vetor", erradas.is_empty(), ", ".join(erradas))
	ok("vetor parado não quebra", VilaCena.direcao_de(Vector2.ZERO) == "south")
	# toda direção gerada precisa existir no SpriteFrames, senão o herói congela
	var sf: SpriteFrames = PersonagensV2.quadros("heroi_jogador")
	var sem_anim: Array = []
	for esperado in casos:
		if not sf.has_animation(esperado + "_walk"):
			sem_anim.append(esperado)
	ok("toda direção da rota tem animação", sem_anim.is_empty(), ", ".join(sem_anim))

	# ---------- a cena monta? ----------
	var vila = VilaCena.new()
	root.add_child(vila)
	vila.estado = {"terra": {"nivel": 5, "nome": "Teste"}, "mes": 6}
	await process_frame

	ok("SubViewport criado", vila.viewport is SubViewport)
	ok("terreno é TileMapLayer com células escritas",
		vila.terreno is TileMapLayer and vila.terreno.get_used_cells().size() > 0,
		"%d células" % (vila.terreno.get_used_cells().size() if vila.terreno else -1))
	ok("faixa de água montada",
		vila.agua is TileMapLayer and vila.agua.get_used_cells().size() > 0,
		"%d células" % (vila.agua.get_used_cells().size() if vila.agua else -1))

	# ---------- Y-SORT: o ponto central desta etapa ----------
	ok("mundo com Y-Sort ligado", vila.mundo != null and vila.mundo.y_sort_enabled)
	# GRADE HI-BIT: 1:1. A arte nasce em 32px e é desenhada em 32px. Antes
	# era 1:2, o que mostrava um tile de 32 com 16 — meia resolução do que
	# se pagou para gerar. Fracionário nunca; inteiro sempre.
	ok("escala do mundo é razão inteira",
		vila.mundo.scale == Vector2(VilaCena.ESCALA_MUNDO, VilaCena.ESCALA_MUNDO)
		and is_equal_approx(VilaCena.ESCALA_MUNDO, roundf(VilaCena.ESCALA_MUNDO)),
		str(vila.mundo.scale))
	ok("camada de terreno com Y-Sort",
		vila.terreno != null and vila.terreno.y_sort_enabled)
	# cada sprite precisa ter a origem nos pés, senão o Y-Sort compara o centro
	var mal_ancorados: Array = []
	for f in vila.mundo.get_children():
		var alt := 0.0
		if f is Sprite2D and f.texture != null:
			alt = f.texture.get_height()
		elif f is AnimatedSprite2D and f.sprite_frames != null:
			var t: Texture2D = f.sprite_frames.get_frame_texture(f.animation, 0)
			alt = t.get_height() if t != null else 0.0
		if alt > 0.0 and not is_equal_approx(f.offset.y, -alt / 2.0):
			mal_ancorados.append("%s off=%.1f alt=%.0f" % [f.name, f.offset.y, alt])
	ok("todo sprite ancorado nos pés", mal_ancorados.is_empty(),
		", ".join(mal_ancorados))

	var n_obj: int = vila._objetos.size()
	var n_ald: int = vila._aldeoes.size()
	print("  ℹ️  nível 5: %d objetos, %d aldeões" % [n_obj, n_ald])
	ok("objetos da vila instanciados", n_obj > 0)
	ok("aldeões instanciados", n_ald > 0)
	# a vila tem que CRESCER com a terra: o castelo é privilégio do nível 5
	var ids5: Array = []
	for p in vila._planta(5):
		ids5.append(p[0])
	var ids1: Array = []
	for p in vila._planta(1):
		ids1.append(p[0])
	ok("torre do castelo só aparece no nível 5",
		"torre_castelo" in ids5 and not ("torre_castelo" in ids1))
	ok("muralha e portão chegam no nível 3",
		"portao_fortificado" in vila._planta(3).map(func(p): return p[0])
		and not ("portao_fortificado" in ids1))

	# ---------- INTEGRAÇÃO: escala e planta ----------
	# VISUAL STRIP: as asserções de sombra, fumaça e fogo saíram junto com o
	# vfx.gd. O que restou aqui é o que continua sendo mecânica de cena —
	# a ESCALA de cada objeto e a sua posição no mundo, que é o que decide
	# quem cobre quem no Y-Sort.
	# a escala vive no VISUAL, não no agente: o agente é mecânica pura e não
	# tem tamanho (ver scripts/agente_movel.gd)
	ok("herói na escala da vila (casas parecem casas)",
		vila.heroi_visual != null and vila.heroi_visual.visual != null
		and vila.heroi_visual.visual.scale.is_equal_approx(
			Vector2(VilaCena.ESCALA_HEROI, VilaCena.ESCALA_HEROI)))
	# a árvore tem arte real e vem em tamanho NATIVO; o que ainda não tem
	# desenho continua entrando como caixote, e é isso que se confere aqui
	var arvore = vila.mundo.get_node_or_null("Obj_arvore_carvalho")
	ok("árvore com arte real em escala nativa",
		arvore != null and arvore.texture != null
		and arvore.texture.get_size() == Vector2(64, 80)
		and arvore.scale.is_equal_approx(Vector2.ONE),
		str(arvore.texture.get_size() if arvore else "ausente"))
	ok("árvore com shader de vento",
		arvore != null and arvore.material is ShaderMaterial)
	var casa = vila.mundo.get_node_or_null("Obj_casa_camponesa")
	ok("casa camponesa montada no mundo", casa != null)
	var tocha = vila.mundo.get_node_or_null("Obj_tocha_estaca")
	ok("tocha do portão montada no mundo", tocha != null)
	ok("moldura de floresta pintada",
		vila.floresta != null and vila.floresta.get_used_cells().size() > 0,
		"%d células" % (vila.floresta.get_used_cells().size() if vila.floresta else -1))
	var ponte = vila.mundo.get_node_or_null("Obj_ponte_madeira")
	ok("ponte cruzando o rio", ponte != null)
	if ponte != null:
		# o tabuleiro precisa ENCOSTAR na linha da areia (y=830), onde a rua
		# termina — o eixo portão→praça→ponte é o que costura a composição
		var topo: float = ponte.position.y - ponte.texture.get_height() * ponte.scale.y
		ok("ponte encosta onde a rua termina", absf(topo - 830.0) < 4.0,
			"topo em y=%.0f" % topo)

	# ---------- o herói caminha e vira ----------
	# O herói é um AGENTE (mecânica) com um VisualController pendurado. A
	# separação é o ponto: o agente anda sem saber que existe sprite, e a
	# animação segue por SINAL. Se isto voltar a ser um AnimatedSprite2D
	# movido à mão, o acoplamento voltou.
	ok("herói é agente de mecânica, não sprite", vila.heroi is AgenteMovel)
	ok("herói tem controlador visual ligado",
		vila.heroi_visual != null and vila.heroi_visual.estado()["por_sinal"])
	if vila.heroi != null:
		var antes: Vector2 = vila.heroi.position
		for i in 20:
			vila.heroi._physics_process(0.05)
		ok("herói se moveu ao longo da rota", vila.heroi.position != antes,
			"%.0f px" % antes.distance_to(vila.heroi.position))
		var an: AnimatedSprite2D = vila.heroi_visual.visual as AnimatedSprite2D
		ok("o visual entrou em caminhada sem a mecânica mandar",
			an != null and an.animation.ends_with("_walk"),
			an.animation if an else "sem visual")
		# a rota é um laço fechado: chegar ao último ponto volta ao primeiro
		var voltas: Array = []
		vila.heroi.chegou.connect(func(i: int): voltas.append(i))
		var rota: Array = vila.heroi._rota
		vila.heroi._alvo = rota.size() - 1
		vila.heroi.position = rota[rota.size() - 1]
		vila.heroi._physics_process(0.05)
		ok("rota é um laço fechado", vila.heroi._alvo == 0,
			"alvo=%d · chegou emitiu %d vez(es)" % [vila.heroi._alvo, voltas.size()])

	# ---------- WANG: as transições saem da máscara certa ----------
	# pinta um único canto "cheio" em (1,1) e confere as 4 células vizinhas
	# contra o dicionário WANG — se o layout embaralhar, isto pega
	var unit: TileMapLayer = MapaV2.criar_camada("campo_terra_atlas", 32)
	if unit != null:
		MapaV2.pintar_wang(unit, Rect2i(0, 0, 2, 2),
			func(c: Vector2i) -> bool: return c == Vector2i(1, 1))
		var esperado := {
			Vector2i(0, 0): MapaV2.WANG[8],   # cheio só no canto inferior-direito
			Vector2i(1, 0): MapaV2.WANG[4],   # ... inferior-esquerdo
			Vector2i(0, 1): MapaV2.WANG[2],   # ... superior-direito
			Vector2i(1, 1): MapaV2.WANG[1],   # ... superior-esquerdo
		}
		var wang_errados: Array = []
		for cel in esperado:
			if unit.get_cell_atlas_coords(cel) != esperado[cel]:
				wang_errados.append("%s→%s (esperava %s)" %
					[cel, unit.get_cell_atlas_coords(cel), esperado[cel]])
		ok("máscara de cantos escolhe o tile Wang certo", wang_errados.is_empty(),
			", ".join(wang_errados))
		unit.free()

	# ---------- a vila acompanha o nível da terra ----------
	# o chão conta a mesma história que as construções
	ok("cidade murada tem rua calçada", vila.rua.get_used_cells().size() > 0,
		"%d células" % vila.rua.get_used_cells().size())
	# a lavoura EXISTE no nível alto: alguma célula da região arada tem tile
	# de transição/terra (não só grama pura) — se tem_lavoura morrer, isto pega
	var arada_n5 := 0
	for lav in VilaCena.LAVOURAS:
		for y in range(lav.position.y - 1, lav.end.y + 1):
			for x in range(lav.position.x - 1, lav.end.x + 1):
				if vila.terreno.get_cell_atlas_coords(Vector2i(x, y)) != MapaV2.TILE_CHEIO:
					arada_n5 += 1
	ok("lavouras aradas no nível 5", arada_n5 > 0, "%d células" % arada_n5)
	# remontar de verdade não pode DUPLICAR nós na cena (o array _objetos
	# sempre volta do mesmo tamanho; o que denuncia vazamento é a árvore)
	var filhos_antes: int = vila.mundo.get_child_count()
	vila.semear_npcs()
	await process_frame
	await process_frame          # o queue_free dos antigos precisa de um quadro
	ok("remontagem não duplica nós na árvore",
		vila.mundo.get_child_count() == filhos_antes,
		"%d ≠ %d" % [vila.mundo.get_child_count(), filhos_antes])
	var no_5: int = vila._objetos.size()
	vila.estado = {"terra": {"nivel": 1, "nome": "Teste"}, "mes": 6}
	await process_frame
	ok("vila menor no nível 1 que no 5", vila._objetos.size() < no_5,
		"%d < %d" % [vila._objetos.size(), no_5])
	# nível 0 é a terra RECÉM-COMPRADA (jogo.gd cria com nivel 0) e também o
	# resultado de um saque: precisa mostrar o acampamento, não uma clareira
	vila.estado = {"terra": {"nivel": 0, "nome": "Teste"}, "mes": 6}
	await process_frame
	ok("nível 0 (terra comprada) mostra o acampamento",
		vila.mundo.get_node_or_null("Obj_tenda_grande") != null
		and vila.mundo.get_node_or_null("Obj_fogueira_acampamento") != null,
		"%d objetos" % vila._objetos.size())
	# sem terra nenhuma: acampamento, e nada pode quebrar
	vila.estado = {"terra": null, "mes": 1}
	await process_frame
	ok("acampamento (sem terra) monta sem quebrar", vila._objetos.size() > 0,
		"%d objetos" % vila._objetos.size())
	ok("acampamento não tem rua calçada", vila.rua.get_used_cells().is_empty(),
		"%d células" % vila.rua.get_used_cells().size())
	# acampamento HABITADO: tendas, fogueira, e a ponte que é geografia
	ok("acampamento tem tendas", vila.mundo.get_node_or_null("Obj_tenda_grande") != null
		and vila.mundo.get_node_or_null("Obj_tenda_simples") != null)
	ok("acampamento tem fogueira",
		vila.mundo.get_node_or_null("Obj_fogueira_acampamento") != null)
	ok("ponte permanece no acampamento",
		vila.mundo.get_node_or_null("Obj_ponte_madeira") != null)
	# sem terra não há lavoura: o chão é só grama, sem tile de terra arada
	var arada := 0
	for c in vila.terreno.get_used_cells():
		if vila.terreno.get_cell_atlas_coords(c) != MapaV2.TILE_CHEIO:
			arada += 1
	ok("acampamento não tem lavoura", arada == 0, "%d células aradas" % arada)
	# o rio é geografia: continua lá em qualquer nível
	ok("rio permanece sem terra", vila.agua.get_used_cells().size() > 0)
	# remontar duas vezes seguidas não pode duplicar objetos
	var antes_semear: int = vila._objetos.size()
	vila.semear_npcs()
	ok("semear_npcs() não duplica objetos", vila._objetos.size() == antes_semear,
		"%d = %d" % [vila._objetos.size(), antes_semear])

	# ---------- ÍCONES DE INVENTÁRIO ----------
	var inv_i: Dictionary = Icones.inventario()
	ok("os %d ícones do catálogo resolvem" % Icones.TODOS.size(),
		inv_i["falta"].is_empty(), ", ".join(inv_i["falta"]))
	var slot := Icones.slot("trigo", 48)
	var com_icone := false
	for f3 in slot.get_children():
		if f3 is TextureRect and f3.texture != null:
			com_icone = true
	ok("slot() monta a moldura Pro com o ícone dentro", com_icone)
	slot.free()
	ok("toda MERCADORIA do mercado tem ícone",
		Icones.de_mercadoria("trigo") != null and Icones.de_mercadoria("cavalos") != null
		and Icones.de_mercadoria("ferro") != null and Icones.de_mercadoria("sal") != null
		and Icones.de_mercadoria("tecidos") != null and Icones.de_mercadoria("madeira") != null)

	vila.queue_free()
	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
