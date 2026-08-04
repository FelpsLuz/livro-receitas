# ============================================================
# TESTE — a ponte entre o PixelLab e a interface.
#
# O que este arquivo protege é um CONTRATO de nomes: a arte é achada por
# cálculo ("tropa_" + a chave de Dados.TROPAS, "evento_" + o id da cena), não
# por uma tabela escrita à mão. Se alguém acrescentar uma unidade ao catálogo
# e esquecer o PNG, é aqui que quebra — não na tela do jogador.
#
# E protege o degrau de baixo: todo caminho de retrato tem que devolver uma
# textura válida mesmo sem arquivo nenhum, porque um Lorde que nasce no meio
# da partida não tem PNG e não pode deixar buraco na UI.
#   godot --headless --script res://tests/teste_arte.gd
# ============================================================
extends SceneTree

const Dados = preload("res://scripts/dados.gd")
const Retratos = preload("res://scripts/retratos.gd")
const Cidadaos = preload("res://scripts/cidadaos.gd")
const Comandantes = preload("res://scripts/comandantes.gd")
const Icones = preload("res://scripts/icones.gd")
const Jogo = preload("res://scripts/jogo.gd")

var passou := 0
var falhou := 0

func ok(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome, ("  " + extra) if extra != "" else "")
	else:
		falhou += 1
		print("  ❌ ", nome, ("  " + extra) if extra != "" else "")

