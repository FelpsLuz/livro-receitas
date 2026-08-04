# ============================================================
# REINO POR CONQUISTA — cena principal (fase 2)
# Toda a interface é construída em código: título, abas de
# gestão, cidade pixel art, conversa com "ponderar" e
# máquina de escrever, modais de evento e fim de jogo.
# ============================================================
extends Control

const Dados = preload("res://scripts/dados.gd")
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
const VilaCena = preload("res://scripts/vila_cena.gd")
const Icones = preload("res://scripts/icones.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Taverna = preload("res://scripts/taverna.gd")
const Marchas = preload("res://scripts/marchas.gd")
const Relogio = preload("res://scripts/relogio.gd")
const Rotas = preload("res://scripts/rotas.gd")

const NPCS_TAVERNA := [
	{"id": "taverneiro", "nome": "Bram, o Taverneiro", "personalidade": "ganancioso"},
	{"id": "capitao", "nome": "Capitã Renna", "personalidade": "honrado"},
	{"id": "espiao", "nome": "O Corvo", "personalidade": "calculista"},
]
const MESES := ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
	"Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]

var state: Dictionary = {}
var npc_atual: Dictionary = {}
var digitando := false
var conversa_texto := ""

var tela_titulo: Control
var tela_jogo: Control
var status_label: Label
var tabs: TabContainer
var cidade_view: Control
var quartel: Timer
var overlay_conversa: Control
var conversa_hist: RichTextLabel
var conversa_input: LineEdit
var conversa_retrato: TextureRect
var conversa_titulo: Label
var overlay_modal: Control
var input_nome: LineEdit

func _ready() -> void:
	theme = Tema.criar()
	var fundo := ColorRect.new()
	fundo.color = Tema.MADEIRA
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_montar_titulo()
	_montar_jogo()
	_montar_conversa()
	_montar_modal()
	tela_jogo.visible = false
	overlay_conversa.visible = false
	overlay_modal.visible = false

# ---------------- TELA DE TÍTULO ----------------
func _montar_titulo() -> void:
	tela_titulo = CenterContainer.new()
	tela_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tela_titulo)
	var caixa := PanelContainer.new()
	caixa.custom_minimum_size = Vector2(520, 0)
	tela_titulo.add_child(caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	caixa.add_child(v)
	# a tela de título mostra um reino no auge — a mesma vila do jogo, nível 5
	var vitrine: SubViewportContainer = VilaCena.new() if VilaCena.disponivel() else CidadeCena.new()
	vitrine.custom_minimum_size = Vector2(480, 270)
	v.add_child(vitrine)
	vitrine.estado = {"terra": {"nivel": 5}, "mes": 6}
	var titulo := Label.new()
	titulo.text = "⚔ REINO POR CONQUISTA"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", Tema.SANGUE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var sub := Label.new()
	sub.text = "De mercenário sem nome a rei — se as intrigas, a fome e as adagas deixarem."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	input_nome = LineEdit.new()
	input_nome.placeholder_text = "Nome do seu mercenário (opcional)"
	input_nome.max_length = 24
	v.add_child(input_nome)
	var b_novo := Button.new()
	b_novo.text = "🗡 Nova Saga"
	b_novo.pressed.connect(func(): iniciar_jogo(input_nome.text.strip_edges()))
	v.add_child(b_novo)
	if Jogo.tem_save():
		var b_cont := Button.new()
		b_cont.text = "📜 Continuar Saga"
		b_cont.pressed.connect(continuar_jogo)
		v.add_child(b_cont)

func iniciar_jogo(nome: String) -> void:
	state = Jogo.novo_jogo(nome)
	_entrar_no_jogo()

func continuar_jogo() -> void:
	var salvo = Jogo.carregar()
	if salvo == null:
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
	tela_jogo.visible = true
	cidade_view.estado = state
	cidade_view.semear_npcs()
	atualizar()

# ---------------- ESTRUTURA DO JOGO ----------------
func _montar_jogo() -> void:
	tela_jogo = MarginContainer.new()
	tela_jogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela_jogo.add_theme_constant_override("margin_left", 8)
	tela_jogo.add_theme_constant_override("margin_right", 8)
	tela_jogo.add_theme_constant_override("margin_top", 8)
	tela_jogo.add_theme_constant_override("margin_bottom", 8)
	add_child(tela_jogo)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tela_jogo.add_child(v)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Tema.OURO)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for nome in ["Sua Terra", "Mapa", "Mercado", "Taverna", "Corte", "Exército", "Clãs", "Intrigas", "Família", "Crônica"]:
		var rolagem := ScrollContainer.new()
		rolagem.name = nome
		var conteudo := VBoxContainer.new()
		conteudo.name = "Conteudo"
		conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conteudo.add_theme_constant_override("separation", 8)
		rolagem.add_child(conteudo)
		tabs.add_child(rolagem)
	tabs.tab_changed.connect(func(_i): atualizar())

	var rodape := HBoxContainer.new()
	v.add_child(rodape)
	var b_mes := Button.new()
	b_mes.text = "⏳ Passar o mês"
	b_mes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_mes.pressed.connect(_passar_mes)
	rodape.add_child(b_mes)
	var b_mudo := Button.new()
	b_mudo.text = "🔊"
	b_mudo.pressed.connect(func():
		Sfx.mudo = not Sfx.mudo
		b_mudo.text = "🔇" if Sfx.mudo else "🔊")
	rodape.add_child(b_mudo)

	# vila em nós nativos quando os assets v2 estão lá; senão, o cenário
	# procedural de sempre. As duas cenas têm a mesma API (.estado, semear_npcs).
	cidade_view = VilaCena.new() if VilaCena.disponivel() else CidadeCena.new()
	_montar_quartel()

