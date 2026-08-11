# ============================================================
# TRABALHO NA TAVERNA — o chão de fábrica do mercenário sem nome.
#
# É a resposta ao buraco que o teste alfa achou: sem ouro, sem tropas e
# sem terra, NÃO existia ação que gerasse renda, e a partida virava um
# estado zumbi. Agora existe — mas cobra o preço certo.
#
# A NOTAÇÃO DE RISCO, que vale para a tabela inteira: o número é a
# CHANCE e é também a FRAÇÃO perdida do que você tem. "honra 10" = 10%
# de chance de perder 10% da honra que você tem hoje. Perda proporcional
# nunca zera de um golpe e dói mais em quem tem mais a perder — um
# mercenário sem nome não teme escândalo; um Conde, sim.
#
# O jogador NUNCA vê as porcentagens: vê o aviso em texto ("dizem que o
# último não voltou"). A régua fica aqui.
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Turnos: 1, 2 ou 3 dias. Trabalhar mais paga proporcionalmente melhor
## E arrisca proporcionalmente mais — é a mesma escolha da marcha longa.
const BONUS_PAGA := [1.0, 1.2, 1.3]
const FATOR_RISCO := [1.0, 1.5, 2.0]

## Pontos de trabalho por atributo ganho. Dez dias de forja por um ponto
## de Força: o atributo é caro de propósito, senão a taverna vira academia.
const PONTOS_POR_PONTO := 10
const ATRIBUTO_MAX := 10

## Os doze ofícios. `nivel` é a faixa da região (1 pobre, 3 rica);
## `honra_min`/`honra_max` são o filtro de reputação: o conselho real não
## contrata um bandido conhecido, e O Corvo não confia num santo.
const EMPREGOS := [
	{"id": "lenhador", "nome": "Lenhador da fronteira", "papel": "Ancião da vila",
		"atributo": "forca", "paga": 18, "nivel": 1,
		"riscos": {"morte": 5},
		"desc": "Derrubar pinheiro na linha da mata, onde a floresta ainda é de ninguém.",
		"aviso": "Árvore não avisa para que lado cai."},
	{"id": "pregador", "nome": "Pregador de rua", "papel": "Sacerdote líder",
		"atributo": "carisma", "paga": 20, "nivel": 1, "honra_min": 35,
		"riscos": {"prisao": 10},
		"desc": "Subir no caixote da praça e falar até a moeda cair no chapéu.",
		"aviso": "Nem todo sermão agrada a guarda."},
	{"id": "bardo", "nome": "Bardo da corte", "papel": "Nobre local",
		"atributo": "carisma", "paga": 24, "nivel": 1, "honra_min": 30,
		"riscos": {"honra": 10, "moral": 10},
		"desc": "Cantar feitos alheios no salão de um nobre, por moeda e sobras.",
		"aviso": "Soldado não respeita senhor que canta para nobre."},
	{"id": "obras", "nome": "Supervisor de obras", "papel": "Arquiteto real",
		"atributo": "gestao", "paga": 22, "nivel": 1, "honra_min": 40,
		"riscos": {"honra": 10},
		"desc": "Contar pedra, medir vala e brigar com pedreiro que bebeu.",
		"aviso": "Obra atrasada sempre acha um culpado."},
	{"id": "intendente", "nome": "Intendente de suprimentos", "papel": "Comandante da guarda",
		"atributo": "gestao", "paga": 28, "nivel": 2, "honra_min": 55,
		"riscos": {"honra": 15},
		"desc": "Fechar as contas do celeiro da guarnição antes da inspeção.",
		"aviso": "Todo livro fechado depressa tem uma linha torta."},
	{"id": "reliquias", "nome": "Negociante de relíquias", "papel": "Mercador viajante",
		"atributo": "carisma", "paga": 34, "nivel": 2,
		"riscos": {"honra": 20},
		"desc": "Vender o dedo de um santo — o terceiro dedo esquerdo desta semana.",
		"aviso": "Freguês devoto tem memória longa."},
	{"id": "cobrador", "nome": "Cobrador de dívidas", "papel": "Agiota do submundo",
		"atributo": "forca", "paga": 40, "nivel": 2, "honra_max": 60,
		"riscos": {"morte": 10, "prisao": 10},
		"desc": "Bater na porta certa e sair com o que é devido, do jeito que der.",
		"aviso": "Devedor encurralado às vezes tem faca."},
	{"id": "guarda_costas", "nome": "Guarda-costas", "papel": "Barão do comércio",
		"atributo": "forca", "paga": 46, "nivel": 2,
		"riscos": {"morte": 15},
		"desc": "Andar dois passos atrás de um homem que muita gente quer morto.",
		"aviso": "O último durou meia estrada."},
	{"id": "diplomata", "nome": "Diplomata emissário", "papel": "Lorde do Castelo",
		"atributo": "carisma", "paga": 32, "nivel": 3, "honra_min": 60,
		"riscos": {"prisao": 5, "honra": 15},
		"desc": "Levar palavra de paz a uma corte que preferia mandar cabeças.",
		"aviso": "Mensageiro também é resposta."},
	{"id": "gladiador", "nome": "Gladiador de poço", "papel": "Mestre da arena",
		"atributo": "forca", "paga": 80, "nivel": 3,
		"riscos": {"morte": 25},
		"desc": "Descer no poço de areia. Sobe um. A bolsa é do que sobe.",
		"aviso": "A areia é trocada toda noite. Não é por limpeza."},
	{"id": "espiao_conselho", "nome": "Espião do conselho", "papel": "Conselheiro real",
		"atributo": "intriga", "paga": 70, "nivel": 3, "honra_min": 45,
		"riscos": {"morte": 20, "prisao": 30},
		"desc": "Ouvir o que se fala na corte vizinha e voltar com a boca fechada.",
		"aviso": "Quem manda você não vai admitir que te conhece."},
	{"id": "falsificador", "nome": "Falsificador de selos", "papel": "O Corvo",
		"atributo": "intriga", "paga": 60, "nivel": 3, "honra_max": 45,
		"riscos": {"prisao": 40, "honra": 25},
		"desc": "Refazer em cera o brasão de uma casa que nunca assinou aquilo.",
		"aviso": "Cera esfria. Testemunha, não."},
]

