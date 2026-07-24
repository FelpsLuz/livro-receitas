# Cena inicial da fase 1: demonstra o núcleo rodando.
# A fase 2 substitui esta cena pelas telas do jogo.
extends Control

const Jogo = preload("res://scripts/jogo.gd")
const Dialogo = preload("res://scripts/dialogo.gd")

func _ready() -> void:
	var s := Jogo.novo_jogo("Demonstração")
	print("Estado criado: %s, %d de ouro, %d reinos." %
		[s["jogador"]["nome"], s["jogador"]["ouro"], s["reinos"].size()])
	var r := Dialogo.falar(s, s["reinos"][0]["rei"], "saudações, majestade")
	print("Rei Aldric responde: ", r["resposta"])
