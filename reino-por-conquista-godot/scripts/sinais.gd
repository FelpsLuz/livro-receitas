# ============================================================
# PONTE DE SINAIS — liga o núcleo estático ao barramento de eventos da cena.
#
# O problema: a forma canônica de ter Signals globais na Godot é um autoload,
# e um autoload É alcançável de dentro de uma `static func`. Mas os testes
# rodam com `godot --script`, e NESSE MODO O AUTOLOAD NÃO É REGISTRADO —
# citar o identificador global derruba a suíte inteira com erro de COMPILAÇÃO
# ("Identifier not found"), antes mesmo de rodar.
#
# A saída: resolver o nó em tempo de execução, sem nunca escrever o nome dele
# como identificador. Onde há barramento, emite; onde não há (teste headless),
# devolve false em silêncio. Verificado nos dois modos.
# ============================================================
extends RefCounted

const CAMINHO := "Eventos"

static var _bus: Node = null
static var _procurou := false

## O nó do barramento, ou null quando não existe (testes headless).
static func bus() -> Node:
	if not _procurou:
		_procurou = true
		var laco := Engine.get_main_loop()
		if laco is SceneTree and laco.root != null:
			_bus = laco.root.get_node_or_null(CAMINHO)
	return _bus

## Emite um sinal do barramento. Devolve false quando não há para onde emitir —
## o chamador nunca precisa saber se está num teste ou no jogo.
##
## `arg` omitido emite SEM argumento: um `emit_signal(nome, null)` num sinal
## de zero parâmetros é erro em runtime ("expected 0 arguments, but called
## with 1") e só aparece rodando como cena, nunca no --script dos testes.
static func emitir(nome: StringName, arg = null) -> bool:
	var b := bus()
	if b == null or not b.has_signal(nome):
		return false
	if arg == null:
		b.emit_signal(nome)
	else:
		b.emit_signal(nome, arg)
	return true

## Só para os testes: esquece o que achou, para reavaliar o ambiente.
static func esquecer() -> void:
	_bus = null
	_procurou = false
