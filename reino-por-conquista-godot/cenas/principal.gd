# ============================================================
# REINO POR CONQUISTA — cena principal (fase 2)
# Toda a interface é construída em código: título, abas de
# gestão, cidade pixel art, conversa com "ponderar" e
# máquina de escrever, modais de evento e fim de jogo.
# ============================================================
extends Control

const Dados = preload("res://scripts/dados.gd")
const Kit = preload("res://scripts/kit.gd")
const UIv2 = preload("res://scripts/ui_v2.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Economia = preload("res://scripts/economia.gd")
const Combate = preload("res://scripts/combate.gd")
const Clas = preload("res://scripts/clas.gd")
const Intriga = preload("res://scripts/intriga.gd")
const Contratos = preload("res://scripts/contratos.gd")
const Jogo = preload("res://scripts/jogo.gd")
const Tema = preload("res://scripts/tema.gd")
const Retratos = preload("res://scripts/retratos.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Llm = preload("res://scripts/llm.gd")
const CidadeView = preload("res://scripts/cidade_view.gd")
const CidadeCena = preload("res://scripts/cidade_cena.gd")
const CenarioV3View = preload("res://scripts/cenario_v3_view.gd")
const Icones = preload("res://scripts/icones.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Empregos = preload("res://scripts/empregos.gd")
const Pretendentes = preload("res://scripts/pretendentes.gd")
const Viagem = preload("res://scripts/viagem.gd")
const Barbaros = preload("res://scripts/barbaros.gd")
const MapaMundi = preload("res://cenas/mapa_mundi.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Relogio = preload("res://scripts/relogio.gd")
const Rotas = preload("res://scripts/rotas.gd")
const Cerco = preload("res://scripts/cerco.gd")
const Intel = preload("res://scripts/intel.gd")
const Equipar = preload("res://scripts/equipar.gd")
const Inimizade = preload("res://scripts/inimizade.gd")
const Armazem = preload("res://scripts/armazem.gd")
const Estacoes = preload("res://scripts/estacoes.gd")
const Vassalagem = preload("res://scripts/vassalagem.gd")
const Comandantes = preload("res://scripts/comandantes.gd")

const NPCS_TAVERNA := [
	{"id": "taverneiro", "nome": "Bram, o Taverneiro", "personalidade": "ganancioso"},
	{"id": "capitao", "nome": "Capitã Renna", "personalidade": "honrado"},
	{"id": "espiao", "nome": "O Corvo", "personalidade": "calculista"},
]

## Cada taverna tem nome próprio e fregueses próprios (Bloco II): quem
## bebe no Covil Negro não é quem bebe na capital imperial. O id de cada
## freguês é a chave do retrato hi-bit E da relação em `tags` — conversar
## com o arpoador das Garças fica lembrado ali, não numa ficha genérica.
## O Reino sem Rei fica com o trio clássico (Bram, Renna e o Corvo — é
## para onde gente sem bandeira vai beber) e as Terras Bárbaras não têm
## taverna: clã não serve cerveja a forasteiro.
const TAVERNAS := {
	"jogador":  "Taverna do Javali Manco",
	"imperio":  "Salão do Cetro Torto",
	"touros":   "Caneca do Urso Afogado",
	"alvorecer":"Pátio da Moeda de Cobre",
	"leoes":    "Estalagem do Cervo Coroado",
	"aguias":   "Farol da Garça Cinzenta",
	"rosa":     "Adega da Víbora Doce",
	"sem_rei":  "Buraco Sem Bandeira",
	"barbaros": "Fogueira dos Clãs",
}
const FREGUESES_POR_LOCAL := {
	"imperio": [
		{"id": "fregues_imperio_1", "nome": "Otto Dedo-de-Tinta", "personalidade": "calculista"},
		{"id": "fregues_imperio_2", "nome": "Vera da Nona Legião", "personalidade": "honrado"},
		{"id": "fregues_imperio_3", "nome": "Tulio, o Escriba", "personalidade": "covarde"},
	],
	"touros": [
		{"id": "fregues_touros_1", "nome": "Grom Remo-Quebrado", "personalidade": "cruel"},
		{"id": "fregues_touros_2", "nome": "Velha Ysolda", "personalidade": "honrado"},
		{"id": "fregues_touros_3", "nome": "Snorri do Âmbar", "personalidade": "ganancioso"},
	],
	"alvorecer": [
		{"id": "fregues_alvorecer_1", "nome": "Basim das Especiarias", "personalidade": "ganancioso"},
		{"id": "fregues_alvorecer_2", "nome": "Nadir Troca-Moeda", "personalidade": "calculista"},
		{"id": "fregues_alvorecer_3", "nome": "Samira das Caravanas", "personalidade": "honrado"},
	],
	"leoes": [
		{"id": "fregues_leoes_1", "nome": "Cedric, Escudeiro", "personalidade": "orgulhoso"},
		{"id": "fregues_leoes_2", "nome": "Irmão Anselmo", "personalidade": "sabio"},
		{"id": "fregues_leoes_3", "nome": "Rowena Caça-Cervos", "personalidade": "calculista"},
	],
	"aguias": [
		{"id": "fregues_aguias_1", "nome": "Halvar do Gelo", "personalidade": "honrado"},
		{"id": "fregues_aguias_2", "nome": "Viúva Gudrun", "personalidade": "ganancioso"},
		{"id": "fregues_aguias_3", "nome": "Eirik Arpoador", "personalidade": "cruel"},
	],
	"rosa": [
		{"id": "fregues_rosa_1", "nome": "Mestre Faruk, Perfumista", "personalidade": "calculista"},
		{"id": "fregues_rosa_2", "nome": "Dona Vespa", "personalidade": "orgulhoso"},
		{"id": "fregues_rosa_3", "nome": "Sálvia, a Herbolária", "personalidade": "ganancioso"},
	],
	"jogador": [
		{"id": "fregues_jogador_1", "nome": "Velho Milo, Moleiro", "personalidade": "honrado"},
		{"id": "fregues_jogador_2", "nome": "Finn Laço-Torto", "personalidade": "covarde"},
		{"id": "fregues_jogador_3", "nome": "Tia Berta, Parteira", "personalidade": "sabio"},
	],
	"sem_rei": [],   # preenchido em _fregueses_do_local com o trio clássico
	"barbaros": [],  # clã não tem taverna
}

func _fregueses_do_local() -> Array:
	var local := str(state.get("local", ""))
	if local == "sem_rei":
		return NPCS_TAVERNA
	return FREGUESES_POR_LOCAL.get(local, NPCS_TAVERNA)
## As onze abas: rótulo visível e o sufixo do ícone (icone_aba_<sufixo>).
## Uma tabela só, para nome e ícone não saírem de sincronia.
# [rótulo, id da aba, ÍCONE]. O terceiro campo existe porque nem toda aba
# tem um ícone com o seu próprio nome: a Taverna se anuncia pela caneca e o
# Exército pela espada. Antes o código montava "aba_" + id e pedia
# `aba_taverna`, que nunca existiu — as abas caíam no caixote cinza sem
# que nada acusasse, porque o fallback do Icones é silencioso de propósito.
## "Terra", não "Sua Terra": com onze abas de plaqueta + ícone, as duas
## sílabas extras eram exatamente o que empurrava "Crônica" para trás das
## setas de rolagem num canvas de 960 — a última aba nascia invisível.
const ABAS := [
	["Terra", "terra", "terra"], ["Mapa", "mapa", "mapa"],
	["Feira", "mercado", "mercado"], ["Taverna", "taverna", "cerveja"],
	["Corte", "corte", "coroa"], ["Tropas", "exercito", "espada"],
	["Clãs", "clas", "alianca"], ["Intriga", "intrigas", "intriga"],
	["Casa", "familia", "familia"], ["Crônica", "cronica", "pergaminho"],
	["Guerra", "guerras", "cerco"],
]

const MESES := ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
	"Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]

## A coroa na barra de tarefas e no canto da janela.
##
## `config/icon` do projeto só vale para o EDITOR; a janela do jogo
## rodando nasce com o losango do Godot até alguém trocar em runtime — era
## por isso que o executável de teste "ainda usava o ícone da engine".
## (O ícone gravado DENTRO do .exe é outro passo, do exportador: ver
## PLATAFORMAS.md.) Lido pelo filesystem virtual, como toda arte aqui.
func _icone_da_janela() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var bytes := FileAccess.get_file_as_bytes("res://icone_jogo.png")
	if bytes.is_empty():
		return
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return
	DisplayServer.set_icon(img)

var state: Dictionary = {}
var npc_atual: Dictionary = {}
var digitando := false
# geração da conversa: sobe a cada abrir/fechar. As corrotinas de resposta
# (_responder atravessa awaits de LLM e de digitação) comparam a geração em
# que nasceram — sair da conversa no meio do "pondera..." matava npc_atual
# sob os pés delas: SCRIPT ERROR e `digitando` preso em true para sempre.
var conversa_geracao := 0
# as falas desta conversa, na ordem — é a MEMÓRIA que vai no prompt da IA.
# Sem ela cada turno nascia amnésico e o personagem repetia a mesma frase.
var conversa_turnos: Array = []
var conversa_texto := ""

var tela_titulo: Control
var tela_jogo: Control
var status_label: Label
## A data mora no rodapé, colada no botão que a faz andar — e não mais na
## barra de cima, onde era o pedaço da linha de identidade que sempre
## sobrava cortado.
var data_label: Label
var hud: HBoxContainer
var tabs: TabContainer
var cidade_view: Control
var quartel: Timer
var overlay_conversa: Control
var conversa_hist: RichTextLabel
var conversa_input: LineEdit
var conversa_retrato: TextureRect
var conversa_titulo: Label
var conversa_relacao: HBoxContainer
var overlay_modal: Control
var modal_centro: CenterContainer
var input_nome: LineEdit
var b_som: Button
var b_dia: Button
var musica_titulo: AudioStreamPlayer
var musica_jogo: AudioStreamPlayer
var fila_musicas: Array[String] = []
var _musica_atual := ""

func _ready() -> void:
	theme = Tema.criar()
	_icone_da_janela()
	# O fundo era um ColorRect chapado. Um retângulo de 960×540 numa cor só é
	# a diferença entre "escuro" e "vazio": o gradiente (3% de luminância do
	# topo à base) e a vinheta nos cantos não são percebidos como efeito, são
	# percebidos como profundidade — e é o que faz a tela parar de parecer um
	# documento e passar a parecer um espaço. As duas texturas nascem em
	# `tema.gd`, somam 4 KB e não custam um quadro.
	var fundo := TextureRect.new()
	fundo.texture = Tema.textura_fundo()
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var vinheta := TextureRect.new()
	vinheta.texture = Tema.textura_vinheta()
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vinheta)
	_montar_titulo()
	_montar_jogo()
	_montar_conversa()
	_montar_modal()
	tela_jogo.visible = false
	overlay_conversa.visible = false
	overlay_modal.visible = false
	# ---- a MOLDURA DE PEDRA da referência, na borda da tela ----
	# Por cima de tudo (inclusive modais — ela é borda, nada encosta nela) e
	# com draw_center desligado: só a cantaria desenha, o miolo é o jogo.
	var tex_moldura := Tema.tex_hibit("ui_moldura_pedra")
	if tex_moldura != null:
		var moldura := NinePatchRect.new()
		moldura.texture = tex_moldura
		moldura.draw_center = false
		moldura.patch_margin_left = 20
		moldura.patch_margin_right = 20
		moldura.patch_margin_top = 20
		moldura.patch_margin_bottom = 20
		moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
		moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		moldura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		moldura.self_modulate = Color(1.30, 1.27, 1.18)
		add_child(moldura)

# ---------------- TELA DE TÍTULO ----------------
func _montar_titulo() -> void:
	tela_titulo = CenterContainer.new()
	tela_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tela_titulo)
	# ---- a composição ----
	#
	# A tela anterior era um painel com cinco filhos empilhados e a mesma
	# separação de 10px entre todos: a vitrine, o título, o subtítulo, o
	# campo e o botão liam como cinco itens de um formulário, e o botão
	# esticado na largura inteira fechava o assunto — parecia a página de
	# cadastro de um site.
	#
	# O que muda aqui é AGRUPAMENTO. A vitrine encosta no topo, sem moldura
	# própria (ela já é uma imagem emoldurada); título e subtítulo formam um
	# bloco colado; o campo e os botões formam outro, separados do primeiro
	# por um respiro de verdade. Três grupos, não cinco itens.
	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", Tema.estilo_modal())
	caixa.custom_minimum_size = Vector2(560, 0)
	tela_titulo.add_child(caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E4)
	caixa.add_child(v)

	# a tela de título mostra um reino no auge — a mesma vila do jogo, nível 5
	var quadro := PanelContainer.new()
	var sb_q := StyleBoxFlat.new()
	sb_q.bg_color = Color("100d0b")
	sb_q.border_color = Tema.BORDA
	sb_q.set_border_width_all(1)
	sb_q.set_corner_radius_all(0)
	sb_q.set_content_margin_all(1)
	quadro.add_theme_stylebox_override("panel", sb_q)
	quadro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(quadro)
	var vitrine: SubViewportContainer = _nova_cena()
	vitrine.custom_minimum_size = Vector2(CenarioV3View.NATIVO * CenarioV3View.ESCALA)
	quadro.add_child(vitrine)
	# nível 8 — o CASTELO pronto: a tela de título é a promessa do jogo, e a
	# promessa é o último degrau da escada, não o meio dela
	vitrine.estado = {"terra": {"nivel": 8}, "mes": 6}

	# ---- título + subtítulo: um bloco só ----
	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", Tema.E1)
	v.add_child(bloco)
	# a linha de cima do título: caixa alta pequena e apagada, o que um
	# frontispício de livro faz antes de dizer o nome da obra
	var supra := Label.new()
	supra.text = " ".join("ESTRATÉGIA MEDIEVAL".split(""))
	supra.add_theme_font_size_override("font_size", Tema.MINI)
	supra.add_theme_color_override("font_color", Tema.TEXTO_3)
	supra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bloco.add_child(supra)
	var titulo := Label.new()
	titulo.text = "REINO POR CONQUISTA"
	var f_titulo := Tema.fonte_titulo()
	if f_titulo != null:
		titulo.add_theme_font_override("font", f_titulo)
	titulo.add_theme_font_size_override("font_size", Tema.TITULO_JOGO)
	titulo.add_theme_color_override("font_color", Tema.ACENTO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bloco.add_child(titulo)
	# régua curta e centrada sob o título: o ornamento mais barato que existe.
	# A altura de 15px é o que dá ar em volta dela — num CenterContainer de
	# altura mínima a régua encostava nos ascendentes do subtítulo e lia como
	# um risco em cima do texto, não como ornamento.
	var orn := CenterContainer.new()
	orn.custom_minimum_size = Vector2(0, 15)
	bloco.add_child(orn)
	var risco := PanelContainer.new()
	var sb_r := StyleBoxFlat.new()
	sb_r.bg_color = Tema.ACENTO_FUNDO
	sb_r.set_corner_radius_all(0)
	risco.add_theme_stylebox_override("panel", sb_r)
	risco.custom_minimum_size = Vector2(120, 1)
	orn.add_child(risco)
	var sub := Label.new()
	sub.text = "De mercenário sem nome a rei — se as intrigas, a fome e as adagas deixarem."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Tema.TEXTO_2)
	sub.add_theme_font_size_override("font_size", Tema.MICRO)
	bloco.add_child(sub)

	# ---- o que se faz aqui ----
	Kit.respiro(v, Tema.E2)
	input_nome = LineEdit.new()
	input_nome.placeholder_text = "Nome do seu mercenário (opcional)"
	input_nome.max_length = 24
	input_nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(input_nome)
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", Tema.E3)
	acoes.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(acoes)
	# UM primário na tela, e é o verbo pelo qual a tela existe. "Continuar"
	# fica fantasma ao lado: quem tem save sabe procurá-lo, e quem não tem
	# não deve ver dois botões do mesmo peso.
	var b_novo := Kit.botao(acoes, "Nova Saga",
		func(): iniciar_jogo(input_nome.text.strip_edges()), "primario", 180)
	b_novo.add_theme_font_size_override("font_size", Tema.CORPO)
	if Jogo.tem_save():
		# valida o save JÁ no título: arquivo corrompido/mutilado ganhava um
		# botão normal cujo clique morria em silêncio — agora o botão conta
		var b_cont := Kit.botao(acoes, "Continuar Saga", continuar_jogo, "fantasma", 160)
		if Jogo.carregar() == null:
			b_cont.disabled = true
			b_cont.tooltip_text = "O arquivo de save está danificado — comece uma Nova Saga."

	# ---- a trilha ----
	# A praça do mercado à noite, em loop (acabou, recomeça — é o próprio
	# stream que dá a volta). O player mora na CENA, não na tela de título:
	# quando o jogo começa a tela morre na hora, e é o fade de 1.4s abaixo,
	# não um corte seco, que faz a transição soar intencional.
	var trilha := Sfx.musica_titulo()
	if trilha != null:
		musica_titulo = AudioStreamPlayer.new()
		musica_titulo.stream = trilha
		musica_titulo.volume_db = -6.0
		add_child(musica_titulo)
		if not Sfx.mudo:
			musica_titulo.play()

func iniciar_jogo(nome: String) -> void:
	Sfx.tocar(self, "tique")
	# a conversa aberta é o coração do jogo, e ela precisa de uma IA para
	# interpretar o jogador de verdade: a PRIMEIRA saga obriga a escolher
	# — mesmo que a escolha consciente seja "sem IA"
	if not Llm.ja_escolheu():
		_modal_llm(func():
			state = Jogo.novo_jogo(nome)
			_entrar_no_jogo())
		return
	state = Jogo.novo_jogo(nome)
	_entrar_no_jogo()

func continuar_jogo() -> void:
	var salvo = Jogo.carregar()
	if salvo == null or (salvo is Dictionary and (salvo as Dictionary).is_empty()):
		# nunca entrar numa tela morta: o save recusado vira aviso com saída
		Sfx.tocar(self, "alerta")
		_modal("SAVE DANIFICADO",
			"O arquivo de save não pôde ser lido. A saga anterior se perdeu — comece uma Nova Saga.",
			[["Entendi", func(): pass]])
		return
	Sfx.tocar(self, "tique")
	if not Llm.ja_escolheu():
		_modal_llm(func():
			state = salvo
			_entrar_no_jogo())
		return
	state = salvo
	_entrar_no_jogo()

func _entrar_no_jogo() -> void:
	# liberar, não esconder: visible=false NÃO para o _process — a vitrine do
	# título (uma vila nível 5 inteira, com herói, aldeões e partículas)
	# continuaria simulando escondida a sessão toda
	if is_instance_valid(tela_titulo):
		tela_titulo.queue_free()
		tela_titulo = null
	if is_instance_valid(musica_titulo):
		var tw := create_tween()
		tw.tween_property(musica_titulo, "volume_db", -40.0, 1.4)
		tw.tween_callback(musica_titulo.queue_free)
		musica_titulo = null
	_iniciar_musica_jogo()
	tela_jogo.visible = true
	cidade_view.estado = state
	cidade_view.semear_npcs()
	# a memória dos números anteriores é de UMA partida. Sem esta linha,
	# carregar um save de 3872 de ouro logo depois de ter jogado outro com 40
	# faria o HUD inteiro escalar na abertura sem nada ter acontecido.
	Kit.esquecer_valores()
	atualizar()

# ---------------- ESTRUTURA DO JOGO ----------------
func _montar_jogo() -> void:
	tela_jogo = MarginContainer.new()
	tela_jogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	# a moldura de pedra pesa ~20px na borda: o conteúdo recua junto quando
	# ela existe, e volta aos 8px de sempre quando não
	var recuo := Tema.E3 if Tema.tex_hibit("ui_moldura_pedra") == null else 22
	for lado in ["left", "right", "top", "bottom"]:
		tela_jogo.add_theme_constant_override("margin_" + lado, recuo)
	add_child(tela_jogo)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E3)
	tela_jogo.add_child(v)

	# ---- HUD com hierarquia ----
	# A barra antiga era uma frase só: nome, título, idade, ouro, renome,
	# homens, moral, guardas e data, tudo no mesmo tamanho e peso, separado por
	# ponto médio. Num jogo de gestão, ouro e homens têm que ser lidos em 200ms;
	# o resto é contexto.
	#
	# Faltava ainda o TERRENO: os números flutuavam direto sobre o fundo da
	# janela, e por isso liam como legenda de debug em vez de painel de
	# instrumentos. Agora a barra tem superfície própria, os recursos viram
	# chips, e a identidade do jogador fica na MESMA barra, à direita — o que
	# recupera uma linha inteira de altura para o conteúdo.
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.estilo_barra_hud())
	v.add_child(barra)
	var linha_hud := HBoxContainer.new()
	linha_hud.add_theme_constant_override("separation", Tema.E4)
	barra.add_child(linha_hud)
	hud = HBoxContainer.new()
	hud.add_theme_constant_override("separation", Tema.E2)
	hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha_hud.add_child(hud)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Tema.TEXTO_2)
	status_label.add_theme_font_size_override("font_size", Tema.MICRO)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# a identidade é CONTEXTO: ela cede a largura quando os chips crescem, e
	# corta com reticências em vez de empurrar o HUD para fora da tela
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	linha_hud.add_child(status_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for i in ABAS.size():
		var rolagem := ScrollContainer.new()
		rolagem.name = str(ABAS[i][0])
		# a aba rola só na vertical. Um card com um rótulo longo demais passa a
		# quebrar linha em vez de abrir uma barra horizontal que ninguém usa.
		rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var conteudo := VBoxContainer.new()
		conteudo.name = "Conteudo"
		conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conteudo.add_theme_constant_override("separation", 8)
		rolagem.add_child(conteudo)
		tabs.add_child(rolagem)
		# ícone antes do rótulo, como na referência. `set_tab_icon` desenha o
		# ícone dentro da própria plaqueta da aba, então o relevo do stylebox
		# envolve os dois — o que uma HBox de botões por fora não daria.
		# tingida, não modulada: a TabBar desenha o ícone cru
		var ic := Icones.textura_tingida(str(ABAS[i][2]))
		if ic != null:
			tabs.set_tab_icon(i, ic)
			# 12, não 16: cada pixel × 11 abas é a folga que faz as ONZE
			# plaquetas caberem nos 916px úteis sem setas de rolagem
			tabs.set_tab_icon_max_width(i, 12)
	tabs.tab_changed.connect(func(_i):
		atualizar()
		_entrada_de_aba())
	# o som de aba fica no CLIQUE, não no tab_changed: o código troca de aba
	# sozinho (voltar da conversa, abrir evento) e essas trocas não são um
	# gesto do jogador — soar nelas viraria ruído de máquina
	tabs.get_tab_bar().tab_clicked.connect(func(_i): Sfx.tocar(self, "aba"))

	# ---- rodapé ----
	# "Passar o mês" é o verbo do jogo inteiro: é o único botão que faz o
	# tempo andar, e por isso é o primário. Ele deixa de esticar na largura
	# toda — um botão de 900px não parece um botão, parece uma divisória — e
	# passa a ter tamanho próprio, ancorado à direita junto do controle de som,
	# com a dica de atalho à esquerda ocupando a sobra.
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", Tema.E3)
	v.add_child(rodape)
	# A DATA mudou de lugar, e a razão é de layout e de sentido ao mesmo
	# tempo. De layout: a linha de identidade era "Aldric de Vau · Conde ·
	# 22 anos · dia 1 de Março, Ano 1" espremida à direita dos chips, e
	# saía cortada — "dia 1 d…" — em toda tela que a barra ficava cheia.
	# De sentido: a data é a única coisa da tela que o botão ao lado dela
	# faz andar. Ela pertence ao verbo, não ao nome do jogador.
	data_label = Label.new()
	data_label.add_theme_font_size_override("font_size", Tema.MICRO)
	data_label.add_theme_color_override("font_color", Tema.TEXTO_2)
	# Spectral, e NÃO a capitular — apesar de "Dia 1 de Março, Ano 1" em
	# versalete ficar bonito. O Cinzel é uma inscricional romana: o
	# algarismo 1 dele é desenhado como um I, e no render a data saiu
	# "Dia I de Março, Ano I". Charmoso e ambíguo: "Dia 11" viraria "II".
	#
	# É também a regra da casa se aplicando a ela mesma — a capitular marca
	# LUGAR e VERBO. Data é dado, e dado se lê no algarismo tabular.
	var f_data := Tema.fonte_numero()
	if f_data != null:
		data_label.add_theme_font_override("font", f_data)
	data_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rodape.add_child(data_label)
	var dica := Label.new()
	dica.text = "Enter passa o dia"
	dica.add_theme_font_size_override("font_size", Tema.MINI)
	dica.add_theme_color_override("font_color", Tema.TEXTO_3)
	dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(dica)
	b_som = Kit.botao_icone(rodape, "som", "Som", _alternar_som, "fantasma", 34)
	# O verbo do jogo agora é o DIA: três cliques fecham o mês. Foi o dia que
	# deu onde acontecer para turno de trabalho, contrato curto e viagem —
	# antes disso a menor unidade que existia era o mês inteiro.
	b_dia = Kit.botao(rodape, "Passar o dia", _passar_dia, "primario", 210)
	b_dia.add_theme_font_size_override("font_size", Tema.CORPO)
	# o sol nascendo é o verbo do botão; a ampulheta fica de reserva
	_com_icone(b_dia, "dia" if Icones.ilustrado("dia") != null else "ampulheta")

## Pendura um ícone ilustrado num botão, quando a leva hi-bit o tiver.
## `icon_max_width` mantém o ícone de 32 no tamanho de texto do botão.
func _com_icone(b: Button, nome: String) -> void:
	var tex := Icones.ilustrado(nome)
	if tex == null:
		return
	b.icon = tex
	b.add_theme_constant_override("icon_max_width", 22)

	# vila em nós nativos quando os assets v2 estão lá; senão, o cenário
	# procedural de sempre. As duas cenas têm a mesma API (.estado, semear_npcs).
	cidade_view = _nova_cena()
	_montar_quartel()

func _alternar_som() -> void:
	Sfx.mudo = not Sfx.mudo
	b_som.icon = Icones.textura_tingida("mudo" if Sfx.mudo else "som")
	b_som.tooltip_text = "Som desligado" if Sfx.mudo else "Som"
	# a música de fundo PAUSA em vez de parar: religar o som retoma a faixa
	# de onde ela estava, não recomeça a playlist
	if is_instance_valid(musica_jogo):
		musica_jogo.stream_paused = Sfx.mudo

# ---------------- MÚSICA DE FUNDO DO JOGO ----------------
## Fila embaralhada de tudo que estiver em assets/audio/musica_jogo,
## tocando BAIXO (-16 dB) — é assoalho da cena, não fanfarra. Acabou a
## faixa, entra a próxima; esvaziou a fila, reembaralha sem devolver de
## primeira a que acabou de tocar. Nasce a -30 dB subindo em 1.5s: é a
## metade de entrada do crossfade com o fade da trilha do título.
func _iniciar_musica_jogo() -> void:
	if Sfx.musicas_jogo().is_empty():
		return
	musica_jogo = AudioStreamPlayer.new()
	musica_jogo.volume_db = -30.0
	add_child(musica_jogo)
	musica_jogo.finished.connect(_proxima_musica)
	musica_jogo.stream_paused = Sfx.mudo
	_proxima_musica()
	create_tween().tween_property(musica_jogo, "volume_db", -16.0, 1.5)

func _proxima_musica() -> void:
	if not is_instance_valid(musica_jogo):
		return
	if fila_musicas.is_empty():
		fila_musicas = Sfx.musicas_jogo()
		fila_musicas.shuffle()
		if fila_musicas.size() > 1 and fila_musicas[0] == _musica_atual:
			fila_musicas.append(fila_musicas.pop_front())
	if fila_musicas.is_empty():
		return
	_musica_atual = str(fila_musicas.pop_front())
	var faixa := Sfx.stream_musica(_musica_atual)
	if faixa == null:
		return
	musica_jogo.stream = faixa
	musica_jogo.play()

## Enter passa o mês. O rodapé anuncia o atalho, então ele tem que existir.
##
## `_unhandled_input` e não `_input`: um LineEdit com foco (o nome na tela de
## título, a fala na conversa, a oferta ao clã) consome o Enter antes de
## chegar aqui, que é exatamente o que se quer — o atalho não pode disparar
## no meio de uma frase digitada.
func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_accept"):
		return
	if state.is_empty() or tela_jogo == null or not tela_jogo.visible:
		return
	if overlay_modal.visible or overlay_conversa.visible:
		return
	get_viewport().set_input_as_handled()
	_passar_dia()

## A cidade_view sai da árvore quando outra aba está ativa (atualizar() a
## remove do pai). Node não é ref-counted: sem isto, fechar o jogo em qualquer
## aba que não a "Sua Terra" vazava a vila inteira — SubViewport, TileMaps,
## sprites e partículas.
func _exit_tree() -> void:
	if cidade_view != null and cidade_view.get_parent() == null:
		cidade_view.free()
		cidade_view = null

## O contingente de um clã em português.
##
## A aba de Clãs imprimia `str(cla["contingente"])` — ou seja, o Dictionary
## cru: o jogador lia `{ "cav_leve": 8 }` na tela, com chave interna e tudo.
## É o único defeito desta auditoria que um jogador leigo chamaria de bug.
func _texto_contingente(d: Dictionary) -> String:
	var partes: Array[String] = []
	for tipo in d:
		var n: int = int(d[tipo])
		var nome: String = str(Dados.TROPAS.get(tipo, {}).get("nome", tipo)).to_lower()
		partes.append("%d %s" % [n, nome])
	return ", ".join(partes)

## mm:ss para a fila do quartel.
## ---------- O TIMER DO QUARTEL ----------
## Um Timer é um nó da cena; o save é um Dictionary. Por isso ele NÃO guarda
## o tempo restante — quem guarda é a fila, dentro do state. O Timer só
## empurra o relógio 1 segundo por vez, exatamente como o turno mensal faz
## com 600 de uma vez. Salvar no meio do treino não perde nada.
## A cena da terra: um CARTÃO por nível, não um mundo navegável.
##
## Havia uma vila de cima em TileMap no meio desta cadeia — com câmera,
## aldeões passeando e Y-Sort. Ela saiu por decisão de escopo: este jogo é
## uma planilha de gerenciamento, o jogador passa o tempo no Mercado e no
## Quartel, e a aba da terra é um cartão de estado. Uma ilustração boa por
## nível vale mais que um mundo medíocre, e é UMA imagem em vez de trinta
## assets que nunca ficam coerentes entre si.
##
## As duas restantes têm a mesma API (.estado e semear_npcs), então quem
## chama não precisa saber qual entrou.
func _nova_cena() -> SubViewportContainer:
	if CenarioV3View.disponivel():
		return CenarioV3View.new()
	return CidadeCena.new()

## O QUARTEL NÃO GIRA SOZINHO.
##
## Existia aqui um Timer de 1 segundo que avançava o relógio do mundo em
## tempo real enquanto houvesse fila ou marcha: o tempo passava sem o
## jogador dar o ok, e um recruta podia ficar pronto enquanto ele lia a
## Crônica. Agora o dia só anda por vontade dele — o botão do rodapé, um
## turno de trabalho, uma viagem, um contrato, ou a cela.
##
## A função continua existindo, vazia de relógio, porque a montagem da
## cena a chama; o que ela guarda hoje é só a decisão de NÃO ter um.
func _montar_quartel() -> void:
	pass

## Emboscada acontecia só na crônica: o jogador via homens sumindo do exército
## sem nada na tela. Agora a estrada interrompe o jogo, com a arte do assalto.
func _narrar_estrada(eventos: Array) -> void:
	# um evento em casa (rebelião, traição, fim de jogo) tem prioridade sobre a
	# estrada: dois modais na mesma tela se atropelam. A emboscada não volta,
	# mas a crônica já guardou a linha dela.
	if state.get("fim") != null or state.get("evento_pendente") != null:
		return
	for ev in eventos:
		if str(ev.get("tipo", "")) != "emboscada":
			continue
		var roubado: Dictionary = ev.get("roubado", {})
		var perdas := ""
		for tipo in ev.get("perdidos", {}):
			perdas += "%s −%d · " % [Dados.TROPAS[tipo]["nome"], int(ev["perdidos"][tipo])]
		var corpo := "Sua coluna foi atacada no caminho.\n%s" % (perdas if perdas != "" else "Nenhuma baixa.")
		if not roubado.is_empty():
			corpo += "\nParte da carga ficou com eles."
		Sfx.tocar(self, "alerta")
		_modal("Emboscada na rota", corpo, [["Seguir marcha", func():
			atualizar()]], Retratos.ilustracao("emboscada"))
		return          # uma emboscada por vez: a próxima espera o clique

func _passar_dia() -> void:
	Sfx.tocar(self, "tique")
	# no ÚLTIMO dia o clique vira o mês inteiro: o jogador vê "fecha o mês"
	# no botão antes de clicar, então a virada nunca é surpresa
	var virou := int(state.get("dia", 1)) >= Jogo.DIAS_POR_MES
	var r: Dictionary = Jogo.passar_dia(state, Jogo.log_para(state))
	if virou:
		Sfx.tocar(self, "pagina")
	elif int(r.get("recrutas", 0)) > 0:
		Sfx.tocar(self, "espada")          # saiu recruta do quartel
	Jogo.salvar(state)
	atualizar()
	# a estrada conta o que houve NELA — era o Timer quem fazia isso
	_narrar_estrada(r.get("marchas", []))
	# o inimigo cobra o dia (coluna no portão, emboscada ou captura). A
	# leitura de `r["inimizade"]` saiu daqui: quem drena é `atualizar()`,
	# pela fila do estado, e assim vale para os SETE caminhos que passam o
	# dia — não só para este botão.
	_checar_inimizade()

## Mantido para os testes de cena e para quem quiser pular o mês inteiro.
func _passar_mes() -> void:
	Sfx.tocar(self, "tique")
	Jogo.passar_mes(state)
	Jogo.salvar(state)
	atualizar()

## Uma célula do HUD, agora como CHIP: ícone + número sobre terreno próprio.
##
## `alarme` é o que decide se o chip fica neutro ou pega o fundo de perigo. A
## regra é a mesma de antes e continua sendo a certa: recurso saudável NÃO
## se colore. Se o ouro fosse sempre dourado, o trigo sempre trigo e a moral
## sempre verde, o HUD seria um arco-íris permanente e nenhum deles saltaria
## no dia em que virasse problema — que é o único dia em que precisa saltar.
## `id` é o que faz o número CORRER quando muda. Ele não pode ser o nome do
## ícone: "moedas" serve tanto ao ouro no cofre quanto ao soldo negativo do
## mercenário sem terra, e os dois no mesmo id fariam um saltar para o valor
## do outro toda vez que o jogador comprasse ou vendesse a terra.
func _celula_hud(icone: String, valor: String, dica: String,
		alarme: bool = false, destaque: bool = false, id: String = "") -> void:
	var cor: Color = Tema.TEXTO_2
	var fundo: Color = Tema.ELEVADO
	if alarme:
		cor = Tema.PERIGO
		fundo = Tema.PERIGO_FUNDO
	elif destaque:
		cor = Tema.ACENTO
	Kit.chip(hud, icone, valor, cor, fundo, dica, id)

func _montar_hud(j: Dictionary) -> void:
	for filho in hud.get_children():
		filho.queue_free()
	var moral: int = Economia.moral(state)
	# ---- A BARRA EM QUATRO GRUPOS ----
	#
	# Eram nove chips iguais em fila, e nove coisas do mesmo peso não são
	# uma barra de estado: são uma lista. Só que elas não são do mesmo tipo.
	# São quatro perguntas diferentes, e agora um fio de 1px separa cada
	# uma da seguinte:
	#
	#   1. O QUE VOCÊ TEM        ouro — sozinho, e maior que todo o resto
	#   2. O QUE VOCÊ COMANDA    homens, moral, guardas
	#   3. O QUE A TERRA DÁ      celeiro, madeireira, imposto
	#   4. QUEM VOCÊ É / O MUNDO renome, honra, estação
	#
	# O ouro fica no primeiro grupo sozinho porque ele é a única grandeza
	# que TODA aba consulta — é a âncora, e âncora que tem o tamanho do
	# vizinho não ancora nada.
	Kit.chip_ancora(hud, "moedas", str(int(j["ouro"])), "Ouro no cofre", "hud_ouro")
	Kit.divisor_vertical(hud)

	_celula_hud("tropa", str(Combate.total_homens(j["tropas"])), "Homens em armas",
		false, false, "hud_tropa")
	_celula_hud("moral", "%d" % moral,
		"Moral do exército — abaixo de 35 os homens desertam", moral <= 35,
		false, "hud_moral")
	if int(j["guardas"]) > 0:
		_celula_hud("escudo", str(int(j["guardas"])),
			"Guardas de elite na sua casa", false, false, "hud_guardas")
	Kit.divisor_vertical(hud)

	# CELEIRO E MADEIREIRA no topo, com o SALDO DO MÊS na dica.
	#
	# O jogador via os números só na aba Terra, e não via para onde eles
	# iam: o exército come todo mês, a colheita repõe, e a diferença entre
	# as duas contas é o que decide se a tropa deserta. Agora os dois
	# recursos ficam na barra, e passar o mouse mostra a conta inteira.
	var t = state.get("terra")
	if t != null:
		var up: Dictionary = Economia.upkeep_de(j["tropas"],
			2.0 - Economia.fator_gestao(state),
			Cidadaos.oficio_ativo(state, "ferreiro"))
		var colheita: int = Economia.colheita_mensal(state)
		var lenha: int = Economia.lenha_mensal(state)
		var saldo_g: int = colheita - int(up["comida"])
		var saldo_m: int = lenha - int(up["madeira"])
		_celula_hud("trigo", str(int(t["alimento"])),
			"Celeiro: %d\n+%d da colheita, −%d que a tropa come\nsaldo do mês: %s%d"
				% [int(t["alimento"]), colheita, int(up["comida"]),
					"+" if saldo_g >= 0 else "", saldo_g],
			int(t["alimento"]) <= 0 or saldo_g < 0, false, "hud_trigo")
		_celula_hud("madeira", str(int(t["madeira"])),
			"Madeireira: %d\n+%d cortados, −%d de manutenção\nsaldo do mês: %s%d"
				% [int(t["madeira"]), lenha, int(up["madeira"]),
					"+" if saldo_m >= 0 else "", saldo_m],
			int(t["madeira"]) <= 0 or saldo_m < 0, false, "hud_madeira")
		_celula_hud("saco", str(Economia.imposto_mensal(state)),
			"Imposto do mês: %d de ouro\n%d camponeses trabalhando · gestão %d"
				% [Economia.imposto_mensal(state), Economia.populacao_ativa(state),
					int(j.get("atributos", {}).get("gestao", 5))],
			false, false, "hud_imposto")
	else:
		# sem terra o mercenário compra tudo na estrada — e é bom saber quanto
		var up_s: Dictionary = Economia.upkeep_de(j["tropas"], 1.0, false)
		_celula_hud("moedas", "−%d" % int(up_s["ouro"]),
			"Soldo do mês do seu exército. Sem terra, comida e madeira saem da estrada.",
			int(up_s["ouro"]) > int(j["ouro"]))
	Kit.divisor_vertical(hud)

	# ---- quem você é, e o mundo lá fora ----
	# Renome e honra saíram do meio dos recursos: eles não medem o que você
	# TEM, medem o que dizem de você — e é essa distinção que os grupos
	# desenham. As duas portas que eles abrem estão na dica.
	_celula_hud("renome", str(int(j["renome"])),
		"Renome — o que o continente sabe do seu nome. Abre contrato melhor e casamento real.",
		false, false, "hud_renome")
	var honra: int = int(j.get("honra", 50))
	_celula_hud("honra" if Icones.ilustrado("honra") != null else "pergaminho", str(honra),
		"Honra — reputação: portas de trabalho e de corte abrem e fecham por ela",
		honra <= 25, false, "hud_honra")
	# a estação pinta o próprio chip: a UI muda de temperatura com o mundo.
	# Na leva hi-bit cada estação tem símbolo próprio (flor, sol, folha,
	# floco — como o floco da referência); sem a arte, o calendário tingido.
	# o ID da estação ("verao"), nunca o nome de exibição: "Verão".to_lower()
	# pedia "estacao_verão" com acento — arquivo que não existe, e o único
	# chip das quatro estações que nunca mostrava o próprio símbolo
	var ic_estacao := "estacao_" + Estacoes.atual(state)
	if Icones.ilustrado(ic_estacao) == null:
		ic_estacao = "calendario"
	Kit.chip(hud, ic_estacao, Estacoes.nome(state), Estacoes.cor(state),
		Tema.ELEVADO, Estacoes.nota(state))

func _conteudo_aba() -> VBoxContainer:
	return tabs.get_current_tab_control().get_node("Conteudo")

## A ENTRADA DA ABA. Onze telas que aparecem prontas, sem transição nenhuma,
## leem como troca de planilha: o olho não sabe que a tela mudou, só que o
## conteúdo é outro.
##
## Meio segundo é demais para algo que o jogador faz cem vezes por partida —
## uma transição que se percebe vira imposto. Doze centésimos e três pixels
## de subida bastam para o movimento existir e não custar tempo.
const ENTRADA_ABA := 0.12

func _entrada_de_aba() -> void:
	var alvo := tabs.get_current_tab_control()
	if alvo == null or not alvo.is_inside_tree():
		return
	alvo.modulate.a = 0.0
	# `position` não serve: o filho da TabContainer é posicionado pelo pai a
	# cada layout, e o container sobrescreveria o deslocamento no mesmo quadro
	alvo.pivot_offset = Vector2.ZERO
	var tw := alvo.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(alvo, "modulate:a", 1.0, ENTRADA_ABA)

func atualizar() -> void:
	if state.is_empty():
		return
	var j: Dictionary = state["jogador"]
	var vs: Dictionary = Vassalagem.resumo(state)
	var selo: String = ""
	if bool(vs.get("vassalo", false)):
		selo = " · vassalo de %s" % vs["nome"]
	_montar_hud(j)
	# A estação saiu daqui: ela já é um chip do HUD, e escrever "Março de
	# Primavera" ao lado de um chip que diz "Primavera" era a mesma
	# informação duas vezes na mesma barra. Sobra a IDENTIDADE, que é o que
	# esta linha sempre quis ser.
	# A DATA saiu daqui e foi para o rodapé: com ela, esta linha media 340px
	# e a barra cortava o fim em toda tela — "dia 1 d…". Sem ela, cabe.
	status_label.text = "%s · %s%s · %d anos" % [
		j["nome"], Contratos.titulo(state), selo, j["idade"]]
	if data_label != null:
		data_label.text = "Dia %d de %s, Ano %d" % [
			int(state.get("dia", 1)), MESES[state["mes"] - 1], state["ano"]]
	if b_dia != null:
		var ultimo := int(state.get("dia", 1)) >= Jogo.DIAS_POR_MES
		b_dia.text = "Fechar o mês" if ultimo else "Passar o dia (%d/%d)" % [
			int(state.get("dia", 1)), Jogo.DIAS_POR_MES]
	# a linha de identidade é creme e fica creme: ela é contexto, não estado.
	# Quem muda de temperatura com a estação é o chip do calendário no HUD.
	status_label.add_theme_color_override("font_color", Tema.TEXTO_2)

	# A ABA REMONTA SEMPRE — inclusive com um modal por vir. A versão
	# anterior retornava antes de remontar quando havia evento pendente, e o
	# resultado era um quadro esquizofrênico: o HUD (montado acima) já dizia
	# "Primavera, Março" enquanto a página visível POR BAIXO do véu ainda
	# era o inverno do mês anterior. O jogador lia dois meses na mesma tela.
	var c := _conteudo_aba()
	for filho in c.get_children():
		if filho != cidade_view:
			filho.queue_free()
	if cidade_view.get_parent() != null:
		cidade_view.get_parent().remove_child(cidade_view)
	match tabs.current_tab:
		0: _aba_terra(c)
		1: _aba_mapa(c)
		2: _aba_mercado(c)
		3: _aba_taverna(c)
		4: _aba_corte(c)
		5: _aba_exercito(c)
		6: _aba_clas(c)
		7: _aba_intrigas(c)
		8: _aba_familia(c)
		9: _aba_cronica(c)
		10: _aba_guerras(c)

	# o modal entra por cima da aba JÁ COERENTE com o estado
	if state["fim"] != null:
		_modal_fim()
	elif state["evento_pendente"] != null:
		_modal_evento()
	else:
		_checar_inimizade()

## O INIMIGO COBRA O DIA — em qualquer caminho que gaste dia.
##
## `Jogo.passar_dia` tem sete chamadores e só o botão "Passar o dia" lia o
## retorno; trabalhar, viajar, cumprir contrato, cortejar, invadir e espiar
## descartavam o acontecimento inteiro. Agora ele fica parado numa fila no
## estado, e este dreno roda depois de toda ação.
##
## Um item por vez, de propósito: um turno de trabalho passa até três dias e
## pode enfileirar três encontros. Empilhar três modais um sobre o outro é
## ilegível — o jogador resolve um, `atualizar()` roda de novo no fim da
## escolha, e o próximo aparece.
##
## Não abre por cima de fim de jogo, de evento pendente ou de outro modal
## já na tela: o véu do overlay come o clique, e dois modais empilhados é
## exatamente o "bug irreversível" que já apareceu neste projeto.
func _checar_inimizade() -> void:
	if state.is_empty() or state["fim"] != null or state["evento_pendente"] != null:
		return
	if overlay_modal != null and overlay_modal.visible:
		return
	var ev: Dictionary = Jogo.puxar_inimizade(state)
	if not ev.is_empty():
		_modal_inimizade(ev)

# ---------------- utilitários de UI ----------------
## Estes quatro sobrevivem como ATALHOS para o kit. Eles são chamados em ~120
## pontos deste arquivo, e trocar cada chamada por `Kit.` não melhoraria uma
## linha de tela — o que melhora a tela é o que eles passaram a desenhar.
func _titulo_secao(c: Container, texto: String, apoio: String = "") -> void:
	Kit.secao(c, texto, apoio)

func _par(c: Container, texto: String) -> Label:
	return Kit.texto(c, texto)

func _botao(c: Container, texto: String, cb: Callable,
		variante: String = "") -> Button:
	return Kit.botao(c, texto, cb, variante)

## O card em linha. A altura mínima de 56px saiu daqui: ela foi escrita para
## uma moldura 9-slice que não existe mais, e o que ela fazia era garantir
## 56px de altura a uma linha de 15px de texto. Medido na imagem renderizada,
## era o que fazia caber quatro itens numa tela de mercado com dez.
func _card(c: Container, marca: Variant = null) -> HBoxContainer:
	var painel := PanelContainer.new()
	if marca is Color:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card_marcado(marca))
	else:
		painel.add_theme_stylebox_override("panel", Tema.estilo_card())
	c.add_child(painel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E4)
	painel.add_child(h)
	return h

