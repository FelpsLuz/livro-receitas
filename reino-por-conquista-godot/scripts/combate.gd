# ============================================================
# COMBATE EM TRÊS FASES — Disparo → Choque → Corpo a corpo.
#
# Cada fase enfrenta o poder de ataque de UMA classe contra a defesa
# CORRESPONDENTE do inimigo: arqueiros contra Def. Arqueiros, cavalaria
# contra Def. Cavalaria, o resto contra Def. Geral. Multiplicador de sorte
# de 0,8 a 1,2 por fase.
#
# A armadilha que a simulação pegou: resolver as três fases como batalhas
# independentes é DEGENERADO — quem vence a fase 1 varre a guarnição inteira
# e as fases 2 e 3 nunca acontecem (um punhado de arqueiros aniquilava
# cavalaria pesada). A correção é uma linha de conceito: cada fase só pode
# matar a FATIA do defensor proporcional ao peso dela no exército atacante.
# Se o atacante é 1/3 arqueiros, o disparo mata no máximo 1/3 da guarnição.
#
# Conferido em 400 batalhas por cenário antes de virar código:
#   100 bárbaros × 50 lanceiros ...... atacante vence com 92 vivos
#   100 bárbaros × 100 espadachins ... defensor segura
#   20 cav. pesada × 100 lanceiros ... a lança mata o cavalo
#   100 arqueiros × 100 espadachins .. o contra-arqueiro segura
# ============================================================
extends RefCounted

const Dados = preload("res://scripts/dados.gd")
const Sinais = preload("res://scripts/sinais.gd")

## Ordem das fases: (classe que ataca, stat de defesa que responde).
const FASES := [["arq", "da"], ["cav", "dc"], ["inf", "dg"]]

# ------------------------------------------------------------
# Medidas
# ------------------------------------------------------------
static func _stat(tipo: String, chave: String) -> float:
	var t = Dados.TROPAS.get(tipo)
	if t == null:
		return 0.0
	return float(t.get(chave, 0))

static func ataque_da_classe(tropas: Dictionary, classe: String, bonus: float = 1.0) -> float:
	var t := 0.0
	for tipo in tropas:
		var d = Dados.TROPAS.get(tipo)
		if d != null and d.get("classe", "inf") == classe:
			t += _stat(tipo, "atq") * int(tropas[tipo]) * bonus
	return t

static func defesa(tropas: Dictionary, stat: String, bonus: float = 1.0) -> float:
	var t := 0.0
	for tipo in tropas:
		t += _stat(tipo, stat) * int(tropas[tipo]) * bonus
	return t

static func total_homens(tropas: Dictionary) -> int:
	var t := 0
	for tipo in tropas:
		t += int(tropas[tipo])
	return t

## População ocupada por um exército — a moeda real do equilíbrio.
static func populacao(tropas: Dictionary) -> int:
	var t := 0
	for tipo in tropas:
		t += int(_stat(tipo, "pop")) * int(tropas[tipo])
	return t

## Resumo para a UI (aba do exército). Mantém a forma antiga: atq/def/homens.
static func poder(tropas: Dictionary, equip: int) -> Dictionary:
	var atq := 0.0
	for f in FASES:
		atq += ataque_da_classe(tropas, f[0])
	var mult := 1.0 + equip * 0.15
	return {"atq": atq * mult, "def": defesa(tropas, "dg") * mult,
		"homens": total_homens(tropas), "pop": populacao(tropas)}

# ------------------------------------------------------------
# Buffs
# ------------------------------------------------------------
## Equipamento vale para todo mundo; o clã mercenário dá +20% SÓ na classe
## em que é especialista — é o que dá caráter a cada bando.
## MORAL VIRA FORÇA. Um exército que não recebe soldo há três meses não
## luta como um exército pago — e até esta linha existir, lutava: a mesma
## batalha com moral 100 e com moral 5 devolvia baixas idênticas. A moral
## só sabia desertar, o que é a consequência TARDIA; esta é a imediata.
##
## A curva é neutra em 100 (nenhuma batalha antiga muda de resultado) e
## desce até 0,70 no fundo do poço — sensível o bastante para o jogador
## sentir, longe de decidir sozinha o combate.
static func fator_moral(moral: int) -> float:
	return 0.70 + 0.30 * (clampi(moral, 0, 100) / 100.0)

