# ============================================================
# MOTOR DE DIÁLOGO LIVRE (port GDScript de js/dialogue.js)
# Intenção + sentimento + memória por tags + vozes por
# personalidade. Ponto de encaixe para LLM local (llama.cpp
# via HTTPRequest) preservado em montar_prompt_llm().
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")

const INTENCOES := [
	{"id": "insulto", "palavras": ["idiota", "burro", "burra", "covarde", "porco", "porca", "verme",
		"inutil", "tolo", "tola", "patetico", "patetica", "fraco", "fraca", "lixo", "imbecil",
		"canalha", "rato", "miseravel", "tirano", "usurpador", "bastardo"]},
	{"id": "elogio", "palavras": ["sabio", "sabia", "sabedoria", "forte", "grande", "magnifico",
		"magnifica", "honrado", "honrada", "belo", "bela", "glorioso", "gloriosa", "admiro",
		"respeito", "corajoso", "justo", "generoso", "lendario", "lendaria", "brilhante",
		"poderoso", "poderosa", "nobre", "maravilhoso", "excelente", "incrivel"]},
	{"id": "ameaca", "palavras": ["vou te matar", "queimar", "destruir", "invadir", "vinganca",
		"pagara caro", "declaro guerra", "morrera", "arrependera"]},
	{"id": "saudacao", "palavras": ["ola", "oi", "saudacoes", "bom dia", "boa noite", "majestade",
		"vossa alteza", "meu rei", "minha rainha", "salve"]},
	{"id": "despedida", "palavras": ["adeus", "tchau", "ate logo", "me retiro", "partir"]},
	{"id": "perguntar_guerra", "palavras": ["guerra", "batalha", "conflito", "inimigo", "exercito",
		"tropas", "campanha"]},
	{"id": "perguntar_preco", "palavras": ["preco", "mercado", "comprar", "vender", "comercio",
		"trigo", "ferro", "sal", "madeira", "tecidos", "cavalos", "quanto custa", "mercadoria"]},
	{"id": "pedir_contrato", "palavras": ["contrato", "trabalho", "servico", "missao", "emprego",
		"mercenario", "escolta", "me contrate", "tarefa"]},
	{"id": "subornar", "palavras": ["ouro para voce", "te pago", "suborno", "presente", "uma oferta",
		"te dou ouro"]},
	{"id": "pedir_casamento", "palavras": ["casamento", "casar", "mao de sua", "mao da sua",
		"noivado", "matrimonio", "unir nossas casas"]},
	{"id": "chantagear", "palavras": ["sei o que voce fez", "segredo", "todos vao saber", "chantagem",
		"revelar", "contarei a todos", "eu sei sobre"]},
	{"id": "pedir_paz", "palavras": ["paz", "tregua", "cessar", "acordo de paz", "fim da guerra"]},
]

const VOZES := {
	"orgulhoso": {
		"insulto": ["Como OUSA falar assim comigo?! Guardas, memorizem este rosto.",
			"Palavras de um verme. Minha paciência com você acabou."],
		"insulto_grave": ["Você acaba de assinar sua sentença. Ninguém me insulta duas vezes e vive para se gabar."],
		"elogio": ["Hm. Ao menos você reconhece grandeza quando a vê.",
			"Palavras adequadas. Continue assim e talvez eu lembre do seu nome."],
		"ameaca": ["Você? Me ameaçar? Meus cavaleiros já esmagaram reinos por menos."],
		"saudacao": ["Fale logo. Meu tempo vale mais que o seu.", "Aproxime-se. E meça suas palavras."],
		"neutro": ["Vá direto ao ponto.", "Estou ouvindo. Por enquanto."],
	},
	"calculista": {
		"insulto": ["*anota algo num pergaminho* Interessante. Isso terá um custo, sabe."],
		"insulto_grave": ["*sorri sem os olhos* As pessoas que falam assim comigo costumam ter... acidentes."],
		"elogio": ["Bajulação. Barata, mas registrada. O que você quer de verdade?"],
		"ameaca": ["Ameaças são promessas de gente fraca. Você é fraco, ou é uma promessa?"],
		"saudacao": ["Sente-se. Toda conversa é uma negociação — comece a sua."],
		"neutro": ["Cada palavra sua está sendo pesada. Prossiga."],
	},
	"ganancioso": {
		"insulto": ["Insultos não pagam minhas taxas. Mas vão encarecer as suas."],
		"insulto_grave": ["Você acaba de virar persona non grata no meu mercado. Boa sorte pagando o dobro."],
		"elogio": ["Haha! Gosto de você. Bajuladores ganham... 5% de desconto. Talvez."],
		"ameaca": ["Ameaças? Eu compro lâminas melhores do que as suas com o troco do café."],
		"saudacao": ["Bem-vindo, bem-vindo! Veio gastar ou desperdiçar meu tempo?"],
		"neutro": ["Tempo é ouro. E você está gastando os dois."],
	},
	"honrado": {
		"insulto": ["Palavras rudes dizem mais sobre você do que sobre mim. Estou desapontado."],
		"insulto_grave": ["Chega. Você não é bem-vindo aqui até aprender respeito."],
		"elogio": ["Agradeço, mas prefiro ser julgado por meus atos, não por palavras doces."],
		"ameaca": ["Não busco guerra, mas não fugirei de uma. Pense bem no que está começando."],
		"saudacao": ["Seja bem-vindo. Fale com franqueza — é tudo que peço."],
		"neutro": ["Fale com sinceridade e será ouvido."],
	},
	"cruel": {
		"insulto": ["Continue. Estou decidindo qual dos seus dedos vai primeiro."],
		"insulto_grave": ["*sorri* Você tem coragem. Vou arrancá-la de você lentamente."],
		"elogio": ["Medo vestido de elogio. Sensato. Continue com medo."],
		"ameaca": ["*inclina-se para frente* Finalmente alguém interessante. Tente. Eu imploro."],
		"saudacao": ["Você tem 30 segundos antes que eu perca o interesse. Use-os."],
		"neutro": ["*tamborila os dedos no trono* ...E?"],
	},
	"romantica": {
		"insulto": ["*olhos marejados* Por que tanta crueldade? Achei que pudéssemos ser amigos..."],
		"insulto_grave": ["Até os gentis têm limites. Você acaba de encontrar o meu."],
		"elogio": ["*sorri* Que gentileza! Palavras assim são raras numa corte cheia de víboras."],
		"ameaca": ["Guerra... sempre a guerra. Meus conselheiros cuidarão de você. Que desperdício."],
		"saudacao": ["Bem-vindo a Torreluz! Conte-me: como está o mundo lá fora?"],
		"neutro": ["Fale-me mais. Adoro histórias de longe."],
	},
}

