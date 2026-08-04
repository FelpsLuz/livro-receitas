# ============================================================
# TEMA MEDIEVAL — pergaminho, madeira e ouro, criado em código.
# ============================================================
extends RefCounted

const MADEIRA := Color("2b1d12")
const MADEIRA_CLARA := Color("4a3421")
const PERGAMINHO := Color("e8d8b0")
const PERGAMINHO_CLARO := Color("f5ecd4")
const TINTA := Color("2d1f10")
const OURO := Color("c9a227")
const SANGUE := Color("8b2635")
const VERDE := Color("3e5f3e")

static func criar() -> Theme:
	var t := Theme.new()

	var painel := StyleBoxFlat.new()
	painel.bg_color = PERGAMINHO
	painel.border_color = MADEIRA_CLARA
	painel.set_border_width_all(2)
	painel.set_corner_radius_all(6)
	painel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", painel)

	# OVERHAUL v2: se a moldura Pro do PixelLab existir, ela substitui o painel
	# chapado em TODA a interface de uma vez (StyleBoxTexture com 9-slice, então
	# os cantos não deformam). Sem o PNG, segue valendo o StyleBoxFlat acima.
	var UIv2 = load("res://scripts/ui_v2.gd")
	var moldura = UIv2.stylebox("painel_madeira")
	if moldura != null:
		t.set_stylebox("panel", "PanelContainer", moldura)
		t.set_stylebox("panel", "Panel", moldura)
	# botões de madeira Pro, nos quatro estados
	var bts: Dictionary = UIv2.estilos_botao()
	for estado in bts.keys():
		t.set_stylebox(estado, "Button", bts[estado])

	var botao := StyleBoxFlat.new()
	botao.bg_color = Color("5d4428")
	botao.border_color = OURO
	botao.set_border_width_all(2)
	botao.set_corner_radius_all(4)
	botao.set_content_margin_all(8)
	t.set_stylebox("normal", "Button", botao)
	var botao_hover := botao.duplicate()
	botao_hover.bg_color = Color("7d5a3a")
	t.set_stylebox("hover", "Button", botao_hover)
	var botao_press := botao.duplicate()
	botao_press.bg_color = Color("3a2a18")
	t.set_stylebox("pressed", "Button", botao_press)
	t.set_color("font_color", "Button", PERGAMINHO)
	t.set_color("font_hover_color", "Button", Color.WHITE)

	var entrada := StyleBoxFlat.new()
	entrada.bg_color = PERGAMINHO_CLARO
	entrada.border_color = MADEIRA_CLARA
	entrada.set_border_width_all(2)
	entrada.set_corner_radius_all(4)
	entrada.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", entrada)
	t.set_color("font_color", "LineEdit", TINTA)
	t.set_color("caret_color", "LineEdit", TINTA)

	t.set_color("font_color", "Label", TINTA)
	t.set_color("default_color", "RichTextLabel", TINTA)

	var aba_sel := StyleBoxFlat.new()
	aba_sel.bg_color = PERGAMINHO
	aba_sel.set_corner_radius_all(4)
	aba_sel.set_content_margin_all(8)
	var aba_normal := aba_sel.duplicate()
	aba_normal.bg_color = MADEIRA_CLARA
	t.set_stylebox("tab_selected", "TabContainer", aba_sel)
	t.set_stylebox("tab_unselected", "TabContainer", aba_normal)
	t.set_color("font_selected_color", "TabContainer", TINTA)
	t.set_color("font_unselected_color", "TabContainer", Color("d4c090"))
	var aba_painel := painel.duplicate()
	t.set_stylebox("panel", "TabContainer", aba_painel)

	return t