## `moral` explícita serve à coluna em marcha, que carrega a moral do
## acampamento, e não a do quartel que ficou em casa. Sem argumento, vale
## a do exército do jogador.
# ------------------------------------------------------------
# FORMAÇÃO — o triângulo que a tela prometia e o motor ignorava
#
# `Dados.FORMACOES` declara `vence_de` desde sempre e a aba Tropas monta três
# botões dizendo "Linha vence Cunha, Cunha vence Envolvimento, Envolvimento
# vence Linha", gravando a escolha em `jogador.formacao`. Nenhuma linha deste
# arquivo lia o campo: a única menção a formação aqui era um sorteio para o
# inimigo que nunca era consultado. O jogador otimizava uma escolha tática e
# perdia do mesmo jeito.
#
# ±15% e não mais: com o escalar de moral (0,70 a 1,00) e o de equipamento
# (1,00 a 1,45), uma vantagem maior faria a formação decidir batalha sozinha
# — e formação é a decisão BARATA das três, a única que não custa dia nem
# ouro. Ela desempata; não substitui exército.
const VANTAGEM_FORMACAO := 1.15
const DESVANTAGEM_FORMACAO := 0.85

## Quanto a formação `minha` vale contra `dele`.
static func fator_formacao(minha: String, dele: String) -> float:
	if minha == "" or dele == "" or minha == dele:
		return 1.0
	if not Dados.FORMACOES.has(minha) or not Dados.FORMACOES.has(dele):
		return 1.0
	if str(Dados.FORMACOES[minha]["vence_de"]) == dele:
		return VANTAGEM_FORMACAO
	if str(Dados.FORMACOES[dele]["vence_de"]) == minha:
		return DESVANTAGEM_FORMACAO
	return 1.0

## A formação que o jogador escolheu, ou a de um exército NPC.
static func formacao_de(d: Dictionary) -> String:
	var f := str(d.get("formacao", ""))
	return f if Dados.FORMACOES.has(f) else ""

## A FORMAÇÃO QUE UM REINO ESTÁ DRILANDO NESTE MÊS.
##
## Derivada, e não sorteada nem guardada, por três razões:
##
##   · o espião e a batalha têm que concordar. Se fosse sorteada na hora do
##     combate, o relatório de 180 de ouro apontaria uma formação e o campo
##     mostraria outra — o pior tipo de mentira que uma interface conta.
##   · muda TODO MÊS. É isso que dá prazo de validade ao relatório do
##     espião: a informação envelhece, como todo o resto do `Intel`.
##   · não consome RNG. Sortear aqui deslocaria o fluxo aleatório e as
##     suítes determinísticas de marcha quebrariam sem relação com o que
##     mudou — já aconteceu neste projeto quando a moral entrou no combate.
## A ARITMÉTICA AQUI FOI CONQUISTADA NUM ERRO, e vale o comentário.
##
## A primeira versão fazia `("touros|%d|%d" % [mes, ano]).hash() % 3`. Parecia
## óbvio e estava errado: o `String.hash()` do Godot é do tipo `h = h*31 + c`,
## e trocar só o último dígito desloca o resultado por um MÚLTIPLO CONSTANTE —
## medido, 1089 por mês. E 1089 é divisível por 3. Resultado: os doze meses
## caíam na mesma classe de resto e todo reino formava em "Linha" o ano
## inteiro. A doutrina "que muda todo mês" nunca mudava, e o relatório de
## espião de 80 de ouro diria a mesma coisa para sempre.
##
## A correção não confia na distribuição do hash: o reino dá a FASE, e mês e
## ano giram por aritmética explícita com multiplicadores coprimos de 3.
## Consequência de desenho, e boa: cada reino está numa parte diferente do
## ciclo, então espionar um não conta nada sobre o outro — mas quem prestou
## atenção num reino consegue prever o mês seguinte dele. Informação com
## prazo de validade E com estrutura para aprender.
static func formacao_do_reino(state: Dictionary, chave: String) -> String:
	if chave == "":
		return ""
	var chaves: Array = Dados.FORMACOES.keys()
	var n: int = chaves.size()
	var fase: int = abs(chave.hash()) % n
	var giro: int = int(state.get("mes", 1)) * 7 + int(state.get("ano", 1)) * 13
	return str(chaves[(fase + giro) % n])

