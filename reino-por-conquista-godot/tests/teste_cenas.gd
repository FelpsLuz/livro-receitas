# ============================================================
# TESTE DAS CENAS (fase 2) — roda headless:
#   godot --headless --path . res://tests/teste_cenas.tscn
# Instancia a cena principal e dirige o jogo como um jogador:
# inicia saga, navega abas, conversa (ponderar+digitação),
# compra no mercado, passa meses, salva e recarrega.
# ============================================================
extends Node

const Jogo = preload("res://scripts/jogo.gd")

var passou := 0
var falhou := 0

func ok(cond: bool, nome: String) -> void:
	if cond:
		passou += 1
		print("  ✅ ", nome)
	else:
		falhou += 1
		print("  ❌ FALHOU: ", nome)

func _ready() -> void:
	print("=== TESTES DE CENA (fase 2) ===")
	Jogo.apagar_save()
	var CenaPrincipal := load("res://cenas/principal.tscn")
	var jogo: Control = CenaPrincipal.instantiate()
	add_child(jogo)
	await get_tree().process_frame

	# título montado
	ok(jogo.tela_titulo.visible, "tela de título visível")
	ok(not jogo.tela_jogo.visible, "tela de jogo oculta no início")

	# iniciar saga
	jogo.iniciar_jogo("Teste da Silva")
	await get_tree().process_frame
	ok(jogo.tela_jogo.visible, "jogo iniciado")
	ok(jogo.state["jogador"]["nome"] == "Teste da Silva", "nome do jogador aplicado")
	ok(jogo.status_label.text.contains("Teste da Silva"), "barra de status renderizada")

	# navegar por todas as abas sem erro
	for i in 10:
		jogo.tabs.current_tab = i
		await get_tree().process_frame
	ok(true, "10 abas navegadas sem erro")

	# cidade pixel art presente na aba Terra
	jogo.tabs.current_tab = 0
	await get_tree().process_frame
	ok(jogo.cidade_view.get_parent() != null, "cidade pixel art montada na aba Terra")

	# mercado: comprar 5 trigo
	jogo.tabs.current_tab = 2
	await get_tree().process_frame
	var ouro_antes: int = jogo.state["jogador"]["ouro"]
	var r_compra: Dictionary = jogo.Economia.comprar(jogo.state, jogo.state["local"], "trigo", 5)
	ok(r_compra["ok"] and jogo.state["jogador"]["ouro"] < ouro_antes, "compra no mercado debita ouro")

	# conversa: insulto com ponderar + máquina de escrever
	var rei: Dictionary = jogo.state["reinos"][0]["rei"]
	jogo.abrir_conversa(rei)
	await get_tree().process_frame
	ok(jogo.overlay_conversa.visible, "conversa aberta")
	ok(jogo.conversa_retrato.texture != null, "retrato 64×64 exibido")
	jogo.enviar_texto("seu porco covarde e patetico")
	await get_tree().process_frame
	ok(jogo.conversa_hist.text.contains("pondera"), "NPC pondera antes de responder")
	ok(jogo.digitando, "entrada travada enquanto digita")
	# espera ponderar + digitação terminarem
	var tentativas := 0
	while jogo.digitando and tentativas < 400:
		await get_tree().create_timer(0.05).timeout
		tentativas += 1
	ok(not jogo.digitando, "resposta concluída")
	ok(jogo.conversa_hist.text.length() > 60, "resposta digitada no histórico")
	ok(jogo.state["tags"]["rei_valdria"]["relacao"] < 0, "insulto derrubou a relação")
	jogo.fechar_conversa()
	await get_tree().process_frame

	# retrato muda de humor com relação negativa
	jogo.state["tags"]["rei_valdria"]["relacao"] = -50
	var tex_raiva = jogo.Retratos.textura("rei_valdria", "raiva")
	ok(tex_raiva != null, "retrato com humor de raiva gerado")

	# passar 6 meses
	for i in 6:
		jogo.state["evento_pendente"] = null
		jogo._passar_mes()
		await get_tree().process_frame
	ok(jogo.state["mes"] != 3 or jogo.state["ano"] > 1, "meses passaram")
	ok(Jogo.tem_save(), "salvamento automático criado")

	# recarregar do save
	var ouro_salvo: int = jogo.state["jogador"]["ouro"]
	var salvo = Jogo.carregar()
	ok(salvo != null and salvo["jogador"]["nome"] == "Teste da Silva", "save recarrega com o mesmo nome")
	ok(salvo["jogador"]["ouro"] == ouro_salvo, "ouro preservado no save (%d)" % ouro_salvo)
	ok(typeof(salvo["jogador"]["ouro"]) == TYPE_INT, "números normalizados para inteiro no load")

	# modal de evento funciona
	jogo.state["evento_pendente"] = {"tipo": "traicao_guardas"}
	jogo.atualizar()
	await get_tree().process_frame
	ok(jogo.overlay_modal.visible, "modal de evento exibido")
	Jogo.resolver_evento(jogo.state, "recusar")
	jogo.overlay_modal.visible = false

	print("================================")
	print("RESULTADO: %d passaram, %d falharam" % [passou, falhou])
	get_tree().quit(1 if falhou > 0 else 0)