## A cidade_view sai da árvore quando outra aba está ativa (atualizar() a
## remove do pai). Node não é ref-counted: sem isto, fechar o jogo em qualquer
## aba que não a "Sua Terra" vazava a vila inteira — SubViewport, TileMaps,
## sprites e partículas.
func _exit_tree() -> void:
	if cidade_view != null and cidade_view.get_parent() == null:
		cidade_view.free()
		cidade_view = null

## mm:ss para a fila do quartel.
func _mmss(seg: int) -> String:
	return "%d:%02d" % [int(seg / 60.0), seg % 60]

## ---------- O TIMER DO QUARTEL ----------
## Um Timer é um nó da cena; o save é um Dictionary. Por isso ele NÃO guarda
## o tempo restante — quem guarda é a fila, dentro do state. O Timer só
## empurra o relógio 1 segundo por vez, exatamente como o turno mensal faz
## com 600 de uma vez. Salvar no meio do treino não perde nada.
func _montar_quartel() -> void:
	quartel = Timer.new()
	quartel.wait_time = 1.0
	quartel.timeout.connect(_tique_quartel)
	add_child(quartel)
	quartel.start()

func _tique_quartel() -> void:
	if state.is_empty() or state.get("fim") != null:
		return
	# nada com prazo pendente? o relógio não precisa girar
	if Recrutamento.fila(state).is_empty() and Marchas.lista(state).is_empty():
		return
	var r: Dictionary = Relogio.avancar(state, 1, Jogo.log_para(state))
	if int(r["recrutas"]) > 0 or not r["marchas"].is_empty():
		Sfx.tocar(self, "tique")
		Jogo.salvar(state)
		atualizar()          # só redesenha quando algo REALMENTE aconteceu

func _passar_mes() -> void:
	Sfx.tocar(self, "tique")
	Jogo.passar_mes(state)
	Jogo.salvar(state)
	atualizar()

func _conteudo_aba() -> VBoxContainer:
	return tabs.get_current_tab_control().get_node("Conteudo")

func atualizar() -> void:
	if state.is_empty():
		return
	var j: Dictionary = state["jogador"]
	status_label.text = "%s · %s · %d anos   🪙 %d   ⭐ %d   ⚔ %d homens   🛡 %d   📅 %s, Ano %d" % [
		j["nome"], Contratos.titulo(state), j["idade"], j["ouro"], j["renome"],
		Combate.total_homens(j["tropas"]), j["guardas"], MESES[state["mes"] - 1], state["ano"]]

	if state["fim"] != null:
		_modal_fim()
		return
	if state["evento_pendente"] != null:
		_modal_evento()
		return

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

# ---------------- utilitários de UI ----------------
func _titulo_secao(c: Container, texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Tema.PERGAMINHO)
	c.add_child(l)

func _par(c: Container, texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color("d4c090"))
	c.add_child(l)
	return l