static func bonus_de(state: Dictionary, tropas: Dictionary, moral: int = -1) -> float:
	# EQUIPAMENTO POR UNIDADE: a média ponderada do aço que ESTES homens
	# carregam.
	#
	# O piso `1 + equip*0,15` saiu daqui. Ele lia `jogador.equip`, um contador
	# de 0 a 3 que NENHUM botão do jogo movia — ficava em 0 para sempre, então
	# o piso era sempre 1,0 e não fazia nada. Pior: se algum dia se movesse,
	# contaria o mesmo aço duas vezes, porque a tabela por unidade abaixo já
	# mede exatamente isso. Agora o exército tem uma fonte de equipamento só.
	var Equipar = load("res://scripts/equipar.gd")
	var b := 1.0
	var soma_eq := 0.0
	var homens_eq := 0
	for tipo_eq in tropas:
		var n_eq: int = int(tropas[tipo_eq])
		if n_eq <= 0:
			continue
		homens_eq += n_eq
		soma_eq += Equipar.fator(state, tipo_eq) * n_eq
	if homens_eq > 0:
		b *= soma_eq / float(homens_eq)
	for a in state.get("clas_ativos", []):
		var esp: String = str(a.get("especialidade", ""))
		if esp == "":
			continue
		for tipo in tropas:
			var d = Dados.TROPAS.get(tipo)
			if int(tropas[tipo]) > 0 and d != null and d.get("classe", "") == esp:
				b += 0.20
				break
	var m: int = moral if moral >= 0 else int(state["jogador"].get("moral", 100))
	return b * fator_moral(m)

# ------------------------------------------------------------
# O assalto: um lado ataca, o outro defende
# ------------------------------------------------------------
## Resolve as três fases numa direção só e MODIFICA os dois dicionários de
## tropas. `intencao`:
##   "saque" — só a primeira fase com poder de fogo acontece (bate e corre)
##   "cerco" — as três fases, até a moral quebrar
static func resolver_assalto(atacante: Dictionary, defensor: Dictionary,
		bonus_atq: float = 1.0, bonus_def: float = 1.0,
		intencao: String = "cerco") -> Dictionary:
	var rel := {"fases": [], "intencao": intencao,
		"baixas_atacante": 0, "baixas_defensor": 0, "vitoria": false}

	var total_atq := 0.0
	for f in FASES:
		total_atq += ataque_da_classe(atacante, f[0], bonus_atq)
	if total_atq <= 0.0:
		rel["resumo"] = "O exército não tinha poder de ataque algum."
		return rel
	var defensores_inicio := total_homens(defensor)
	var atacantes_inicio := total_homens(atacante)

	for f in FASES:
		var classe: String = f[0]
		var pa := ataque_da_classe(atacante, classe, bonus_atq)
		if pa <= 0.0 or total_homens(defensor) == 0:
			continue
		# o peso é a fatia que esta fase representa no exército atacante:
		# é ISSO que impede uma fase sozinha de varrer a guarnição inteira
		var peso := pa / total_atq
		pa *= randf_range(0.8, 1.2)                     # a sorte do dia
		var pd := defesa(defensor, f[1], bonus_def)
		var razao: float = pa / maxf(1.0, pd)
		var perda_def: float = minf(1.0, razao) * peso
		# expoente 1.5: quem vence folgado quase não sangra
		var perda_atq: float = minf(1.0, pow(1.0 / maxf(0.001, razao), 1.5))
		var mortos_d := _ceifar(defensor, perda_def)
		var mortos_a := _ceifar(atacante, perda_atq, classe)
		rel["baixas_defensor"] += mortos_d
		rel["baixas_atacante"] += mortos_a
		rel["fases"].append({
			"fase": classe, "nome": Dados.FASES_NOME.get(classe, classe),
			"ataque": roundi(pa), "defesa": roundi(pd),
			"mortos_atacante": mortos_a, "mortos_defensor": mortos_d})
		if intencao == "saque":
			break                                        # saque dura um round

	# Debandada da guarnição: diante de um atacante que a supera 10 para 1,
	# sangrando 3 vezes menos, e já tendo posto abaixo boa parte da defesa,
	# quem sobra se rende ou dispersa. Sem esta regra, o arredondamento por
	# fase deixava um punhado de "imortais" de pé e NENHUM exército misto
	# vencia um cerco — 2.000 homens perdiam para 53 em 10 de 10 tentativas.
	# Saque fica de fora: uma rapina de um round não desmonta uma guarnição.
	if intencao != "saque":
		var restam := total_homens(defensor)
		if restam > 0 and defensores_inicio > 0 and atacantes_inicio > 0 \
				and restam * 10 <= total_homens(atacante) \
				and restam <= roundi(defensores_inicio * 0.6):
			# a dor se mede em FRAÇÃO de cada lado, nunca em absolutos: dois
			# mil homens perdem 50 (2,5%) esmagando 53 que perderam 68% —
			# comparar 50 contra 36 esconderia quem realmente quebrou
			var frac_def := float(rel["baixas_defensor"]) / float(defensores_inicio)
			var frac_atq := float(rel["baixas_atacante"]) / float(atacantes_inicio)
			if frac_def >= frac_atq * 3.0:
				rel["baixas_defensor"] += _ceifar(defensor, 1.0)
				rel["debandada_defensor"] = true

	rel["vitoria"] = total_homens(defensor) == 0
	return rel