static func por_id(id: String) -> Dictionary:
	for e in EMPREGOS:
		if e["id"] == id:
			return e
	return {}

# ------------------------------------------------------------
# A ESCALA POR REGIÃO
# ------------------------------------------------------------
## Reino rico paga mais e oferece o serviço mais perigoso; reino pobre
## paga pouco e só tem trabalho de vila. A régua é o TESOURO que a
## geopolítica já mantém — nenhum número novo inventado.
static func fator_reino(state: Dictionary, reino_id: String) -> float:
	var Geopolitica = load("res://scripts/geopolitica.gd")
	var r: Dictionary = Geopolitica.reino_por_id(state, reino_id)
	if r.is_empty():
		return 0.7                              # terra de ninguém paga mal
	return clampf(float(int(r.get("tesouro", 800))) / 1200.0, 0.7, 2.0)

## As faixas que uma taverna oferece, pelo bolso do reino.
static func _niveis_de(fator: float) -> Array:
	if fator >= 1.5:
		return [2, 3, 3]
	if fator >= 1.0:
		return [1, 2, 2]
	return [1, 1, 2]

## O quadro de empregos DESTA taverna. Estável na partida inteira (o
## sorteio é por hash do reino, não por dado), para o jogador aprender
## onde fica cada ofício — e diferente em cada reino, que é o pedido.
static func do_reino(state: Dictionary, reino_id: String) -> Array:
	var fator: float = fator_reino(state, reino_id)
	var vagas: Array = []
	var usados: Array[String] = []
	for nivel in _niveis_de(fator):
		var pool: Array = EMPREGOS.filter(func(e):
			return int(e["nivel"]) == nivel and not usados.has(str(e["id"])))
		if pool.is_empty():
			continue
		var escolhido: Dictionary = pool[_hash(reino_id + "|" + str(nivel)
			+ "|" + str(usados.size())) % pool.size()]
		usados.append(str(escolhido["id"]))
		var v: Dictionary = escolhido.duplicate(true)
		v["patrao"] = _nome_do_patrao(reino_id, str(escolhido["id"]), str(escolhido["papel"]))
		v["paga_dia"] = maxi(1, roundi(int(escolhido["paga"]) * fator))
		vagas.append(v)
	return vagas

