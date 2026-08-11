# ============================================================
# ROTAS — leitura do grafo de estradas.
#
# `entre()` é o primitivo: procura "A_B", depois "B_A", e só então desiste
# num fallback caro. `caminho()` é o que dá sentido ao grafo — acha a rota
# mais curta atravessando terceiros, e é por isso que os gargalos importam:
# marchar do seu vale até os Cervos Escarlates custa passar pelo Império (ou
# dar a volta inteira pelo Jardim Azul, mais longe e mais perigoso).
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

## Trecho DIRETO entre dois vizinhos. Devolve sempre um dicionário utilizável
## — nunca null —, para nenhum chamador precisar tratar ausência.
static func entre(a: String, b: String) -> Dictionary:
	if a == b:
		return {"distancia": 0, "perigo": 0.0, "direta": true}
	var ida: String = a + "_" + b
	if Dados.ROTAS.has(ida):
		var r: Dictionary = Dados.ROTAS[ida].duplicate()
		r["direta"] = true
		return r
	var volta: String = b + "_" + a
	if Dados.ROTAS.has(volta):
		var r2: Dictionary = Dados.ROTAS[volta].duplicate()
		r2["direta"] = true
		return r2
	var f: Dictionary = Dados.ROTA_DESCONHECIDA.duplicate()
	f["direta"] = false
	return f

## Vizinhos diretos de um nó.
static func vizinhos(a: String) -> Array:
	var saida: Array = []
	for chave in Dados.ROTAS:
		var partes: PackedStringArray = chave.split("_", false)
		# ids compostos (sem_rei) têm underscore: reconstrói pelos extremos
		var par := _partes_da_chave(chave)
		if par.is_empty():
			continue
		if par[0] == a and not saida.has(par[1]):
			saida.append(par[1])
		elif par[1] == a and not saida.has(par[0]):
			saida.append(par[0])
	return saida

## "jogador_sem_rei" tem DOIS underscores. Quebrar em "_" cegamente daria
## ["jogador","sem","rei"]. Testamos cada corte contra os ids conhecidos.
static func _partes_da_chave(chave: String) -> Array:
	var ids := todos_os_nos()
	for id in ids:
		if chave.begins_with(id + "_"):
			var resto: String = chave.substr(id.length() + 1)
			if ids.has(resto):
				return [id, resto]
	return []

static func todos_os_nos() -> Array:
	# "barbaros" não está em REINOS_BASE de propósito: a fronteira selvagem
	# não é um reino, é o lugar onde ainda não há um. Mas É um nó do grafo,
	# e sem estar nesta lista nem `vizinhos()` nem `caminho()` a enxergam.
	var ids: Array = ["jogador", Dados.SEM_REI["id"], "barbaros"]
	for r in Dados.REINOS_BASE:
		ids.append(r["id"])
	return ids

## Caminho mais curto (Dijkstra sobre um grafo de 8 nós — sobra folga).
## Devolve {"nos": [...], "distancia": int, "perigo": float, "existe": bool}.
## `perigo` é a chance combinada de UM dia ruim em qualquer trecho.
static func caminho(a: String, b: String) -> Dictionary:
	if a == b:
		return {"nos": [a], "distancia": 0, "perigo": 0.0, "existe": true}
	var dist := {a: 0.0}
	var anterior := {}
	var pendentes: Array = [a]
	var visitados := {}
	while not pendentes.is_empty():
		# menor distância entre os pendentes
		var atual: String = pendentes[0]
		for n in pendentes:
			if float(dist.get(n, INF)) < float(dist.get(atual, INF)):
				atual = n
		pendentes.erase(atual)
		if atual == b:
			break
		visitados[atual] = true
		for v in vizinhos(atual):
			if visitados.has(v):
				continue
			var trecho := entre(atual, v)
			var alt: float = float(dist[atual]) + float(trecho["distancia"])
			if alt < float(dist.get(v, INF)):
				dist[v] = alt
				anterior[v] = atual
				if not pendentes.has(v):
					pendentes.append(v)

	if not dist.has(b):
		# sem ligação no grafo: atravessa o desconhecido
		var f := entre(a, b)
		return {"nos": [a, b], "distancia": int(f["distancia"]),
			"perigo": float(f["perigo"]), "existe": false}

	# reconstrói o caminho e soma o perigo trecho a trecho
	var nos: Array = [b]
	var passo: String = b
	while anterior.has(passo):
		passo = anterior[passo]
		nos.push_front(passo)
	var sobreviver := 1.0
	for i in range(nos.size() - 1):
		var t := entre(nos[i], nos[i + 1])
		sobreviver *= (1.0 - float(t["perigo"]))
	return {"nos": nos, "distancia": int(dist[b]),
		"perigo": 1.0 - sobreviver, "existe": true}

## Nome legível de um nó, para a UI e os relatórios.
static func nome_do(state: Dictionary, id: String) -> String:
	if id == "jogador":
		if state.get("terra") != null:
			return str(state["terra"]["nome"])
		return "Seu acampamento"
	if id == Dados.SEM_REI["id"]:
		return str(Dados.SEM_REI["nome"])
	for r in state["reinos"]:
		if r["id"] == id:
			return str(r["nome"])
	# a fronteira selvagem não é um reino ainda — mas tem nome no mapa
	if id == "barbaros":
		return "Terras Bárbaras"
	return id

## Descrição do trajeto para o modal de envio: "Vale do Corvo → Touros → Império".
static func descrever(state: Dictionary, rota: Dictionary) -> String:
	var partes: Array = []
	for n in rota.get("nos", []):
		partes.append(nome_do(state, n))
	return " → ".join(partes)
