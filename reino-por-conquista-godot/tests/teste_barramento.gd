# ============================================================
# TESTE DO BARRAMENTO — roda como CENA, não com --script.
#
# Este é o outro lado da ponte: teste_fase3.gd prova que o núcleo funciona
# SEM autoload (modo --script); este prova que COM autoload os sinais
# realmente chegam à UI. Os dois juntos cobrem os dois ambientes reais.
#   godot --headless --path . res://tests/teste_barramento.tscn
# ============================================================
extends Node

const Jogo = preload("res://scripts/jogo.gd")
const Recrutamento = preload("res://scripts/recrutamento.gd")
const Geopolitica = preload("res://scripts/geopolitica.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Sinais = preload("res://scripts/sinais.gd")

var passou := 0
var falhou := 0
var recebidos: Array = []

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func _ready() -> void:
	seed(99)
	print("=== BARRAMENTO DE SINAIS (modo cena, com autoload) ===")
	Sinais.esquecer()

	var bus := Sinais.bus()
	ok("autoload encontrado a partir de uma static func", bus != null)
	if bus == null:
		_fim()
		return

	bus.tropa_pronta.connect(func(info): recebidos.append(["tropa_pronta", info]))
	bus.fila_vazia.connect(func(): recebidos.append(["fila_vazia", {}]))
	bus.cidadao_ascendeu.connect(func(info): recebidos.append(["cidadao_ascendeu", info]))
	bus.conquista_npc.connect(func(info): recebidos.append(["conquista_npc", info]))

	# ---- o núcleo estático emite, a UI recebe ----
	var s := Jogo.novo_jogo("Barramento")
	s["terra"] = {"nome": "T", "nivel": 2, "populacao": 120, "alimento": 400,
		"madeira": 50, "felicidade": 80, "pressao": 0.0}
	s["jogador"]["ouro"] = 5000
	Recrutamento.enfileirar(s, "lanceiro", 2)
	Recrutamento.avancar(s, 1000)
	ok("sinal de tropa pronta chegou à cena", _tem("tropa_pronta"),
		"%d sinais" % recebidos.size())
	ok("sinal de fila vazia chegou", _tem("fila_vazia"))
	var info: Dictionary = _primeiro("tropa_pronta")
	ok("o sinal carrega os dados certos", info.get("tipo") == "lanceiro")

	# cidadão que ascende também anuncia
	var c := Jogo.novo_jogo("Lorde")
	c["terra"] = {"nome": "L", "nivel": 5, "populacao": 200, "alimento": 900,
		"madeira": 50, "felicidade": 95, "pressao": 0.0}
	Cidadaos.tick(c, Jogo.log_para(c))
	for n in Cidadaos.lista(c):
		n["lealdade"] = 95
		n["riqueza"] = 500
	Cidadaos.tick(c, Jogo.log_para(c))
	ok("ascensão a lorde anuncia no barramento", _tem("cidadao_ascendeu"))

	_fim()

func _tem(nome: String) -> bool:
	for r in recebidos:
		if r[0] == nome:
			return true
	return false

func _primeiro(nome: String) -> Dictionary:
	for r in recebidos:
		if r[0] == nome:
			return r[1] if r[1] is Dictionary else {}
	return {}

func _fim() -> void:
	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	get_tree().quit(1 if falhou > 0 else 0)