## Mata uma fração das tropas. `classe` vazia atinge todo mundo; preenchida,
## só a classe daquela fase — quem ficou para trás não morre no choque.
static func _ceifar(tropas: Dictionary, frac: float, classe: String = "") -> int:
	if frac <= 0.0:
		return 0
	var mortos := 0
	for tipo in tropas:
		if classe != "":
			var d = Dados.TROPAS.get(tipo)
			if d == null or d.get("classe", "inf") != classe:
				continue
		var n: int = int(tropas[tipo])
		if n <= 0:
			continue
		var m: int = mini(n, roundi(n * frac))
		tropas[tipo] = n - m
		mortos += m
	return mortos

# ------------------------------------------------------------
# Batalha campal (o caminho que contratos, rebeliões e guerras usam)
# ------------------------------------------------------------
## Os dois lados atacam. Para não dar vantagem a quem "vai primeiro", as duas
## direções são calculadas contra o exército como ele estava ANTES do choque.
static func batalhar(state: Dictionary, inimigo: Dictionary, contexto: String,
		intencao: String = "cerco") -> Dictionary:
	var j: Dictionary = state["jogador"]
	var meu: Dictionary = j["tropas"]
	var dele: Dictionary = inimigo["tropas"]

	var b_meu := bonus_de(state, meu)
	# moral: força do personagem ainda conta, como antes
	b_meu *= 1.0 + (float(j["atributos"]["forca"]) - 5.0) * 0.04
	var b_dele := 1.0 + int(inimigo.get("equip", 0)) * 0.15

	# ---- A FORMAÇÃO ENTRA AQUI ----
	# Os dois lados a declaram e os dois sentem o resultado: quem escolhe a
	# formação que vence a do outro leva +15%, e o outro leva −15%. É uma
	# diferença de 35% entre as duas pontas — grande o bastante para valer a
	# escolha, pequena o bastante para não substituir exército.
	var f_meu := formacao_de(j)
	var f_dele := formacao_de(inimigo)
	if f_dele == "":
		# reino tem doutrina e treina; bando de estrada não. Para o bando, a
		# chave vira a própria composição — assim ele TEM formação (senão o
		# jogador nunca perderia vantagem) sem ser espionável.
		f_dele = formacao_do_reino(state, str(inimigo.get("id",
			"bando|" + str(inimigo.get("tropas", {}).keys()))))
	var vantagem := fator_formacao(f_meu, f_dele)
	b_meu *= vantagem
	b_dele *= fator_formacao(f_dele, f_meu)

	# fotografias: os dois golpes saem simultâneos
	var foto_meu: Dictionary = meu.duplicate(true)
	var foto_dele: Dictionary = dele.duplicate(true)

	var ida := resolver_assalto(foto_meu, dele, b_meu, b_dele, intencao)
	var volta := resolver_assalto(foto_dele, meu, b_dele, b_meu, intencao)

	var vivos_meu := total_homens(meu)
	var vivos_dele := total_homens(dele)
	var rel := {
		"contexto": contexto, "intencao": intencao,
		"fases": ida["fases"], "fases_inimigo": volta["fases"],
		"baixas_jogador": ida["baixas_atacante"] + volta["baixas_defensor"],
		"baixas_inimigo": ida["baixas_defensor"] + volta["baixas_atacante"],
		"vivos_jogador": vivos_meu, "vivos_inimigo": vivos_dele,
		"debandada": "",
		# a formação vai no RELATÓRIO, e essa é metade do ponto: uma
		# vantagem que o jogador não consegue ler depois da batalha é uma
		# vantagem que ele não aprende a usar
		"formacao": f_meu, "formacao_inimigo": f_dele,
		"vantagem_formacao": vantagem,
	}
	if vivos_dele == 0 and vivos_meu > 0:
		rel["debandada"] = "inimigo"
	elif vivos_meu == 0 and vivos_dele > 0:
		rel["debandada"] = "jogador"
	rel["vitoria"] = vivos_dele == 0 or (vivos_meu > 0 and vivos_meu > vivos_dele)
	# derrota esmagadora: perdeu quase tudo e o inimigo ficou de pé
	rel["esmagado"] = (not rel["vitoria"]) and vivos_meu <= maxi(1, roundi(vivos_dele * 0.15))
	rel["resumo"] = montar_relatorio(rel)
	Sinais.emitir(&"batalha_terminou", rel)
	return rel

