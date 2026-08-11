# ============================================================
# VIAGEM — atravessar o mapa vira uma decisão, não um teletransporte.
#
# O botão "Viajar" era instantâneo e de graça: mudava `state.local` e
# pronto. Com o DIA existindo, a estrada passa a custar o que sempre
# devia custar — tempo do mês, e o risco de quem anda por ela.
#
# O grafo (rotas.gd) já sabia distância e perigo de cada trecho; esta
# camada só transforma isso em dias, em encontro de estrada e em escolha.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Rotas = preload("res://scripts/rotas.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Quantos campos de estrada cabem num dia de viagem SOZINHO. O exército
## anda mais devagar (marchas.gd tem a própria régua) — um homem a cavalo
## atravessa o que uma coluna leva semanas para vencer.
const CAMPOS_POR_DIA := 9

static func estimar(state: Dictionary, destino: String) -> Dictionary:
	var origem: String = str(state.get("local", ""))
	if origem == destino:
		return {"ok": false, "msg": "Você já está aqui.", "dias": 0}
	var c: Dictionary = Rotas.caminho(origem, destino)
	if not bool(c.get("existe", false)):
		return {"ok": false, "msg": "Não há estrada conhecida até lá.", "dias": 0}
	var dist: int = int(c["distancia"])
	var dias: int = clampi(ceili(float(dist) / float(CAMPOS_POR_DIA)), 1, 3)
	var perigo: float = float(c["perigo"])
	var nomes: Array = []
	for n in c["nos"]:
		nomes.append(Rotas.nome_do(state, str(n)))
	return {"ok": true, "dias": dias, "distancia": dist, "perigo": perigo,
		"trajeto": " → ".join(nomes),
		"risco_txt": _texto_risco(perigo),
		"nos": c["nos"]}

static func _texto_risco(p: float) -> String:
	if p >= 0.30:
		return "estrada sem lei"
	if p >= 0.18:
		return "moderado"
	if p >= 0.09:
		return "baixo"
	return "seguro"

## A viagem. Consome os dias, resolve UM encontro de estrada e chega.
##
## O encontro não é castigo automático: metade das vezes é uma CHANCE —
## uma caravana mal escoltada passando no sentido contrário. Saquear paga
## bem e custa honra; deixar passar não custa nada além do que você não
## ganhou. É a escolha que o pedido chamava de "saque na estrada".
static func viajar(state: Dictionary, destino: String, log: Callable = Callable()) -> Dictionary:
	var est := estimar(state, destino)
	if not bool(est["ok"]):
		return est
	var Jogo = load("res://scripts/jogo.gd")
	var dias: int = int(est["dias"])
	if int(state.get("dia", 1)) + dias > Jogo.DIAS_POR_MES + 1:
		return {"ok": false, "sem_tempo": true,
			"msg": "A viagem leva %d %s e o mês não tem tanto. Feche o mês antes." % [
				dias, "dia" if dias == 1 else "dias"]}

	var ev := _encontro(state, float(est["perigo"]))
	state["local"] = destino
	for i in dias:
		Jogo.passar_dia(state, log)
		if state["fim"] != null:
			break
	if log.is_valid():
		log.call("Você viaja até %s — %d %s de estrada." % [
			Rotas.nome_do(state, destino), dias, "dia" if dias == 1 else "dias"])
	Sinais.emitir(&"viagem", {"destino": destino, "dias": dias})
	est["encontro"] = ev
	return est

## O que a estrada guarda. Devolve {} quando o caminho foi calmo.
static func _encontro(state: Dictionary, perigo: float) -> Dictionary:
	if randf() >= perigo:
		return {}
	# metade dos encontros é oportunidade, metade é problema
	if randf() < 0.5:
		var bolsa: int = Dados.ri(60, 200)
		return {"tipo": "caravana", "ouro": bolsa,
			"titulo": "Uma caravana na curva",
			"texto": "Seis mulas, dois guardas sonolentos e fardos que valem uns %d de ouro. Ninguém por perto." % bolsa}
	return {"tipo": "assalto", "titulo": "Salteadores na estrada",
		"texto": "Saem do mato antes de você ouvir. Não querem conversa — querem a bolsa."}

## Aceitar o assalto: eles levam uma fatia do que você carrega. Fatia, e
## não tudo — a mesma régua proporcional dos empregos.
static func resolver_assalto(state: Dictionary, log: Callable = Callable()) -> Dictionary:
	var j: Dictionary = state["jogador"]
	var perdido: int = roundi(int(j["ouro"]) * 0.25)
	j["ouro"] = maxi(0, int(j["ouro"]) - perdido)
	if log.is_valid():
		log.call("Salteadores levaram %d de ouro na estrada." % perdido)
	return {"ouro_perdido": perdido}

## Saquear a caravana: ouro agora, nome depois. Honra é proporcional, como
## em todo o resto do jogo.
static func saquear_caravana(state: Dictionary, ouro: int,
		log: Callable = Callable()) -> Dictionary:
	var j: Dictionary = state["jogador"]
	j["ouro"] = int(j["ouro"]) + ouro
	var antes: int = int(j.get("honra", 50))
	j["honra"] = maxi(0, roundi(antes * 0.85))
	j["crueldade"] = int(j.get("crueldade", 0)) + 1
	if log.is_valid():
		log.call("Você saqueou uma caravana na estrada: +%d de ouro, honra %d → %d."
			% [ouro, antes, int(j["honra"])])
	return {"ouro": ouro, "honra": int(j["honra"])}
