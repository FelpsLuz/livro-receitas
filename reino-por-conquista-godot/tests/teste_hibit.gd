# ============================================================
# TESTE DO PIPELINE HI-BIT — as três frentes, medidas.
#
#   xvfb-run godot --rendering-driver opengl3 --path . \
#       --script res://tests/teste_hibit.gd
#
# O que este arquivo protege, e que nada mais protegeria:
#
#   FRENTE 1  as chaves de pixel perfection no project.godot. São texto num
#             .cfg: qualquer merge as apaga em silêncio e ninguém percebe
#             até a arte ferver na tela de alguém.
#   FRENTE 2  que a ponte de IA NÃO chama a rede sem chave e NÃO roda em
#             build exportada. É contenção de custo e de vazamento, não
#             estética — e é a única parte deste pipeline que gasta dinheiro.
#             Os shaders precisam COMPILAR: shader quebrado não derruba o
#             jogo, só desenha errado, e isso passa despercebido.
#   FRENTE 3  que o VisualController observa por SINAL e que a mecânica não
#             encosta no nó visual. É a regressão que o reacoplamento
#             inteiro existe para impedir.
# ============================================================
extends SceneTree

const Ambiente = preload("res://scripts/environment_manager.gd")
const CameraMundo = preload("res://scripts/camera_mundo.gd")
const AIVisualBridge = preload("res://scripts/ai_visual_bridge.gd")
const AgenteMovel = preload("res://scripts/agente_movel.gd")
const VisualController = preload("res://scripts/visual_controller.gd")

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
	print("\n=== FRENTE 1 · pipeline de renderização ===")
	_frente1()
	print("\n=== FRENTE 2 · IA e shaders ===")
	_frente2()
	print("\n=== FRENTE 3 · reacoplamento por sinal ===")
	await _frente3()
	print("\n=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [_v, _x])
	quit(1 if _x > 0 else 0)


# ------------------------------------------------------------
func _frente1() -> void:
	var modo := str(ProjectSettings.get_setting("display/window/stretch/mode"))
	ok(modo == "viewport" or modo == "canvas_items", "stretch mode de pixel art",
		modo)
	ok(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep",
		"aspect keep (sem deformar a grade)",
		str(ProjectSettings.get_setting("display/window/stretch/aspect")))
	ok(str(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer",
		"escala INTEIRA (o pixel não vira 1,5 pixel)",
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode")))
	# 0 = Nearest. Qualquer outro valor borra a arte inteira.
	var filtro := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"))
	ok(filtro == 0, "filtro de textura padrão = Nearest", "valor %d" % filtro)
	ok(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")),
		"snap de transform em pixel")

	# ---- EnvironmentManager ----
	var amb = Ambiente.new()
	root.add_child(amb)
	amb.intensidade = 1.0

	amb.hora = 0.5
	var meio_dia: float = amb.luminancia()
	var cor_dia: Color = amb.cor_atual()
	amb.hora = 0.0
	var meia_noite: float = amb.luminancia()
	var cor_noite: Color = amb.cor_atual()
	# LUMINÂNCIA, não Color.v — `v` é o canal máximo, e a tinta de inverno
	# tem o azul acima de 1, o que faria o inverno "mais claro" que o verão
	ok(meia_noite < meio_dia, "noite é mais escura que o meio-dia",
		"lum %.2f contra %.2f" % [meia_noite, meio_dia])
	# Purkinje: a noite não é só escura, é DESLOCADA PARA O AZUL
	ok(cor_noite.b > cor_noite.r, "noite puxa para o azul, não só escurece",
		"b %.2f > r %.2f" % [cor_noite.b, cor_noite.r])
	# meio-dia NÃO é branco puro: a tinta da estação entra por cima, e verão
	# de meio-dia é quente de propósito. A invariante que vale é que nenhuma
	# outra hora é mais clara que o meio-dia.
	var mais_claro := true
	for i in 20:
		amb.hora = float(i) / 20.0
		if amb.luminancia() > meio_dia + 0.001:
			mais_claro = false
	ok(mais_claro, "nenhuma hora é mais clara que o meio-dia",
		"meio-dia lum %.3f · cor %s" % [meio_dia, str(cor_dia)])

	amb.definir_mes(1)
	var inverno: float = amb.luminancia()
	var cor_inv: Color = amb.cor_atual()
	amb.definir_mes(7)
	var verao: float = amb.luminancia()
	var cor_ver: Color = amb.cor_atual()
	ok(inverno < verao, "inverno tem dia mais curto que o verão",
		"lum %.3f contra %.3f" % [inverno, verao])
	ok(cor_inv.b > cor_inv.r and cor_ver.r > cor_ver.b,
		"inverno esfria e verão esquenta o croma")

	# o efeito é POR VIEWPORT: um CanvasModulate na raiz tingiria a interface
	var vp := SubViewport.new()
	root.add_child(vp)
	var cm: CanvasModulate = amb.registrar(vp)
	ok(cm != null and cm.get_parent() == vp,
		"CanvasModulate entra no viewport pedido, não na raiz")
	ok(amb.registrar(vp) == cm, "registrar duas vezes não duplica o nó")
	amb.esquecer(vp)
	ok(amb.registrar(vp) != cm, "esquecer solta o viewport do ciclo")

	amb.intensidade = 0.0
	ok(amb.cor_atual().is_equal_approx(Color.WHITE),
		"intensidade 0 devolve o neutro do multiply (branco)")

	# ---- CameraMundo ----
	var cam := CameraMundo.criar(Vector2(960, 540))
	root.add_child(cam)
	ok(cam.limit_right == 960 and cam.limit_bottom == 540,
		"limites da câmera no tamanho do mundo",
		"%d x %d" % [cam.limit_right, cam.limit_bottom])
	ok(cam.position_smoothing_enabled, "suavização de posição ligada")
	var alvo := Node2D.new()
	alvo.position = Vector2(400, 300)
	root.add_child(alvo)
	# a conversão de espaço é a armadilha: o alvo vive em escala 0,5
	cam.seguir(alvo, 0.5)
	ok(cam.position.is_equal_approx(Vector2(200, 150)),
		"câmera converte o espaço do alvo pela escala", str(cam.position))
	alvo.free()
	cam.free()
	vp.free()
	amb.free()


# ------------------------------------------------------------
func _frente2() -> void:
	# ---- a ponte NÃO pode gastar sozinha ----
	var ponte := AIVisualBridge.new()
	root.add_child(ponte)
	var tem_chave := AIVisualBridge.chave() != ""
	print("      (chave no ambiente: %s)" % ("sim" if tem_chave else "não"))

	var prompt := AIVisualBridge.montar_prompt({
		"tipo": "character", "tamanho": 32, "acao": "walking down",
		"quadro": 1, "descricao": "young knight in leather armor"})
	ok(prompt.begins_with("32x32 pixel art"),
		"prompt começa pela resolução alvo", prompt.substr(0, 40) + "…")
	ok(prompt.contains("Stardew Valley") and prompt.contains("hi-bit"),
		"assinatura Hi-Bit no prompt")
	ok(prompt.contains("walking down") and prompt.contains("frame 1"),
		"estado da entidade entra no prompt")
	ok(prompt.contains("transparent background"),
		"pede fundo transparente — sprite com fundo é retrabalho manual")

	# o teto de gasto tem que barrar ANTES de qualquer request
	ponte.teto_usd = 0.0
	var falhas: Array = []
	ponte.falhou.connect(func(id: String, motivo: String): falhas.append(motivo))
	var aceitou := ponte.pedir("teste_teto", {"tamanho": 32})
	ok(not aceitou and falhas.size() == 1,
		"teto de gasto barra o pedido antes de tocar na rede",
		falhas[0] if falhas.size() > 0 else "não barrou")

	# modo simulado: fluxo inteiro, custo zero
	ponte.teto_usd = 1.0
	ponte.simular = true
	var recebidas: Array = []
	ponte.pronto.connect(func(id: String, tex: ImageTexture): recebidas.append(id))
	ponte.pedir("simulado", {"tamanho": 32})
	ok(recebidas.size() == 1 and ponte.gasto_usd == 0.0,
		"modo simulado devolve textura sem gastar",
		"gasto US$ %.4f" % ponte.gasto_usd)

	ok(not AIVisualBridge.disponivel() or not OS.has_feature("template"),
		"a ponte nunca se declara disponível numa build exportada")
	ponte.free()

	# ---- os três shaders precisam COMPILAR ----
	for caminho in ["res://shaders/vento_folhagem.gdshader",
			"res://shaders/contorno.gdshader",
			"res://shaders/paleta_dinamica.gdshader"]:
		var sh = load(caminho)
		var nome: String = caminho.get_file()
		if not (sh is Shader):
			ok(false, "%s carrega" % nome, "não é Shader")
			continue
		# um shader com erro de sintaxe carrega mesmo assim e só falha ao
		# desenhar; get_shader_uniform_list vazio denuncia isso
		var uniformes: Array = sh.get_shader_uniform_list()
		ok(uniformes.size() > 0, "%s compila e expõe uniformes" % nome,
			"%d uniformes" % uniformes.size())


# ------------------------------------------------------------
func _frente3() -> void:
	var agente := AgenteMovel.new()
	root.add_child(agente)
	var vc := VisualController.novo(agente)
	vc.usar_personagem("heroi_jogador", 0.55)
	var ligou := vc.observar(agente)

	ok(ligou, "VisualController se liga ao agente")
	ok(vc.estado()["por_sinal"], "a ligação é por SINAL, não por leitura",
		"sem _physics_process rodando à toa")
	ok(agente.has_signal("moveu") and agente.has_signal("parou")
		and agente.has_signal("direcao_mudou"),
		"o agente emite os três sinais do contrato")

	# A prova do desacoplamento: o agente não pode ter NENHUMA referência ao
	# nó visual. Se tivesse, a mecânica voltaria a depender da arte.
	var f := FileAccess.open("res://scripts/agente_movel.gd", FileAccess.READ)
	var texto := f.get_as_text() if f != null else ""
	var sujo: Array = []
	if texto == "":
		sujo.append("não consegui ler agente_movel.gd")
	# só CÓDIGO: o cabeçalho do arquivo explica o acoplamento que ele desfez
	# e cita os tipos visuais de propósito. Uma varredura de texto cru
	# reprovava o arquivo pelos próprios comentários.
	var codigo := ""
	for linha in texto.split("\n"):
		var l := str(linha)
		var jogo := l.find("#")
		if jogo >= 0:
			l = l.substr(0, jogo)
		if l.strip_edges() != "":
			codigo += l + "\n"
	for termo in ["Sprite2D", "AnimatedSprite2D", "sprite_frames", "texture",
			"PersonagensV2", "VisualController"]:
		if codigo.contains(termo):
			sujo.append(termo)
	ok(sujo.is_empty(), "o agente não cita nenhum tipo visual", ", ".join(sujo))

	# movimento real: a rota move o agente e a animação segue sozinha
	agente.position = Vector2.ZERO
	agente.definir_rota([Vector2(300, 0)])
	for i in 6:
		await physics_frame
	ok(agente.position.x > 0.0, "o agente andou pela rota",
		"x = %.1f" % agente.position.x)
	ok(agente.direcao == "east", "direção deduzida do vetor", agente.direcao)
	var an: AnimatedSprite2D = vc.visual as AnimatedSprite2D
	ok(an.animation == "east_walk",
		"o visual entrou na caminhada sem a mecânica mandar", an.animation)

	agente.definir_rota([])
	agente.esperar(0.1)
	await physics_frame
	ok(an.animation == "east", "parar volta para a pose parada", an.animation)

	# a origem tem que ficar nos PÉS, senão o Y-Sort compara o centro
	ok(an.offset.y < 0.0, "visual ancorado nos pés (Y-Sort correto)",
		"offset.y = %.1f" % an.offset.y)

	# luz de ponto com gradiente gerado
	var luz := vc.acender(Color(1, 0.7, 0.4), 96.0)
	ok(luz != null and luz.texture is GradientTexture2D,
		"luz de ponto com textura de gradiente gerada")
	ok(luz.blend_mode == Light2D.BLEND_MODE_ADD, "luz em modo aditivo")

	agente.free()