# ------------------------------------------------------------
# Relatório de batalha
# ------------------------------------------------------------
## Texto pronto para o modal e para a crônica. Mostra fase a fase o que
## aconteceu — é onde a matemática invisível fica legível.
static func montar_relatorio(rel: Dictionary) -> String:
	var l: Array = []
	l.append("⚔ %s — %s" % [rel.get("contexto", "Batalha"),
		"SAQUE" if rel.get("intencao", "") == "saque" else "CERCO"])
	# A LINHA DA FORMAÇÃO. Ela vem antes das fases porque explica os números
	# das fases: sem ela, o jogador vê o ataque 15% maior e não sabe por quê.
	var f_meu := str(rel.get("formacao", ""))
	var f_dele := str(rel.get("formacao_inimigo", ""))
	if f_meu != "" and f_dele != "":
		var nome_meu := str(Dados.FORMACOES.get(f_meu, {}).get("nome", f_meu))
		var nome_dele := str(Dados.FORMACOES.get(f_dele, {}).get("nome", f_dele))
		var v := float(rel.get("vantagem_formacao", 1.0))
		if v > 1.0:
			l.append("  %s contra %s: a formação era a certa (+15%% de força)."
				% [nome_meu, nome_dele])
		elif v < 1.0:
			l.append("  %s contra %s: ele leu o campo melhor (−15%% de força)."
				% [nome_meu, nome_dele])
		else:
			l.append("  %s contra %s: nenhum dos dois levou vantagem de formação."
				% [nome_meu, nome_dele])
	for f in rel.get("fases", []):
		l.append("  %s: %d de ataque contra %d de defesa — %d baixas suas, %d dele."
			% [f["nome"], f["ataque"], f["defesa"], f["mortos_atacante"], f["mortos_defensor"]])
	l.append("Baixas: %d suas, %d dele. Restam %d contra %d." % [
		rel.get("baixas_jogador", 0), rel.get("baixas_inimigo", 0),
		rel.get("vivos_jogador", 0), rel.get("vivos_inimigo", 0)])
	if rel.get("debandada", "") == "inimigo":
		l.append("O inimigo debandou.")
	elif rel.get("debandada", "") == "jogador":
		l.append("Suas linhas quebraram.")
	l.append("VITÓRIA." if rel.get("vitoria", false) else "DERROTA.")
	return "\n".join(l)

# ------------------------------------------------------------
# Saque
# ------------------------------------------------------------
## O que os sobreviventes conseguem carregar, repartido entre os bens.
static func colher_saque(sobreviventes: Dictionary, cofre: Dictionary) -> Dictionary:
	var capacidade := 0
	for tipo in sobreviventes:
		capacidade += int(_stat(tipo, "saque")) * int(sobreviventes[tipo])
	var levado := {}
	var bens := cofre.keys()
	if bens.is_empty() or capacidade <= 0:
		return levado
	var por_bem: int = int(capacidade / float(bens.size()))
	for g in bens:
		var fatia: int = mini(int(cofre[g]), por_bem)
		if fatia > 0:
			levado[g] = fatia
			cofre[g] = int(cofre[g]) - fatia
	return levado

# ------------------------------------------------------------
# Exércitos inimigos por nível de ameaça
# ------------------------------------------------------------
static func exercito_inimigo(forca: int) -> Dictionary:
	var e := {"tropas": {}, "equip": 1 if forca > 2 else 0,
		"formacao": Dados.rnd(Dados.FORMACOES.keys())}
	match forca:
		1: e["tropas"] = {"campones": Dados.ri(8, 14), "lanceiro": Dados.ri(2, 5)}
		2: e["tropas"] = {"lanceiro": Dados.ri(8, 14), "arqueiro": Dados.ri(4, 8),
			"barbaro": Dados.ri(3, 7)}
		3: e["tropas"] = {"lanceiro": Dados.ri(12, 18), "espadachim": Dados.ri(6, 10),
			"arqueiro": Dados.ri(8, 12), "cav_leve": Dados.ri(2, 4)}
		_: e["tropas"] = {"lanceiro": Dados.ri(20, 30), "espadachim": Dados.ri(10, 16),
			"arqueiro": Dados.ri(12, 18), "cav_leve": Dados.ri(4, 7),
			"cav_pesada": Dados.ri(1, 3)}
	return e