func _botao(c: Container, texto: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.pressed.connect(cb)
	c.add_child(b)
	return b

func _card(c: Container) -> HBoxContainer:
	var painel := PanelContainer.new()
	c.add_child(painel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	painel.add_child(h)
	return h

func _retrato(c: Container, id: String, tamanho: int = 52) -> void:
	var tr := TextureRect.new()
	tr.texture = Retratos.textura(id, Retratos.humor_de(state, id))
	tr.custom_minimum_size = Vector2(tamanho, tamanho)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# OVERHAUL v2: a moldura ornamentada do PixelLab entra POR CIMA do retrato
	var moldura := UIv2.criar_painel("moldura_retrato")
	if moldura == null:
		c.add_child(tr)
		return
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(tamanho, tamanho)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(tr)
	caixa.add_child(moldura)
	c.add_child(caixa)

func _aviso(msg: String) -> void:
	if msg == "":
		return
	var linha := Label.new()
	linha.text = "▸ " + msg
	linha.add_theme_color_override("font_color", Tema.OURO)
	_conteudo_aba().add_child(linha)
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func():
		if is_instance_valid(linha):
			linha.queue_free())

# ---------------- ABAS ----------------
func _aba_terra(c: Container) -> void:
	var t = state["terra"]
	_titulo_secao(c, ("%s — %s" % [t["nome"], Dados.NIVEIS_TERRA[t["nivel"]]["nome"]]) if t != null else "Acampamento Mercenário")
	cidade_view.estado = state
	cidade_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(cidade_view)
	if t == null:
		_par(c, "Sem terras, sem raízes. Junte 25 de renome e 300 de ouro para comprar seu primeiro pedaço de chão.")
		_botao(c, "🏕 Comprar terra (300 🪙, requer 25 ⭐)", func():
			var r: Dictionary = Jogo.comprar_terra(state)
			if r["ok"]:
				Sfx.tocar(self, "moeda")
				cidade_view.semear_npcs()
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())
	else:
		_par(c, "👥 População %d   🌾 Alimento %d   🪵 Madeira %d   😊 Felicidade %d" %
			[t["populacao"], t["alimento"], t["madeira"], t["felicidade"]])
		if int(t["felicidade"]) <= 30:
			_par(c, "⚠ O povo murmura. Felicidade baixa termina em foices e tochas.")
		if int(t["nivel"]) < 5:
			var prox: Dictionary = Dados.NIVEIS_TERRA[int(t["nivel"]) + 1]
			_botao(c, "🏗 Evoluir para %s (%d 🪙 + %d 🪵)" % [prox["nome"], prox["custo_ouro"], prox["custo_madeira"]], func():
				var r: Dictionary = Jogo.melhorar_terra(state)
				if r["ok"]:
					Sfx.tocar(self, "vitoria")
					cidade_view.semear_npcs()
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
		_botao(c, "📦 Exportar 30 de alimento (ouro rápido, povo reclama)", func():
			var r: Dictionary = Jogo.exportar_comida(state, 30)
			if r["ok"]:
				Sfx.tocar(self, "moeda")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())

func _aba_mapa(c: Container) -> void:
	_titulo_secao(c, "Os Seis Reinos")
	for g in state["guerras"]:
		_par(c, "⚔ %s × %s — %d meses de guerra. Campos em chamas." % [g["a"], g["b"], g["meses"]])
	if state["guerras"].is_empty():
		_par(c, "🕊 Os reinos estão em paz. Por enquanto.")
	for reino in state["reinos"]:
		var h := _card(c)
		_retrato(h, reino["rei"]["id"])
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var rel: int = state["tags"].get("rei_" + reino["id"], {"relacao": 0})["relacao"]
		var extras := ""
		if state["casus_belli"].has(reino["id"]):
			extras += "  📜 Casus Belli"
		if state["jogador"]["rei_de"] == reino["id"]:
			extras += "  👑 SEU TRONO"
		var info := Label.new()
		info.text = "%s — %s\n%s · %s (%d)%s" % [reino["nome"], reino["capital"],
			reino["rei"]["nome"], Dialogo.nome_relacao(rel), rel, extras]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(info)
		var lb := HBoxContainer.new()
		v.add_child(lb)
		if state["local"] != reino["id"]:
			_botao(lb, "🐴 Viajar", func():
				state["local"] = reino["id"]
				Jogo.salvar(state)
				atualizar())
		else:
			_par(lb, "📍 Você está aqui")
		if state["jogador"]["rei_de"] == "":
			var tem_cb: bool = state["casus_belli"].has(reino["id"])
			_botao(lb, "⚔ Conquistar" if tem_cb else "⚔ Atacar SEM casus belli", func():
				var rel_batalha: Dictionary = Intriga.declarar_guerra(state, reino["id"], Jogo.log_para(state))
				Jogo.salvar(state)
				_modal_batalha(rel_batalha))

func _aba_mercado(c: Container) -> void:
	var reino := _reino_local()
	_titulo_secao(c, "📖 Livro-Razão — Mercado de %s" % reino["nome"])
	var em_guerra := false
	for g in state["guerras"]:
		if g["a"] == state["local"] or g["b"] == state["local"]:
			em_guerra = true
	if em_guerra:
		_par(c, "⚔ Reino em guerra: trigo com ágio de contrabando (+30%), mas patrulhas confiscam cargas.")
	for g_id in Dados.MERCADORIAS:
		var h := _card(c)
		var preco := Economia.preco_de(state, state["local"], g_id)
		var carga: int = int(state["carga"].get(g_id, 0))
		# ícone Pro da mercadoria — sem o PNG, o card segue só com texto
		var ic := Icones.imagem(g_id, 28)
		if ic != null:
			h.add_child(ic)
		var l := Label.new()
		l.text = "%s — %d 🪙 · carga: %d" % [Dados.MERCADORIAS[g_id]["nome"], preco, carga]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		_botao(h, "Comprar 5", func():
			var r: Dictionary = Economia.comprar(state, state["local"], g_id, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())
		var b_vender := _botao(h, "Vender 5", func():
			var r: Dictionary = Economia.vender(state, state["local"], g_id, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())
		b_vender.disabled = carga < 5
	_par(c, "💡 Compre onde há fartura, venda onde há guerra e fome.")

func _aba_taverna(c: Container) -> void:
	_titulo_secao(c, "🍺 Taverna do Javali Manco — Mural de Contratos")
	for ct in state["contratos"]:
		var h := _card(c)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_par(v, "%s — para %s%s\n%s\n💰 %d 🪙 · ⭐ +%d · dificuldade %s" % [
			ct["nome"], ct["contratante"],
			(" (alvo: %s)" % ct["alvo"]) if ct["alvo"] != "" else "",
			ct["desc"], ct["pagamento"], ct["renome"], "⚔".repeat(int(ct["forca"]))])
		_botao(v, "Aceitar e executar", func():
			if Combate.total_homens(state["jogador"]["tropas"]) == 0:
				_aviso("Você não tem tropas! Recrute no quartel.")
				return
			var rel_batalha: Dictionary = Contratos.executar(state, ct, Jogo.log_para(state))
			state["contratos"] = state["contratos"].filter(func(x): return x["uid"] != ct["uid"])
			Jogo.salvar(state)
			_modal_batalha(rel_batalha))
	_titulo_secao(c, "Fregueses")
	for npc in NPCS_TAVERNA:
		_card_npc(c, npc)

func _aba_corte(c: Container) -> void:
	var reino := _reino_local()
	_titulo_secao(c, "👑 Corte de %s" % reino["capital"])
	_card_npc(c, reino["rei"])
	_par(c, "💡 Escreva o que quiser: elogie, insulte, ameace, proponha casamento, chantageie, negocie a paz. O NPC entende — e LEMBRA.")
	var h := HBoxContainer.new()
	c.add_child(h)
	_botao(h, "🧠 IA Local (llama.cpp): " + ("configurada" if Llm.url() != "" else "desligada"), _modal_llm)

func _card_npc(c: Container, npc: Dictionary) -> void:
	var h := _card(c)
	_retrato(h, npc["id"])
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var rel: int = state["tags"].get(npc["id"], {"relacao": 0})["relacao"]
	_par(v, "%s  (%s %d)" % [npc["nome"], Dialogo.nome_relacao(rel), rel])
	_botao(v, "💬 Conversar", func(): abrir_conversa(npc))

func _aba_exercito(c: Container) -> void:
	var j: Dictionary = state["jogador"]
	_titulo_secao(c, "⚔ Quartel")
	var p := Combate.poder(j["tropas"], j["equip"])
	_par(c, "Ataque %d · Defesa %d · %d homens · Manutenção %s 🪙/mês · Equipamento %d/3" %
		[roundi(p["atq"]), roundi(p["def"]), p["homens"], str(j.get("ultima_manut", "—")), j["equip"]])
	_par(c, "👥 População comprometida: %d de %d" %
		[Recrutamento.pop_usada(state), Recrutamento.pop_maxima(state)])
	for tipo in Dados.TROPAS:
		var h := _card(c)
		var l := Label.new()
		l.text = "%s — você tem %d (custo %d, manut. %d/mês, treino %ds)" % [
			Dados.TROPAS[tipo]["nome"], j["tropas"].get(tipo, 0),
			Dados.TROPAS[tipo]["custo"], Dados.TROPAS[tipo]["manut"],
			Recrutamento.tempo_de(state, tipo)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		_botao(h, "Recrutar 5", func():
			var r: Dictionary = Jogo.recrutar(state, tipo, 5)
			Sfx.tocar(self, "moeda" if r["ok"] else "alerta")
			_aviso(r["msg"])
			Jogo.salvar(state)
			atualizar())

	# ---- fila do quartel ----
	# Sem isto o jogador clica em "Recrutar" e não vê nada mudar, porque a
	# tropa agora leva tempo. A fila É o feedback.
	var fila: Array = Recrutamento.fila(state)
	if not fila.is_empty():
		_titulo_secao(c, "⏳ Quartel — %s até o último recruta"
			% _mmss(Recrutamento.minutos_restantes(state)))
		for i in fila.size():
			var item: Dictionary = fila[i]
			var hf2 := _card(c)
			var lf := Label.new()
			lf.text = "%s ×%d — próximo em %s" % [
				Dados.TROPAS[item["tipo"]]["nome"], item["restantes"],
				_mmss(int(item["restante"]))]
			lf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hf2.add_child(lf)
			var idx := i
			_botao(hf2, "Cancelar", func():
				var r: Dictionary = Recrutamento.cancelar(state, idx)
				Sfx.tocar(self, "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
	# ---- exércitos na estrada ----
	# O jogador precisa VER que mandou gente e quanto falta para o impacto,
	# senão o exército some do inventário e parece bug.
	var transito: Array = Marchas.em_transito(state)
	if not transito.is_empty():
		_titulo_secao(c, "🏇 Exércitos em marcha")
		for mt in transito:
			var hm := _card(c)
			var lm := Label.new()
			var rumo: String = "→ %s" % Rotas.nome_do(state, mt["alvo"]) \
				if mt["fase"] == "ida" else "← voltando de %s" % Rotas.nome_do(state, mt["alvo"])
			var carga := ""
			for g in mt["carga"]:
				carga += " · %s %d" % [g, int(mt["carga"][g])]
			lm.text = "%d homens %s (%s) — chega em %s%s" % [
				mt["homens"], rumo, mt["intencao"], mt["texto_faltam"], carga]
			lm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hm.add_child(lm)
			if mt["fase"] == "ida":
				var mid: String = mt["id"]
				_botao(hm, "Recuar", func():
					var r: Dictionary = Marchas.recolher(state, mid)
					_aviso(r["msg"])
					Jogo.salvar(state)
					atualizar())

	# ---- enviar exército ----
	# A estimativa de marcha aparece ANTES de decidir: é a informação que
	# transforma "atacar" numa escolha de logística, não num clique.
	if Combate.total_homens(j["tropas"]) > 0:
		_titulo_secao(c, "⚔ Enviar exército")
		_par(c, "Metade das suas tropas parte. Saque volta rápido com carga; cerco quebra o inimigo.")
		for alvo in Rotas.todos_os_nos():
			if alvo == "jogador":
				continue
			var metade := {}
			for tipo in j["tropas"]:
				var q: int = int(int(j["tropas"][tipo]) / 2)
				if q > 0:
					metade[tipo] = q
			if metade.is_empty():
				break
			var est: Dictionary = Marchas.estimar(state, alvo, metade)
			var ha := _card(c)
			var la := Label.new()
			la.text = "%s — %s de marcha · risco %s\n%s" % [
				Rotas.nome_do(state, alvo), Relogio.texto_dias(int(est["minutos"])),
				est["risco"], est["trajeto"]]
			la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ha.add_child(la)
			var destino: String = alvo
			var envio: Dictionary = metade
			_botao(ha, "Saque", func():
				var r: Dictionary = Marchas.despachar(state, destino, envio, "saque")
				Sfx.tocar(self, "tique" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
			_botao(ha, "Cerco", func():
				var r: Dictionary = Marchas.despachar(state, destino, envio, "cerco")
				Sfx.tocar(self, "tique" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())

	_titulo_secao(c, "Formação de batalha")
	var hf := HBoxContainer.new()
	c.add_child(hf)
	for f_id in Dados.FORMACOES:
		var b := _botao(hf, Dados.FORMACOES[f_id]["nome"] + (" ✓" if j["formacao"] == f_id else ""), func():
			j["formacao"] = f_id
			Jogo.salvar(state)
			atualizar())
	_par(c, "💡 Linha ≻ Cunha ≻ Envolvimento ≻ Linha.")
	_botao(c, "🛠 Melhorar equipamento (%d 🪙)" % (200 * (int(j["equip"]) + 1)), func():
		var r: Dictionary = Jogo.melhorar_equip(state)
		_aviso(r["msg"])
		Jogo.salvar(state)
		atualizar())
	_botao(c, "🛡 Contratar 2 guardas de elite (120 🪙)", func():
		var r: Dictionary = Jogo.contratar_guardas(state, 2)
		_aviso(r["msg"])
		Jogo.salvar(state)
		atualizar())

func _aba_clas(c: Container) -> void:
	_titulo_secao(c, "🐺 Clãs Mercenários")
	_par(c, "Envie um mensageiro com sua oferta; a resposta chega na virada do mês. Oferta generosa convence.")
	for cla in Clas.CLAS:
		var h := _card(c)
		_retrato(h, cla["id"])
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var rel: int = state["tags"].get(cla["id"], {"relacao": 0})["relacao"]
		_par(v, "%s — %s (%s %d)\n⚔ %s · pede ~%d + %d/mês · exige ⭐ %d" % [
			cla["nome"], cla["lider"], Dialogo.nome_relacao(rel), rel,
			str(cla["contingente"]), cla["preco_base"], cla["soldo"], cla["renome_min"]])
		var contrato := Clas.ativo(state, cla["id"])
		var pendente := false
		for m in state["mensageiros"]:
			if m["cla"] == cla["id"]:
				pendente = true
		if not contrato.is_empty():
			_par(v, "🤝 Sob contrato: restam %d meses." % contrato["meses"])
		elif pendente:
			_par(v, "🐴 Mensageiro na estrada...")
		else:
			var linha := HBoxContainer.new()
			v.add_child(linha)
			var oferta := SpinBox.new()
			oferta.min_value = 50
			oferta.max_value = 5000
			oferta.step = 50
			oferta.value = cla["preco_base"]
			linha.add_child(oferta)
			_botao(linha, "✉ Enviar mensageiro (10 🪙)", func():
				var r: Dictionary = Clas.enviar_mensageiro(state, cla["id"], int(oferta.value))
				Sfx.tocar(self, "pagina" if r["ok"] else "alerta")
				_aviso(r["msg"])
				Jogo.salvar(state)
				atualizar())
	_titulo_secao(c, "✉ Cartas recebidas")
	if state["cartas"].is_empty():
		_par(c, "Nenhuma carta sobre a mesa.")
	for carta in state["cartas"].slice(0, 6):
		_par(c, "— %s" % str(carta))

func _aba_intrigas(c: Container) -> void:
	_titulo_secao(c, "🕯 Mesa de Intrigas")
	if state["chantagem_pendente"] != null:
		_par(c, "✉ Chantagem em curso — escolha sua exigência:")
		var hb := HBoxContainer.new()
		c.add_child(hb)
		for par in [["ouro", "💰 Ouro"], ["casamento", "💍 Casamento forçado"], ["casusbelli", "📜 Casus Belli"]]:
			_botao(hb, par[1], func():
				Intriga.resolver_chantagem(state, par[0])
				Jogo.salvar(state)
				atualizar())
	_titulo_secao(c, "Segredos que você guarda")
	if state["segredos"].is_empty():
		_par(c, "Nenhum. Mande espiões às cortes.")
	for seg in state["segredos"]:
		_par(c, "✉ %s%s" % [seg["reino"], " (usado)" if seg["usado"] else " — chantageie o rei em conversa"])
	_titulo_secao(c, "Operações")
	for reino in state["reinos"]:
		if state["jogador"]["rei_de"] == reino["id"]:
			continue
		var h := _card(c)
		var l := Label.new()
		l.text = reino["nome"] + ("  📜 CB" if state["casus_belli"].has(reino["id"]) else "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		_botao(h, "🕵 Espionar (80)", func():
			_aviso(Intriga.espionar(state, reino["id"])["msg"])
			Jogo.salvar(state)
			atualizar())
		if not state["casus_belli"].has(reino["id"]):
			_botao(h, "📜 Forjar doc. (150)", func():
				_aviso(Intriga.forjar_documento(state, reino["id"])["msg"])
				Jogo.salvar(state)
				atualizar())

func _aba_familia(c: Container) -> void:
	var f: Dictionary = state["familia"]
	var j: Dictionary = state["jogador"]
	_titulo_secao(c, "🏰 Sua Casa")
	var a: Dictionary = j["atributos"]
	_par(c, "%s, %d anos — 💪%d 🗣%d 📊%d 🗡%d%s" % [j["nome"], j["idade"],
		a["forca"], a["carisma"], a["gestao"], a["intriga"],
		"  · reputação de crueldade" if int(j.get("crueldade", 0)) >= 3 else ""])
	if f["conjuge"] != null:
		_par(c, "💍 Casado com %s%s" % [f["conjuge"]["nome"],
			" (união sob pressão)" if f["conjuge"]["forcado"] else ""])
	else:
		_par(c, "Solteiro. Casamento real exige 40+ de renome e boa relação — peça a mão em conversa na corte.")
	_titulo_secao(c, "Herdeiros")
	if f["filhos"].is_empty():
		_par(c, "Nenhum filho. Sem herdeiro, sua morte é o fim da linhagem — e do jogo.")
	for filho in f["filhos"]:
		var fa: Dictionary = filho["atributos"]
		_par(c, "%s, %d anos — 💪%d 🗣%d 📊%d 🗡%d%s%s" % [filho["nome"], filho["idade"],
			fa["forca"], fa["carisma"], fa["gestao"], fa["intriga"],
			"  · mimado (vassalos conspirarão!)" if filho.get("mimado", false) else "",
			"  · herdeiro apto" if int(filho["idade"]) >= 16 else ""])

func _aba_cronica(c: Container) -> void:
	_titulo_secao(c, "📜 Crônica da Casa")
	for entrada in state["cronica"]:
		_par(c, "%s/A%d — %s" % [MESES[entrada["mes"] - 1].substr(0, 3), entrada["ano"], entrada["msg"]])

func _reino_local() -> Dictionary:
	for r in state["reinos"]:
		if r["id"] == state["local"]:
			return r
	return state["reinos"][0]

# ---------------- CONVERSA (ponderar + máquina de escrever) ----------------
func _montar_conversa() -> void:
	overlay_conversa = PanelContainer.new()
	overlay_conversa.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_conversa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	overlay_conversa.add_child(v)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	v.add_child(cab)
	conversa_retrato = TextureRect.new()
	conversa_retrato.custom_minimum_size = Vector2(96, 96)
	conversa_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	conversa_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	conversa_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cab.add_child(conversa_retrato)
	conversa_titulo = Label.new()
	conversa_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(conversa_titulo)
	var b_sair := Button.new()
	b_sair.text = "← Sair da conversa"
	b_sair.pressed.connect(fechar_conversa)
	cab.add_child(b_sair)
	conversa_hist = RichTextLabel.new()
	conversa_hist.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conversa_hist.scroll_following = true
	conversa_hist.bbcode_enabled = true
	v.add_child(conversa_hist)
	var form := HBoxContainer.new()
	v.add_child(form)
	conversa_input = LineEdit.new()
	conversa_input.placeholder_text = "Diga o que quiser..."
	conversa_input.max_length = 200
	conversa_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversa_input.text_submitted.connect(func(_t): enviar_texto(conversa_input.text))
	form.add_child(conversa_input)
	var b_falar := Button.new()
	b_falar.text = "Falar"
	b_falar.pressed.connect(func(): enviar_texto(conversa_input.text))
	form.add_child(b_falar)

func abrir_conversa(npc: Dictionary) -> void:
	npc_atual = npc
	overlay_conversa.visible = true
	conversa_texto = "[i]%s aguarda você falar...[/i]\n" % npc["nome"]
	conversa_hist.text = conversa_texto
	_atualizar_cab_conversa()
	conversa_input.grab_focus()

func fechar_conversa() -> void:
	overlay_conversa.visible = false
	npc_atual = {}
	atualizar()

func _atualizar_cab_conversa() -> void:
	if npc_atual.is_empty():
		return
	var rel: int = state["tags"].get(npc_atual["id"], {"relacao": 0})["relacao"]
	conversa_titulo.text = "%s\nrelação: %s (%d)" % [npc_atual["nome"], Dialogo.nome_relacao(rel), rel]
	conversa_retrato.texture = Retratos.textura(npc_atual["id"], Retratos.humor_de(state, npc_atual["id"]))

func enviar_texto(texto: String) -> void:
	texto = texto.strip_edges()
	if texto == "" or digitando or npc_atual.is_empty():
		return
	digitando = true
	conversa_input.text = ""
	conversa_input.placeholder_text = "%s está ouvindo..." % npc_atual["nome"]
	conversa_texto += "[b]Você:[/b] %s\n" % texto
	var resultado := Dialogo.falar(state, npc_atual, texto)
	conversa_hist.text = conversa_texto + "[i]%s pondera...[/i]" % npc_atual["nome"]
	_responder(resultado)

func _responder(resultado: Dictionary) -> void:
	# IA local (llama.cpp): tenta gerar a superfície do texto no processador do PC
	var texto_final: String = resultado["resposta"]
	if Llm.url() != "":
		var prompt := Dialogo.montar_prompt_llm(state, npc_atual, "", resultado)
		var gerado: String = await Llm.gerar(self, prompt)
		if gerado != "":
			texto_final = gerado
	# ponderar proporcional ao peso da resposta
	await get_tree().create_timer(clampf(0.5 + texto_final.length() * 0.009, 0.6, 2.4)).timeout
	Sfx.tocar(self, "pagina")
	# substitui a linha "pondera..." e digita letra a letra
	for i in range(0, texto_final.length(), 2):
		conversa_hist.text = conversa_texto + "[b]%s:[/b] %s" % [npc_atual["nome"], texto_final.substr(0, i + 2)]
		await get_tree().create_timer(0.024).timeout
	conversa_texto += "[b]%s:[/b] %s\n" % [npc_atual["nome"], texto_final]
	if not resultado["efeitos"].is_empty():
		conversa_texto += "[color=#8b2635]%s[/color]\n" % " ".join(resultado["efeitos"])
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
	overlay_modal = CenterContainer.new()
	overlay_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_modal)

func _modal(titulo: String, corpo: String, botoes: Array) -> void:
	for filho in overlay_modal.get_children():
		filho.queue_free()
	overlay_modal.visible = true
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(460, 0)
	overlay_modal.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	painel.add_child(v)
	var l_titulo := Label.new()
	l_titulo.text = titulo
	l_titulo.add_theme_font_size_override("font_size", 22)
	l_titulo.add_theme_color_override("font_color", Tema.SANGUE)
	v.add_child(l_titulo)
	var l_corpo := Label.new()
	l_corpo.text = corpo
	l_corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l_corpo)
	for par in botoes:
		var b := Button.new()
		b.text = par[0]
		var cb: Callable = par[1]
		b.pressed.connect(func():
			overlay_modal.visible = false
			cb.call())
		v.add_child(b)

func _modal_evento() -> void:
	var ev: Dictionary = state["evento_pendente"]
	Sfx.tocar(self, "alerta")
	match ev["tipo"]:
		"rebeliao":
			_modal("🔥 REBELIÃO!", "O povo marcha sobre sua residência com foices, tochas e uma lista de queixas escrita com fome.", [
				["⚔ Reprimir pela força", func(): _modal_batalha(Jogo.resolver_evento(state, "reprimir"))],
				["🕊 Abrir os celeiros e ceder", func():
					Jogo.resolver_evento(state, "conceder")
					Jogo.salvar(state)
					atualizar()],
			])
		"traicao_guardas":
			_modal("🌙 Traição por Ouro", "Sua guarda está sem soldo — e um reino rival ofereceu o dobro para abrirem seus portões esta noite.", [
				["💰 Pagar em dobro agora", func():
					Jogo.resolver_evento(state, "pagar")
					Jogo.salvar(state)
					atualizar()],
				["🎲 Confiar na lealdade deles", func():
					Jogo.resolver_evento(state, "recusar")
					Jogo.salvar(state)
					atualizar()],
			])
		_:
			state["evento_pendente"] = null
			atualizar()

func _modal_batalha(rel: Dictionary) -> void:
	if rel.is_empty():
		Jogo.salvar(state)
		atualizar()
		return
	Sfx.tocar(self, "tambor")
	Sfx.tocar(self, "vitoria" if rel["vitoria"] else "derrota")
	var corpo := ""
	for r in rel["rodadas"]:
		corpo += "Rodada %d: inimigo em %s — baixas: você −%d, inimigo −%d\n" % [
			r["rodada"], Dados.FORMACOES[r["formacao_inimiga"]]["nome"], r["baixas_j"], r["baixas_i"]]
	if rel["debandada"] != "":
		corpo += "Debandada: %s!\n" % rel["debandada"]
	corpo += "Cada soldado conta: você perdeu %d homens." % rel["baixas_jogador"]
	_modal("🏆 VITÓRIA — %s" % rel["contexto"] if rel["vitoria"] else "☠ DERROTA — %s" % rel["contexto"],
		corpo, [["Continuar", func():
			Jogo.salvar(state)
			atualizar()]])

func _modal_fim() -> void:
	var vitoria: bool = state["fim"]["tipo"] == "vitoria"
	_modal("👑 REINO POR CONQUISTA" if vitoria else "💀 FIM DA SAGA",
		"Você segurou o trono por um ano. Os bardos cantarão sua saga!" if vitoria
		else "Sua linhagem chega ao fim. As crônicas mal lembrarão seu nome.",
		[["Nova saga", func():
			Jogo.apagar_save()
			get_tree().reload_current_scene()]])

func _modal_llm() -> void:
	for filho in overlay_modal.get_children():
		filho.queue_free()
	overlay_modal.visible = true
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(460, 0)
	overlay_modal.add_child(painel)
	var v := VBoxContainer.new()
	painel.add_child(v)
	var l := Label.new()
	l.text = "🧠 IA Local — os personagens pensam no SEU processador.\n1. Baixe um modelo GGUF pequeno (ex.: Qwen2.5-1.5B Q4).\n2. Rode: llama-server -m modelo.gguf --port 8080\n3. Informe a URL abaixo (vazio = desligado):"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var campo := LineEdit.new()
	campo.text = Llm.url()
	campo.placeholder_text = "http://localhost:8080"
	v.add_child(campo)
	var b := Button.new()
	b.text = "Salvar"
	b.pressed.connect(func():
		Llm.definir_url(campo.text)
		overlay_modal.visible = false
		atualizar())
	v.add_child(b)