## A CELA — o estado que a interface inteira ignorava.
##
## O jogador era preso, e nada na tela mudava: nenhum selo, nenhum aviso, e
## todas as ações continuavam disponíveis. Agora a cadeia se anuncia onde
## ela é vivida (a aba da sua casa), diz quanto falta, e oferece a única
## coisa que ouro sempre comprou — a saída.
func _painel_cadeia(c: Container) -> void:
	if not Jogo.esta_preso(state):
		return
	var meses: int = Jogo.meses_preso(state)
	var card := _card(c, Tema.PERIGO)
	_arte(card, Retratos.ilustracao("traicao"), 64)
	var v := Kit.coluna(card, Tema.E2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Kit.fila(v, Tema.E3)
	var ic := Icones.imagem("correntes", 20)
	if ic != null:
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_child(ic)
	Kit.texto(l, "A ferros — faltam %d %s" % [meses, "mês" if meses == 1 else "meses"],
		Tema.PERIGO, Tema.CORPO_G)
	Kit.nota(v, "Daqui não se viaja, não se trabalha, não se marcha e não se corteja. Mas o soldo, o tributo e a palavra dada continuam correndo.")
	var custo: int = Jogo.preco_fianca(state)
	var acao := Kit.fila(card, Tema.E3)
	acao.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.icone_valor(acao, "moedas", str(custo), Tema.ACENTO)
	var b_f := Kit.botao_mini(acao, "Pagar fiança", func():
		var r: Dictionary = Jogo.pagar_fianca(state, Jogo.log_para(state))
		Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
		_aviso(str(r["msg"]))
		Jogo.salvar(state)
		atualizar(), "primario", 130)
	b_f.disabled = int(state["jogador"]["ouro"]) < custo

## Retrato de um personagem fixo (rei, chefe de clã, freguês da taverna).
##
## Aqui morava o pior defeito visual do jogo, e ele se disfarçava de outra
## coisa. `moldura_retrato` é um NinePatchRect com margem de 32px nos quatro
## lados — tamanho mínimo 64×64. Esta caixa pedia 52. Com o alvo menor que a
## soma das margens o 9-slice DEGENERA: some o miolo, e sobram só os quatro
## cantos de 32×32 encostados uns nos outros, cobrindo o retrato inteiro.
##
## O efeito: os seis reis, os quatro clãs e os três fregueses apareciam como
## o MESMO quadradinho ornamentado. Medido: 91% dos pixels idênticos entre
## dois reis diferentes. Não era "todo mundo usa o mesmo brasão" — eram treze
## retratos distintos, já gerados e já pagos, escondidos atrás de um bug de
## dimensionamento.
##
## A moldura só volta onde há espaço para ela: no retrato grande da conversa.
## Retrato de um personagem fixo (rei, chefe de clã, freguês da taverna).
##
## O tamanho é 32 ou 64, e nunca 52, que era o valor anterior. A razão é
## aritmética: o retrato nasce 64×64, e mostrá-lo em 52 é uma redução de
## 0,81 — com filtro NEAREST isso descarta uma linha de pixels a cada cinco,
## e as linhas descartadas são justamente as de 1px (olho, boca, contorno)
## que carregam a cara. Em 32 a redução é exata (o próprio `Retratos` faz a
## média 2×2), e em 64 não há redução nenhuma.
func _retrato(c: Container, id: String, tamanho: int = 32) -> void:
	var humor := Retratos.humor_de(state, id)
	var tex := Retratos.textura_pequena(id, humor) if tamanho <= 32 \
		else Retratos.textura(id, humor)
	Kit.retrato(c, tex, tamanho)

## Coloca uma arte gerada num container. Aceita null de propósito: toda arte
## do PixelLab é opcional, e a UI tem que continuar legível sem ela — é o
## mesmo contrato dos ícones do mercado.
func _arte(c: Container, tex: Texture2D, tamanho: int = 48) -> Control:
	return Kit.retrato(c, tex, tamanho)

## Ilustração grande de um momento (cerco, emboscada, inverno, coroação).
##
## As cenas do PixelLab saem QUADRADAS, 128×128. Esticá-las numa faixa larga
## cortava três quartos do desenho — a vila na neve virava um pedaço de telhado.
## Aqui a arte aparece inteira, ampliada e centrada na largura disponível.
func _faixa(c: Container, tex: Texture2D, altura: int = 120) -> void:
	Kit.ilustracao(c, tex, altura)

## O aviso de resultado ("ouro insuficiente", "recrutados 5 lanceiros").
##
## Era um Label solto acrescentado ao FIM do conteúdo da aba — ou seja, numa
## aba rolada, a resposta ao clique aparecia fora da tela, e o jogador
## clicava sem retorno nenhum. Agora é uma faixa fixada no TOPO da aba, com
## terreno e barra de acento, que é onde ela é vista sem rolar.
func _aviso(msg: String) -> void:
	if msg == "":
		return
	var c := _conteudo_aba()
	var faixa := PanelContainer.new()
	faixa.add_theme_stylebox_override("panel",
		Tema.estilo_card_marcado(Tema.ACENTO))
	c.add_child(faixa)
	c.move_child(faixa, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Tema.E3)
	faixa.add_child(h)
	var l := Label.new()
	l.text = msg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Tema.ACENTO_FORTE)
	l.add_theme_font_size_override("font_size", Tema.MICRO)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	# o timer é FILHO da faixa: morre junto com ela quando qualquer
	# atualizar() remonta a aba — o SceneTreeTimer antigo sobrevivia à faixa
	# e enchia o log de "Lambda capture was freed" a cada aviso
	var timer := Timer.new()
	timer.wait_time = 3.5
	timer.one_shot = true
	timer.autostart = true
	faixa.add_child(timer)
	timer.timeout.connect(faixa.queue_free)