const ACENTOS := {"á":"a","à":"a","â":"a","ã":"a","é":"e","ê":"e","í":"i","ó":"o","ô":"o","õ":"o","ú":"u","ç":"c"}

static func norm(t: String) -> String:
	var s := t.to_lower()
	for k in ACENTOS:
		s = s.replace(k, ACENTOS[k])
	var limpo := ""
	for ch in s:
		limpo += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == " " else " "
	while limpo.contains("  "):
		limpo = limpo.replace("  ", " ")
	return limpo.strip_edges()

static func detectar_intencoes(texto: String) -> Array:
	var t := norm(texto)
	var achadas: Array = []
	for intencao in INTENCOES:
		var peso := 0
		for p in intencao["palavras"]:
			if t.contains(p):
				peso += 2 if (p as String).contains(" ") else 1
		if peso > 0:
			achadas.append({"id": intencao["id"], "peso": peso})
	achadas.sort_custom(func(a, b): return a["peso"] > b["peso"])
	return achadas

static func sentimento(intencoes: Array) -> float:
	var s := 0.0
	for i in intencoes:
		match i["id"]:
			"insulto": s -= i["peso"] * 2.0
			"ameaca": s -= i["peso"] * 3.0
			"elogio": s += i["peso"] * 1.5
			"saudacao": s += 0.5
	return clampf(s, -10.0, 10.0)

# ---------- memória por tags ----------
static func tags_de(state: Dictionary, npc_id: String) -> Dictionary:
	if not state["tags"].has(npc_id):
		state["tags"][npc_id] = {"relacao": 0, "flags": {}}
	return state["tags"][npc_id]

static func mudar_relacao(state: Dictionary, npc_id: String, delta: int, _motivo: String) -> String:
	var t := tags_de(state, npc_id)
	t["relacao"] = clampi(t["relacao"] + delta, -100, 100)
	return "[%s: %d]" % [nome_relacao(t["relacao"]), t["relacao"]]

static func nome_relacao(r: int) -> String:
	if r <= -60: return "Odiado"
	if r <= -25: return "Hostil"
	if r < 25: return "Neutro"
	if r < 60: return "Amistoso"
	return "Leal"

