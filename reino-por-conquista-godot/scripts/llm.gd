# ============================================================
# IA LOCAL (llama.cpp) — o processador do PC gera as falas.
# Rode no seu computador:
#   llama-server -m modelo-q4.gguf --port 8080
# Configure a URL no jogo (botão "IA Local" na Corte).
# Se o servidor não responder, o motor interno responde — o
# jogo NUNCA depende do LLM.
# ============================================================
extends RefCounted

const ARQUIVO_CFG := "user://llm_url.txt"

static func url() -> String:
	if FileAccess.file_exists(ARQUIVO_CFG):
		var f := FileAccess.open(ARQUIVO_CFG, FileAccess.READ)
		return f.get_as_text().strip_edges()
	return ""

static func definir_url(nova: String) -> void:
	var f := FileAccess.open(ARQUIVO_CFG, FileAccess.WRITE)
	f.store_string(nova.strip_edges())

# Gera texto via llama.cpp. Retorna "" em qualquer falha (timeout,
# servidor desligado, resposta inválida) — o chamador usa o fallback.
static func gerar(no_pai: Node, prompt: String, timeout_s: float = 12.0) -> String:
	var base := url()
	if base == "" or no_pai == null or not no_pai.is_inside_tree():
		return ""
	var req := HTTPRequest.new()
	req.timeout = timeout_s
	no_pai.add_child(req)
	var corpo := JSON.stringify({"prompt": prompt, "n_predict": 120, "temperature": 0.8,
		"stop": ["\n\n", "Jogador:"]})
	var erro := req.request(base.trim_suffix("/") + "/completion",
		["Content-Type: application/json"], HTTPClient.METHOD_POST, corpo)
	if erro != OK:
		req.queue_free()
		return ""
	var resultado: Array = await req.request_completed
	req.queue_free()
	# resultado = [result, response_code, headers, body]
	if resultado[0] != HTTPRequest.RESULT_SUCCESS or resultado[1] != 200:
		return ""
	var json = JSON.parse_string(resultado[3].get_string_from_utf8())
	if json == null or not json.has("content"):
		return ""
	return str(json["content"]).strip_edges()