func _initialize() -> void:
	print("=== ARTE: TROPAS, LORDES E CENAS ===")

	# ---------- 1. toda tropa do catálogo tem retrato ----------
	var sem_png: Array = []
	for tipo in Dados.TROPAS:
		if Retratos.sprite_gerado("tropa_" + tipo) == null:
			sem_png.append(tipo)
	ok("as %d tropas de dados.gd têm PNG gerado" % Dados.TROPAS.size(),
		sem_png.is_empty(), "faltam: " + str(sem_png))

	var todas_resolvem := true
	for tipo in Dados.TROPAS:
		var t := Retratos.textura_tropa(tipo)
		if t == null or t.get_width() <= 0:
			todas_resolvem = false
	ok("textura_tropa devolve textura para toda unidade", todas_resolvem)

	# o nome da arte é DERIVADO da chave: uma unidade inventada agora já
	# encontraria o PNG dela sem ninguém editar retratos.gd
	ok("a unidade nova entra sem tabela paralela",
		Retratos.textura_tropa("lanceiro") == Retratos.textura("tropa_lanceiro"))

	# ---------- 2. ilustrações de evento ----------
	var cenas := ["cerco", "emboscada", "inverno", "rebeliao", "juramento", "coroacao",
		"traicao", "saque", "fome", "derrota"]
	var sem_cena: Array = []
	for e in cenas:
		if Retratos.ilustracao(e) == null:
			sem_cena.append(e)
	ok("as %d cenas de evento existem" % cenas.size(),
		sem_cena.is_empty(), "faltam: " + str(sem_cena))

	var panoramica := true
	for e in cenas:
		var il := Retratos.ilustracao(e)
		if il != null and il.get_width() < 96:
			panoramica = false
	ok("as cenas são maiores que um retrato (entram como faixa)", panoramica)

	ok("evento inexistente devolve null em vez de quebrar",
		Retratos.ilustracao("nao_existe_isso") == null)

	# ---------- 3. bases recoloríveis ----------
	ok("existe base masculina de nobre", Retratos.sprite_gerado("lorde_generico") != null)
	ok("existe base feminina de nobre", Retratos.sprite_gerado("lorde_generica") != null)

	# ---------- 4. retrato de quem nasce durante a partida ----------
	var ferreiro := {"nome": "Bram Cinzas", "genero": "m", "oficio": "ferreiro",
		"riqueza": 500, "lealdade": 80, "ambicao": 4, "lorde": true}
	var mercador := {"nome": "Bram Cinzas", "genero": "m", "oficio": "mercador",
		"riqueza": 500, "lealdade": 80, "ambicao": 4, "lorde": true}
	var dama := {"nome": "Elda do Vau", "genero": "f", "oficio": "moleiro",
		"riqueza": 420, "lealdade": 70, "ambicao": 6, "lorde": true}

	var t_ferreiro := Retratos.textura_cidadao(ferreiro)
	ok("lorde gerado em partida tem retrato",
		t_ferreiro != null and t_ferreiro.get_width() > 0)
	ok("dama gerada em partida tem retrato",
		Retratos.textura_cidadao(dama) != null)

	# a mesma pessoa tem que ter SEMPRE a mesma cara entre uma tela e outra
	ok("o retrato é estável para a mesma pessoa",
		Retratos.textura_cidadao(ferreiro) == Retratos.textura_cidadao(ferreiro))

	# e dois ofícios diferentes não podem sair idênticos, senão a corte inteira
	# vira o mesmo homem repetido
	var img_f: Image = Retratos.textura_cidadao(ferreiro).get_image()
	var img_m: Image = Retratos.textura_cidadao(mercador).get_image()
	ok("ofícios diferentes rendem retratos diferentes",
		img_f.get_data() != img_m.get_data())

	# ---------- 5. o recolorido preserva o sombreamento ----------
	# pintar tudo de uma cor só achataria o sprite; o teste é que a VARIAÇÃO
	# de luz sobreviva à troca de matiz
	# compara com a base do MESMO gênero: o ferreiro recolore lorde_generico,
	# a dama recoloria lorde_generica e a comparação não diria nada
	var base := Retratos.sprite_gerado("lorde_generico")
	if base != null:
		var orig: Image = base.get_image()
		orig.convert(Image.FORMAT_RGBA8)
		var novo: Image = Retratos.textura_cidadao(ferreiro).get_image()
		novo.convert(Image.FORMAT_RGBA8)
		ok("o recolorido mantém o tamanho da base",
			novo.get_width() == orig.get_width() and novo.get_height() == orig.get_height())
		var iguais := 0
		var vistos := 0
		var luz_ok := true
		for y in range(0, orig.get_height(), 2):
			for x in range(0, orig.get_width(), 2):
				var a := orig.get_pixel(x, y)
				if a.a < 0.1:
					continue
				vistos += 1
				var b := novo.get_pixel(x, y)
				if absf(a.v - b.v) > 0.02:
					luz_ok = false
				if a.is_equal_approx(b):
					iguais += 1
		ok("a luz de cada pixel é preservada", luz_ok)
		# nem tudo muda (pele e metal ficam) e nem tudo fica (o tecido troca)
		ok("o recolorido troca o tecido sem repintar o sprite inteiro",
			iguais > 0 and iguais < vistos, "%d de %d intactos" % [iguais, vistos])

	# ---------- 6. o degrau final: sem arquivo nenhum ----------
	# um cidadão de gênero inventado não acha base para recolorir e cai no
	# desenho procedural — que continua tendo que devolver 64×64 válidos
	var estranho := {"nome": "Ninguém", "genero": "x", "oficio": "andarilho",
		"riqueza": 10, "lealdade": 50}
	var t_estranho := Retratos.textura_cidadao(estranho)
	ok("cidadão sem base nem ofício conhecido ainda tem retrato",
		t_estranho != null and t_estranho.get_width() == 64)

	var ficha := Retratos.ficha_de_cidadao(estranho)
	ok("a ficha de reserva sai completa",
		ficha.has("pele") and ficha.has("cabelo") and ficha.has("roupa"))
	ok("cor pessoal é estável",
		Retratos.cor_de_cidadao(ferreiro).is_equal_approx(Retratos.cor_de_cidadao(ferreiro)))

	# ---------- 7. comandantes ----------
	var state := Jogo.novo_jogo("Testador")
	var cmds: Array = Comandantes.disponiveis(state)
	ok("o senhor está sempre disponível para comandar", cmds.size() >= 1)
	var t_senhor := Retratos.textura_comandante(state, cmds[0])
	ok("o comandante padrão tem retrato", t_senhor != null)
	ok("comandante vazio devolve null",
		Retratos.textura_comandante(state, {}) == null)

	# um lorde que subiu de cidadão leva para a marcha a MESMA cara da Corte
	state["terra"] = {"nome": "Vau", "nivel": 2, "populacao": 40, "alimento": 50,
		"madeira": 20, "felicidade": 60, "notaveis": [ferreiro]}
	var achou := false
	for cmd in Comandantes.disponiveis(state):
		if str(cmd["id"]) == "lorde:Bram Cinzas":
			achou = true
			ok("o lorde na marcha usa o retrato da Corte",
				Retratos.textura_comandante(state, cmd) == Retratos.textura_cidadao(ferreiro))
	ok("o lorde jurado aparece na lista de comandantes", achou)

	# mercenário contratado não é cidadão: cai na arte do perfil
	var capitao := {"id": "cla:cla_lobos", "perfil": "batedor", "nome": "Chefe", "atributo": 6}
	ok("comandante de clã resolve pelo retrato do clã",
		Retratos.textura_comandante(state, capitao) != null)
	ok("existe arte para os perfis contratados",
		Retratos.sprite_gerado("mercenario_lanca") != null
		and Retratos.sprite_gerado("mercenario_arco") != null)

	# ---------- 8. NPCs de serviço da taverna ----------
	for id in ["informante", "cartografo"]:
		ok("a taverna tem o rosto de %s" % id, Retratos.sprite_gerado(id) != null)

	# ---------- 9. ícones de mecânica ----------
	# Estes não são mercadoria: são estados (neblina, moral, fila, cerco) que a
	# UI mostrava só com emoji. O inventário tem que estar completo, senão o
	# ícone some sem ninguém perceber.
	var inv: Dictionary = Icones.inventario()
	ok("todo ícone do catálogo tem PNG", inv["falta"].is_empty(), str(inv["falta"]))
	for n in ["espiao", "neblina", "populacao", "moral", "ampulheta", "cerco"]:
		ok("ícone de %s carrega" % n, Icones.textura(n) != null)
	ok("ícone inexistente devolve null", Icones.textura("nao_existe") == null)
	ok("Icones.imagem devolve TextureRect pronto",
		Icones.imagem("espiao", 30) is TextureRect)

	print("=====================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	quit(1 if falhou > 0 else 0)