# ---------- fala principal ----------
static func falar(state: Dictionary, npc: Dictionary, texto: String) -> Dictionary:
	var tags := tags_de(state, npc["id"])
	var intencoes := detectar_intencoes(texto)
	var sent := sentimento(intencoes)
	var voz: Dictionary = VOZES.get(npc["personalidade"], VOZES["honrado"])
	var efeitos: Array = []
	var acoes: Array = []
	var resposta := ""
	var principal: String = intencoes[0]["id"] if intencoes.size() > 0 else ""

	match principal:
		"insulto":
			tags["flags"]["insultou"] = int(tags["flags"].get("insultou", 0)) + 1
			var grave: bool = tags["flags"]["insultou"] >= 2 or sent <= -6
			efeitos.append(mudar_relacao(state, npc["id"], -30 if grave else -15, "insulto"))
			var chave := "insulto_grave" if grave and voz.has("insulto_grave") else "insulto"
			resposta = Dados.rnd(voz[chave])
			if tags["relacao"] <= -50 and (npc["id"] as String).begins_with("rei_"):
				tags["flags"]["marcado_para_morte"] = true
				efeitos.append("[Marcado: um assassino pode ser enviado atrás de você]")
			if (npc["id"] as String).begins_with("rei_"):
				efeitos.append("[Preços no reino dele aumentaram para você]")
		"elogio":
			tags["flags"]["elogiou"] = int(tags["flags"].get("elogiou", 0)) + 1
			var rendimento: int = maxi(2, 10 - tags["flags"]["elogiou"] * 2
				- (4 if npc["personalidade"] == "calculista" else 0))
			efeitos.append(mudar_relacao(state, npc["id"], rendimento, "elogio"))
			resposta = Dados.rnd(voz["elogio"])
		"ameaca":
			tags["flags"]["ameacou"] = int(tags["flags"].get("ameacou", 0)) + 1
			efeitos.append(mudar_relacao(state, npc["id"], -25, "ameaça"))
			resposta = Dados.rnd(voz["ameaca"])
		"saudacao":
			resposta = Dados.rnd(voz["saudacao"])
			if tags["relacao"] > -10:
				efeitos.append(mudar_relacao(state, npc["id"], 1, "cortesia"))
		"despedida":
			resposta = "Vá. E reze para não cruzarmos de novo." if tags["relacao"] < -25 else "Até a próxima."
			acoes.append({"tipo": "fim_conversa"})
		"perguntar_guerra":
			resposta = _resposta_guerra(state, npc)
		"perguntar_preco":
			resposta = "Abra o Livro-Razão no mercado: os preços mudam com guerras e colheitas."
		"pedir_contrato":
			acoes.append({"tipo": "oferecer_contratos"})
			resposta = "Trabalho, é? Veja o mural de contratos na taverna." if tags["relacao"] > -40 \
				else "Trabalho? Para VOCÊ? Prefiro contratar os corvos."
		"subornar":
			var honesto: bool = npc["personalidade"] == "honrado"
			var custo: int = 50 + maxi(0, -int(tags["relacao"])) * 2
			if honesto:
				efeitos.append(mudar_relacao(state, npc["id"], -20, "tentativa de suborno"))
				resposta = "Você tentou me COMPRAR? Saia. Agora."
			elif state["jogador"]["ouro"] >= custo:
				state["jogador"]["ouro"] -= custo
				efeitos.append("[−%d ouro]" % custo)
				efeitos.append(mudar_relacao(state, npc["id"], 15, "suborno"))
				resposta = "*faz as moedas desaparecerem* Um investimento sensato. Prossiga."
			else:
				resposta = "Pouco. Muito pouco. (Você precisaria de %d de ouro.)" % custo
		"pedir_paz":
			resposta = _resposta_paz(state, npc, efeitos)
		_:
			resposta = "Não tenho paciência para balbucios. Fale claro ou saia." \
				if tags["relacao"] <= -40 else Dados.rnd(voz["neutro"])

	tags["flags"]["ultimo_topico"] = principal
	return {"resposta": resposta, "efeitos": efeitos, "acoes": acoes, "intencao": principal}

static func _resposta_guerra(state: Dictionary, npc: Dictionary) -> String:
	var guerras: Array = state["guerras"]
	if guerras.is_empty():
		return "Os reinos estão em paz. Paz é apenas a pausa entre duas guerras."
	var g: Dictionary = guerras[0]
	return "Dizem que %s e %s estão se despedaçando. O trigo lá vale ouro — bons tempos para contrabandistas." \
		% [g["a"], g["b"]]

static func _resposta_paz(state: Dictionary, npc: Dictionary, efeitos: Array) -> String:
	if not (npc["id"] as String).begins_with("rei_"):
		return "Paz? Fale com quem usa coroa."
	var meu_reino: String = (npc["id"] as String).replace("rei_", "")
	var idx := -1
	for i in state["guerras"].size():
		var g: Dictionary = state["guerras"][i]
		if g["a"] == meu_reino or g["b"] == meu_reino:
			idx = i
			break
	if idx < 0:
		return "Já estamos em paz. Não force minha sorte."
	if tags_de(state, npc["id"])["relacao"] >= 30:
		state["guerras"].remove_at(idx)
		state["jogador"]["renome"] += 15
		efeitos.append("[Guerra encerrada por mediação sua]")
		efeitos.append("[+15 Renome]")
		return "Sua palavra tem peso comigo. Que seja. Mandarei emissários."
	return "Paz se negocia entre iguais ou entre amigos. Você não é nenhum dos dois. Ainda."

# ---------- adaptador LLM (fase 2: HTTPRequest ao llama.cpp) ----------
static func montar_prompt_llm(state: Dictionary, npc: Dictionary, texto: String, resultado: Dictionary) -> String:
	var tags := tags_de(state, npc["id"])
	return "\n".join([
		"Você é %s, personalidade: %s." % [npc["nome"], npc["personalidade"]],
		"Relação com o jogador: %s (%d)." % [nome_relacao(tags["relacao"]), tags["relacao"]],
		"Intenção detectada: %s." % resultado["intencao"],
		"Jogador disse: \"%s\"" % texto,
		"Responda em 1-3 frases, em português, no tom da personalidade.",
	])