# ---------------- ABAS ----------------
func _aba_terra(c: Container) -> void:
	_painel_cadeia(c)
	var t = state["terra"]
	Kit.titulo_tela(c, ("%s — %s" % [t["nome"], Dados.NIVEIS_TERRA[t["nivel"]]["nome"]]) if t != null else "Acampamento Mercenário")

	# duas colunas: a estampa da vila à esquerda, o estado dela à direita. A
	# imagem tem 400px de largura nativa e a tela tem 930 úteis — em coluna
	# única sobravam 350px de nada ao lado dela, e o estado da vila descia
	# para baixo da dobra.
	var colunas := Kit.duas_colunas(c, 0.52)
	var col_esq: VBoxContainer = colunas[0]
	var col_dir: VBoxContainer = colunas[1]

	cidade_view.estado = state
	# SHRINK_CENTER (o padrão do nó), não EXPAND_FILL: o cartão tem tamanho
	# próprio e esticá-lo não aumenta a imagem — o SubViewportContainer com
	# `stretch = false` desenha a textura no tamanho nativo e o resto do
	# retângulo fica vazio.
	# A moldura de madeira com cantoneira de metal, no lugar do retângulo de
	# 1px que tratava a melhor arte da tela como célula de tabela.
	var quadro_vila := Kit.moldura_arte(col_esq)
	quadro_vila.add_child(cidade_view)

	if t == null:
		_par(col_dir, "Sem terras, sem raízes. Junte 25 de renome e %d de ouro para comprar seu primeiro pedaço de chão." % Dados.PRECO_TERRA)
		_botao(col_dir, "Comprar terra  ·  %d ouro" % Dados.PRECO_TERRA, func():
			var r: Dictionary = Jogo.comprar_terra(state)
			if r["ok"]:
				Sfx.tocar(self, "moeda")
				cidade_view.semear_npcs()
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "primario").tooltip_text = "Requer 25 de renome"
	else:
		# ---- a coluna da direita: o ESTADO da vila ----
		# A ilustração ficava sozinha no meio da tela com 350px de vazio à
		# direita e o estado da vila descia embaixo dela em sete linhas de
		# texto corrido. Aqui a imagem fica à esquerda e o estado à direita,
		# na altura dela: a largura da tela passa a ser usada, e o jogador vê
		# a vila e os números dela no mesmo golpe de vista.
		var alim: int = int(t["alimento"])
		var fel: int = int(t["felicidade"])
		var ativa: int = Economia.populacao_ativa(state)
		var armas: int = Economia.pop_em_armas(state)
		var nivel_cap: int = clampi(int(t["nivel"]), 0, Dados.NIVEIS_TERRA.size() - 1)

		var teto: int = Recrutamento.pop_maxima(state)
		var folga: int = teto - armas

		Kit.secao(col_dir, "Recursos e população")
		# tudo o que descreve a vila vive dentro de UM sulco: antes eram
		# cinco controles empilhados soltos no painel, e empilhado não é
		# agrupado — o olho lia cinco coisas em vez de uma.
		var grupo := Kit.sulco(col_dir, Tema.E4, Tema.E3)

		var res := Kit.fila(grupo, Tema.E5)
		Kit.icone_valor(res, "populacao", "%d" % int(t["populacao"]), Tema.TEXTO)
		Kit.icone_valor(res, "trigo", "%d" % alim,
			Tema.PERIGO if alim <= 0 else Tema.TEXTO)
		Kit.icone_valor(res, "madeira", "%d" % int(t["madeira"]), Tema.TEXTO)

		# ---- O NÚMERO DA TELA ----
		# "Em armas 182" e "Tropa que a terra sustenta 200" eram a primeira e
		# a quarta linha de uma tabela de quatro, na mesma fonte e no mesmo
		# tamanho do imposto. São os dois números que decidem se dá para
		# recrutar, e ninguém os comparava porque nada dizia que eram um par.
		#
		# A cor INVERTE a escala de saúde: encostar no teto é a má notícia
		# aqui, ao contrário de felicidade ou celeiro.
		var cor_armas: Color = Tema.cor_de_saude(float(folga) / maxf(1.0, teto))
		var glosa := "Faltam %d para o limite que a terra sustenta." % folga
		if folga <= 0:
			glosa = "A terra não sustenta mais ninguém: evolua a terra ou alugue baia no armazém antes de recrutar."
		Kit.destaque(grupo, "Homens em armas", armas, teto, cor_armas,
			glosa, "terra_armas")

		Kit.medidor_rotulado(grupo, "Felicidade do povo", fel, 100, "/100",
			null, "terra_felicidade")

		# O DILEMA: quem pega em armas some da base de imposto. Sobraram as
		# duas CONTAGENS — o teto subiu para o destaque e "em armas" com
		# ele, senão o mesmo número apareceria duas vezes na mesma coluna.
		#
		# Em FATO e não em tabela: duas linhas de tabela custam 84px de
		# altura numa coluna que tem 290, e era esse o estouro que mandava
		# o imposto para baixo da dobra.
		var fatos := Kit.fila(grupo, Tema.E6)
		Kit.fato(fatos, "foice", "%d" % ativa, "nos campos",
			Tema.TEXTO, "Camponeses que ainda lavram — e que pagam imposto.")
		Kit.fato(fatos, "saco", "%d" % Economia.imposto_mensal(state),
			"de imposto por mês", Tema.TEXTO,
			"Cada homem em armas é um pagador de imposto a menos.")

		# ---- avisos: o que exige uma decisão AGORA ----
		if alim <= 0:
			# texto e ilustração LADO A LADO. Empilhados, a imagem centrava
			# sozinha debaixo de um texto alinhado à esquerda e o card ficava
			# com 120px de altura para dizer uma frase.
			var av := Kit.fila(Kit.card(c, Tema.PERIGO), Tema.E4)
			Kit.ilustracao(av, Retratos.ilustracao("fome"), 72)
			var v_fome := Kit.coluna(av, Tema.E2)
			v_fome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			Kit.texto(v_fome, "O celeiro está vazio.", Tema.PERIGO, Tema.CORPO_G)
			Kit.nota(v_fome, "Os homens comem o que a vila não tem. Moral cai, e o povo com fome pega em foices.")
		if fel <= 30:
			Kit.texto(Kit.card(c, Tema.PERIGO),
				"O povo murmura. Felicidade baixa termina em foices e tochas.",
				Tema.PERIGO)
		# a estação, e o aviso de que o inverno vem aí
		var aviso_est: String = Estacoes.nota(state)
		if Estacoes.proxima(state) == "inverno" and Estacoes.meses_ate_virar(state) <= 2:
			aviso_est += " O inverno chega em %d mês(es)." % Estacoes.meses_ate_virar(state)
		# ---- o banner de estação, em PERGAMINHO (como na referência) ----
		# o único terreno claro da interface: aviso é carta, e carta se lê
		# em tinta escura sobre papel
		var perg := PanelContainer.new()
		perg.add_theme_stylebox_override("panel", Tema.estilo_pergaminho())
		c.add_child(perg)
		var h_est := Kit.fila(perg, Tema.E4)
		# no inverno a vila aparece coberta de neve: a estação que zera a
		# colheita tem que ser vista, não lida numa linha entre outras cinco
		if Estacoes.e_inverno(state):
			Kit.ilustracao(h_est, Retratos.ilustracao("inverno"), 64)
		var l_est_nome := Kit.texto(h_est, Estacoes.nome(state).to_upper(),
			Estacoes.cor(state).darkened(0.25), Tema.MICRO)
		var f_est := Tema.fonte_forte()
		if f_est != null:
			l_est_nome.add_theme_font_override("font", f_est)
		l_est_nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l_est_txt := Kit.texto(h_est, aviso_est, Tema.TINTA_PERGAMINHO, Tema.CORPO)
		l_est_txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# ---- o que se faz com a terra ----
		var acoes := Kit.fila(c, Tema.E3)
		# o topo vem da TABELA. Era um 5 escrito à mão, irmão do que estava em
		# `melhorar_terra`: com a escada em nove degraus, o botão de evoluir
		# simplesmente SUMIA na Vila de Pedra e o jogador ficava sem caminho,
		# sem mensagem nenhuma explicando por quê.
		if int(t["nivel"]) < Dados.NIVEIS_TERRA.size() - 1:
			var prox: Dictionary = Dados.NIVEIS_TERRA[int(t["nivel"]) + 1]
			var b_ev := _botao(acoes, "Evoluir para %s  ·  %d ouro + %d madeira" % [
				prox["nome"], prox["custo_ouro"], prox["custo_madeira"]], func():
				var r: Dictionary = Jogo.melhorar_terra(state)
				if r["ok"]:
					Sfx.tocar(self, "vitoria")
					cidade_view.semear_npcs()
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
			_com_icone(b_ev, "martelo")
		var b_ex := _botao(acoes, "Exportar 30 de alimento", func():
			var r: Dictionary = Jogo.exportar_comida(state, 30)
			if r["ok"]:
				Sfx.tocar(self, "moeda")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "fantasma")
		b_ex.tooltip_text = "Ouro rápido — e o povo reclama da despensa vazia"
		_com_icone(b_ex, "carroca")
		var _fim := nivel_cap

func _aba_mapa(c: Container) -> void:
	Kit.titulo_tela(c, "Os Seis Reinos",
		"Clique num domínio para viajar. A cor da estrada conta o perigo dela.")
	# ---- O NÚMERO DO MAPA: o risco de hoje ----
	#
	# A tela do mapa dizia quantas guerras havia no continente e deixava o
	# jogador deduzir o que isso custava A ELE. Mas o custo existe e é
	# diário: `Inimizade.risco_do_dia` rola um dado toda vez que o dia
	# passa, e a chance depende de ONDE ele está parado — 75% na capital de
	# quem o odeia, 0% sob o teto de um aliado, 15% na estrada sem terra.
	#
	# Esse número estava calculado, aplicado e invisível. É a informação
	# mais acionável da tela, porque é a única que muda conforme a próxima
	# coisa que o jogador vai fazer: viajar.
	var risco: Dictionary = Inimizade.risco_do_dia(state)
	var pct: int = roundi(float(risco["chance"]) * 100.0)
	var meus_inimigos: Array = Inimizade.inimigos(state)
	var grupo_m := Kit.sulco(c, Tema.E4, Tema.E3)
	var glosa_m := "Ninguém no continente tem motivo para te emboscar."
	if pct > 0:
		match str(risco["tipo"]):
			"captura":
				glosa_m = "Você está na capital de %s, que te declarou guerra. Quem é reconhecido aqui sai a ferros." % Rotas.nome_do(state, str(risco["por"]))
			"ataque_terra":
				glosa_m = "Com terra e inimigo, a coluna de %s pode aparecer no seu portão a qualquer amanhecer." % Rotas.nome_do(state, str(risco["por"]))
			_:
				glosa_m = "Homens de %s vigiam a estrada. Sem casa para onde recuar, quem perde acorda numa cela." % Rotas.nome_do(state, str(risco["por"]))
	elif not meus_inimigos.is_empty():
		glosa_m = "Você tem inimigos, mas aqui está sob teto que não deixa te pegarem."
	# A manchete só aparece quando existe manchete. Sem inimigo nenhum, um
	# "0 / 100" com a barra verde ocuparia noventa pixels para não dizer
	# nada — e noventa pixels aqui é o que empurra o mapa para fora da tela.
	if not meus_inimigos.is_empty():
		Kit.destaque(grupo_m, "Risco de emboscada hoje", pct, 100,
			Tema.cor_de_saude(1.0 - float(pct) / 100.0), glosa_m, "mapa_risco")
	var fatos_m := Kit.fila(grupo_m, Tema.E6)
	Kit.fato(fatos_m, "espada", "%d" % meus_inimigos.size(), "inimigos seus",
		Tema.PERIGO if not meus_inimigos.is_empty() else Tema.TEXTO,
		"Reinos em guerra COM VOCÊ. Cada um é uma rolagem de dado por dia.")
	Kit.fato(fatos_m, "guerra", "%d" % state["guerras"].size(),
		"guerras no continente", Tema.TEXTO,
		"Todas as guerras em curso, suas e de terceiros.")
	var aliados := 0
	for r_a in state["reinos"]:
		if int(state["tags"].get("rei_" + str(r_a["id"]), {"relacao": 0})["relacao"]) >= 60:
			aliados += 1
	Kit.fato(fatos_m, "alianca", "%d" % aliados, "cortes que te abrigam",
		Tema.GANHO if aliados > 0 else Tema.TEXTO,
		"Relação 60 ou mais: nessa corte a chance de emboscada é zero.")

	# o MAPA vem DEPOIS do risco, e essa ordem foi invertida de propósito.
	# A rede de estradas é a informação que a tabela nunca conseguiu dar,
	# mas ela responde "para onde dá para ir"; o risco responde "o que
	# custa ir". A segunda pergunta manda na primeira.
	var mapa := MapaMundi.new()
	c.add_child(mapa)
	mapa.reino_clicado.connect(_popup_dominio)
	mapa.montar(state)

	_fronteira_selvagem(c)
	# o juramento é o contrato que rege o resto do mapa: enquanto vale, o
	# suserano não marcha — e leva um quinto do seu ouro todo mês
	var vs_mapa: Dictionary = Vassalagem.resumo(state)
	if bool(vs_mapa.get("vassalo", false)):
		var hv := _card(c)
		_arte(hv, Retratos.ilustracao("juramento"), 72)
		var lv := Label.new()
		lv.text = "Vassalo de %s há %d meses — tributo estimado: %d no próximo mês." % [
			vs_mapa["nome"], int(vs_mapa["meses"]), int(vs_mapa["tributo_estimado"])]
		lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(lv)
	for g in state["guerras"]:
		# nome de exibição, nunca o id: "leoes × imperio" não bate com
		# nenhum dos reinos que esta mesma tela anuncia por extenso
		_par(c, "%s × %s — %d meses de guerra. Campos em chamas." % [
			Rotas.nome_do(state, str(g["a"])), Rotas.nome_do(state, str(g["b"])), g["meses"]])
	if state["guerras"].is_empty():
		_par(c, "Os reinos estão em paz. Por enquanto.")
	for reino in state["reinos"]:
		var aqui: bool = state["local"] == reino["id"]
		var meu: bool = state["jogador"]["rei_de"] == reino["id"]
		# a barra de acento diz de relance ONDE você está e o que é seu, sem
		# gastar uma palavra da linha de texto para isso
		var h := _card(c, Tema.ACENTO if meu else (Tema.ACENTO_FUNDO if aqui else null))
		# 64, não 32: os seis reis têm identidade fixa (coroa de ferro, elmo
		# de chifres, galhada, tiara…) e a 32px a silhueta do toucado — que é
		# o traço que os distingue — perdia metade dos pixels. O card do
		# reino tem duas linhas + botões, então os 64 cabem sem esticar nada.
		_retrato(h, reino["rei"]["id"], 64)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", Tema.E2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var rel: int = state["tags"].get("rei_" + reino["id"], {"relacao": 0})["relacao"]

		# ---- linha 1: nome do reino, capital e os SELOS de estado ----
		# "Casus Belli" e "SEU TRONO" eram palavras soltas no fim de uma
		# frase de três linhas, e estado escrito no meio de prosa não é lido.
		var l1 := Kit.fila(v, Tema.E3)
		var nome_r := Kit.texto(l1, str(reino["nome"]), Tema.TEXTO, Tema.CORPO_G)
		var f_r := Tema.fonte_forte()
		if f_r != null:
			nome_r.add_theme_font_override("font", f_r)
		Kit.texto(l1, str(reino["capital"]), Tema.TEXTO_3, Tema.MICRO)
		if aqui:
			Kit.selo(l1, "você está aqui", Tema.TEXTO, Tema.ELEVADO)
		if meu:
			Kit.selo(l1, "seu trono", Tema.ACENTO_FORTE, Tema.ACENTO_FUNDO)
		if state["casus_belli"].has(reino["id"]):
			Kit.selo(l1, "casus belli", Color("e8917a"), Tema.PERIGO_FUNDO)

		# ---- linha 2: o rei, a relação como MEDIDOR, e a força ----
		var l2 := Kit.fila(v, Tema.E4)
		Kit.texto(l2, str(reino["rei"]["nome"]), Tema.TEXTO_2, Tema.MICRO)
		# a relação vai de −100 a +100; o medidor mostra os dois lados
		var barra_rel := Kit.medidor(l2, float(rel + 100), 200.0, 90, 5,
			Tema.PERIGO if rel <= -25 else (Tema.GANHO if rel >= 25 else Tema.TEXTO_3))
		barra_rel.tooltip_text = "Relação: %d" % rel
		Kit.texto(l2, "%s (%d)" % [Dialogo.nome_relacao(rel), rel],
			Tema.TEXTO_3, Tema.MICRO)
		# NEBLINA: a força do inimigo NÃO aparece de graça. Sem um espião
		# recente, o jogador vê "???" — e marchar às cegas é decisão dele.
		var vis: Dictionary = Intel.sobre(state, reino["id"])
		var forca_txt: String = "%s" % vis["texto"]
		if bool(vis.get("conhecido", false)):
			var det: Array = Intel.detalhar(state, reino["id"])
			var partes: Array = []
			for l in det.slice(0, 3):
				partes.append("%d %s" % [int(l["n"]), str(l["nome"]).to_lower()])
			if not partes.is_empty():
				forca_txt += " (" + ", ".join(partes) + ")"
		var l_forca := Kit.texto(l2, forca_txt,
			Tema.TEXTO_3 if not bool(vis.get("conhecido", false)) else Tema.TEXTO_2,
			Tema.MICRO)
		l_forca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not bool(vis.get("conhecido", false)):
			l_forca.tooltip_text = "Sem espião recente: a força deste reino está sob neblina."

		var lb := Kit.fila(v, Tema.E2)
		if not aqui:
			var destino_lb: String = str(reino["id"])
			var b_viajar := _botao(lb, "Viajar", func(): _abrir_viagem(destino_lb), "fantasma")
			_com_icone(b_viajar, "cavalos")  # viagem é a cavalo — a marcha é que anda a pé
		var alvo_id: String = reino["id"]
		# JURAR LEALDADE: a saída para quem começa pobre diante de reinos ricos
		if not Vassalagem.e_vassalo(state) and Vassalagem.pode_jurar(state, alvo_id)["ok"]:
			_botao(lb, "Jurar lealdade", func():
				var r: Dictionary = Vassalagem.jurar(state, alvo_id, Jogo.log_para(state))
				Sfx.tocar(self, "tique" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
		elif Vassalagem.suserano(state) == alvo_id:
			_botao(lb, "Declarar independência", func():
				var r: Dictionary = Vassalagem.declarar_independencia(state, Jogo.log_para(state))
				Sfx.tocar(self, "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
		if not Intel.tem(state, alvo_id):
			# Aqui havia dois ícones soltos — a neblina e o espião — plantados
			# entre dois botões, em 30px, sem rótulo e sem moldura. Na imagem
			# renderizada eles liam como sujeira: duas manchas de 30px no meio
			# de uma fila de botões. A informação que eles queriam dar ("o
			# ??? sai daqui") está na DICA do botão, que é onde ela é lida.
			_botao(lb, "Espionar  ·  80 ouro", func():
				var r: Dictionary = Intriga.espionar(state, alvo_id)
				if int(r.get("prender", 0)) > 0:
					Jogo.prender(state, int(r["prender"]), Jogo.log_para(state))
				Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar(), "fantasma").tooltip_text = \
					"Um espião na estrada levanta a neblina sobre a força deste reino"
		if state["jogador"]["rei_de"] == "":
			var tem_cb: bool = state["casus_belli"].has(reino["id"])
			# atacar sem casus belli é a decisão irreversível da tela: ela
			# ganha a variante de perigo, e é a única aqui que a tem
			_botao(lb, "Tomar o trono" if aqui else "Tomar o trono (é preciso estar lá)", func():
				var rel_batalha: Dictionary = Intriga.assaltar_trono(state, reino["id"], Jogo.log_para(state))
				if not bool(rel_batalha.get("ok", true)):
					Sfx.tocar(self, "alerta")
					_aviso(str(rel_batalha.get("msg", "")))
					return
				Jogo.salvar(state)
				_modal_batalha(rel_batalha), "" if tem_cb else "perigo")

## O MERCADO — a tela que mais precisava de uma tabela e não tinha nenhuma.
##
## Cada linha era a string "Trigo — 10 · carga: 0" jogada num Label que
## expandia até empurrar os botões para a direita: 481px contíguos de vazio
## no meio de uma linha de 910, e o preço de cada mercadoria começando num x
## diferente, porque o nome da mercadoria tem comprimento diferente. Um
## livro-razão em que a coluna de preço não é uma coluna.
##
## Agora é uma tabela de verdade: ícone, nome, PREÇO alinhado à direita na
## monoespaçada, carga, valor da carga, e as duas ações. Em 34px de altura
## por linha as dez mercadorias cabem na tela — antes cabiam quatro.
func _aba_mercado(c: Container) -> void:
	# NEM TODO LUGAR DO MAPA TEM PRAÇA. O Reino sem Rei e as Terras
	# Bárbaras são nós de viagem sem armazém — e a tabela desenhada ali
	# disparava um erro por mercadoria e mostrava preço 0 em tudo, o que
	# fazia "Comprar 5" custar zero: ouro infinito por um clique.
	if not Economia.tem_praca(state, str(state.get("local", ""))):
		Kit.titulo_tela(c, "Sem mercado aqui",
			Economia.AVISO_SEM_PRACA)
		var sp := Kit.card(c, Tema.ATENCAO)
		Kit.texto(sp, "Não há feitor, armazém nem livro-razão nesta terra.",
			Tema.ATENCAO, Tema.MICRO)
		Kit.nota(sp, "Volte a um dos seis reinos para comprar e vender.")
		return
	var reino := _reino_local()
	var em_guerra := false
	for g in state["guerras"]:
		if g["a"] == state["local"] or g["b"] == state["local"]:
			em_guerra = true
	Kit.titulo_tela(c, "Livro-Razão — Mercado de %s" % reino["nome"],
		"Compre onde há fartura, venda onde há guerra e fome.")
	# O SELO DA GUILDA — uma licença POR PRAÇA, permanente e cara. É o
	# degrau que faz o mercador nascer devagar: cada cidade nova custa a
	# entrada, e a entrada acompanha a riqueza dela.
	var local_f: String = str(state["local"])
	var tem_mapa := Economia.tem_licenca(state, local_f)
	if not tem_mapa:
		var sem := Kit.card(c, Tema.PERIGO)
		Kit.texto(sem, "Você não tem o selo da guilda desta praça.",
			Tema.PERIGO, Tema.MICRO)
		Kit.nota(sem, "Sem ele nenhum feitor te vende nem te compra AQUI. O selo é para sempre — e só vale nesta cidade.")
		var l_sel := Kit.fila(sem, Tema.E3)
		var preco_sel: int = Economia.preco_licenca(state, local_f)
		Kit.icone_valor(l_sel, "moedas", str(preco_sel), Tema.ACENTO)
		var b_sel := Kit.botao_mini(l_sel, "Comprar o selo", func():
			var r: Dictionary = Economia.comprar_licenca(state, local_f)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar(), "primario", 150)
		b_sel.disabled = int(state["jogador"]["ouro"]) < preco_sel
	else:
		var com_mapa := Kit.fila(c, Tema.E3)
		Kit.selo(com_mapa, "selo da guilda", Tema.GANHO, Tema.GANHO_FUNDO)
		Kit.nota(com_mapa, "Você negocia nesta praça. Cada cidade pede o seu.")
	if em_guerra:
		var av := Kit.card(c, Tema.ATENCAO)
		Kit.texto(av, "Reino em guerra: trigo com ágio de contrabando (+30%), mas patrulhas confiscam cargas.",
			Tema.ATENCAO, Tema.MICRO)

	# ---- O NÚMERO DA FEIRA: o que a carga vale AQUI ----
	#
	# O mercador não decide olhando o preço de uma mercadoria: ele decide
	# olhando quanto do patrimônio dele está preso em coisa que ainda não
	# virou ouro. Carga é aposta; ouro é liberdade — e a tela não dizia a
	# proporção entre os dois em lugar nenhum.
	#
	# O teto é o patrimônio (ouro + carga), então a barra lê como "quanto do
	# que eu tenho está imobilizado". Encher a barra é ficar sem margem de
	# manobra, e por isso a cor inverte a escala de saúde.
	if tem_mapa:
		var ouro_f: int = int(state["jogador"]["ouro"])
		var valor_carga := 0
		for g_v in state["carga"]:
			valor_carga += int(state["carga"][g_v]) \
				* Economia.preco_de(state, state["local"], str(g_v))
		var patrimonio: int = maxi(1, ouro_f + valor_carga)
		var grupo_f := Kit.sulco(c, Tema.E4, Tema.E3)
		var glosa_f := "Tudo o que você tem está em ouro. Livre para comprar, e sem nada a vender."
		if valor_carga > 0:
			glosa_f = "%d%% do seu patrimônio está em mercadoria — e mercadoria só vira ouro na praça certa." % \
				roundi(100.0 * float(valor_carga) / float(patrimonio))
		Kit.destaque(grupo_f, "Sua carga vale aqui", valor_carga, patrimonio,
			Tema.cor_de_saude(1.0 - float(valor_carga) / float(patrimonio)),
			glosa_f, "feira_carga")
		var fatos_f := Kit.fila(grupo_f, Tema.E6)
		Kit.fato(fatos_f, "moedas", str(ouro_f), "no cofre", Tema.ACENTO,
			"Ouro livre — é com isto que se compra.")
		# a MAIOR margem do continente, que é a razão de a feira existir.
		# O retrato de preços já era calculado e só aparecia no mapa comercial
		var retrato: Array = Economia.retrato_de_precos(state)
		if not retrato.is_empty():
			var melhor: Dictionary = retrato[0]
			Kit.fato(fatos_f, "carroca", "+%d" % int(melhor["margem"]),
				"por %s" % str(melhor["bem"]).to_lower(), Tema.GANHO,
				"%s: %d em %s, %d em %s. A maior diferença do continente hoje." % [
					melhor["bem"], int(melhor["barato"]), melhor["barato_em"],
					int(melhor["caro"]), melhor["caro_em"]])

	var tab := Kit.tabela(c, [
		{"t": "", "w": 26, "a": Kit.CENTRO},
		{"t": "Mercadoria", "w": 0},
		{"t": "Preço", "w": 76, "a": Kit.DIR},
		{"t": "Carga", "w": 64, "a": Kit.DIR},
		{"t": "Valor", "w": 76, "a": Kit.DIR},
		{"t": "", "w": 190, "a": Kit.DIR},
	])
	for g_id in Dados.MERCADORIAS:
		var preco := Economia.preco_de(state, state["local"], g_id)
		var carga: int = int(state["carga"].get(g_id, 0))
		# a linha só se marca quando há algo em carga: é o que faz o jogador
		# achar as suas mercadorias no meio das dez sem ler a coluna inteira
		var cel := Kit.linha(tab, Tema.ACENTO_FUNDO if carga > 0 else null)
		var ic := Icones.imagem(g_id, 20)
		if ic != null:
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cel[0].add_child(ic)
		Kit.texto(cel[1], str(Dados.MERCADORIAS[g_id]["nome"]))
		Kit.numero(cel[2], str(preco), Tema.ACENTO)
		Kit.numero(cel[3], str(carga), Tema.TEXTO if carga > 0 else Tema.TEXTO_3)
		Kit.numero(cel[4], str(carga * preco),
			Tema.TEXTO_2 if carga > 0 else Tema.TEXTO_3)
		var b_comprar := Kit.botao_mini(cel[5], "Comprar 5", func():
			var r: Dictionary = Economia.comprar(state, state["local"], g_id, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "fantasma", 88)
		b_comprar.disabled = not tem_mapa
		var b_vender := Kit.botao_mini(cel[5], "Vender 5", func():
			var r: Dictionary = Economia.vender(state, state["local"], g_id, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "fantasma", 88)
		b_vender.disabled = carga < 5 or not tem_mapa
		# grão e madeira também SUSTENTAM: o que você carrega pode ir para
		# o celeiro da sua terra, e é de lá que o exército come
		if Economia.DESCARREGAVEL.has(g_id) and state["terra"] != null:
			var b_desc := Kit.botao_mini(cel[5], "Ao celeiro", func():
				var r: Dictionary = Economia.descarregar(state, g_id)
				Sfx.tocar(self, "pagina" if r["ok"] else "alerta")
				_aviso(str(r["msg"]))
				Jogo.salvar(state)
				atualizar(), "fantasma", 88)
			b_desc.disabled = carga <= 0
			b_desc.tooltip_text = "Descarrega tudo na sua terra: mais celeiro sustenta mais tropa"

func _aba_taverna(c: Container) -> void:
	Kit.titulo_tela(c, str(TAVERNAS.get(str(state.get("local", "")),
		"Taverna do Javali Manco")), "Mural de contratos")

	# ---- a taverna NÃO ganha destaque, e isso é decisão ----
	#
	# A regra da rodada é que cada aba promove UM número — o par valor/teto
	# que decide o que se pode fazer ali. A taverna não tem esse par: o
	# mural é uma lista que muda, e renome não tem teto. Inventar um seria
	# exatamente o defeito que a rodada veio corrigir, só que ao contrário —
	# dar peso de manchete a um número que não manda em nada.
	#
	# O que ela tem é CONTEXTO, e o contexto que falta aqui é a moral: os
	# serviços humilhantes deste balcão custam moral, e moral abaixo de 35 é
	# o exército desertando na aba ao lado. Os dois viviam em telas
	# diferentes sem nunca se citarem.
	var moral_t: int = Economia.moral(state)
	var grupo_t := Kit.sulco(c, Tema.E4, Tema.E3)
	var fatos_t := Kit.fila(grupo_t, Tema.E6)
	Kit.fato(fatos_t, "moral", str(moral_t), "de moral",
		Tema.cor_de_saude(float(moral_t) / 100.0),
		"Serviço humilhante paga em ouro e cobra em moral. Abaixo de 35 os homens desertam.")
	Kit.fato(fatos_t, "renome", str(int(state["jogador"]["renome"])), "de renome",
		Tema.TEXTO, "Contrato cumprido sobe; palavra quebrada derruba.")
	Kit.fato(fatos_t, "honra", str(int(state["jogador"].get("honra", 50))), "de honra",
		Tema.PERIGO if int(state["jogador"].get("honra", 50)) <= 25 else Tema.TEXTO,
		"Honra baixa fecha a porta dos empregos de confiança.")
	Kit.fato(fatos_t, "pergaminho", "%d" % Contratos.do_local(state).size(),
		"no mural", Tema.TEXTO, "Contratos oferecidos nesta praça hoje.")
	# O pagamento e o renome eram dois números no fim de uma frase de três
	# linhas, e a "dificuldade" era uma string repetida que saía VAZIA na
	# tela (`"".repeat(n)` repete nada n vezes). Aqui o pagamento é coluna, o
	# renome é coluna, e a dificuldade é um medidor — que era o que aquela
	# repetição queria ser.
	var tab := Kit.tabela(c, [
		{"t": "Contrato", "w": 0},
		{"t": "Dificuldade", "w": 96, "a": Kit.CENTRO},
		{"t": "Paga", "w": 76, "a": Kit.DIR},
		{"t": "Renome", "w": 76, "a": Kit.DIR},
		{"t": "", "w": 140, "a": Kit.DIR},
	])
	for ct in Contratos.do_local(state):
		var cel := Kit.linha(tab)
		var v := Kit.coluna(cel[0], 0)
		var l1 := Kit.fila(v, Tema.E3)
		Kit.texto(l1, str(ct["nome"]))
		# NOME DE EXIBIÇÃO, nunca o id: o contrato guarda "leoes" e "aguias",
		# e era isso que o mural imprimia — id cru, sem acento, minúsculo, e
		# que não bate com nenhum dos seis reinos que o Mapa anuncia. O
		# jogador não tem como saber que "leoes" são os Cervos Escarlates.
		Kit.texto(l1, "para %s" % Rotas.nome_do(state, str(ct["contratante"])),
			Tema.TEXTO_3, Tema.MICRO)
		# o selo de alvo mora na SEGUNDA linha: na primeira, nome + "para X"
		# + selo somavam mais largura mínima que o canvas de 960 tem — a
		# interface INTEIRA deslocava e cortava o botão "Passar o mês"
		if str(ct["alvo"]) != "":
			var l_alvo := Kit.fila(v, Tema.E3)
			Kit.selo(l_alvo, "alvo: %s" % Rotas.nome_do(state, str(ct["alvo"])),
				Tema.TEXTO_2, Tema.ELEVADO)
		Kit.nota(v, str(ct["desc"]))
		var forca: int = int(ct["forca"])
		Kit.medidor(cel[1], float(forca), 10.0, 80, 5,
			Tema.PERIGO if forca >= 7 else (Tema.ATENCAO if forca >= 4 else Tema.GANHO))
		Kit.numero(cel[2], str(ct["pagamento"]), Tema.ACENTO)
		Kit.numero(cel[3], "+%d" % int(ct["renome"]), Tema.GANHO)
		# o dia e a palavra dada entram na linha: são a informação que
		# transforma "aceitar" numa decisão de agenda, não num clique
		var dias_ct: int = Contratos.duracao_dias(ct)
		Kit.texto(l1, "%d %s" % [dias_ct, "dia" if dias_ct == 1 else "dias"],
			Tema.TEXTO_3, Tema.MICRO)
		if bool(ct.get("aceito", false)):
			Kit.selo(l1, "palavra dada", Tema.ACENTO, Tema.ACENTO_FUNDO)
		Kit.botao_mini(cel[4], "Ver serviço", func():
			_modal_preparacao(ct), "fantasma", 136)
	_balcao_de_empregos(c)
	_salao_de_pretendentes(c)
	# ---- serviços: informação vira dinheiro ----
	# taverna.gd já resolvia rumor, rota e informante; faltava a porta de
	# entrada. Cada serviço tem o rosto de quem o vende — é o que separa
	# "clicar num botão" de "pagar um homem por uma informação".
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Serviços do balcão")
	var ouvidos: Array = state.get("informantes", [])
	# os três serviços têm a MESMA forma — rosto, o que é, quanto custa,
	# botão — então são três chamadas do mesmo molde em vez de três blocos
	# escritos à mão com larguras diferentes, que era o estado anterior
	_servico(c, Retratos.textura("taverneiro"), "Rumor de mercado",
		"Um choque de preço antes de ele acontecer. Nem todo boato é verdade.",
		Taverna.PRECO_RUMOR, "Ouvir", func():
			var r: Dictionary = Taverna.comprar_rumor(state)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())
	_servico(c, Retratos.sprite_gerado("cartografo"), "Mapa comercial",
		"O retrato dos preços do continente, hoje. Depois de lido, o papel já não vale.",
		Taverna.PRECO_ROTA, "Comprar mapa", func():
			var r: Dictionary = Taverna.comprar_rota(state)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			Jogo.salvar(state)
			if bool(r["ok"]):
				_modal_mapa_comercial(r)
			else:
				_aviso(str(r["msg"]))
				atualizar())
	# O rótulo dizia "Informante em Império Central" em qualquer taverna do
	# mapa, porque lia `_reino_local()["nome"]` — que mentia — enquanto
	# contratava `state["local"]`, que é o lugar certo. O nome de exibição
	# agora vem da mesma fonte que a contratação.
	#
	# E onde não há corte, não há o que um informante escute: o serviço
	# cobrava 120 de entrada mais 25 por mês para nunca entregar notícia
	# nenhuma. Some do balcão em vez de vender o que não existe.
	var tem_corte: bool = not _reino_local().is_empty()
	if tem_corte:
		_servico(c, Retratos.sprite_gerado("informante"),
			"Informante em %s" % Rotas.nome_do(state, str(state["local"])),
			"Notícia da corte todo mês, por mais 25 de soldo.%s" % (
				(" Ouvidos ativos: %d." % ouvidos.size()) if not ouvidos.is_empty() else ""),
			Taverna.PRECO_INFORMANTE,
			"" if ouvidos.has(state["local"]) else "Contratar", func():
				var r: Dictionary = Taverna.contratar_informante(state, str(state["local"]))
				Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())

	var fregueses: Array = _fregueses_do_local()
	if not fregueses.is_empty():
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Fregueses")
		for npc in fregueses:
			_card_npc(c, npc, false)

## Um serviço do balcão: rosto de quem vende, o que é, o preço e o botão.
## `rotulo_botao` vazio significa "já contratado" — o card fica, o botão não.
## A FRONTEIRA SELVAGEM — o único lugar do jogo onde não há trono a tomar.
##
## Só aparece quando você está lá: é uma decisão de viagem antes de ser
## uma decisão militar. E a ordem é sempre a mesma — batedor, exército,
## coroa —, porque marchar às cegas contra três clãs é enterrar homens
## num número que ninguém viu.
func _fronteira_selvagem(c: Container) -> void:
	if str(state.get("local", "")) != Barbaros.ID:
		return
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "A fronteira selvagem")
	# o panorama das três terras — geleira, estepe e lama — como a primeira
	# coisa que se vê da fronteira, em qualquer estado dela
	var pano := Retratos.peca("barbaros_panorama")
	if pano != null:
		# a mesma moldura de madeira da vila e do retrato de conversa: é a
		# terceira ilustração que carrega uma tela inteira, e as três agora
		# se apresentam do mesmo jeito
		var cc := Kit.moldura_arte(c)
		var tr_p := TextureRect.new()
		# A arte vem com letterbox CINEMATOGRÁFICO assado: 30px de preto
		# chapado em cima e 30 embaixo, medidos no PNG — sobra 400×164 de
		# imagem. Solto na tela aquilo passava por escolha de composição;
		# dentro da moldura de madeira vira moldura DUPLA, e as duas
		# tarjas pretas leem como falha de carregamento.
		#
		# `AtlasTexture` recorta na exibição sem tocar no arquivo: se a
		# arte for regerada sem tarja um dia, basta apagar estas linhas.
		var recorte := AtlasTexture.new()
		recorte.atlas = pano
		recorte.region = Rect2(0, 30, 400, 164)
		tr_p.texture = recorte
		tr_p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr_p.custom_minimum_size = Vector2(400, 164)
		tr_p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cc.add_child(tr_p)
	if Barbaros.conquistado(state):
		if str(state["jogador"].get("rei_de", "")) == Barbaros.ID:
			Kit.nota(c, "Estas terras são o seu reino. O mapa tem sete casas.")
			return
		var pf: Dictionary = Barbaros.pode_fundar(state)
		var card_f := _card(c, Tema.ACENTO)
		var vf := Kit.coluna(card_f, 0)
		Kit.texto(vf, "Três clãs quebrados e nenhum trono.", Tema.ACENTO)
		Kit.nota(vf, "Aqui não se herda coroa: se funda uma casa do zero, com capital, produção e brasão próprios.")
		if not bool(pf["ok"]):
			Kit.nota(vf, str(pf["msg"]))
			return
		Kit.botao(vf, "Fundar um reino", func(): _modal_fundar(), "primario", 180)
		return
	var card := _card(c)
	var v := Kit.coluna(card, 0)
	if not Barbaros.reconhecido(state):
		var l_neb := Kit.fila(v, Tema.E2)
		var ic_neb := Icones.imagem("neblina", 18)
		if ic_neb != null:
			ic_neb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			l_neb.add_child(ic_neb)
		Kit.texto(l_neb, "Ninguém sabe quantos são.")
		Kit.nota(v, "Um batedor atravessa a fronteira e volta com a conta dos clãs. Sem isso, o exército marcha no escuro.")
		var l_esp := Kit.fila(v, Tema.E3)
		Kit.icone_valor(l_esp, "moedas", str(Barbaros.CUSTO_ESPIAO), Tema.ACENTO)
		Kit.botao_mini(l_esp, "Mandar batedor", func():
			var r: Dictionary = Barbaros.espiar(state, Jogo.log_para(state))
			Sfx.tocar(self, "tique" if r["ok"] else "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar(), "fantasma", 140)
		return
	# reconhecido: a conta dos clãs na mesa, e a decisão de atravessar
	Kit.texto(v, "O batedor voltou: %d homens em três clãs."
		% Barbaros.total_de_homens(state))
	var tab := Kit.tabela(v, [
		{"t": "", "w": 40, "a": Kit.CENTRO},
		{"t": "Clã", "w": 0},
		{"t": "Homens", "w": 90, "a": Kit.DIR},
	])
	for cla in Barbaros.CLAS:
		var cel := Kit.linha(tab)
		# o chefe tem cara (prefixo barbaro_: cla_estepe já é o clã
		# MERCENÁRIO da aba Clãs, e são duas pessoas diferentes)
		Kit.retrato(cel[0], Retratos.textura_pequena("barbaro_" + str(cla["id"])), 32)
		var col := Kit.coluna(cel[1], 0)
		Kit.texto(col, str(cla["nome"]))
		Kit.nota(col, str(cla["nota"]))
		Kit.numero(cel[2], str(Combate.total_homens(
			Barbaros.forcas(state)[cla["id"]])), Tema.PERIGO)
	var pi: Dictionary = Barbaros.pode_invadir(state)
	if not bool(pi["ok"]):
		Kit.nota(v, str(pi["msg"]))
		return
	Kit.botao(v, "Atravessar a fronteira", func(): _modal_invadir(), "perigo", 200)

func _modal_invadir() -> void:
	_modal("Atravessar a fronteira",
		"Três clãs, um depois do outro, sem descanso entre eles: %d homens ao todo contra os seus %d.\n\nQuem recua no meio perde o que já gastou — e os clãs lembram." % [
			Barbaros.total_de_homens(state),
			Combate.total_homens(state["jogador"]["tropas"])],
		[["Marchar", func():
			var r: Dictionary = Barbaros.invadir(state, Jogo.log_para(state))
			Jogo.salvar(state)
			var corpo := ""
			for f in r.get("fases", []):
				corpo += "%s — %s (você −%d, eles −%d)\n" % [str(f["cla"]),
					"vencido" if bool(f["vitoria"]) else "resistiu",
					int(f["baixas_suas"]), int(f["baixas_deles"])]
			corpo += "\nBaixas suas: %d." % int(r.get("baixas", 0))
			Sfx.tocar(self, "vitoria" if bool(r.get("vitoria", false)) else "derrota")
			_modal("TERRAS BÁRBARAS" if bool(r.get("vitoria", false)) else "A fronteira resistiu",
				corpo, [["Continuar", func(): atualizar()]],
				Retratos.ilustracao("invasao"))],
		["Recuar", func(): atualizar()]], Retratos.ilustracao("invasao"))

func _modal_fundar() -> void:
	var v := _painel_modal()
	var l := Label.new()
	l.text = "Fundar uma casa"
	var f := Tema.fonte_forte()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l.add_theme_color_override("font_color", Tema.ACENTO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	Kit.nota(v, "O nome que o mapa vai carregar, e a capital que os mensageiros vão procurar.")
	var r_casa := Kit.fila(v, Tema.E2)
	Kit.texto(r_casa, "Casa", Tema.TEXTO_3, Tema.MICRO)
	var campo_casa := LineEdit.new()
	campo_casa.placeholder_text = "Casa de %s" % str(state["jogador"]["nome"]).split(" ")[0]
	campo_casa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_casa.add_child(campo_casa)
	var r_cap := Kit.fila(v, Tema.E2)
	Kit.texto(r_cap, "Capital", Tema.TEXTO_3, Tema.MICRO)
	var campo_cap := LineEdit.new()
	campo_cap.placeholder_text = "Forte da Fronteira"
	campo_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_cap.add_child(campo_cap)
	Kit.respiro(v, Tema.E1)
	_botao_modal(v, "Erguer o estandarte", func():
		var r: Dictionary = Barbaros.fundar_reino(state, campo_casa.text,
			campo_cap.text, Jogo.log_para(state))
		overlay_modal.visible = false
		Sfx.tocar(self, "vitoria" if r["ok"] else "alerta")
		Jogo.salvar(state)
		_aviso(str(r["msg"]))
		atualizar(), "primario")

## O DIA EM QUE O INIMIGO APARECE.
##
## Ter guerra declarada deixou de ser um número numa aba: todo dia há
## chance de alguém cobrar. Onde você está decide o quê — coluna no seu
## portão, emboscada na estrada, ou a mão da guarda na sua gola dentro da
## capital de quem te odeia.
func _modal_inimizade(ev: Dictionary) -> void:
	Sfx.tocar(self, "alerta")
	var tipo := str(ev.get("tipo", ""))
	if tipo == "captura":
		# na corte inimiga não há escolha: são muitos e o portão fechou
		Jogo.prender(state, 2, Jogo.log_para(state))
		Jogo.salvar(state)
		_modal(str(ev["titulo"]), "%s\n\nDois meses a ferros. A fiança está na aba Terra." % str(ev["texto"]),
			[["Que seja", func(): atualizar()]], Retratos.ilustracao("traicao"))
		return
	var botoes: Array = [
		["Sair com o exército", func():
			var rel: Dictionary = Inimizade.enfrentar(state, ev, Jogo.log_para(state))
			Jogo.salvar(state)
			_modal_batalha(rel)],
	]
	if tipo == "ataque_terra":
		botoes.append(["Trancar tudo e deixar a guarda", func():
			var rel: Dictionary = Inimizade.deixar_a_guarda(state, ev, Jogo.log_para(state))
			Jogo.salvar(state)
			_modal_batalha(rel)])
	else:
		botoes.append(["Tentar escapar pela mata", func():
			# fugir custa carga e um pedaço do ouro, mas não a liberdade
			var perdido: int = roundi(int(state["jogador"]["ouro"]) * 0.20)
			state["jogador"]["ouro"] = maxi(0, int(state["jogador"]["ouro"]) - perdido)
			Jogo.salvar(state)
			_modal("Vocês correram", "Deixaram para trás %d de ouro e boa parte do orgulho — mas ninguém foi para a cela." % perdido,
				[["Seguir", func(): atualizar()]])])
	_modal(str(ev["titulo"]), str(ev["texto"]), botoes,
		Retratos.ilustracao("emboscada" if tipo == "emboscada" else "cerco"))

## RELATÓRIO DE OPERAÇÃO — espionagem e falsificação contando o que houve.
##
## Antes as duas devolviam uma linha no rodapé e um casus belli aparecia do
## nada na aba Intriga, sem explicação nenhuma do que tinha acontecido.
func _modal_operacao(r: Dictionary) -> void:
	if not r.has("relato"):
		_aviso(str(r.get("msg", "")))
		atualizar()
		return
	var venceu: bool = bool(r.get("sucesso", false))
	_modal(str(r.get("titulo", "Operação")), str(r["relato"]),
		[["Entendi", func(): atualizar()]],
		Retratos.ilustracao("juramento" if venceu else "traicao"),
		"louros" if venceu else "caveira")

## O MAPA COMERCIAL, aberto uma vez só.
##
## É informação perecível: o cartógrafo desenha os preços de hoje, o
## jogador lê, e ao fechar o papel já não vale. Nada fica guardado no
## estado de propósito — quem quiser olhar de novo compra outro mapa.
func _modal_mapa_comercial(r: Dictionary) -> void:
	var v := _painel_modal()
	var l := Label.new()
	l.text = "Mapa Comercial"
	var f := Tema.fonte_forte()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l.add_theme_color_override("font_color", Tema.ACENTO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	Kit.nota(v, "O que o cartógrafo viu HOJE. Ao fechar, o papel vira lenha.")
	var linhas: Array = r.get("linhas", [])
	if linhas.is_empty():
		Kit.texto(v, "Ninguém sabe de nada esta noite.", Tema.TEXTO_2)
	else:
		var tab := Kit.tabela(v, [
			{"t": "Mercadoria", "w": 0},
			{"t": "Barato em", "w": 150},
			{"t": "Caro em", "w": 150},
			{"t": "Margem", "w": 70, "a": Kit.DIR},
		])
		for ln in linhas.slice(0, 8):
			var cel := Kit.linha(tab, Tema.GANHO_FUNDO if int(ln["margem"]) >= 8 else null)
			Kit.texto(cel[0], str(ln["bem"]))
			Kit.texto(cel[1], "%s · %d" % [str(ln["barato_em"]), int(ln["barato"])],
				Tema.GANHO, Tema.MICRO)
			Kit.texto(cel[2], "%s · %d" % [str(ln["caro_em"]), int(ln["caro"])],
				Tema.ATENCAO, Tema.MICRO)
			Kit.numero(cel[3], "+%d" % int(ln["margem"]), Tema.ACENTO)
	if str(r.get("msg", "")) != "":
		Kit.nota(v, str(r["msg"]))
	Kit.respiro(v, Tema.E2)
	_botao_modal(v, "Guardar na memória e queimar", func(): atualizar(), "primario")

## O POPUP DO DOMÍNIO — o que o clique no castelo abre.
##
## Antes o clique ia direto para a viagem, e todo o resto (quem manda ali,
## espionar, atacar) morava numa lista de cards abaixo do mapa. Agora o
## mapa é a porta: uma janela só, que diz de quem é a terra e encadeia as
## decisões DENTRO dela — clicar em "Espionar" mostra o resultado na mesma
## janela, e de lá dá para atacar ou viajar sem recomeçar.
func _popup_dominio(id: String) -> void:
	var v := _painel_modal()
	var reino: Dictionary = {}
	for r in state["reinos"]:
		if str(r["id"]) == id:
			reino = r
	var aqui: bool = str(state.get("local", "")) == id
	var nome := Rotas.nome_do(state, id)

	# ---- cabeçalho: retrato de quem manda + nome do domínio ----
	var topo := Kit.fila(v, Tema.E4)
	var rosto: Texture2D = Retratos.textura("rei_" + id) if not reino.is_empty() else null
	if rosto != null:
		Kit.retrato(topo, rosto, 64)
	var vt := Kit.coluna(topo, 0)
	vt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l_nome := Kit.texto(vt, nome, Tema.ACENTO, Tema.TITULO_SECAO)
	var f_t := Tema.fonte_forte()
	if f_t != null:
		l_nome.add_theme_font_override("font", f_t)
	if reino.is_empty():
		# Reino sem Rei e Terras Bárbaras: não há trono, e é isso que
		# muda TUDO — não se espiona uma corte que não existe
		Kit.nota(vt, "Terra sem soberano. Ninguém cobra imposto, ninguém organiza defesa.")
	else:
		var rei_d: Dictionary = reino.get("rei", {})
		Kit.nota(vt, "%s · %s" % [str(rei_d.get("nome", "?")),
			str(reino.get("capital", ""))])
		var rel_d: int = int(state["tags"].get("rei_" + id, {"relacao": 0})["relacao"])
		var lr := Kit.fila(vt, Tema.E3)
		Kit.medidor(lr, float(rel_d + 100), 200.0, 110, 5,
			Tema.PERIGO if rel_d <= -25 else (Tema.GANHO if rel_d >= 25 else Tema.TEXTO_3))
		Kit.texto(lr, "%s (%d)" % [Dialogo.nome_relacao(rel_d), rel_d],
			Tema.TEXTO_2, Tema.MICRO)
		if str(reino.get("dominado_por", "")) != "":
			Kit.selo(vt, "dominado por %s"
				% Rotas.nome_do(state, str(reino["dominado_por"])),
				Tema.PERIGO, Tema.PERIGO_FUNDO)

	# ---- o que se sabe da força dali ----
	var vis: Dictionary = Intel.sobre(state, id) if not reino.is_empty() else {}
	if not reino.is_empty():
		var lf := Kit.fila(v, Tema.E3)
		Kit.texto(lf, "Força:", Tema.TEXTO_3, Tema.MICRO)
		Kit.texto(lf, str(vis.get("texto", "???")),
			Tema.TEXTO_2 if bool(vis.get("conhecido", false)) else Tema.TEXTO_3, Tema.MICRO)
		if bool(vis.get("conhecido", false)):
			var det: Array = Intel.detalhar(state, id)
			var partes: Array = []
			for l in det.slice(0, 3):
				partes.append("%d %s" % [int(l["n"]), str(l["nome"]).to_lower()])
			if not partes.is_empty():
				Kit.nota(v, ", ".join(partes))

	# ---- a estrada até lá ----
	if not aqui:
		var est: Dictionary = Viagem.estimar(state, id)
		if bool(est.get("ok", false)):
			Kit.nota(v, "%s — %d %s de estrada · assalto: %s" % [str(est["trajeto"]),
				int(est["dias"]), "dia" if int(est["dias"]) == 1 else "dias",
				str(est["risco_txt"])])
	else:
		Kit.selo(v, "você está aqui", Tema.ACENTO, Tema.ACENTO_FUNDO)

	Kit.respiro(v, Tema.E2)

	# ---- as decisões, todas nesta janela ----
	if not aqui:
		_botao_modal(v, "Viajar até aqui", func(): _abrir_viagem(id), "primario", 200)
	if not reino.is_empty():
		if not Intel.tem(state, id):
			_botao_modal(v, "Mandar espião  ·  80 ouro", func():
				var r: Dictionary = Intriga.espionar(state, id)
				if int(r.get("prender", 0)) > 0:
					Jogo.prender(state, int(r["prender"]), Jogo.log_para(state))
				Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
				Jogo.salvar(state)
				_modal_operacao(r), "fantasma", 200)
		if str(state["jogador"]["rei_de"]) != id:
			var tem_cb: bool = state["casus_belli"].has(id)
			var b_ass := _botao_modal(v, "Tomar o trono", func():
				var r: Dictionary = Intriga.assaltar_trono(state, id, Jogo.log_para(state))
				Jogo.salvar(state)
				if not bool(r.get("ok", true)):
					Sfx.tocar(self, "alerta")
					_aviso(str(r["msg"]))
					atualizar()
					return
				Sfx.tocar(self, "espada")
				_modal_batalha(r), "perigo", 200)
			b_ass.disabled = not aqui
			b_ass.tooltip_text = ("Assalto aos muros: gasta o dia inteiro." if aqui
				else "Você precisa ESTAR na capital. Viaje até lá, ou mande uma coluna de cerco pela aba Tropas.")
			# o casus belli explicado onde ele importa: na hora de atacar
			if tem_cb:
				Kit.nota(v, "Você tem CASUS BELLI aqui: um pretexto que as outras cortes aceitam. Atacar não vai virar o mapa inteiro contra você.")
			else:
				Kit.nota(v, "SEM casus belli: atacar é agressão pura, e os seis reinos reagem (relação −35 com todos, −60 com este). Forje um documento na Mesa de Intrigas antes.")
	else:
		Kit.nota(v, "Sem trono não há corte para espionar nem guerra para declarar. Aqui se chega andando — e se resolve com aço, na aba Tropas.")
	_botao_modal(v, "Fechar", func(): atualizar(), "", 200)

## A VIAGEM — o popup que o clique no mapa abre.
##
## Dias, trajeto e risco ANTES de confirmar; depois o tempo pula sozinho
## até a chegada. É o mesmo contrato do relatório de contrato: nenhuma
## decisão de agenda acontece às cegas.
func _abrir_viagem(destino: String) -> void:
	if destino == str(state.get("local", "")):
		_aviso("Você já está aqui.")
		return
	var est: Dictionary = Viagem.estimar(state, destino)
	if not bool(est["ok"]):
		Sfx.tocar(self, "alerta")
		_aviso(str(est["msg"]))
		return
	var dias: int = int(est["dias"])
	var corpo := "%s\n\n%d %s de estrada · risco %s" % [str(est["trajeto"]),
		dias, "dia" if dias == 1 else "dias", str(est["risco_txt"])]
	if int(state.get("dia", 1)) + dias > Jogo.DIAS_POR_MES + 1:
		corpo += "\n\nNão sobra mês para esta viagem. Feche o mês antes de partir."
		_modal("Viajar até %s" % Rotas.nome_do(state, destino), corpo,
			[["Entendi", func(): atualizar()]])
		return
	_modal("Viajar até %s" % Rotas.nome_do(state, destino), corpo, [
		["Partir agora", func(): _viajar(destino)],
		["Ficar", func(): atualizar()]])

func _viajar(destino: String) -> void:
	var r: Dictionary = Viagem.viajar(state, destino, Jogo.log_para(state))
	if not bool(r.get("ok", false)):
		Sfx.tocar(self, "alerta")
		_aviso(str(r.get("msg", "")))
		return
	Sfx.tocar(self, "pagina")
	Jogo.salvar(state)
	var enc: Dictionary = r.get("encontro", {})
	if enc.is_empty():
		atualizar()
		return
	# a estrada tem gente: e o encontro é uma ESCOLHA, não um castigo
	match str(enc["tipo"]):
		"caravana":
			var ouro_c: int = int(enc["ouro"])
			_modal(str(enc["titulo"]), str(enc["texto"]), [
				["Saquear", func():
					var rs: Dictionary = Viagem.saquear_caravana(state, ouro_c,
						Jogo.log_para(state))
					Sfx.tocar(self, "moeda")
					Jogo.salvar(state)
					_aviso("+%d de ouro. A honra caiu para %d." % [ouro_c, int(rs["honra"])])
					atualizar()],
				["Deixar passar", func():
					Jogo.salvar(state)
					atualizar()]], Retratos.ilustracao("caravana"))
		"assalto":
			var ra: Dictionary = Viagem.resolver_assalto(state, Jogo.log_para(state))
			Sfx.tocar(self, "alerta")
			Jogo.salvar(state)
			_modal(str(enc["titulo"]),
				"%s\n\nLevaram %d de ouro." % [str(enc["texto"]), int(ra["ouro_perdido"])],
				[["Seguir viagem", func(): atualizar()]],
				Retratos.ilustracao("emboscada"))

## O RELATÓRIO DE PREPARAÇÃO — a tela entre aceitar e marchar.
##
## Antes, "Aceitar e executar" era um botão só: o jogador descobria o
## tamanho do inimigo quando já tinha perdido os homens. Agora ele vê a
## conta antes — e o preço de largar depois de dar a palavra.
func _modal_preparacao(ct: Dictionary) -> void:
	var rp: Dictionary = Contratos.relatorio_preparacao(state, ct)
	var dias: int = int(rp["dias"])
	var corpo := "%s\n\n" % str(ct["desc"])
	# a chave crua ("facil"/"media"/"dificil") é régua de mecânica, não texto
	# de tela — o render flagrou "Serviço de facil" sem acento no modal
	var nome_dif: Dictionary = {"facil": "Serviço fácil", "media": "Serviço mediano",
		"dificil": "Serviço difícil"}
	corpo += "%s — %d %s de trabalho.\n" % [
		str(nome_dif.get(str(rp["dificuldade"]), "Serviço")),
		dias, "dia" if dias == 1 else "dias"]
	corpo += "Eles: cerca de %d homens.   Você: %d, equipamento %d, moral %d.\n" % [
		int(rp["inimigos"]), int(rp["meus"]), int(rp["equipamento"]), int(rp["moral"])]
	corpo += "\n%s\n\n" % str(rp["veredito"])
	corpo += "Paga %d de ouro e +%d de renome. Largar depois de dar a palavra custa %d de honra." % [
		int(ct["pagamento"]), int(ct["renome"]), int(rp["penalidade"])]
	var botoes: Array = []
	if bool(ct.get("aceito", false)):
		botoes.append(["Marchar agora", func(): _executar_contrato(ct)])
		botoes.append(["Largar o serviço", func():
			var r: Dictionary = Contratos.abandonar(state, str(ct["uid"]),
				Jogo.log_para(state))
			Sfx.tocar(self, "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar()])
	else:
		botoes.append(["Dar a palavra", func():
			var r: Dictionary = Contratos.aceitar(state, str(ct["uid"]))
			Sfx.tocar(self, "tique" if r["ok"] else "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar()])
	botoes.append(["Voltar ao mural", func(): atualizar()])
	_modal(str(ct["nome"]), corpo, botoes, _arte_de_batalha(str(ct["nome"])))

func _executar_contrato(ct: Dictionary) -> void:
	if Combate.total_homens(state["jogador"]["tropas"]) == 0:
		Sfx.tocar(self, "alerta")
		_aviso("Você não tem tropas! Recrute no quartel.")
		return
	var rel: Dictionary = Contratos.executar(state, ct, Jogo.log_para(state))
	if bool(rel.get("sem_tempo", false)):
		Sfx.tocar(self, "alerta")
		_aviso(str(rel["msg"]))
		return
	state["contratos"] = state["contratos"].filter(func(x): return x["uid"] != ct["uid"])
	Jogo.salvar(state)
	_modal_batalha(rel)

## O SALÃO — as três moças da região.
##
## Casar com plebeia não dá dote nem aliança: dá OFÍCIO, todo mês, e o
## povo levanta a caneca. Os reis é que torcem o nariz. É a escolha entre
## uma casa que produz e uma casa que abre portas.
func _salao_de_pretendentes(c: Container) -> void:
	if state["familia"]["conjuge"] != null:
		return
	var reino_id: String = str(state.get("local", ""))
	var mocas: Array = Pretendentes.do_reino(state, reino_id)
	if mocas.is_empty():
		return
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "No salão")
	Kit.nota(c, "Casar fora da nobreza custa relação com os reis e um naco de renome — e traz o ofício da casa dela para dentro da sua.")
	for m in mocas:
		var idx: int = int(m["idx"])
		var h := _card(c)
		# a leva ilustrada por (reino, ofício); busto procedural de reserva
		var id_arte := Retratos.id_pretendente(reino_id, str(m["oficio"]))
		Kit.retrato(h, Retratos.textura_pequena(id_arte) if id_arte != ""
			else Retratos.textura_cidadao({
				"nome": str(m["nome"]), "oficio": str(m["oficio"]),
				"genero": "f", "riqueza": 200}), 32)
		var v := Kit.coluna(h, 0)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l1 := Kit.fila(v, Tema.E3)
		Kit.texto(l1, str(m["nome"]))
		Kit.texto(l1, str(m["titulo"]), Tema.TEXTO_3, Tema.MICRO)
		Kit.nota(v, "%s  %s" % [str(m["dom"]), str(m["efeito"])])
		var af: int = int(m["afeto"])
		Kit.medidor(v, float(af), float(Pretendentes.AFETO_PARA_CASAR), 140, 5,
			Tema.GANHO if af >= Pretendentes.AFETO_PARA_CASAR else Tema.ACENTO)
		var acao := Kit.fila(h, Tema.E4)
		acao.size_flags_horizontal = Control.SIZE_SHRINK_END
		acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if af >= Pretendentes.AFETO_PARA_CASAR:
			Kit.botao_mini(acao, "Pedir a mão", func():
				var r: Dictionary = Pretendentes.pedir_a_mao(state, reino_id, idx,
					Jogo.log_para(state))
				Sfx.tocar(self, "vitoria" if r["ok"] else "alerta")
				Jogo.salvar(state)
				if bool(r["ok"]):
					_modal("Casados", "%s\n\n%s" % [str(r["msg"]), str(r["efeito"])],
						[["Que os bardos cantem", func(): atualizar()]],
						Retratos.ilustracao("casamento"))
				else:
					_aviso(str(r["msg"]))
					atualizar(), "primario", 118)
			continue
		Kit.icone_valor(acao, "moedas", str(Pretendentes.CUSTO_CORTEJO), Tema.ACENTO)
		Kit.botao_mini(acao, "Cortejar", func():
			var r: Dictionary = Pretendentes.cortejar(state, reino_id, idx,
				Jogo.log_para(state))
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar(), "fantasma", 100)

## O BALCÃO DE EMPREGOS — a saída para quem está sem ouro, sem tropa e
## sem terra (o "estado zumbi" que o teste alfa encontrou).
##
## Cada reino tem o SEU quadro: o Covil Negro oferece lenha e sermão, uma
## corte rica oferece o poço do gladiador e o espião do conselho. A régua
## é o tesouro do reino, que a geopolítica já mantém.
##
## O jogador nunca vê porcentagem — vê o aviso em texto. É a diferença
## entre "risco 25%" e "a areia é trocada toda noite; não é por limpeza".
func _balcao_de_empregos(c: Container) -> void:
	var reino_id: String = str(state.get("local", ""))
	var vagas: Array = Empregos.do_reino(state, reino_id)
	if vagas.is_empty():
		return
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Trabalho no balcão")
	Kit.nota(c, "Um turno rende ouro e ofício — e come dias do mês. Turno maior paga melhor e arrisca mais.")
	for vaga in vagas:
		_vaga_de_emprego(c, reino_id, vaga)

func _vaga_de_emprego(c: Container, reino_id: String, vaga: Dictionary) -> void:
	var id_vaga: String = str(vaga["id"])
	var h := _card(c)
	# o ícone do OFÍCIO, não a cara do patrão: numa lista de vagas o que
	# distingue as linhas é o que se faz — machado, alaúde, sinete. O busto
	# procedural fica de reserva para quando a peça não existir.
	var ic_of := Icones.imagem("emprego_" + id_vaga, 32)
	if ic_of != null:
		ic_of.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic_of)
	else:
		Kit.retrato(h, Retratos.textura_cidadao({
			"nome": str(vaga["patrao"]), "oficio": "mercador",
			"genero": "m", "riqueza": 400}), 32)
	var v := Kit.coluna(h, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l1 := Kit.fila(v, Tema.E3)
	Kit.texto(l1, str(vaga["nome"]))
	Kit.selo(l1, str(vaga["atributo"]), Tema.TEXTO_2, Tema.ELEVADO)
	Kit.nota(v, str(vaga["patrao"]))
	Kit.nota(v, "%s  %s" % [str(vaga["desc"]), str(vaga["aviso"])])
	var acao := Kit.fila(h, Tema.E4)
	acao.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.icone_valor(acao, "moedas", "%d/dia" % int(vaga["paga_dia"]), Tema.ACENTO)
	if not Empregos.contratado(state, reino_id, id_vaga):
		# a porta fechada é o desenho: sem pedir, não se trabalha — e a
		# HONRA é a entrevista inteira
		Kit.botao_mini(acao, "Pedir emprego", func():
			var r: Dictionary = Empregos.pedir_emprego(state, reino_id, id_vaga)
			Sfx.tocar(self, "tique" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "fantasma", 118)
		return
	for dias in [1, 2, 3]:
		Kit.botao_mini(acao, "%dd" % dias, func():
			_trabalhar(reino_id, id_vaga, dias), "fantasma", 40)

## Avisos que o jogador já entendeu e não quer rever. Ficam no `state`
## (e portanto no save), com a chave do aviso — é preferência de partida,
## não de instalação.
func _aviso_silenciado(chave: String) -> bool:
	return bool(state.get("avisos_ocultos", {}).get(chave, false))

func _silenciar_aviso(chave: String) -> void:
	if not (state.get("avisos_ocultos") is Dictionary):
		state["avisos_ocultos"] = {}
	state["avisos_ocultos"][chave] = true
	Jogo.salvar(state)

## O TURNO CONSOME O DIA — e isso precisa ser dito ANTES, não descoberto.
##
## O jogador clicava "2d" e o calendário andava sozinho; parecia bug. O
## aviso explica a troca uma vez e oferece não repetir, porque na décima
## vez ele vira obstáculo em vez de ajuda.
func _trabalhar(reino_id: String, emprego_id: String, dias: int) -> void:
	if not _aviso_silenciado("turno_consome_dia"):
		var e_av: Dictionary = Empregos.por_id(emprego_id)
		_modal("O turno come o mês",
			"Trabalhar %d %s faz o calendário andar %d %s: é o mesmo tempo que uma viagem ou um contrato custariam.\n\n%s paga %d por dia — e o mês só tem %d." % [
				dias, "dia" if dias == 1 else "dias", dias,
				"dia" if dias == 1 else "dias", str(e_av.get("nome", "O ofício")),
				int(e_av.get("paga", 0)), Jogo.DIAS_POR_MES],
			[["Entendi, trabalhar", func():
				overlay_modal.visible = false
				_executar_turno(reino_id, emprego_id, dias)],
			["Entendi, não avise mais", func():
				_silenciar_aviso("turno_consome_dia")
				overlay_modal.visible = false
				_executar_turno(reino_id, emprego_id, dias)],
			["Voltar", func(): atualizar()]],
			Retratos.ilustracao("emprego"))
		return
	_executar_turno(reino_id, emprego_id, dias)

func _executar_turno(reino_id: String, emprego_id: String, dias: int) -> void:
	var r: Dictionary = Empregos.trabalhar(state, reino_id, emprego_id, dias,
		Jogo.log_para(state))
	if not bool(r.get("ok", false)):
		Sfx.tocar(self, "alerta")
		_aviso(str(r.get("msg", "")))
		return
	Jogo.salvar(state)
	var e: Dictionary = Empregos.por_id(emprego_id)
	var conseq: Array = r.get("consequencias", [])
	if bool(r.get("morreu", false)):
		Sfx.tocar(self, "derrota")
		atualizar()
		return                          # o modal de fim já vem por atualizar()
	if conseq.is_empty():
		Sfx.tocar(self, "moeda")
		_aviso("Turno cumprido: +%d de ouro." % int(r["paga"]))
		atualizar()
		return
	# consequência não é aviso de rodapé: é acontecimento, e ganha modal
	Sfx.tocar(self, "alerta")
	_modal(str(e["nome"]),
		"Turno de %d %s: +%d de ouro.\n\n%s" % [dias, "dia" if dias == 1 else "dias",
			int(r["paga"]), "\n".join(conseq)],
		[["Seguir", func(): atualizar()]], Retratos.ilustracao("emprego"))

func _servico(c: Container, rosto: Texture2D, titulo: String, desc: String,
		preco: int, rotulo_botao: String, cb: Callable) -> void:
	var h := _card(c)
	Kit.retrato(h, rosto, 32)
	var v := Kit.coluna(h, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.texto(v, titulo)
	Kit.nota(v, desc)
	var acao := Kit.fila(h, Tema.E4)
	acao.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.icone_valor(acao, "moedas", str(preco), Tema.ACENTO)
	if rotulo_botao == "":
		Kit.selo(acao, "já contratado", Tema.GANHO, Tema.GANHO_FUNDO)
	else:
		Kit.botao_mini(acao, rotulo_botao, cb, "fantasma", 118)

## A CORTE DE UMA TERRA QUE NÃO TEM TRONO.
##
## Antes esta tela abria a corte do Império em qualquer lugar do mapa que não
## fosse um dos seis reinos. Agora ela diz a verdade — e a verdade tinha que
## vir com um caminho, senão a aba vira um beco.
##
## Nos dois casos o caminho existe e já estava escrito noutra aba: nas Terras
## Bárbaras, a fronteira selvagem do Mapa (espiar, invadir, fundar a própria
## casa); no Reino sem Rei, o trono vazio que ninguém reclamou.
func _corte_sem_trono(c: Container) -> void:
	var e_barbaro: bool = str(state.get("local", "")) == Barbaros.ID
	Kit.titulo_tela(c, "Sem corte aqui",
		"Terra sem soberano não tem salão, não tem guarda de portão e não tem com quem negociar.")
	var card := Kit.card(c, Tema.ATENCAO)
	if e_barbaro:
		Kit.texto(card, "Os clãs não mandam recado: mandam cavaleiros.",
			Tema.ATENCAO, Tema.CORPO_G)
		Kit.nota(card, "Aqui não há rei para elogiar, chantagear ou pedir paz. O que existe são três clãs — geleira, estepe e lama — e eles só entendem duas linguagens: o batedor que você paga para olhar, e a coluna que você manda entrar.")
		Kit.nota(card, "A fronteira selvagem fica na aba Mapa: espiar, invadir e, se o seu nome pesar o bastante, fundar a sua própria casa neste chão.")
	else:
		Kit.texto(card, "O trono está vazio, e ninguém sentou nele.",
			Tema.ATENCAO, Tema.CORPO_G)
		Kit.nota(card, "Não há rei, não há consorte, não há herdeiro — e por isso não há relação a construir nem favor a cobrar. A relação que você acumula nas outras cortes não vale nada aqui.")
		Kit.nota(card, "O que esta terra tem é o que qualquer um pode tomar. Veja o domínio no Mapa.")
	var ir := Kit.fila(c, Tema.E3)
	_botao(ir, "Abrir o Mapa", func():
		tabs.current_tab = 1
		atualizar(), "primario")
	# renda de fundo de poço, que existe justamente nestes dois nós
	_botao(ir, "Ver os serviços da taverna", func():
		tabs.current_tab = 3
		atualizar())

func _aba_corte(c: Container) -> void:
	var reino := _reino_local()
	# `_reino_local` devolve vazio fora dos seis reinos. Antes ela devolvia o
	# Império e esta tela inteira rodava com o reino errado.
	if reino.is_empty():
		_corte_sem_trono(c)
		return
	Kit.titulo_tela(c, "Corte de %s" % reino["capital"],
		"Escreva o que quiser: elogie, insulte, ameace, proponha casamento, chantageie, negocie a paz. O NPC entende — e LEMBRA.")
	# escada de acesso (Parte 2): o guarda do portão é sempre o primeiro
	# contato — o rei só atende em pessoa quando a relação (e, no Neutro, o
	# título) já foi conquistada. quem_atende() devolve o card certo pronto.
	var atende: Dictionary = Dialogo.quem_atende(state, reino["id"])
	var no_portao: bool = str(atende.get("papel", "")) == "guarda"

	# ---- O NÚMERO DA CORTE: a relação com quem manda ----
	#
	# Ela já governava tudo nesta tela — quem te atende, se o portão abre, se
	# a corte te abriga quando você tem inimigo, se o rei te prende — e
	# aparecia como uma barrinha de 90px perdida numa linha do card do reino.
	#
	# A escala é de −100 a +100, então o medidor recebe rel+100 sobre 200: um
	# valor negativo com barra vazia leria como "ainda não começou", quando o
	# que ele diz é "ele te quer morto".
	var rel_rei: int = int(state["tags"].get("rei_" + str(reino["id"]),
		{"relacao": 0})["relacao"])
	var grupo_c := Kit.sulco(c, Tema.E4, Tema.E3)
	var glosa_c := "Neutro: ele te recebe, mas nada te deve."
	if rel_rei >= 60:
		glosa_c = "Aliado. Sob este teto, inimigo nenhum te pega — e o portão está aberto."
	elif rel_rei >= 25:
		glosa_c = "Ele te ouve. Mais alguns favores e esta casa te abriga."
	elif rel_rei <= -60:
		glosa_c = "Ele te quer a ferros. Pisar nesta capital em guerra é entregar o pescoço."
	elif rel_rei <= -25:
		glosa_c = "A casa está contra você. O portão só abre com ouro ou com medo."
	# teto 0: relação não tem teto para imprimir ("0 / 200" não quer dizer
	# nada). A barra recebe a fração deslocada; o número, a relação crua.
	Kit.destaque(grupo_c, "Relação com %s" % str(reino["rei"]["nome"]),
		rel_rei, 0,
		Tema.PERIGO if rel_rei <= -25 else (Tema.GANHO if rel_rei >= 25 else Tema.ATENCAO),
		glosa_c, "corte_relacao_" + str(reino["id"]),
		float(rel_rei + 100) / 200.0)
	# Os fatos são NÚMEROS, e essa restrição é do componente: `fato` põe o
	# valor na fonte de número, no tamanho de número. Pôr "Desconfiado" ou
	# "sim" ali seria usar o peso do algarismo para carregar uma palavra.
	var casa_peso: Dictionary = Geopolitica.casa_real(state, str(reino["id"]))
	var membros_c: Array = casa_peso.get("membros", [])
	# a média PONDERADA da casa: é ela que `_tick_influencia_corte` usa para
	# empurrar o rei ±3 por mês, e abaixo de −60 ela pede a sua prisão.
	# Estava calculada e invisível.
	var soma_c := 0.0
	var peso_total := 0.0
	for m_c in membros_c:
		var p_c := float(int(m_c.get("peso", 1)))
		soma_c += float(int(state["tags"].get(str(m_c["id"]), {"relacao": 0})["relacao"])) * p_c
		peso_total += p_c
	var media_casa: int = roundi(soma_c / maxf(1.0, peso_total))
	var fatos_c := Kit.fila(grupo_c, Tema.E6)
	Kit.fato(fatos_c, "familia", "%d" % membros_c.size(), "na casa real",
		Tema.TEXTO,
		"Consorte e herdeiros. Falam ao ouvido do rei todo mês — a favor ou contra.")
	Kit.fato(fatos_c, "intriga", "%d" % media_casa, "de peso da casa",
		Tema.PERIGO if media_casa <= -25 else (Tema.GANHO if media_casa >= 25 else Tema.TEXTO_2),
		"A média ponderada da casa empurra a relação do rei em até 3 por mês. Abaixo de −60, eles pedem a sua prisão.")
	var guerras_reino := 0
	for g_c in state["guerras"]:
		if str(g_c.get("a", "")) == str(reino["id"]) or str(g_c.get("b", "")) == str(reino["id"]):
			guerras_reino += 1
	Kit.fato(fatos_c, "guerra", "%d" % guerras_reino, "guerras desta casa",
		Tema.ATENCAO if guerras_reino > 0 else Tema.TEXTO,
		"Reino em guerra compra caro, recruta muito e escuta quem traz homens.")

	if no_portao:
		Kit.nota(c, "Você fala no PORTÃO. Ganhe a confiança da casa — ou pague o guarda — para entrar no salão.")
	_card_npc(c, atende)

	# ---- DENTRO DO SALÃO: a casa real, quando a porta abre ----
	# Antes, "entrar" só mudava com quem você conversava — a tela era a
	# mesma. Agora a corte se abre: o rei, quem se sentou ao lado dele e
	# os filhos que herdam. É o que faz a entrada valer o preço.
	if not no_portao:
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "No salão de %s" % str(reino["capital"]))
		var casa_r: Dictionary = Geopolitica.casa_real(state, str(reino["id"]))
		if (casa_r.get("membros", []) as Array).is_empty():
			Kit.nota(c, "O trono está só. Nem consorte, nem herdeiro — e uma casa sem herdeiro é uma guerra esperando a hora.")
		Kit.nota(c, "Eles falam ao ouvido do rei todo mês. Quem tem a casa do lado tem o trono; quem tem a casa contra sai daqui a ferros.")
		for membro in casa_r.get("membros", []):
			var hc := _card(c)
			Kit.retrato(hc, Retratos.textura_cidadao({
				"nome": str(membro["nome"]), "oficio": "senhor", "riqueza": 500,
				"genero": str(membro.get("genero", "f")), "lealdade": 60,
				"lorde": true}, true,
				str(Retratos.REIS.get("rei_" + str(reino["id"]), {}).get("fundo", ""))), 32)
			var vc := Kit.coluna(hc, 0)
			vc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var lc := Kit.fila(vc, Tema.E3)
			Kit.texto(lc, str(membro["nome"]))
			Kit.selo(lc, str(membro["papel"]), Tema.TEXTO_2, Tema.ELEVADO)
			var rel_m: int = int(state["tags"].get(str(membro["id"]),
				{"relacao": 0})["relacao"])
			Kit.medidor(lc, float(rel_m + 100), 200.0, 90, 5,
				Tema.PERIGO if rel_m <= -25 else (Tema.GANHO if rel_m >= 25 else Tema.TEXTO_3))
			Kit.texto(lc, "%s (%d)" % [Dialogo.nome_relacao(rel_m), rel_m],
				Tema.TEXTO_3, Tema.MICRO)
			Kit.nota(vc, str(membro["nota"]))
			# quem herda pesa mais no ouvido do rei — e o card diz isso
			var peso_m: int = int(membro.get("peso", 1))
			Kit.nota(vc, "Peso na corte: %s" % ["fraco", "moderado", "grande"][
				clampi(peso_m - 1, 0, 2)])
			var npc_membro := {"id": str(membro["id"]), "nome": str(membro["nome"]),
				"personalidade": str(membro.get("personalidade", "calculista")),
				"papel": "casa", "reino_id": str(reino["id"]),
				"intencoes_permitidas": null}
			var acao_c := Kit.fila(hc, Tema.E3)
			acao_c.size_flags_horizontal = Control.SIZE_SHRINK_END
			acao_c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_botao(acao_c, "Conversar", func(): abrir_conversa(npc_membro), "fantasma")

	# ---- a SUA corte: gente que nasceu durante a partida ----
	# Cada retrato é gerado a partir do NOME do notável, então a lista muda a
	# cada saga e nunca fica com buraco — e nunca fica com sete cópias do
	# mesmo rosto, que era o efeito do caixote cinza.
	var res_cid: Dictionary = Cidadaos.resumo(state)
	if int(res_cid["total"]) > 0:
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Sua Corte — %d notáveis, %d jurados" % [
			int(res_cid["total"]), int(res_cid["lordes"])])
		var tab := Kit.tabela(c, [
			{"t": "", "w": 34, "a": Kit.CENTRO},
			{"t": "", "w": 0},
			{"t": "", "w": 130, "a": Kit.DIR},
			{"t": "", "w": 150, "a": Kit.DIR},
		])
		for n in Cidadaos.lista(state):
			var preso: bool = bool(n.get("capturado", false))
			var cel := Kit.linha(tab, Tema.PERIGO if preso else null)
			# lorde jurado carrega o fundo da casa — a mesma marca de facção
			# dos reis. Cidadão comum fica neutro: o fundo é heráldica, e
			# heráldica em ferreiro leria como erro.
			Kit.retrato(cel[0], Retratos.textura_cidadao(n, true,
				Retratos.fundo_da_casa(state) if bool(n.get("lorde", false)) else ""), 32)
			var vn := Kit.coluna(cel[1], 0)
			var l_nome := Kit.fila(vn, Tema.E3)
			Kit.texto(l_nome, str(n["nome"]))
			Kit.texto(l_nome, str(n["oficio"]), Tema.TEXTO_3, Tema.MICRO)
			if bool(n.get("lorde", false)):
				Kit.selo(l_nome, "seu lorde", Tema.ACENTO, Tema.ACENTO_FUNDO)
			if preso:
				var ic_ferros := Icones.imagem("correntes", 14)
				if ic_ferros != null:
					ic_ferros.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					l_nome.add_child(ic_ferros)
				Kit.selo(l_nome, "a ferros", Color("e8917a"), Tema.PERIGO_FUNDO)
			# riqueza e lealdade são status OCULTOS: o jogador lê a impressão,
			# não o número, exatamente como leria um vassalo de verdade
			var lealdade: int = int(n.get("lealdade", 50))
			var leitura := "parece contente com o seu governo"
			if lealdade < 40:
				leitura = "evita o seu olhar nas assembleias"
			elif lealdade < 60:
				leitura = "cumpre o que deve, nada além"
			Kit.nota(vn, leitura)
			if int(n.get("riqueza", 0)) >= 280:
				Kit.texto(cel[2], "casa próspera", Tema.TEXTO_3, Tema.MICRO)
			if preso:
				var nome_preso: String = str(n["nome"])
				Kit.botao_mini(cel[3], "Pagar resgate · 300", func():
					var r: Dictionary = Comandantes.resgatar(state, nome_preso)
					Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
					_aviso(r["msg"])
					Jogo.salvar(state)
					atualizar(), "fantasma", 146)

	Kit.respiro(c, Tema.E2)
	var h := Kit.fila(c, Tema.E3)
	_botao(h, "IA dos personagens: " + Llm.descricao_estado(),
		_modal_llm, "fantasma")

## O card de um NPC com quem se pode CONVERSAR.
##
## O botão "Conversar" ficava numa VBox que expandia na largura toda: 830px
## de botão. Aqui ele volta ao tamanho do seu texto e vai para a direita do
## card, onde uma ação de linha pertence — e a relação, que era um número
## entre parênteses, vira medidor.
## `destaque` decide se o "Conversar" é o botão primário do card.
##
## A Corte tem UM interlocutor — quem atende no portão, ou o rei — e ali o
## primário é o certo: é o verbo pelo qual a aba existe. A Taverna tem TRÊS
## fregueses em lista, e três botões de latão empilhados não hierarquizam
## nada: eles só gastam o latão, que é o recurso mais escasso da paleta.
## Qual ROSTO desenhar para um NPC.
##
## Não é `npc["id"]`, e a diferença custou um bug visível: no portão, o
## guarda aparecia com a cara do rei. O `id` é a chave de RELAÇÃO — o
## guarda usa "rei_<reino>" porque a simpatia ganhada no portão é simpatia
## da casa, e tem que ser a mesma que o rei consulta lá dentro. Quem fala é
## outra pessoa, e é isso que `retrato` diz.
func _id_retrato(npc: Dictionary) -> String:
	return str(npc.get("retrato", npc.get("id", "")))

func _card_npc(c: Container, npc: Dictionary, destaque: bool = true) -> void:
	var h := _card(c)
	_retrato(h, _id_retrato(npc), 64)
	var v := Kit.coluna(h, Tema.E2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nome := Kit.texto(v, str(npc["nome"]), Tema.TEXTO, Tema.CORPO_G)
	var f := Tema.fonte_forte()
	if f != null:
		nome.add_theme_font_override("font", f)
	var rel: int = state["tags"].get(npc["id"], {"relacao": 0})["relacao"]
	var lr := Kit.fila(v, Tema.E3)
	Kit.medidor(lr, float(rel + 100), 200.0, 110, 5,
		Tema.PERIGO if rel <= -25 else (Tema.GANHO if rel >= 25 else Tema.TEXTO_3))
	Kit.texto(lr, "%s (%d)" % [Dialogo.nome_relacao(rel), rel], Tema.TEXTO_2, Tema.MICRO)
	var acao := Kit.fila(h, Tema.E3)
	acao.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_botao(acao, "Conversar", func(): abrir_conversa(npc),
		"primario" if destaque else "")

## As três classes, por extenso — "arq" e "cav" são chave de tabela, não
## coisa que se mostre a quem está escolhendo tropa.
func _nome_classe(cl: String) -> String:
	match cl:
		"arq": return "atiradores"
		"cav": return "cavalaria"
	return "infantaria"

## Para que serve cada unidade, em uma linha. É a pergunta que a tabela de
## números não responde: o jogador vê "atq 150" e não sabe que a cavalaria
## pesada quebra linha mas morre para lanceiro em muro.
func _serve_para(tipo: String) -> String:
	match tipo:
		"campones": return "Carne barata: enche a linha e paga pouco soldo. Morre fácil."
		"lanceiro": return "A parede. Segura carga de cavalaria melhor que ninguém."
		"espadachim": return "Quem decide o corpo a corpo depois que as linhas se encontram."
		"barbaro": return "Ataque puro, defesa nenhuma. Ganha rápido ou morre rápido."
		"arqueiro": return "Fere antes do choque. Frágil se a cavalaria chegar."
		"explorador": return "Não luta: enxerga. Ocupa dois de população."
		"cav_leve": return "Persegue quem foge e volta com carga. Fraca em muro."
		"arq_cavalo": return "Fere e recua. Cara de manter, difícil de encurralar."
		"cav_pesada": return "Quebra a linha inimiga de uma vez — e come como três."
	return ""

func _aba_exercito(c: Container) -> void:
	var j: Dictionary = state["jogador"]
	var p := Combate.poder(j["tropas"], j["equip"])
	var moral: int = Economia.moral(state)
	# "Manutenção —" sem número acontece no primeiro mês, antes de a economia
	# rodar uma vez. Melhor dizer isso do que mostrar um travessão solto.
	var manut = j.get("ultima_manut", null)
	Kit.titulo_tela(c, "Quartel",
		("Último soldo pago: %d de ouro." % int(manut)) if manut != null
			else "Nenhum soldo pago ainda.")

	# ---- o painel de estado do exército ----
	# Era uma frase de sete números ("Ataque 3050 · Defesa 5300 · 98 homens
	# · Equipamento 0/3 · nenhum soldo pago ainda") seguida de outra frase e
	# de um card com quatro ícones. Ataque e Defesa são os dois números pelos
	# quais o jogador decide marchar ou não, e liam com o mesmo peso do resto.
	#
	# desconto do ferreiro entra no upkeep: sem isto, o número mostrado na
	# tela nunca bateria com o que Economia.tick_exercito realmente cobra no
	# fim do mês — a Corte teria efeito invisível até o soldo cair.
	var up: Dictionary = Economia.upkeep_de(j["tropas"], 1.0,
		Cidadaos.oficio_ativo(state, "ferreiro"))
	# ---- O NÚMERO DO QUARTEL: a moral ----
	#
	# Ela é o único número desta tela com um LIMIAR mecânico: abaixo de 35 os
	# homens desertam e `Combate.fator_moral` corta a força em campo. Era um
	# medidor de 6px de altura ao lado de outro, com o mesmo peso do sustento.
	#
	# E é a ponte com a Taverna, que é onde ela se gasta: cada dia de serviço
	# humilhante cobra moral, e as duas telas nunca se citavam.
	var painel := Kit.sulco(c, Tema.E4, Tema.E3)
	Kit.destaque(painel, "Moral do exército", moral, 100,
		Tema.cor_de_saude(float(moral) / 100.0),
		("Lutam a %d%% da força em campo. Abaixo de 35, começam a desertar."
			% roundi(Combate.fator_moral(moral) * 100.0)) if moral > 35
		else "Eles já estão indo embora, e lutam a %d%% da força. Vitória, soldo em dia e descanso trazem de volta."
			% roundi(Combate.fator_moral(moral) * 100.0),
		"quartel_moral")

	# o bloco de quatro números que este trecho montava à mão era o `fato`
	# antes de o `fato` existir: rótulo em versalete pequeno, número acima.
	# Passa a ser o componente — e ganha a dica de para que cada um serve.
	var topo := Kit.fila(painel, Tema.E6)
	Kit.fato(topo, "espada", str(roundi(p["atq"])), "de ataque", Tema.TEXTO,
		"Força de choque somada, já com equipamento e moral.")
	Kit.fato(topo, "escudo", str(roundi(p["def"])), "de defesa", Tema.TEXTO,
		"O que segura carga inimiga. Lanceiro pesa aqui.")
	Kit.fato(topo, "tropa", str(p["homens"]), "homens", Tema.TEXTO,
		"Cabeças em armas. Cada uma come, bebe e recebe soldo.")
	Kit.fato(topo, "martelo", "%d/3" % int(j["equip"]), "de equipamento",
		Tema.ATENCAO if int(j["equip"]) == 0 else Tema.TEXTO,
		"Da forja: couro batido, malha de ferro, placas. Multiplica a força em campo.")
	# a manutenção do mês, à direita: é o que o exército CUSTA, e custo fica
	# separado de força para as duas leituras não se misturarem
	var custo := Kit.fila(topo, Tema.E4)
	custo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custo.alignment = BoxContainer.ALIGNMENT_END
	custo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for par_up in [["moedas", int(up["ouro"])], ["trigo", int(up["comida"])],
			["madeira", int(up["madeira"])]]:
		Kit.icone_valor(custo, str(par_up[0]), "%d" % int(par_up[1]), Tema.TEXTO_2)
	Kit.nota(custo, "por mês")

	var medidores := Kit.fila(painel, Tema.E6)
	# "Sustento da terra", não "população comprometida": a aba Terra já usa
	# esse segundo nome para OUTRA conta (homens em armas sobre a base ativa).
	# Dois medidores quase homônimos com denominadores diferentes eram uma
	# pegadinha; este mede contra o teto que a terra sustenta — o mesmo
	# número da linha "Tropa que a terra sustenta" da aba Terra.
	# ---- O DEPÓSITO: o teto de tropas antes de ter terra ----
	# Sem chão o bando era travado em vinte homens, e terra custa 5.000:
	# não havia como crescer para pegar contrato médio. A baia alugada é a
	# ponte — dez espaços por 5 de ouro POR DIA, cobrados no passar do dia.
	var esp_arm: int = Armazem.espacos(state)
	var card_arm := _card(c, Tema.ATENCAO if Armazem.aluguel_diario(state) > 0 else null)
	var ic_arm := Icones.imagem("carroca", 32)
	if ic_arm != null:
		ic_arm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_arm.add_child(ic_arm)
	var v_arm := Kit.coluna(card_arm, 0)
	v_arm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.texto(v_arm, "%s — %d baias, %d espaços" % [
		"Depósito próprio" if Armazem.proprio(state) else "Armazém alugado",
		Armazem.baias(state), esp_arm])
	if Armazem.aluguel_diario(state) > 0:
		Kit.nota(v_arm, "Custa %d de ouro POR DIA. Três dias sem pagar e o feitor fica com uma baia — e com o que houver nela."
			% Armazem.aluguel_diario(state))
	elif Armazem.proprio(state):
		Kit.nota(v_arm, "Construído na sua terra: não cobra diária.")
	else:
		Kit.nota(v_arm, "Cada baia sustenta mais 10 homens e guarda o que os alimenta. É assim que se cresce antes de ter terra.")
	var acao_arm := Kit.fila(card_arm, Tema.E3)
	acao_arm.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao_arm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var custo_arm: int = Armazem.custo_proxima(state) * (2 if state["terra"] != null else 1)
	Kit.icone_valor(acao_arm, "moedas", str(custo_arm), Tema.ACENTO)
	var b_arm := Kit.botao_mini(acao_arm,
		"Construir baia" if state["terra"] != null else "Alugar baia", func():
		var r: Dictionary = Armazem.construir(state) if state["terra"] != null \
			else Armazem.alugar(state)
		Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
		_aviso(str(r["msg"]))
		Jogo.salvar(state)
		atualizar(), "fantasma", 140)
	b_arm.disabled = int(j["ouro"]) < custo_arm

	Kit.medidor_rotulado(medidores, "Sustento da terra",
		Recrutamento.pop_usada(state), Recrutamento.pop_maxima(state),
		" de %d" % Recrutamento.pop_maxima(state), Tema.TEXTO_2, "quartel_sustento")
	# A MORAL AGORA VALE NA BATALHA, e o jogador tem que saber disso — e
	# saber como se recupera, que era a metade invisível da mecânica.
	if moral <= 35:
		var cm := Kit.card(c, Tema.PERIGO)
		Kit.texto(cm, "Moral baixa: seus homens desertam e lutam pior (%d%% da força)."
			% roundi(Combate.fator_moral(moral) * 100), Tema.PERIGO)
		Kit.nota(cm, "Pague o soldo e encha os celeiros: mês com tudo em dia devolve 6 de moral.")
	elif moral < 100:
		Kit.nota(c, "Moral %d: o exército luta a %d%% da força. Mês com soldo e celeiro em dia devolve 6."
			% [moral, roundi(Combate.fator_moral(moral) * 100)])

	# ---- as unidades, em tabela ----
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Recrutamento — os homens de armas")
	# A DIFERENÇA QUE FALTAVA ESTAR ESCRITA: estes são os homens que
	# MARCHAM. A guarda de elite (aba Casa) faz o contrário — nunca sai, e
	# é ela que segura o portão quando alguém marcha contra a sua terra.
	Kit.nota(c, "Estes homens partem em campanha: contrato, saque, cerco. Quem fica defendendo a sua casa é a guarda de elite, na aba Casa.")
	Kit.nota(c, "Passe o mouse sobre a unidade para ver ataque, defesas, soldo e para que ela serve.")
	var tab := Kit.tabela(c, [
		{"t": "", "w": 34, "a": Kit.CENTRO},
		{"t": "Unidade", "w": 0},
		{"t": "Tem", "w": 60, "a": Kit.DIR},
		{"t": "Custo", "w": 64, "a": Kit.DIR},
		{"t": "Manut.", "w": 64, "a": Kit.DIR},
		{"t": "Ritmo", "w": 84, "a": Kit.DIR},
		{"t": "", "w": 96, "a": Kit.DIR},
	])
	for tipo in Dados.TROPAS:
		var n_tem: int = int(j["tropas"].get(tipo, 0))
		var porta: Dictionary = Recrutamento.pode_recrutar(state, tipo)
		var liberada: bool = bool(porta["ok"])
		var cel := Kit.linha(tab, Tema.ACENTO_FUNDO if n_tem > 0 else null)
		# a arte da unidade vem por cálculo: "tropa_" + a chave de Dados.TROPAS.
		# Unidade nova no catálogo já nasce com retrato assim que o PNG existir,
		# sem tocar nesta linha.
		Kit.retrato(cel[0], Retratos.textura_tropa(tipo), 32)
		var l_un := Kit.fila(cel[1], Tema.E3)
		Kit.texto(l_un, str(Dados.TROPAS[tipo]["nome"]),
			Tema.TEXTO if liberada else Tema.TEXTO_3)
		if not liberada:
			Kit.selo(l_un, "exige %s" % str(Dados.NIVEIS_TERRA[
				Recrutamento.nivel_exigido(tipo)]["nome"]), Tema.ATENCAO,
				Tema.ATENCAO_FUNDO)
		Kit.numero(cel[2], str(n_tem), Tema.TEXTO if n_tem > 0 else Tema.TEXTO_3)
		Kit.numero(cel[3], str(Dados.TROPAS[tipo]["custo"]), Tema.ACENTO)
		Kit.numero(cel[4], str(Dados.TROPAS[tipo]["manut"]), Tema.TEXTO_2)
		# HOMENS POR DIA, não "0,0 d". Com o treino por lote de cinco, todos
		# os tempos caem abaixo de um dia e a coluna virava uma fileira de
		# zeros. O ritmo responde à pergunta que o jogador de fato faz —
		# "quanto tempo para duzentos arqueiros?" — por divisão simples.
		var por_dia: float = float(Recrutamento.POR_LOTE) \
			* Relogio.MINUTOS_POR_DIA / maxf(1.0, float(Recrutamento.tempo_de(state, tipo)))
		var l_ritmo := Kit.numero(cel[5], "%d/dia" % roundi(por_dia), Tema.TEXTO_2)
		l_ritmo.tooltip_text = "Quantos ficam prontos por dia. 200 deles levariam %s." \
			% Relogio.texto_dias(roundi(200.0 / maxf(1.0, por_dia)) * Relogio.MINUTOS_POR_DIA)
		var b_rec := Kit.botao_mini(cel[6], "Recrutar 5", func():
			var r: Dictionary = Jogo.recrutar(state, tipo, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar(), "fantasma", 92)
		b_rec.disabled = not liberada
		# A FICHA DA UNIDADE na dica: sem ela o jogador escolhia tropa pelo
		# preço, que é o único número que a tabela cabia mostrar. Aqui estão
		# os três valores que decidem a batalha (ataque e as duas defesas),
		# o que ela come, quanta gente ocupa e para que serve.
		var d_un: Dictionary = Dados.TROPAS[tipo]
		var ficha := "%s\n\nAtaque %d · classe %s\nDefesa contra: infantaria %d · cavalaria %d · flecha %d\nCusta %d · soldo %d/mês · come %d de trigo · %d de madeira\nOcupa %d de população · saque %d\n%s" % [
			str(d_un["nome"]), int(d_un["atq"]), _nome_classe(str(d_un["classe"])),
			int(d_un["dg"]), int(d_un["dc"]), int(d_un["da"]),
			int(d_un["custo"]), int(d_un["manut"]), int(d_un["comida"]),
			int(d_un["madeira"]), int(d_un.get("pop", 1)), int(d_un.get("saque", 0)),
			_serve_para(tipo)]
		if not liberada:
			ficha += "\n\n%s" % str(porta["msg"])
		cel[1].tooltip_text = ficha
		b_rec.tooltip_text = ficha

	# ---- fila do quartel ----
	# Sem isto o jogador clica em "Recrutar" e não vê nada mudar, porque a
	# tropa agora leva tempo. A fila É o feedback.
	var fila: Array = Recrutamento.fila(state)
	if not fila.is_empty():
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Na fila do quartel — %s até o último recruta"
			% Relogio.texto_dias(Recrutamento.minutos_restantes(state)))
		var tab_f := Kit.tabela(c, [
			{"t": "", "w": 24, "a": Kit.CENTRO},
			{"t": "", "w": 0},
			{"t": "", "w": 90, "a": Kit.DIR},
			{"t": "", "w": 86, "a": Kit.DIR},
		])
		for i in fila.size():
			var item: Dictionary = fila[i]
			var cel_f := Kit.linha(tab_f)
			var ic_amp := Icones.imagem("ampulheta", 18)
			if ic_amp != null:
				ic_amp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cel_f[0].add_child(ic_amp)
			var col_f := Kit.coluna(cel_f[1], 0)
			Kit.texto(col_f, "%s ×%d" % [
				Dados.TROPAS[item["tipo"]]["nome"], item["restantes"]])
			# BARRA: "3:20" sozinho não diz se falta muito ou pouco — a barra
			# diz de relance, e é o que o quartel sempre quis mostrar
			var total_i: int = maxi(1, Recrutamento.tempo_de(state, str(item["tipo"])))
			var feito_i: int = clampi(total_i - int(item["restante"]), 0, total_i)
			Kit.medidor(col_f, float(feito_i), float(total_i), 150, 5, Tema.ACENTO)
			Kit.numero(cel_f[2], Relogio.texto_dias(int(item["restante"])), Tema.ATENCAO)
			var idx := i
			Kit.botao_mini(cel_f[3], "Cancelar", func():
				var r: Dictionary = Recrutamento.cancelar(state, idx)
				Sfx.tocar(self, "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar(), "perigo", 80)
	# ---- exércitos na estrada ----
	# O jogador precisa VER que mandou gente e quanto falta para o impacto,
	# senão o exército some do inventário e parece bug.
	# DUAS LISTAS, NÃO UMA. `em_transito` devolve todas as colunas do mapa,
	# inclusive as que um rei inimigo despachou CONTRA você: elas apareciam
	# no seu painel de exércitos, com botão de "Recuar" — e o clique
	# cancelava a invasão dele de graça. Agora a origem separa as duas.
	var todas_marchas: Array = Marchas.em_transito(state)
	var transito: Array = todas_marchas.filter(
		func(m): return str(m.get("origem", "jogador")) == "jogador")
	var contra_voce: Array = todas_marchas.filter(
		func(m): return str(m.get("origem", "jogador")) != "jogador")
	if not contra_voce.is_empty():
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Marchando contra você")
		for mi in contra_voce:
			var hi := _card(c, Tema.PERIGO)
			var vi := Kit.coluna(hi, Tema.E2)
			vi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var li := Kit.fila(vi, Tema.E3)
			Kit.icone_valor(li, "tropa", "%d" % int(mi["homens"]), Tema.PERIGO)
			Kit.texto(li, "de %s" % Rotas.nome_do(state, str(mi.get("origem", ""))),
				Tema.PERIGO, Tema.CORPO)
			if str(mi["fase"]) == "cerco":
				Kit.selo(li, "sitiando sua terra", Tema.PERIGO, Tema.PERIGO_FUNDO)
			else:
				Kit.texto(li, "chega em %s" % str(mi["texto_faltam"]),
					Tema.TEXTO_2, Tema.MICRO)
			Kit.nota(vi, "Coluna inimiga. Você não manda nela — só pode estar pronto.")
	if not transito.is_empty():
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Seus exércitos em marcha")
		for mt in transito:
			# a coluna em marcha é o único item da aba que muda sozinho com o
			# relógio; a barra de acento na esquerda é o que a separa das
			# listas estáticas acima sem gastar um cabeçalho por item
			var sitiando: bool = mt["fase"] == "cerco"
			var hm := _card(c, Tema.ATENCAO if sitiando else Tema.ACENTO_FUNDO)
			# acampamento de cerco na linha do exército sitiando: o cerco dura
			# meses fora da tela, e a arte é o que faz ele existir para o jogador
			if sitiando:
				_arte(hm, Retratos.ilustracao("cerco"), 64)
			var vm := Kit.coluna(hm, Tema.E2)
			vm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var rumo: String = ""
			match mt["fase"]:
				"ida": rumo = "→ %s" % Rotas.nome_do(state, mt["alvo"])
				"cerco": rumo = "sitiando %s" % Rotas.nome_do(state, mt["alvo"])
				_: rumo = "← voltando de %s" % Rotas.nome_do(state, mt["alvo"])

			var l1 := Kit.fila(vm, Tema.E3)
			Kit.icone_valor(l1, "tropa", "%d" % int(mt["homens"]), Tema.TEXTO)
			Kit.texto(l1, rumo, Tema.TEXTO, Tema.CORPO)
			if sitiando:
				var pg: Dictionary = mt.get("cerco", {})
				Kit.selo(l1, "fase %d de %d" % [
					int(pg.get("fase", 0)), int(pg.get("de", 6))],
					Tema.ATENCAO, Tema.ATENCAO_FUNDO)
				var reforcos: int = int(pg.get("reforcos", 0))
				if reforcos > 0:
					Kit.selo(l1, "%d intervenção%s" % [reforcos,
						"" if reforcos == 1 else "ões"], Tema.TEXTO_2, Tema.ELEVADO)
				# O CUSTO DO CERCO, em três valores separados.
				#
				# Aqui morava um defeito de leitura que parecia um número: o
				# formato era "gasto %d%d%d", e os três gastos saíam
				# CONCATENADOS — ouro 128, comida 56 e madeira 56 apareciam na
				# tela como "gasto 1285656". Não era um número grande: eram
				# três números sem separador, e nenhum jogador teria como
				# adivinhar isso. Cada um agora tem o seu ícone.
				var l2 := Kit.fila(vm, Tema.E4)
				var gasto: Dictionary = pg.get("gasto", {})
				Kit.icone_valor(l2, "moedas", "%d" % int(gasto.get("ouro", 0)), Tema.ACENTO)
				Kit.icone_valor(l2, "trigo", "%d" % int(gasto.get("comida", 0)), Tema.TEXTO_2)
				Kit.icone_valor(l2, "madeira", "%d" % int(gasto.get("madeira", 0)), Tema.TEXTO_2)
				Kit.nota(l2, "gasto no cerco")
				var moral_c: int = int(pg.get("moral", 0))
				Kit.medidor(l2, float(moral_c), 100.0, 90, 5)
				Kit.texto(l2, "moral %d/100" % moral_c, Tema.TEXTO_3, Tema.MICRO)
			else:
				Kit.selo(l1, str(mt["intencao"]), Tema.TEXTO_2, Tema.ELEVADO)
				Kit.texto(l1, "chega em %s" % str(mt["texto_faltam"]),
					Tema.TEXTO_2, Tema.MICRO)
				if not mt["carga"].is_empty():
					var l_carga := Kit.fila(vm, Tema.E4)
					Kit.nota(l_carga, "carga:")
					for g in mt["carga"]:
						# "ouro" não tem ícone próprio — o símbolo é o das
						# moedas, como o gasto do cerco já faz logo acima
						Kit.icone_valor(l_carga, "moedas" if str(g) == "ouro" else str(g),
							"%d" % int(mt["carga"][g]), Tema.TEXTO_2)
			# a ordem de retirada vale na estrada E no muro: `recolher` tem
			# um ramo dedicado a levantar cerco, escrito porque sem ele a
			# tropa ficava presa pagando upkeep dobrado até a moral quebrar
			# sozinha — e a interface nunca criava o botão para chamá-lo
			if mt["fase"] == "ida" or sitiando:
				var mid: String = mt["id"]
				var acao_m := Kit.fila(hm, Tema.E3)
				acao_m.size_flags_horizontal = Control.SIZE_SHRINK_END
				acao_m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				Kit.botao_mini(acao_m, "Levantar o cerco" if sitiando else "Recuar", func():
					var r: Dictionary = Marchas.recolher(state, mid)
					_aviso(r["msg"])
					Jogo.salvar(state)
					atualizar(), "perigo", 140 if sitiando else 84)

	# ---- enviar exército ----
	# A estimativa de marcha aparece ANTES de decidir: é a informação que
	# transforma "atacar" numa escolha de logística, não num clique.
	if Combate.total_homens(j["tropas"]) > 0:
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Enviar exército")
		Kit.nota(c, "Metade das suas tropas parte. Saque volta rápido com carga; cerco quebra o inimigo.")
		# COMANDANTE: quem lidera muda o que a marcha faz — e é capturado se
		# o exército for obliterado, então escolher é apostar duas coisas
		var escolhido: String = str(j.get("comandante_escolhido", "senhor"))
		var hc := _card(c)
		var atual_cmd: Dictionary = Comandantes.por_id(state, escolhido)
		# o comandante tem CARA: se for um lorde que subiu de cidadão, é o mesmo
		# retrato da Corte; se for contratado, é a arte do mercenário
		_arte(hc, Retratos.textura_comandante(state, atual_cmd), 32)
		var perfil: Dictionary = Comandantes.PERFIS.get(atual_cmd.get("perfil", "senhor"), {})
		var vc := Kit.coluna(hc, 0)
		Kit.texto(vc, str(atual_cmd.get("nome", "—")), Tema.TEXTO)
		Kit.nota(vc, str(perfil.get("desc", "")))
		var opcoes: Array = Comandantes.disponiveis(state)
		if opcoes.size() > 1:
			Kit.botao_mini(hc, "Trocar comandante", func():
				var i := 0
				for k in opcoes.size():
					if str(opcoes[k]["id"]) == escolhido:
						i = k
				state["jogador"]["comandante_escolhido"] = str(opcoes[(i + 1) % opcoes.size()]["id"])
				Jogo.salvar(state)
				atualizar(), "fantasma", 140)
		# a estimativa de marcha aparece ANTES de decidir, e agora em COLUNA:
		# dias e risco são o que se compara entre destinos, e comparar exige
		# que os dois estejam no mesmo x de linha para linha
		# DUAS PERGUNTAS DIFERENTES, DUAS COLUNAS. "Risco" sozinho misturava
		# o perigo da ESTRADA (salteador, que é pior justamente onde não há
		# rei) com a dificuldade do ALVO (guarnição, que é menor justamente
		# onde não há rei). Lidas como uma coisa só, davam a impressão
		# errada: as Terras Bárbaras pareciam mais duras que o Império.
		var tab_m := Kit.tabela(c, [
			{"t": "Destino", "w": 0},
			{"t": "Marcha", "w": 86, "a": Kit.DIR},
			{"t": "Estrada", "w": 92, "a": Kit.DIR},
			{"t": "Defesa", "w": 92, "a": Kit.DIR},
			{"t": "", "w": 150, "a": Kit.DIR},
		])
		for alvo in Rotas.todos_os_nos():
			if alvo == "jogador" or alvo == Barbaros.ID:
				continue
			var metade := {}
			for tipo in j["tropas"]:
				var q: int = int(int(j["tropas"][tipo]) / 2)
				if q > 0:
					metade[tipo] = q
			if metade.is_empty():
				break
			var est: Dictionary = Marchas.estimar(state, alvo, metade)
			var cel_m := Kit.linha(tab_m)
			var v_alvo := Kit.coluna(cel_m[0], 0)
			Kit.texto(v_alvo, Rotas.nome_do(state, alvo))
			Kit.nota(v_alvo, str(est["trajeto"]))
			Kit.numero(cel_m[1], Relogio.texto_dias(int(est["minutos"])), Tema.TEXTO_2)
			var l_est := Kit.texto(cel_m[2], str(est["risco"]),
				Tema.PERIGO if str(est["risco"]).begins_with("alt") else Tema.TEXTO_2,
				Tema.MICRO)
			l_est.tooltip_text = "Chance de emboscada no caminho. Terra sem lei tem estrada pior."
			var def_txt := Marchas.rotulo_de_defesa(state, alvo)
			var l_def := Kit.texto(cel_m[3], def_txt,
				Tema.PERIGO if def_txt.begins_with("mui") or def_txt.begins_with("for")
				else Tema.TEXTO_2, Tema.MICRO)
			l_def.tooltip_text = "O que espera no fim da estrada. Sem rei não há guarnição paga: terra sem trono é a mais fraca do mapa."
			var destino: String = alvo
			var envio: Dictionary = metade
			var cmd_id: String = str(state["jogador"].get("comandante_escolhido", "senhor"))
			Kit.botao_mini(cel_m[4], "Saque", func():
				var r: Dictionary = Marchas.despachar(state, destino, envio, "saque", cmd_id)
				Sfx.tocar(self, "tique" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar(), "fantasma", 68)
			Kit.botao_mini(cel_m[3], "Cerco", func():
				var r: Dictionary = Marchas.despachar(state, destino, envio, "cerco", cmd_id)
				Sfx.tocar(self, "tique" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar(), "fantasma", 68)

	# ---- formação e melhorias ----
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Formação de batalha")
	Kit.nota(c, "Linha vence Cunha, Cunha vence Envolvimento, Envolvimento vence Linha.")
	var hf := Kit.fila(c, Tema.E3)
	# o desenho tático de cada formação, no ícone: escudos na Linha, lança
	# na Cunha, arco no Envolvimento (flanco de atiradores)
	var icone_formacao := {"linha": "escudo", "cunha": "lanca", "cerco": "arco"}
	for f_id in Dados.FORMACOES:
		# a formação ATIVA é um botão primário e as outras são fantasma. O
		# asterisco que marcava a escolhida ("Cunha*") é uma convenção de
		# terminal: num jogo, o estado de um botão é o preenchimento dele.
		var b_f := Kit.botao(hf, str(Dados.FORMACOES[f_id]["nome"]), func():
			j["formacao"] = f_id
			Jogo.salvar(state)
			atualizar(), "primario" if j["formacao"] == f_id else "fantasma", 150)
		_com_icone(b_f, str(icone_formacao.get(f_id, "")))
	# ---- A FERRARIA: aço por HOMEM, não um número do exército ----
	# "Melhorar equipamento" era um botão que subia `equip` de 0 a 3 e
	# valia para todos ao mesmo tempo: duzentos camponeses viravam
	# veteranos junto com a cavalaria. Agora cada leva se equipa sozinha,
	# e a decisão é ONDE gastar o ferro.
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Ferraria")
	Kit.nota(c, "O aço é por homem. Melhorar tira a leva da linha enquanto o ferreiro trabalha — tropa na bigorna não marcha.")
	var fila_f: Array = Equipar.fila(state)
	if not fila_f.is_empty():
		for item in fila_f:
			var h_forja := _card(c, Tema.ATENCAO)
			var vf2 := Kit.coluna(h_forja, 0)
			vf2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			Kit.texto(vf2, "%d %s na bigorna" % [int(item["qtd"]),
				str(Dados.TROPAS[str(item["tipo"])]["nome"]).to_lower()], Tema.ATENCAO)
			Kit.nota(vf2, "Saem em %s, com %s." % [
				Relogio.texto_dias(int(item["restante"])),
				str(Equipar.NIVEIS[mini(int(item["de"]) + 1, Equipar.MAX_NIVEL)]["nome"])])
	var tab_eq := Kit.tabela(c, [
		{"t": "Unidade", "w": 0},
		{"t": "Sem aço", "w": 74, "a": Kit.DIR},
		{"t": "Couro", "w": 74, "a": Kit.DIR},
		{"t": "Malha", "w": 74, "a": Kit.DIR},
		{"t": "Placas", "w": 74, "a": Kit.DIR},
		{"t": "", "w": 210, "a": Kit.DIR},
	])
	for tipo_eq in Dados.TROPAS:
		if int(j["tropas"].get(tipo_eq, 0)) <= 0:
			continue
		var dist: Array = Equipar.distribuicao(state, tipo_eq)
		var cel_eq := Kit.linha(tab_eq)
		Kit.texto(cel_eq[0], str(Dados.TROPAS[tipo_eq]["nome"]))
		for n_eq in range(0, Equipar.MAX_NIVEL + 1):
			Kit.numero(cel_eq[1 + n_eq], str(int(dist[n_eq])),
				Tema.TEXTO if int(dist[n_eq]) > 0 else Tema.TEXTO_3)
		# o degrau oferecido é o MAIS BAIXO que ainda tem gente: é onde o
		# ferro rende mais, e evita uma coluna de cinco botões por linha
		var de_eq := -1
		for n_eq in range(0, Equipar.MAX_NIVEL):
			if int(dist[n_eq]) > 0:
				de_eq = n_eq
				break
		if de_eq < 0:
			Kit.nota(cel_eq[5], "tudo em placas")
			continue
		var lote_eq: int = mini(5, int(dist[de_eq]))
		var preco_eq: int = Equipar.custo(tipo_eq, de_eq, lote_eq)
		var tipo_fix: String = tipo_eq
		var de_fix: int = de_eq
		var lote_fix: int = lote_eq
		var b_eq := Kit.botao_mini(cel_eq[5], "%d → %s · %d" % [lote_eq,
			str(Equipar.NIVEIS[de_eq + 1]["nome"]), preco_eq], func():
			var r: Dictionary = Equipar.encomendar(state, tipo_fix, de_fix, lote_fix)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(str(r["msg"]))
			Jogo.salvar(state)
			atualizar(), "fantasma", 206)
		b_eq.disabled = int(j["ouro"]) < preco_eq
		b_eq.tooltip_text = "Sobe %d homens de %s para %s. Leva %s, e eles ficam fora da linha até acabar." % [
			lote_eq, str(Equipar.NIVEIS[de_eq]["nome"]),
			str(Equipar.NIVEIS[de_eq + 1]["nome"]),
			Relogio.texto_dias(Equipar.minutos(tipo_eq, de_eq, lote_eq))]
	# a guarda de elite saiu daqui: ela não é tropa de campanha, é a
	# guarnição da SUA casa — e agora vive na aba Casa, onde pertence

func _aba_clas(c: Container) -> void:
	Kit.titulo_tela(c, "Clãs Mercenários",
		"Envie um mensageiro com sua oferta; a resposta chega na virada do mês. Oferta generosa convence.")

	# Sem destaque, e pelo mesmo motivo da taverna: contratar clã é uma
	# decisão de ouro contra tempo, não um valor correndo para um teto.
	# O que faltava era o estado da mesa — quantos já servem e quantas
	# ofertas estão no ar, que o jogador só descobria contando os cards.
	var sob_contrato := 0
	var melhor_rel := -100
	for cla_r in Clas.CLAS:
		if not Clas.ativo(state, cla_r["id"]).is_empty():
			sob_contrato += 1
		melhor_rel = maxi(melhor_rel,
			int(state["tags"].get(str(cla_r["id"]), {"relacao": 0})["relacao"]))
	var grupo_cl := Kit.sulco(c, Tema.E4, Tema.E3)
	var fatos_cl := Kit.fila(grupo_cl, Tema.E6)
	Kit.fato(fatos_cl, "tropa", "%d/%d" % [sob_contrato, Clas.CLAS.size()],
		"clãs a soldo", Tema.GANHO if sob_contrato > 0 else Tema.TEXTO,
		"Clã sob contrato marcha com você enquanto o soldo durar.")
	Kit.fato(fatos_cl, "viagem", "%d" % state["mensageiros"].size(),
		"mensageiros na estrada", Tema.ATENCAO if not state["mensageiros"].is_empty() else Tema.TEXTO,
		"Oferta enviada. A resposta chega na virada do mês.")
	Kit.fato(fatos_cl, "moedas", str(int(state["jogador"]["ouro"])), "no cofre",
		Tema.ACENTO, "Clã não fia: a oferta sai do cofre na hora do aceite.")
	Kit.fato(fatos_cl, "alianca", "%d" % melhor_rel, "melhor relação",
		Tema.GANHO if melhor_rel >= 25 else Tema.TEXTO_2,
		"Relação alta baixa o preço que o clã aceita.")

	for cla in Clas.CLAS:
		var contrato := Clas.ativo(state, cla["id"])
		var pendente := false
		for m in state["mensageiros"]:
			if m["cla"] == cla["id"]:
				pendente = true
		var h := _card(c, Tema.GANHO if not contrato.is_empty() else null)
		_retrato(h, cla["id"], 32)
		var v := Kit.coluna(h, Tema.E2)
		var rel: int = state["tags"].get(cla["id"], {"relacao": 0})["relacao"]

		var l1 := Kit.fila(v, Tema.E3)
		var nome_c := Kit.texto(l1, str(cla["nome"]), Tema.TEXTO, Tema.CORPO_G)
		var f_c := Tema.fonte_forte()
		if f_c != null:
			nome_c.add_theme_font_override("font", f_c)
		Kit.texto(l1, str(cla["lider"]), Tema.TEXTO_3, Tema.MICRO)
		Kit.medidor(l1, float(rel + 100), 200.0, 70, 5,
			Tema.PERIGO if rel <= -25 else (Tema.GANHO if rel >= 25 else Tema.TEXTO_3))
		Kit.texto(l1, Dialogo.nome_relacao(rel), Tema.TEXTO_3, Tema.MICRO)
		if not contrato.is_empty():
			Kit.selo(l1, "sob contrato · %d meses" % int(contrato["meses"]),
				Tema.GANHO, Tema.GANHO_FUNDO)
		elif pendente:
			Kit.selo(l1, "mensageiro na estrada", Tema.ATENCAO, Tema.ATENCAO_FUNDO)

		# o que o clã TRAZ e o que ele PEDE, separados: era tudo uma frase só
		var l2 := Kit.fila(v, Tema.E4)
		Kit.texto(l2, _texto_contingente(cla["contingente"]), Tema.TEXTO_2, Tema.MICRO)
		Kit.icone_valor(l2, "moedas", "~%d" % int(cla["preco_base"]), Tema.ACENTO)
		Kit.texto(l2, "+%d/mês" % int(cla["soldo"]), Tema.TEXTO_2, Tema.MICRO)
		Kit.icone_valor(l2, "renome", "%d" % int(cla["renome_min"]),
			Tema.PERIGO if int(state["jogador"]["renome"]) < int(cla["renome_min"])
				else Tema.TEXTO_2)

		if contrato.is_empty() and not pendente:
			var linha := Kit.fila(h, Tema.E3)
			linha.size_flags_horizontal = Control.SIZE_SHRINK_END
			linha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var oferta := SpinBox.new()
			oferta.min_value = 50
			oferta.max_value = 5000
			oferta.step = 50
			oferta.value = cla["preco_base"]
			oferta.custom_minimum_size = Vector2(96, 0)
			linha.add_child(oferta)
			Kit.botao_mini(linha, "Enviar mensageiro · 10", func():
				var r: Dictionary = Clas.enviar_mensageiro(state, cla["id"], int(oferta.value))
				Sfx.tocar(self, "pagina" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar(), "fantasma", 168)

	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Cartas recebidas")
	if state["cartas"].is_empty():
		Kit.nota(c, "Nenhuma carta sobre a mesa.")
	for carta in state["cartas"].slice(0, 6):
		var hc := Kit.fila(_card(c), Tema.E3)
		var ic_carta := Icones.imagem("carta", 18)
		if ic_carta != null:
			ic_carta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hc.add_child(ic_carta)
		Kit.texto(hc, str(carta), Tema.TEXTO_2, Tema.MICRO)

func _aba_intrigas(c: Container) -> void:
	Kit.titulo_tela(c, "Mesa de Intrigas",
		"Segredo é moeda: o que se sabe de um rei vale mais que o que se toma dele.")

	# O que a mesa tem em caixa. Segredo GUARDADO é a única moeda que ela
	# aceita, e o jogador contava os cards para saber quantos ainda valiam.
	var por_usar := 0
	for seg_c in state["segredos"]:
		if not bool(seg_c.get("usado", false)):
			por_usar += 1
	var grupo_i := Kit.sulco(c, Tema.E4, Tema.E3)
	var fatos_i := Kit.fila(grupo_i, Tema.E6)
	Kit.fato(fatos_i, "pergaminho", "%d" % por_usar, "segredos por gastar",
		Tema.ACENTO if por_usar > 0 else Tema.TEXTO_3,
		"Cada um vale uma chantagem — ouro, casamento forçado ou casus belli. Só serve uma vez.")
	Kit.fato(fatos_i, "guerra", "%d" % state["casus_belli"].size(),
		"casus belli na mão", Tema.ATENCAO if not state["casus_belli"].is_empty() else Tema.TEXTO,
		"Pretexto de guerra. Sem ele, declarar guerra derruba honra e assusta as outras cortes.")
	Kit.fato(fatos_i, "carisma", str(int(state["jogador"]["atributos"].get("carisma", 5))),
		"de carisma", Tema.TEXTO,
		"Decide se o espião volta com o segredo ou volta com a cabeça na cesta.")
	Kit.fato(fatos_i, "honra", str(int(state["jogador"].get("honra", 50))), "de honra",
		Tema.PERIGO if int(state["jogador"].get("honra", 50)) <= 25 else Tema.TEXTO,
		"Toda intriga descoberta cobra aqui.")

	if state["chantagem_pendente"] != null:
		var cb_card := Kit.card(c, Tema.ATENCAO)
		Kit.texto(cb_card, "Chantagem em curso — escolha sua exigência:", Tema.ATENCAO)
		var hb := Kit.fila(cb_card, Tema.E3)
		for par in [["ouro", "Ouro"], ["casamento", "Casamento forçado"],
				["casusbelli", "Casus Belli"]]:
			_botao(hb, par[1], func():
				Intriga.resolver_chantagem(state, par[0])
				Jogo.salvar(state)
				atualizar())

	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Segredos que você guarda")
	if state["segredos"].is_empty():
		Kit.nota(c, "Nenhum. Mande espiões às cortes.")
	for seg in state["segredos"]:
		var hs := Kit.fila(_card(c, null if seg["usado"] else Tema.ACENTO_FUNDO), Tema.E3)
		var ic_s := Icones.imagem("pergaminho", 18)
		if ic_s != null:
			ic_s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hs.add_child(ic_s)
		Kit.texto(hs, str(seg["reino"]))
		if seg["usado"]:
			Kit.selo(hs, "usado", Tema.TEXTO_3, Tema.ELEVADO)
		else:
			Kit.texto(hs, "chantageie o rei em conversa", Tema.TEXTO_3, Tema.MICRO)

	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Operações")
	# CASUS BELLI EXPLICADO onde ele é fabricado. O termo aparecia como
	# selo e como nome de botão, e em lugar nenhum dizia o que era.
	Kit.nota(c, "CASUS BELLI é o PRETEXTO para atacar sem virar pária: um documento que prova direito antigo sobre a terra do outro.")
	Kit.nota(c, "Com ele, os outros cinco reinos aceitam o seu ataque como reivindicação. Sem ele, atacar é agressão: −60 de relação com o atacado e −35 com TODOS os outros.")
	var tab := Kit.tabela(c, [
		{"t": "", "w": 24, "a": Kit.CENTRO},
		{"t": "", "w": 0},
		{"t": "", "w": 260, "a": Kit.DIR},
	])
	for reino in state["reinos"]:
		if state["jogador"]["rei_de"] == reino["id"]:
			continue
		var tem_cb: bool = state["casus_belli"].has(reino["id"])
		var cel := Kit.linha(tab)
		var ic_op := Icones.imagem("espiao", 18)
		if ic_op != null:
			ic_op.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cel[0].add_child(ic_op)
		var l_nome := Kit.fila(cel[1], Tema.E3)
		Kit.texto(l_nome, str(reino["nome"]))
		if tem_cb:
			# "CB" colado no nome do reino ("Império CentralCB") era uma
			# abreviação que só quem escreveu o código entendia
			Kit.selo(l_nome, "casus belli", Color("e8917a"), Tema.PERIGO_FUNDO)
		Kit.botao_mini(cel[2], "Espionar · 80", func():
			var r_esp: Dictionary = Intriga.espionar(state, reino["id"])
			if int(r_esp.get("prender", 0)) > 0:
				Jogo.prender(state, int(r_esp["prender"]), Jogo.log_para(state))
			Jogo.salvar(state)
			_modal_operacao(r_esp), "fantasma", 104)
		if not tem_cb:
			Kit.botao_mini(cel[2], "Forjar casus belli · 150", func():
				var r_fj: Dictionary = Intriga.forjar_documento(state, reino["id"])
				Jogo.salvar(state)
				_modal_operacao(r_fj), "fantasma", 176)

## Os quatro atributos, com ícone e medidor.
##
## Eram quatro números crus separados por espaço ("8 5 6 4"), sem rótulo
## nenhum: o jogador tinha que saber de cor que o terceiro é gestão. Com
## ícone e barra, a ficha do herdeiro é lida sem legenda.
const ATRIBUTOS := [["forca", "Força"], ["carisma", "Carisma"],
	["gestao", "Gestão"], ["intriga", "Intriga"]]

func _ficha_atributos(c: Container, a: Dictionary) -> void:
	var h := Kit.fila(c, Tema.E5)
	for par in ATRIBUTOS:
		var bloco := VBoxContainer.new()
		bloco.add_theme_constant_override("separation", Tema.E1)
		bloco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(bloco)
		var topo := Kit.fila(bloco, Tema.E2)
		var ic := Icones.imagem(str(par[0]), 16)
		if ic != null:
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			topo.add_child(ic)
		var rot := Kit.texto(topo, str(par[1]), Tema.TEXTO_3, Tema.MINI)
		rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.numero(topo, str(int(a[par[0]])), Tema.TEXTO, Tema.MICRO + 1)
		Kit.medidor(bloco, float(int(a[par[0]])), 10.0, 0, 4, Tema.TEXTO_2)

func _aba_familia(c: Container) -> void:
	var f: Dictionary = state["familia"]
	var j: Dictionary = state["jogador"]
	Kit.titulo_tela(c, "Sua Casa")

	# ---- O NÚMERO DA CASA: a chance de não ver o ano que vem ----
	#
	# Este jogo termina quando o jogador morre, e a idade estava escrita como
	# apoio de um retrato ("22 anos · Conde"), no tamanho de uma legenda.
	#
	# O que vai na manchete NÃO é a idade: é o RISCO que ela carrega, porque
	# é ele que muda de verdade. `Jogo._envelhecer` rola 4% ao ano depois dos
	# 45, 10% depois dos 55 e 25% depois dos 65 — três degraus que ninguém
	# via chegar. Uma barra de idade contra um teto fixo mentiria duas vezes:
	# ficaria cheia antes da hora e estouraria depois dela.
	var idade_j: int = int(j["idade"])
	var risco_ano: int = 25 if idade_j > 65 else (10 if idade_j > 55
		else (4 if idade_j > 45 else 0))
	var grupo_h := Kit.sulco(c, Tema.E4, Tema.E3)
	var herdeiros: int = (f["filhos"] as Array).size()
	# Mesma regra do mapa: manchete só quando há manchete. Aos 22 anos o
	# risco é ZERO, e um "0 / 100" de barra vazia gastaria noventa pixels
	# para não dizer nada — que é o defeito que esta rodada veio corrigir,
	# só que ao contrário.
	if risco_ano > 0:
		var glosa_h := "A cada virada de ano o dado é lançado. "
		glosa_h += "A casa tem quem herde." if herdeiros > 0 else \
			"E sem herdeiro, a sua morte encerra a casa e tudo que ela juntou."
		Kit.destaque(grupo_h, "Risco de morrer este ano", risco_ano, 100,
			Tema.cor_de_saude(1.0 - float(risco_ano) / 30.0),
			glosa_h, "casa_risco")
	var fatos_h := Kit.fila(grupo_h, Tema.E6)
	Kit.fato(fatos_h, "ampulheta", "%d" % idade_j, "anos", Tema.TEXTO,
		"Aos 46 o risco vira 4% ao ano; aos 56, 10%; aos 66, 25%.")
	Kit.fato(fatos_h, "familia", "%d" % herdeiros, "filhos",
		Tema.GANHO if herdeiros > 0 else Tema.PERIGO,
		"Aos 8 anos cada um é educado no seu atributo mais forte.")
	Kit.fato(fatos_h, "renome", str(int(j["renome"])), "de renome", Tema.TEXTO,
		"O que a casa vale aos olhos do continente.")
	Kit.fato(fatos_h, "caveira", "%d" % int(j.get("crueldade", 0)), "de crueldade",
		Tema.PERIGO if int(j.get("crueldade", 0)) >= 3 else Tema.TEXTO,
		"Seis meses de povo contente (felicidade 65+) apagam um ponto.")

	var colunas := Kit.duas_colunas(c, 0.5)
	var esq: VBoxContainer = colunas[0]
	var dir: VBoxContainer = colunas[1]

	var meu := Kit.card(esq)
	var l_eu := Kit.fila(meu, Tema.E3)
	Kit.retrato(l_eu, Retratos.textura_cidadao(
		{"nome": str(j["nome"]), "oficio": "senhor", "riqueza": 500,
		"genero": "m", "lealdade": 60, "lorde": true}, true,
		Retratos.fundo_da_casa(state)), 32)
	var v_eu := Kit.coluna(l_eu, 0)
	Kit.texto(v_eu, str(j["nome"]), Tema.TEXTO, Tema.CORPO_G)
	Kit.nota(v_eu, "%d anos · %s" % [int(j["idade"]), Contratos.titulo(state)])
	if int(j.get("crueldade", 0)) >= 3:
		Kit.selo(l_eu, "reputação de crueldade", Color("e8917a"), Tema.PERIGO_FUNDO)
	_ficha_atributos(meu, j["atributos"])

	var casa := Kit.card(dir)
	Kit.subsecao(casa, "Casamento")
	if f["conjuge"] != null:
		var cj: Dictionary = f["conjuge"]
		var lc := Kit.fila(casa, Tema.E3)
		# a leva ilustrada primeiro: plebeia leva o retrato do salão onde
		# foi cortejada, nobre leva o herdeiro real da casa de origem. O
		# procedural fica de reserva — com o fundo do reino DE ORIGEM,
		# porque a aliança é justamente o que a heráldica tem que mostrar
		var id_cj := Retratos.id_conjuge(cj)
		Kit.retrato(lc, Retratos.textura_pequena(id_cj) if id_cj != ""
			else Retratos.textura_cidadao(
				{"nome": str(cj["nome"]), "oficio": "senhor", "riqueza": 500,
				"genero": str(cj.get("genero", "f")), "lealdade": 60, "lorde": true},
				true, str(Retratos.REIS.get("rei_" + str(cj.get("reino", "")), {}).get("fundo", ""))), 32)
		Kit.texto(lc, "Casado com %s" % str(cj["nome"]))
		if cj["forcado"]:
			Kit.selo(lc, "união sob pressão", Tema.ATENCAO, Tema.ATENCAO_FUNDO)
	else:
		Kit.texto(casa, "Solteiro.", Tema.TEXTO)
		# as DUAS portas do altar, senão a ficha esconde metade do jogo: a
		# nobre pela corte, a plebeia pelo salão da taverna (Bloco I)
		Kit.nota(casa, "Casamento real exige 40+ de renome e boa relação — peça a mão em conversa na corte.")
		Kit.nota(casa, "Sem coroa ao alcance, corteje uma moça no salão da taverna: casa plebeia, mas o ofício dela vem junto.")

	# ---- A GUARDA DA CASA ----
	# Ela morava na aba Tropas, entre "melhorar equipamento" e "contratar",
	# como se fosse exército — e o jogador não tinha como saber que estes
	# homens NÃO marcham. Aqui, na Casa, a função fica óbvia: são os que
	# ficam. E agora eles lutam de verdade: entram na guarnição quando uma
	# coluna inimiga chega à sua terra, valendo dois espadachins cada.
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Guarda da casa")
	var card_g := _card(c)
	var ic_g := Icones.imagem("escudo", 32)
	if ic_g != null:
		ic_g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_g.add_child(ic_g)
	var vg := Kit.coluna(card_g, 0)
	vg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n_guardas: int = int(j.get("guardas", 0))
	Kit.texto(vg, "%d guardas de elite" % n_guardas,
		Tema.TEXTO if n_guardas > 0 else Tema.TEXTO_3)
	Kit.nota(vg, "Nunca marcham. Defendem a sua terra quando alguém vem tomá-la — cada um vale dois espadachins no muro.")
	if n_guardas > 0:
		Kit.nota(vg, "Cuidado: guarda mal paga é guarda que escuta ofertas. Com a moral no chão, eles abrem o portão.")
	var acao_g := Kit.fila(card_g, Tema.E3)
	acao_g.size_flags_horizontal = Control.SIZE_SHRINK_END
	acao_g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.icone_valor(acao_g, "moedas", "120", Tema.ACENTO)
	var b_g := Kit.botao_mini(acao_g, "Contratar 2", func():
		var r: Dictionary = Jogo.contratar_guardas(state, 2)
		Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
		_aviso(str(r["msg"]))
		Jogo.salvar(state)
		atualizar(), "fantasma", 120)
	b_g.disabled = int(j["ouro"]) < 120

	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Herdeiros")
	if f["filhos"].is_empty():
		Kit.texto(Kit.card(c, Tema.PERIGO),
			"Nenhum filho. Sem herdeiro, sua morte é o fim da linhagem — e do jogo.",
			Tema.PERIGO)
	for filho in f["filhos"]:
		var apto: bool = int(filho["idade"]) >= 16
		var card := Kit.card(c, Tema.GANHO if apto else null)
		var lf := Kit.fila(card, Tema.E3)
		# bebê, criança e jovem têm cara própria na leva do Bloco II
		var id_f := Retratos.id_filho(filho)
		Kit.retrato(lf, Retratos.textura_pequena(id_f) if id_f != ""
			else Retratos.textura_cidadao(
				{"nome": str(filho["nome"]), "oficio": "herdeiro", "riqueza": 400,
				"genero": str(filho.get("genero", "m")), "lealdade": 60}, true,
				Retratos.fundo_da_casa(state)), 32)
		var vf := Kit.coluna(lf, 0)
		Kit.texto(vf, str(filho["nome"]))
		Kit.nota(vf, "%d anos" % int(filho["idade"]))
		if apto:
			Kit.selo(lf, "herdeiro apto", Tema.GANHO, Tema.GANHO_FUNDO)
		if filho.get("mimado", false):
			Kit.selo(lf, "mimado · vassalos conspirarão", Color("e8917a"),
				Tema.PERIGO_FUNDO)
		_ficha_atributos(card, filho["atributos"])

## A CRÔNICA — o diário da casa.
##
## Era uma pilha de linhas idênticas ("Mar/A1 — texto"), sem separação entre
## meses e sem nada que distinguisse "nasceu um herdeiro" de "o preço do
## trigo subiu". Aqui a data vira uma coluna própria na monoespaçada — o que
## faz as entradas do mesmo mês se agruparem sozinhas aos olhos — e a mais
## recente vem PRIMEIRO, que é a que o jogador abriu a aba para ler.
## A ABA GUERRAS — o mapa político num lugar só.
##
## As guerras viviam soltas: uma linha no Mapa, outra na Crônica, e a
## vassalagem num card que só aparecia quando você rolava até ele. Aqui
## fica a pergunta que o jogador faz toda virada de mês — quem luta contra
## quem, de que lado eu estou, e o que essa casa me deve.
func _aba_guerras(c: Container) -> void:
	Kit.titulo_tela(c, "Guerras e Juramentos",
		"Quem sangra com quem — e o que a sua palavra vale hoje.")

	# ---- as SUAS guerras primeiro: é a linha que decide o seu mês ----
	var minhas: Array = state["guerras"].filter(func(g):
		return str(g["a"]) == "jogador" or str(g["b"]) == "jogador")

	# O placar da mesa, antes dos cards. Sem destaque: a guerra não tem um
	# par valor/teto — o que ela tem é DURAÇÃO, e a mais longa é o número
	# que diz se o continente está se estabilizando ou se afundando.
	var mais_longa := 0
	for g_l in state["guerras"]:
		mais_longa = maxi(mais_longa, int(g_l["meses"]))
	var grupo_g := Kit.sulco(c, Tema.E4, Tema.E3)
	var fatos_g := Kit.fila(grupo_g, Tema.E6)
	Kit.fato(fatos_g, "espada", "%d" % minhas.size(), "guerras suas",
		Tema.PERIGO if not minhas.is_empty() else Tema.GANHO,
		"Cada uma é uma rolagem de emboscada por dia, onde quer que você esteja.")
	Kit.fato(fatos_g, "guerra", "%d" % (state["guerras"].size() - minhas.size()),
		"guerras alheias", Tema.TEXTO,
		"Guerra dos outros encarece o trigo e enche o mural de contratos.")
	Kit.fato(fatos_g, "ampulheta", "%d" % mais_longa, "meses, a mais longa",
		Tema.ATENCAO if mais_longa >= 12 else Tema.TEXTO,
		"Guerra longa esgota os dois lados — e abre a porta para um terceiro.")
	var vs_g: Dictionary = Vassalagem.resumo(state)
	Kit.fato(fatos_g, "vassalo",
		"%d" % (int(vs_g.get("meses", 0)) if bool(vs_g.get("vassalo", false)) else 0),
		"meses de juramento",
		Tema.ATENCAO if bool(vs_g.get("vassalo", false)) else Tema.TEXTO,
		"Enquanto o juramento vale, o suserano não marcha contra você — e leva um quinto do seu ouro.")
	if not minhas.is_empty():
		Kit.subsecao(c, "Você está em guerra")
		for g in minhas:
			var inimigo: String = str(g["b"]) if str(g["a"]) == "jogador" else str(g["a"])
			var h := _card(c, Tema.PERIGO)
			Kit.retrato(h, Retratos.textura("rei_" + inimigo), 48)
			var v := Kit.coluna(h, 0)
			v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			Kit.texto(v, "Contra %s" % Rotas.nome_do(state, inimigo), Tema.PERIGO)
			Kit.nota(v, "%d %s de guerra. Marchas dele podem cair sobre a sua terra." % [
				int(g["meses"]), "mês" if int(g["meses"]) == 1 else "meses"])
	else:
		Kit.nota(c, "Ninguém marcha contra você. Por enquanto.")

	# ---- as guerras dos outros: onde o contrato fica caro e o trigo, raro ----
	var alheias: Array = state["guerras"].filter(func(g):
		return str(g["a"]) != "jogador" and str(g["b"]) != "jogador")
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "O resto do mapa")
	if alheias.is_empty():
		Kit.nota(c, "Os reinos estão em paz. É quando o trigo fica barato e o mercenário, ocioso.")
	else:
		var tab := Kit.tabela(c, [
			{"t": "Guerra", "w": 0},
			{"t": "Meses", "w": 76, "a": Kit.DIR},
			{"t": "O que muda", "w": 260},
		])
		for g in alheias:
			var cel := Kit.linha(tab)
			var ic_g := Icones.imagem("guerra", 16)
			if ic_g != null:
				ic_g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cel[0].add_child(ic_g)
			Kit.texto(cel[0], "%s × %s" % [Rotas.nome_do(state, str(g["a"])),
				Rotas.nome_do(state, str(g["b"]))])
			Kit.numero(cel[1], str(int(g["meses"])), Tema.ATENCAO)
			Kit.nota(cel[2], "Trigo escasso dos dois lados; contratos de fronteira pagam mais.")

	# ---- casus belli: a licença de atacar sem manchar o nome ----
	var cb: Array = state.get("casus_belli", [])
	if not cb.is_empty():
		Kit.respiro(c, Tema.E2)
		Kit.subsecao(c, "Pretextos de guerra")
		var linha_cb := Kit.fila(c, Tema.E3)
		for id_cb in cb:
			Kit.selo(linha_cb, Rotas.nome_do(state, str(id_cb)), Tema.ACENTO, Tema.ACENTO_FUNDO)
		Kit.nota(c, "Contra estes você pode marchar sem que o mapa inteiro te chame de bandido.")

	# ---- o juramento: a escada da casa a que você serve ----
	Kit.respiro(c, Tema.E2)
	Kit.subsecao(c, "Seu juramento")
	var vs: Dictionary = Vassalagem.resumo(state)
	if not bool(vs.get("vassalo", false)):
		Kit.nota(c, "Você não deve joelho a ninguém. Também não há quem mande soldo ou lanças quando a terra queimar.")
		Kit.nota(c, "Juramento se faz em pessoa, na corte do rei: viaje até a capital dele e diga que quer servir.")
		return
	var hj := _card(c, Tema.ACENTO)
	Kit.retrato(hj, Retratos.textura("rei_" + str(vs["suserano"])), 48)
	var vj := Kit.coluna(hj, 0)
	vj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l_cargo := Kit.fila(vj, Tema.E3)
	var ic_v := Icones.imagem("vassalo", 20)
	if ic_v != null:
		ic_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l_cargo.add_child(ic_v)
	Kit.texto(l_cargo, "%s de %s" % [str(vs["cargo"]), str(vs["nome"])], Tema.ACENTO)
	Kit.texto(l_cargo, "%d meses de serviço" % int(vs["meses"]), Tema.TEXTO_3, Tema.MICRO)
	var l_trib := Kit.fila(vj, Tema.E2)
	var ic_t := Icones.imagem("tributo", 16)
	if ic_t != null:
		ic_t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l_trib.add_child(ic_t)
	Kit.texto(l_trib, "Tributo estimado do mês: %d de ouro." % int(vs["tributo_estimado"]),
		Tema.TEXTO_3, Tema.MICRO)
	if int(vs["soldo"]) > 0:
		Kit.nota(vj, "A casa te paga %d de ouro por mês%s." % [int(vs["soldo"]),
			" e manda %d lanceiros a cada meia dúzia de meses" % int(vs["tropas_lote"])
			if int(vs["tropas_lote"]) > 0 else ""])
	else:
		Kit.nota(vj, "Juramentado raso: ainda não há soldo. Sirva e a casa reconhece.")
	if str(vs.get("proximo_cargo", "")) != "":
		Kit.nota(c, "Próximo degrau: %s — %d meses de serviço e relação %d." % [
			str(vs["proximo_cargo"]), int(vs["proximo_meses"]), int(vs["proximo_relacao"])])

func _aba_cronica(c: Container) -> void:
	Kit.titulo_tela(c, "Crônica da Casa", "A mais recente no alto.")
	if state["cronica"].is_empty():
		Kit.nota(c, "Nada digno de registro. Ainda.")
		return
	var tab := Kit.tabela(c, [
		{"t": "", "w": 76},
		{"t": "", "w": 0},
	])
	# a crônica JÁ vem mais-recente-primeiro (log_para usa push_front) — o
	# reverse() que morava aqui desfazia a ordem certa e contradizia o
	# subtítulo impresso logo acima
	for entrada in state["cronica"]:
		var cel := Kit.linha(tab)
		Kit.numero(cel[0], "%s/A%d" % [
			MESES[entrada["mes"] - 1].substr(0, 3), entrada["ano"]],
			Tema.TEXTO_3, Tema.MICRO)
		Kit.texto(cel[1], str(entrada["msg"]), Tema.TEXTO_2, Tema.MICRO)

## O reino onde o jogador está — ou VAZIO, quando ele não está em nenhum.
##
## Esta função devolvia `state["reinos"][0]` no caso de não achar, e esse
## fallback silencioso era o furo mais grave do jogo. Ele não falhava: ele
## MENTIA, e devolvia o Império Central com a cara de "o lugar onde você
## está". Nas Terras Bárbaras e no Reino sem Rei — que não são reinos e não
## têm trono — a aba Corte então abria a corte imperial e entregava a
## conversa com Felippe. Dali dava para chantageá-lo, subornar o portão
## dele, casar na casa dele e mediar a paz dele, do meio da estepe.
##
## A diplomacia deste jogo é PRESENCIAL em todo o resto — juramento, assalto
## ao trono, contrato, emprego e mercado exigem estar lá. A corte era a única
## porta que não exigia, e exatamente por acidente.
##
## Devolver vazio obriga quem chama a decidir o que fazer, que é o certo:
## são três chamadores, e cada um tem uma resposta diferente para "não há
## reino aqui".
func _reino_local() -> Dictionary:
	for r in state["reinos"]:
		if r["id"] == state["local"]:
			return r
	return {}

# ---------------- CONVERSA (ponderar + máquina de escrever) ----------------
# ---------------- CONVERSA ----------------
#
# Esta é a peça central do jogo — o NPC entende texto livre e LEMBRA — e era
# a tela mais vazia dele: um quadrado cinza de 96px, uma linha de texto, 380
# pixels de nada, e um campo colado no rodapé. Medido na imagem renderizada:
# 70% da altura era vazio.
#
# O que ela ganha aqui:
#   · o RETRATO existe (é o mesmo gerador da Corte, em 128 = 2× o nativo,
#     sem redução fracionária), com moldura;
#   · a relação vira MEDIDOR, ao lado do nome, em vez de "(Neutro 0)";
#   · o histórico ganha painel próprio, margem interna e espaçamento de
#     parágrafo — é onde a conversa acontece, e ele passa a parecer uma
#     página em vez de um Label solto;
#   · a coluna do meio fica ESTREITA (620px) e centrada. Linha de dez
#     palavras se lê; linha de trinta, não. Era o vício que fazia a tela
#     parecer terminal.
func _montar_conversa() -> void:
	overlay_conversa = PanelContainer.new()
	overlay_conversa.set_anchors_preset(Control.PRESET_FULL_RECT)
	# fundo sólido: sem ele a aba continuaria aparecendo por trás da conversa
	var sb_fundo := StyleBoxFlat.new()
	sb_fundo.bg_color = Tema.FUNDO
	sb_fundo.set_corner_radius_all(0)
	# o mesmo recuo que a tela_jogo usa sob a moldura de pedra: com E5 o
	# retrato do NPC ficava com a borda enterrada embaixo da cantaria
	sb_fundo.set_content_margin_all(22 if Tema.tex_hibit("ui_moldura_pedra") != null else Tema.E5)
	overlay_conversa.add_theme_stylebox_override("panel", sb_fundo)
	add_child(overlay_conversa)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E4)
	overlay_conversa.add_child(v)

	# ---- cabeça: retrato, nome, medidor de relação, saída ----
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", Tema.E5)
	v.add_child(cab)
	# a MESMA moldura de madeira da ilustração da Terra. Aqui ela vale
	# ainda mais: a conversa é a tela em que só existem duas coisas — o
	# rosto e o que se diz a ele —, e o rosto estava num retângulo de 1px.
	var moldura := Kit.moldura_arte(cab)
	moldura.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	conversa_retrato = TextureRect.new()
	# 128 = 2× o nativo de 64. Fator inteiro: nenhum pixel do retrato é
	# interpolado nem descartado.
	conversa_retrato.custom_minimum_size = Vector2(128, 128)
	conversa_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	conversa_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	conversa_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moldura.add_child(conversa_retrato)

	var v_cab := VBoxContainer.new()
	v_cab.add_theme_constant_override("separation", Tema.E3)
	v_cab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_cab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(v_cab)
	conversa_titulo = Label.new()
	# nome de quem está na sua frente = nome de LUGAR na gramática desta
	# interface: é a resposta para "onde estou". Vai na capitular, no
	# tamanho de título de tela.
	conversa_titulo.add_theme_font_size_override("font_size", Tema.TITULO_TELA - 4)
	conversa_titulo.add_theme_color_override("font_color", Tema.ACENTO)
	var f_conv := Tema.fonte_titulo()
	if f_conv != null:
		conversa_titulo.add_theme_font_override("font", f_conv)
	v_cab.add_child(conversa_titulo)
	conversa_relacao = HBoxContainer.new()
	conversa_relacao.add_theme_constant_override("separation", Tema.E3)
	v_cab.add_child(conversa_relacao)
	var l_dica := Label.new()
	l_dica.text = "Elogie, insulte, ameace, proponha casamento, chantageie, negocie a paz. Ele lembra."
	l_dica.add_theme_font_size_override("font_size", Tema.MINI)
	l_dica.add_theme_color_override("font_color", Tema.TEXTO_3)
	l_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v_cab.add_child(l_dica)
	var v_sair := VBoxContainer.new()
	v_sair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(v_sair)
	Kit.botao(v_sair, "← Sair da conversa", fechar_conversa, "fantasma")

	v.add_child(Kit.regua(Tema.BORDA))

	# ---- o histórico, na coluna estreita ----
	var centro := HBoxContainer.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(centro)
	var pagina := PanelContainer.new()
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = Tema.SUPERFICIE
	sb_p.border_color = Tema.HAIRLINE
	sb_p.set_border_width_all(1)
	sb_p.set_corner_radius_all(0)
	sb_p.set_content_margin_all(Tema.E5)
	pagina.add_theme_stylebox_override("panel", sb_p)
	pagina.custom_minimum_size = Vector2(620, 0)
	pagina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_child(pagina)
	conversa_hist = RichTextLabel.new()
	conversa_hist.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conversa_hist.scroll_following = true
	conversa_hist.bbcode_enabled = true
	conversa_hist.add_theme_constant_override("line_separation", 3)
	conversa_hist.add_theme_color_override("default_color", Tema.TEXTO)
	pagina.add_child(conversa_hist)

	# ---- a fala, alinhada com a coluna do histórico ----
	var centro_form := HBoxContainer.new()
	centro_form.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(centro_form)
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", Tema.E3)
	form.custom_minimum_size = Vector2(620, 0)
	centro_form.add_child(form)
	conversa_input = LineEdit.new()
	conversa_input.placeholder_text = "Diga o que quiser..."
	conversa_input.max_length = 200
	conversa_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversa_input.text_submitted.connect(func(_t): enviar_texto(conversa_input.text))
	form.add_child(conversa_input)
	Kit.botao(form, "Falar", func(): enviar_texto(conversa_input.text),
		"primario", 100)

func abrir_conversa(npc: Dictionary) -> void:
	conversa_geracao += 1
	digitando = false
	conversa_turnos = []
	npc_atual = npc
	overlay_conversa.visible = true
	conversa_texto = "[color=#7a6b58][i]%s aguarda você falar...[/i][/color]\n\n" % npc["nome"]
	conversa_hist.text = conversa_texto
	_atualizar_cab_conversa()
	conversa_input.grab_focus()

func fechar_conversa() -> void:
	conversa_geracao += 1
	digitando = false
	overlay_conversa.visible = false
	npc_atual = {}
	atualizar()

func _atualizar_cab_conversa() -> void:
	if npc_atual.is_empty():
		return
	var rel: int = state["tags"].get(npc_atual["id"], {"relacao": 0})["relacao"]
	conversa_titulo.text = str(npc_atual["nome"])
	# a relação como MEDIDOR: "(Neutro 0)" obriga a saber que a escala vai de
	# −100 a +100 e onde ficam os limiares. A barra mostra os dois lados e a
	# cor muda onde a mecânica muda.
	for filho in conversa_relacao.get_children():
		filho.queue_free()
	var cor := Tema.PERIGO if rel <= -25 else (Tema.GANHO if rel >= 25 else Tema.TEXTO_3)
	Kit.medidor(conversa_relacao, float(rel + 100), 200.0, 140, 6, cor)
	Kit.texto(conversa_relacao, "%s (%d)" % [Dialogo.nome_relacao(rel), rel],
		cor, Tema.MICRO)
	# o retrato muda de expressão com a relação: é o mesmo `humor` que a
	# Corte usa, e é o único traço que muda para o mesmo personagem.
	# O ROSTO vem de `_id_retrato` e o HUMOR do `id`: quem fala pode ser o
	# guarda, mas a simpatia que ele demonstra é a da casa.
	conversa_retrato.texture = Retratos.textura(_id_retrato(npc_atual),
		Retratos.humor_de(state, str(npc_atual["id"])))

func enviar_texto(texto: String) -> void:
	# emoji do teclado do celular viraria tofu na fonte do jogo — o mesmo
	# filtro que limpa a resposta do modelo limpa a fala do jogador
	texto = Dialogo.sem_emoji(texto).strip_edges()
	if texto == "" or digitando or npc_atual.is_empty():
		return
	digitando = true
	conversa_input.text = ""
	conversa_input.placeholder_text = "%s está ouvindo..." % npc_atual["nome"]
	# Quem fala é marcado por COR, não só por negrito: numa página de vinte
	# turnos, "Você:" e "Touro Bill:" em negrito idêntico obrigam a ler o
	# nome para saber de quem é a fala. O jogador fica em creme apagado (é o
	# lado que ele já conhece) e o NPC em latão.
	# `[` do jogador vira [lb]: sem o escape, "[b]oi[/b]" digitado FORMATAVA
	# o histórico (RichTextLabel interpreta) em vez de aparecer literal
	conversa_texto += "[color=#b5a48c][b]Você[/b] · %s[/color]\n" % texto.replace("[", "[lb]")
	conversa_turnos.append({"quem": "Jogador", "fala": texto})
	var resultado := Dialogo.falar(state, npc_atual, texto)
	conversa_hist.text = conversa_texto \
		+ "[color=#7a6b58][i]%s pondera...[/i][/color]" % npc_atual["nome"]
	_responder(resultado, texto)

func _responder(resultado: Dictionary, fala_jogador: String = "") -> void:
	# FOTO local do npc e da geração: o botão Sair pode fechar a conversa no
	# meio de qualquer await abaixo (npc_atual vira {}). A mecânica já
	# aconteceu em falar(); daqui em diante é só encenação — se a geração
	# mudou, ela morre em silêncio, sem tocar no estado da conversa nova.
	var npc := npc_atual
	var ger := conversa_geracao
	# IA do jogador (local ou nuvem): tenta gerar a superfície do texto.
	# O saneamento corta o modelo continuando o diálogo sozinho; se sobrar
	# nada, vale a resposta do motor interno — a mecânica já decidiu tudo.
	var texto_final: String = resultado["resposta"]
	if Llm.ativa():
		# a fala do jogador E a memória da conversa vão no prompt; as regras
		# do mundo vão como SISTEMA. Faltando as duas primeiras, o modelo
		# improvisava no vácuo e repetia a mesma frase todo turno
		var prompt := Dialogo.montar_prompt_llm(state, npc, fala_jogador,
			resultado, conversa_turnos)
		var gerado: String = await Llm.gerar(self, prompt, 12.0, Dialogo.SISTEMA_BASE)
		gerado = Dialogo.sanear_llm(gerado, str(npc["nome"]))
		if gerado != "":
			texto_final = gerado
	# o texto do modelo também entra escapado — [img]/[color] gerados não
	# devem formatar a tela (os efeitos mecânicos abaixo são nossos e podem)
	texto_final = texto_final.replace("[", "[lb]")
	# ponderar proporcional ao peso da resposta
	await get_tree().create_timer(clampf(0.5 + texto_final.length() * 0.009, 0.6, 2.4)).timeout
	if ger != conversa_geracao:
		return
	Sfx.tocar(self, "pagina")
	# substitui a linha "pondera..." e digita letra a letra
	var cabeca := "[color=#e8b04b][b]%s[/b][/color] · " % npc["nome"]
	for i in range(0, texto_final.length(), 2):
		conversa_hist.text = conversa_texto + cabeca + texto_final.substr(0, i + 2)
		await get_tree().create_timer(0.024).timeout
		if ger != conversa_geracao:
			return
	conversa_texto += cabeca + texto_final + "\n"
	conversa_turnos.append({"quem": "npc", "fala": texto_final})
	# os EFEITOS da fala (relação caiu, segredo usado, guerra declarada) são
	# consequência mecânica, não diálogo: entram apagados e recuados, para
	# não serem lidos como mais uma frase do personagem
	if not resultado["efeitos"].is_empty():
		conversa_texto += "[color=#d9603f]    %s[/color]\n" % " ".join(resultado["efeitos"])
	conversa_texto += "\n"
	conversa_hist.text = conversa_texto
	digitando = false
	conversa_input.placeholder_text = "Diga o que quiser..."
	_atualizar_cab_conversa()
	Jogo.salvar(state)
	for acao in resultado["acoes"]:
		match acao["tipo"]:
			"fim_conversa":
				fechar_conversa()
			"oferecer_contratos":
				fechar_conversa()
				tabs.current_tab = 3

# ---------------- MODAIS ----------------
func _montar_modal() -> void:
	overlay_modal = Control.new()
	overlay_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_modal)
	# véu escuro: separa o modal do jogo e deixa claro que nada mais responde
	var veu := ColorRect.new()
	veu.color = Color(0, 0, 0, 0.68)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	# o véu ENGOLE o clique: sem isto, um botão da aba por baixo continuava
	# clicável através do modal, e "nada mais responde" era só uma aparência
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_modal.add_child(veu)
	modal_centro = CenterContainer.new()
	modal_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_modal.add_child(modal_centro)

## Painel do modal: fundo opaco e largura fixa. Devolve o VBox de conteúdo.
## BOTÃO DE MODAL — fecha a janela ANTES de agir, sempre.
##
## `_modal()` já embrulhava os botões dele assim, mas os painéis montados
## à mão (`_painel_modal()` + Kit.botao) não: o popup do domínio e o mapa
## comercial ficavam presos na tela, e como o overlay come o clique, o
## jogo travava de vez. Um helper só, e nenhum painel pode esquecer.
func _botao_modal(v: Container, texto: String, cb: Callable,
		variante: String = "", largura: int = 0) -> Button:
	return Kit.botao(v, texto, func():
		overlay_modal.visible = false
		cb.call(), variante, largura)

func _painel_modal() -> VBoxContainer:
	for filho in modal_centro.get_children():
		filho.queue_free()
	overlay_modal.visible = true
	Sfx.tocar(self, "abrir")
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Tema.estilo_modal())
	painel.custom_minimum_size = Vector2(480, 0)
	modal_centro.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Tema.E4)
	painel.add_child(v)
	return v

## O quarto argumento é a ILUSTRAÇÃO do momento (Retratos.ilustracao(...)).
## Vem por último e aceita null porque nenhum modal depende dela para funcionar:
## sem o PNG, é o mesmo modal de texto de sempre.
func _modal(titulo: String, corpo: String, botoes: Array, arte: Texture2D = null,
		selo_icone: String = "") -> void:
	var v := _painel_modal()
	# a ilustração é CENTRADA e o título também: o modal anterior tinha a
	# arte centrada e o título alinhado à esquerda logo abaixo dela, e o
	# desalinhamento entre os dois era a coisa que fazia o modal parecer
	# montado às pressas
	if arte != null:
		var centro_arte := CenterContainer.new()
		v.add_child(centro_arte)
		Kit.ilustracao(centro_arte, arte, 150)
	var l_titulo := Label.new()
	l_titulo.text = titulo
	var f := Tema.fonte_forte()
	if f != null:
		l_titulo.add_theme_font_override("font", f)
	l_titulo.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l_titulo.add_theme_color_override("font_color", Tema.ACENTO)
	l_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# O SELO DO DESFECHO — louros na vitória, caveira na derrota — vai na
	# MESMA linha do título, não sozinho acima dele. Ícone solto e sem
	# rótulo no meio de um painel lê como sujeira (foi o que já aconteceu
	# com a neblina e o espião na aba Mapa); colado ao título ele vira o
	# que é: a marca do que aconteceu.
	## Os dois selos LADEIAM o título, numa fila que ocupa o painel inteiro:
	## o rótulo continua expandido e centrado (é ele quem manda na largura),
	## e os louros ficam como uma coroa em volta do nome do desfecho. Pôr o
	## título dentro de um CenterContainer com autowrap ligado o colapsa
	## para uma letra por linha — foi o que o render flagrou.
	var ic_esq: TextureRect = null
	if selo_icone != "":
		ic_esq = Icones.imagem(selo_icone, 26)
	if ic_esq != null:
		var linha_t := Kit.fila(v, Tema.E3)
		ic_esq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha_t.add_child(ic_esq)
		l_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha_t.add_child(l_titulo)
		var ic_dir := Icones.imagem(selo_icone, 26)
		if ic_dir != null:
			ic_dir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			linha_t.add_child(ic_dir)
	else:
		v.add_child(l_titulo)
	var l_corpo := Label.new()
	l_corpo.text = corpo
	l_corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_corpo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_corpo.add_theme_color_override("font_color", Tema.TEXTO_2)
	v.add_child(l_corpo)
	Kit.respiro(v, Tema.E2)
	# A PRIMEIRA escolha é a primária. Num modal de evento as opções não são
	# equivalentes — "Reprimir pela força" e "Abrir os celeiros" custam
	# coisas diferentes — e dar o mesmo peso às duas não é neutralidade, é
	# ausência de desenho. A ordem em que o código as lista já era a ordem
	# de intenção; agora ela aparece.
	for i in botoes.size():
		var par: Array = botoes[i]
		var cb: Callable = par[1]
		Kit.botao(v, str(par[0]), func():
			overlay_modal.visible = false
			cb.call(), "primario" if i == 0 else "fantasma")

func _modal_evento() -> void:
	var ev: Dictionary = state["evento_pendente"]
	Sfx.tocar(self, "alerta")
	match ev["tipo"]:
		"rebeliao":
			_modal("REBELIÃO!", "O povo marcha sobre sua residência com foices, tochas e uma lista de queixas escrita com fome.", [
				["Reprimir pela força", func(): _modal_batalha(Jogo.resolver_evento(state, "reprimir"))],
				["Abrir os celeiros e ceder", func():
					Jogo.resolver_evento(state, "conceder")
					Jogo.salvar(state)
					atualizar()],
			], Retratos.ilustracao("rebeliao"))
		"notavel_ambicioso":
			# o rico que olha o seu assento com fome. Sem este ramo o evento
			# caía no `_` e sumia — a ascensão de cidadãos ficava sem desfecho.
			var nome_amb: String = str(ev["nome"])
			var ficha_amb: Dictionary = {}
			for n in Cidadaos.lista(state):
				if str(n.get("nome", "")) == nome_amb:
					ficha_amb = n
			var ele: String = "dela" if str(ficha_amb.get("genero", "m")) == "f" else "dele"
			var eleu: String = "ela" if str(ficha_amb.get("genero", "m")) == "f" else "ele"
			_modal("Uma casa rica demais",
				"%s enriqueceu na sua vila e agora recebe visitas que não passam pela sua porta. Ou você compra o joelho dobrado %s, ou %s compra o seu."
					% [nome_amb, ele, eleu], [
				["Comprar a lealdade (250)", func():
					_aviso(str(Jogo.resolver_evento(state, "comprar").get("msg", "")))
					Jogo.salvar(state)
					atualizar()],
				["Exilar a família", func():
					_aviso(str(Jogo.resolver_evento(state, "exilar").get("msg", "")))
					Jogo.salvar(state)
					atualizar()],
				["Ignorar (por enquanto)", func():
					_aviso(str(Jogo.resolver_evento(state, "ignorar").get("msg", "")))
					Jogo.salvar(state)
					atualizar()],
			], null if ficha_amb.is_empty() else Retratos.textura_cidadao(ficha_amb))
		"traicao_guardas":
			_modal("Traição por Ouro", "Sua guarda está sem soldo — e um reino rival ofereceu o dobro para abrirem seus portões esta noite.", [
				["Pagar em dobro agora", func():
					Jogo.resolver_evento(state, "pagar")
					Jogo.salvar(state)
					atualizar()],
				["Confiar na lealdade deles", func():
					Jogo.resolver_evento(state, "recusar")
					Jogo.salvar(state)
					atualizar()],
			], Retratos.ilustracao("traicao"))
		_:
			state["evento_pendente"] = null
			atualizar()

## O corpo do modal é montado do formato REAL de Combate.batalhar (fases,
## baixas_jogador/inimigo, vivos, debandada) — a versão anterior lia chaves
## de um formato antigo ("rodadas") que batalhar nunca devolveu, e o
## relatório de TODA batalha da UI morria num SCRIPT ERROR antes de abrir.
func _modal_batalha(rel: Dictionary) -> void:
	if rel.is_empty():
		Jogo.salvar(state)
		atualizar()
		return
	Sfx.tocar(self, "espada")
	Sfx.tocar(self, "vitoria" if rel.get("vitoria", false) else "derrota")
	var venceu: bool = bool(rel.get("vitoria", false))
	var contexto := str(rel.get("contexto", "Batalha"))
	var v := _painel_modal()
	if _arte_de_batalha(contexto) != null:
		var cc := CenterContainer.new()
		v.add_child(cc)
		Kit.ilustracao(cc, _arte_de_batalha(contexto), 120)
	# ---- título com o selo do desfecho ----
	var lt := Kit.fila(v, Tema.E3)
	var ic_s := Icones.imagem("louros" if venceu else "caveira", 26)
	if ic_s != null:
		ic_s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lt.add_child(ic_s)
	var l_tit := Label.new()
	l_tit.text = ("VITÓRIA — %s" if venceu else "DERROTA — %s") % contexto
	var f_b := Tema.fonte_forte()
	if f_b != null:
		l_tit.add_theme_font_override("font", f_b)
	l_tit.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l_tit.add_theme_color_override("font_color", Tema.ACENTO if venceu else Tema.PERIGO)
	l_tit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lt.add_child(l_tit)

	# ---- AS TRÊS FASES, EM TABELA ----
	# Eram três frases longas coladas ("Disparo: 361 de ataque contra 310
	# de defesa — baixas: você −24, inimigo −3"), e ninguém consegue
	# comparar três linhas assim de bate-pronto. Em colunas, a fase que
	# decidiu a batalha salta aos olhos.
	Kit.subsecao(v, "Como foi")
	var tabf := Kit.tabela(v, [
		{"t": "Fase", "w": 0},
		{"t": "Ataque", "w": 70, "a": Kit.DIR},
		{"t": "Defesa", "w": 70, "a": Kit.DIR},
		{"t": "Você", "w": 62, "a": Kit.DIR},
		{"t": "Eles", "w": 62, "a": Kit.DIR},
	])
	for f in rel.get("fases", []):
		var celf := Kit.linha(tabf)
		Kit.texto(celf[0], str(f.get("nome", f.get("fase", "?"))))
		Kit.numero(celf[1], str(int(f.get("ataque", 0))), Tema.TEXTO_2)
		Kit.numero(celf[2], str(int(f.get("defesa", 0))), Tema.TEXTO_2)
		Kit.numero(celf[3], "−%d" % int(f.get("mortos_atacante", 0)), Tema.PERIGO)
		Kit.numero(celf[4], "−%d" % int(f.get("mortos_defensor", 0)), Tema.GANHO)
	match str(rel.get("debandada", "")):
		"inimigo":
			Kit.selo(v, "o inimigo debandou", Tema.GANHO, Tema.GANHO_FUNDO)
		"jogador":
			Kit.selo(v, "suas linhas quebraram", Tema.PERIGO, Tema.PERIGO_FUNDO)

	# ---- O SALDO, em dois blocos grandes ----
	Kit.subsecao(v, "O saldo")
	var placar := Kit.fila(v, Tema.E6)
	for lado in [["Suas baixas", int(rel.get("baixas_jogador", 0)),
				"De pé: %d" % int(rel.get("vivos_jogador", 0)), Tema.PERIGO],
			["Baixas deles", int(rel.get("baixas_inimigo", 0)),
				"De pé: %d" % int(rel.get("vivos_inimigo", 0)), Tema.GANHO]]:
		var bloco := VBoxContainer.new()
		bloco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloco.add_theme_constant_override("separation", 0)
		placar.add_child(bloco)
		var rot := Kit.texto(bloco, str(lado[0]), Tema.TEXTO_3, Tema.MINI)
		rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var num := Kit.numero(bloco, "−%d" % int(lado[1]), lado[3] as Color, Tema.CORPO_G)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := Kit.texto(bloco, str(lado[2]), Tema.TEXTO_2, Tema.MICRO)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- o que a vitória rendeu (ou o que a derrota custou) ----
	if rel.has("ganho_ouro") or rel.has("ganho_renome"):
		var lg := Kit.fila(v, Tema.E4)
		if int(rel.get("ganho_ouro", 0)) != 0:
			Kit.icone_valor(lg, "moedas", "+%d" % int(rel["ganho_ouro"]), Tema.ACENTO)
		if int(rel.get("ganho_renome", 0)) != 0:
			Kit.icone_valor(lg, "renome", "+%d" % int(rel["ganho_renome"]), Tema.GANHO)
		if int(rel.get("ganho_honra", 0)) != 0:
			Kit.icone_valor(lg, "honra", "+%d" % int(rel["ganho_honra"]), Tema.GANHO)
	Kit.respiro(v, Tema.E2)
	_botao_modal(v, "Continuar", func():
		Jogo.salvar(state)
		atualizar(), "primario")

## A ilustração sai do CONTEXTO que combate.gd já escreve ("Cerco a …",
## "Rebelião camponesa"…), então nenhuma chamada precisa passar arte à mão.
func _arte_de_batalha(contexto: String) -> Texture2D:
	var t := contexto.to_lower()
	if t.contains("cerco"):
		return Retratos.ilustracao("cerco")
	if t.contains("rebeli"):
		return Retratos.ilustracao("rebeliao")
	if t.contains("saque"):
		return Retratos.ilustracao("saque")
	if t.contains("estrada") or t.contains("embosc"):
		return Retratos.ilustracao("emboscada")
	return null

func _modal_fim() -> void:
	var vitoria: bool = state["fim"]["tipo"] == "vitoria"
	_modal("REINO POR CONQUISTA" if vitoria else "FIM DA SAGA",
		"Você segurou o trono por um ano. Os bardos cantarão sua saga!" if vitoria
		else "Sua linhagem chega ao fim. As crônicas mal lembrarão seu nome.",
		[["Nova saga", func():
			Jogo.apagar_save()
			get_tree().reload_current_scene()]],
		Retratos.ilustracao("coroacao") if vitoria else Retratos.ilustracao("derrota"))

## O seletor de IA. O jogador escolhe QUALQUER provedor — Gemini com a
## maior faixa grátis (recomendado), llama.cpp local ilimitado, Groq e
## OpenRouter grátis com conta, OpenAI e Anthropic pagos — e o AVISO muda
## de cor junto: pago é vermelho e diz "cobra por uso" antes de qualquer
## chamada. Com `ao_confirmar` válido é o modo OBRIGATÓRIO da primeira
## saga: pré-seleciona o recomendado, valida a chave e só então começa.
func _modal_llm(ao_confirmar := Callable()) -> void:
	var obrigatorio := ao_confirmar.is_valid()
	var v := _painel_modal()
	var l_titulo := Label.new()
	l_titulo.text = "Escolha a IA dos Personagens" if obrigatorio else "IA dos Personagens"
	var f := Tema.fonte_forte()
	if f != null:
		l_titulo.add_theme_font_override("font", f)
	l_titulo.add_theme_font_size_override("font_size", Tema.TITULO_SECAO)
	l_titulo.add_theme_color_override("font_color", Tema.ACENTO)
	l_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l_titulo)
	var l := Label.new()
	l.text = ("Este jogo se joga CONVERSANDO abertamente com os personagens — e é a IA que interpreta o que você escreve. Há opções grátis; sem IA, valem as respostas curtas do motor interno." \
		if obrigatorio else \
		"As falas dos NPCs podem ser geradas por uma IA à sua escolha. A mecânica decide o que acontece; a IA interpreta e narra.")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Tema.TEXTO_2)
	v.add_child(l)

	var cfg: Dictionary = Llm.config()
	var ids: Array = Llm.PROVEDORES.keys()

	var escolha := OptionButton.new()
	for id in ids:
		escolha.add_item(str(Llm.PROVEDORES[id]["nome"]))
	# primeira vez: o RECOMENDADO já vem selecionado — quem só aperta
	# "Começar" cai na maior faixa grátis, não no silêncio
	var inicial := ids.find(Llm.RECOMENDADO) if obrigatorio and not Llm.ja_escolheu() \
		else ids.find(str(cfg["provedor"]))
	escolha.select(maxi(0, inicial))
	v.add_child(escolha)

	var nota := Label.new()
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", Tema.MICRO)
	nota.add_theme_color_override("font_color", Tema.TEXTO_3)
	v.add_child(nota)

	# ---- o aviso de custo, colorido pelo bolso ----
	var aviso_painel := PanelContainer.new()
	var aviso := Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.MICRO)
	aviso_painel.add_child(aviso)
	v.add_child(aviso_painel)

	var r_url := Kit.fila(v, Tema.E2)
	Kit.texto(r_url, "Servidor", Tema.TEXTO_3, Tema.MICRO)
	var campo_url := LineEdit.new()
	campo_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_url.add_child(campo_url)

	var r_chave := Kit.fila(v, Tema.E2)
	Kit.texto(r_chave, "Chave", Tema.TEXTO_3, Tema.MICRO)
	var campo_chave := LineEdit.new()
	campo_chave.secret = true
	campo_chave.placeholder_text = "sua chave de API (fica só neste computador)"
	campo_chave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_chave.add_child(campo_chave)

	var r_modelo := Kit.fila(v, Tema.E2)
	Kit.texto(r_modelo, "Modelo", Tema.TEXTO_3, Tema.MICRO)
	var campo_modelo := LineEdit.new()
	campo_modelo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_modelo.add_child(campo_modelo)

	# preenche os campos para um provedor: o salvo, quando é o dele; o
	# padrão do catálogo, quando o jogador acabou de trocar
	var aplicar := func(idx: int) -> void:
		var id := str(ids[idx])
		var p: Dictionary = Llm.PROVEDORES[id]
		var salvo := id == str(cfg["provedor"])
		nota.text = str(p.get("nota", ""))
		campo_url.text = str(cfg["url"]) if salvo else str(p["url"])
		campo_chave.text = str(cfg["chave"]) if salvo else ""
		campo_modelo.text = str(cfg["modelo"]) \
			if salvo and str(cfg["modelo"]) != "" else str(p["modelo"])
		var liga := str(p["protocolo"]) != ""
		r_url.visible = liga
		r_chave.visible = liga and bool(p["chave"])
		r_modelo.visible = liga and str(p["modelo"]) != ""
		var sb := StyleBoxFlat.new()
		sb.set_content_margin_all(Tema.E2)
		sb.set_corner_radius_all(4)
		match str(p["custo"]):
			"pago":
				aviso.text = "⚠ PROVEDOR PAGO: usa a SUA chave e gera cobrança por uso a cada fala. Confira os preços do provedor antes de ligar."
				aviso.add_theme_color_override("font_color", Color("e8917a"))
				sb.bg_color = Tema.PERIGO_FUNDO
			"gratis_conta":
				aviso.text = "Requer conta e chave do provedor. Tem faixa GRATUITA com limites de uso; acima dela pode haver cobrança."
				aviso.add_theme_color_override("font_color", Tema.ATENCAO)
				sb.bg_color = Tema.ATENCAO_FUNDO
			_:
				aviso.text = "Grátis: roda na sua máquina, nada sai do seu computador." if liga \
					else "O motor interno do jogo responde — grátis e imediato."
				aviso.add_theme_color_override("font_color", Tema.TEXTO_3)
				sb.bg_color = Tema.ELEVADO
		aviso_painel.add_theme_stylebox_override("panel", sb)
	aplicar.call(escolha.selected)
	escolha.item_selected.connect(func(idx: int): aplicar.call(idx))

	Kit.respiro(v, Tema.E1)
	Kit.botao(v, "Começar a saga" if obrigatorio else "Salvar", func():
		var id := str(ids[escolha.selected])
		var p: Dictionary = Llm.PROVEDORES[id]
		# quem escolheu um provedor não pode sair sem o que ele exige —
		# senão a primeira conversa falharia em silêncio
		if str(p["protocolo"]) != "" and campo_url.text.strip_edges() == "":
			aviso.text = "⚠ Falta a URL do servidor para este provedor."
			aviso.add_theme_color_override("font_color", Color("e8917a"))
			return
		if bool(p["chave"]) and campo_chave.text.strip_edges() == "":
			aviso.text = "⚠ Falta a CHAVE: crie a conta no site do provedor (é grátis nos de faixa grátis) e cole a chave aqui."
			aviso.add_theme_color_override("font_color", Color("e8917a"))
			return
		Llm.definir({"provedor": id,
			"url": campo_url.text, "chave": campo_chave.text,
			"modelo": campo_modelo.text})
		Sfx.tocar(self, "fechar")
		overlay_modal.visible = false
		if obrigatorio:
			ao_confirmar.call()
		else:
			atualizar(), "primario")