static func _hash(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = ((h ^ s.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h

## O patrão tem NOME, não só cargo: é o que faz a taverna do Covil Negro
## não ser a mesma taverna de Aurora Alta com outra tinta.
static func _nome_do_patrao(reino_id: String, emprego_id: String, papel: String) -> String:
	var semente: int = _hash(reino_id + "|" + emprego_id + "|patrao")
	var nomes: Array = Dados.NOMES_M if semente % 2 == 0 else Dados.NOMES_F
	return "%s %s — %s" % [nomes[semente % nomes.size()],
		Dados.SOBRENOMES[(semente / 7) % Dados.SOBRENOMES.size()], papel]

# ------------------------------------------------------------
# PEDIR EMPREGO — a porta que precisa ser aberta antes de trabalhar
# ------------------------------------------------------------
static func honra(state: Dictionary) -> int:
	return int(state["jogador"].get("honra", 50))

static func _chave(reino_id: String, emprego_id: String) -> String:
	return reino_id + ":" + emprego_id

static func contratado(state: Dictionary, reino_id: String, emprego_id: String) -> bool:
	return bool(state.get("empregos", {}).get(_chave(reino_id, emprego_id), false))

## Por que o patrão aceita ou recusa. Devolve msg em personagem — a
## reputação do jogador é a entrevista inteira.
static func pedir_emprego(state: Dictionary, reino_id: String, emprego_id: String) -> Dictionary:
	var e: Dictionary = por_id(emprego_id)
	if e.is_empty():
		return {"ok": false, "msg": "Esse trabalho não existe por aqui."}
	if contratado(state, reino_id, emprego_id):
		return {"ok": false, "msg": "Você já trabalha para ele."}
	var h: int = honra(state)
	if e.has("honra_min") and h < int(e["honra_min"]):
		return {"ok": false, "msg": "\"Ouvi falar de você. Não o bastante de bom. Procure outro.\""}
	if e.has("honra_max") and h > int(e["honra_max"]):
		return {"ok": false, "msg": "\"Você tem nome demais para este serviço. Nomes falam.\""}
	if not state.has("empregos"):
		state["empregos"] = {}
	state["empregos"][_chave(reino_id, emprego_id)] = true
	Sinais.emitir(&"emprego_conseguido", {"reino": reino_id, "emprego": emprego_id})
	return {"ok": true, "msg": "\"Apareça amanhã ao amanhecer. E não me faça esperar.\""}

# ------------------------------------------------------------
# TRABALHAR
# ------------------------------------------------------------
## Um turno de 1 a 3 dias. O tempo do jogo ANDA (é esse o custo real),
## a bolsa engorda, o atributo sobe um degrau — e o dado do risco rola
## uma vez só, com peso proporcional ao tamanho do turno.
static func trabalhar(state: Dictionary, reino_id: String, emprego_id: String,
		dias: int, log: Callable = Callable()) -> Dictionary:
	var e: Dictionary = por_id(emprego_id)
	if e.is_empty():
		return {"ok": false, "msg": "Trabalho desconhecido."}
	if not contratado(state, reino_id, emprego_id):
		return {"ok": false, "msg": "Peça o emprego ao patrão primeiro."}
	dias = clampi(dias, 1, 3)
	var Jogo = load("res://scripts/jogo.gd")
	if int(state.get("dia", 1)) + dias > Jogo.DIAS_POR_MES + 1:
		return {"ok": false, "msg": "Não sobra mês para esse turno. Passe o mês antes."}

	var j: Dictionary = state["jogador"]
	var fator: float = FATOR_RISCO[dias - 1]
	var ev: Dictionary = {"ok": true, "emprego": emprego_id, "dias": dias,
		"paga": 0, "consequencias": [], "morreu": false}

	# ---- o dado do risco, uma vez por turno ----
	var riscos: Dictionary = e["riscos"]
	for tipo in riscos:
		var chance := float(int(riscos[tipo])) / 100.0
		if randf() >= chance * fator:
			continue
		var perda := float(int(riscos[tipo])) / 100.0   # o número é chance E fração
		match str(tipo):
			"morte":
				ev["morreu"] = true
				ev["consequencias"].append("Você não voltou do turno.")
			"prisao":
				var meses: int = 2 if int(riscos[tipo]) >= 30 else 1
				ev["prender"] = meses
				ev["consequencias"].append("A guarda levou você: %d %s a ferros."
					% [meses, "mês" if meses == 1 else "meses"])
			"honra":
				var antes: int = honra(state)
				j["honra"] = maxi(0, roundi(antes * (1.0 - perda)))
				ev["consequencias"].append("A história correu a praça: honra %d → %d."
					% [antes, int(j["honra"])])
			"moral":
				var m_antes := int(j.get("moral", 100))
				j["moral"] = maxi(0, roundi(m_antes * (1.0 - perda)))
				ev["consequencias"].append("A tropa ouviu falar: moral %d → %d."
					% [m_antes, int(j["moral"])])

	# ---- morte encerra tudo: sem paga, sem atributo ----
	if bool(ev["morreu"]):
		if log.is_valid():
			log.call("%s morre trabalhando como %s." % [str(j["nome"]), str(e["nome"])])
		Jogo.morrer(state, "trabalho de " + str(e["nome"]), log)
		Sinais.emitir(&"trabalho_terminou", ev)
		return ev

	# ---- a bolsa ----
	var vaga: Dictionary = _vaga_ou_base(state, reino_id, emprego_id, e)
	ev["paga"] = maxi(1, roundi(int(vaga["paga_dia"]) * dias * BONUS_PAGA[dias - 1]))
	j["ouro"] = int(j["ouro"]) + int(ev["paga"])

	# ---- o ofício deixa marca: um ponto de progresso por dia ----
	var atrib := str(e["atributo"])
	if not state.has("progresso_atributo"):
		state["progresso_atributo"] = {}
	var prog: Dictionary = state["progresso_atributo"]
	prog[atrib] = int(prog.get(atrib, 0)) + dias
	while int(prog[atrib]) >= PONTOS_POR_PONTO \
			and int(j["atributos"].get(atrib, 0)) < ATRIBUTO_MAX:
		prog[atrib] = int(prog[atrib]) - PONTOS_POR_PONTO
		j["atributos"][atrib] = int(j["atributos"].get(atrib, 0)) + 1
		ev["consequencias"].append("Os anos de ofício aparecem: %s sobe para %d."
			% [atrib.capitalize(), int(j["atributos"][atrib])])
		ev["subiu"] = atrib
	# no teto o progresso para de acumular, senão viraria dívida invisível
	if int(j["atributos"].get(atrib, 0)) >= ATRIBUTO_MAX:
		prog[atrib] = 0

	if log.is_valid():
		log.call("%d %s de %s: +%d de ouro." % [dias, "dia" if dias == 1 else "dias",
			str(e["nome"]).to_lower(), int(ev["paga"])])

	# ---- o tempo anda: é o custo que não aparece na bolsa ----
	for i in dias:
		Jogo.passar_dia(state, log)
		if state["fim"] != null:
			break
	if ev.has("prender"):
		Jogo.prender(state, int(ev["prender"]), log)
	Sinais.emitir(&"trabalho_terminou", ev)
	return ev

## A vaga desta taverna (com a paga já escalada pelo reino); se o emprego
## não estiver no quadro de hoje, vale a paga-base — quem foi contratado
## continua contratado.
static func _vaga_ou_base(state: Dictionary, reino_id: String,
		emprego_id: String, e: Dictionary) -> Dictionary:
	for v in do_reino(state, reino_id):
		if str(v["id"]) == emprego_id:
			return v
	return {"paga_dia": maxi(1, roundi(int(e["paga"]) * fator_reino(state, reino_id)))}
