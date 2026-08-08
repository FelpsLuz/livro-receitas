# ============================================================
# IA DOS PERSONAGENS — o jogador escolhe o provedor.
#
# Grátis de verdade (llama.cpp na sua máquina), faixa grátis com
# conta (Groq, OpenRouter) ou pago com a própria chave (OpenAI,
# Anthropic Claude). O campo `custo` de cada provedor alimenta o
# AVISO da interface — provedor pago nunca entra sem o jogador
# ver que paga.
#
# Qualquer falha (timeout, chave errada, recusa, servidor fora)
# devolve "" e o motor interno de diálogo responde — o jogo NUNCA
# depende da IA. A chave fica só no user:// da máquina do jogador.
# ============================================================
extends RefCounted

const ARQUIVO_CFG := "user://ia_cfg.json"
const ARQUIVO_LEGADO := "user://llm_url.txt"

## O catálogo. `custo`: "gratis" (roda na sua máquina), "gratis_conta"
## (precisa de conta; tem faixa gratuita com limites), "pago" (usa a SUA
## chave e cobra por uso). `protocolo`: como falar com o servidor.
const PROVEDORES := {
	"desligado": {"nome": "Desligado — motor interno do jogo",
		"protocolo": "", "url": "", "chave": false, "custo": "gratis", "modelo": ""},
	"local": {"nome": "IA local (llama.cpp) — grátis",
		"protocolo": "llama", "url": "http://localhost:8080",
		"chave": false, "custo": "gratis", "modelo": ""},
	"groq": {"nome": "Groq — nuvem com faixa grátis",
		"protocolo": "openai", "url": "https://api.groq.com/openai/v1",
		"chave": true, "custo": "gratis_conta", "modelo": "llama-3.3-70b-versatile"},
	"openrouter": {"nome": "OpenRouter — modelos grátis e pagos",
		"protocolo": "openai", "url": "https://openrouter.ai/api/v1",
		"chave": true, "custo": "gratis_conta",
		"modelo": "meta-llama/llama-3.3-70b-instruct:free"},
	"openai": {"nome": "OpenAI — pago",
		"protocolo": "openai", "url": "https://api.openai.com/v1",
		"chave": true, "custo": "pago", "modelo": "gpt-4o-mini"},
	"anthropic": {"nome": "Anthropic Claude — pago",
		"protocolo": "anthropic", "url": "https://api.anthropic.com/v1",
		"chave": true, "custo": "pago", "modelo": "claude-opus-5"},
}

static var _cfg: Dictionary = {}

## A configuração salva, com migração do arquivo antigo (só-URL): quem
## já usava a IA local continua com ela ligada sem reconfigurar nada.
static func config() -> Dictionary:
	if not _cfg.is_empty():
		return _cfg
	if FileAccess.file_exists(ARQUIVO_CFG):
		var j = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_CFG))
		if j is Dictionary and PROVEDORES.has(str(j.get("provedor", ""))):
			_cfg = j
			return _cfg
	if FileAccess.file_exists(ARQUIVO_LEGADO):
		var antiga := FileAccess.get_file_as_string(ARQUIVO_LEGADO).strip_edges()
		if antiga != "":
			_cfg = {"provedor": "local", "url": antiga, "chave": "", "modelo": ""}
			return _cfg
	_cfg = {"provedor": "desligado", "url": "", "chave": "", "modelo": ""}
	return _cfg

static func definir(cfg: Dictionary) -> void:
	_cfg = {
		"provedor": str(cfg.get("provedor", "desligado")),
		"url": str(cfg.get("url", "")).strip_edges(),
		"chave": str(cfg.get("chave", "")).strip_edges(),
		"modelo": str(cfg.get("modelo", "")).strip_edges(),
	}
	var f := FileAccess.open(ARQUIVO_CFG, FileAccess.WRITE)
	f.store_string(JSON.stringify(_cfg))

## A IA está pronta para gerar? Provedor escolhido, URL presente e a
## chave lá quando o provedor exige uma.
static func ativa() -> bool:
	var c := config()
	var p: Dictionary = PROVEDORES.get(str(c["provedor"]), {})
	if p.is_empty() or str(p["protocolo"]) == "":
		return false
	if str(c["url"]) == "":
		return false
	if bool(p["chave"]) and str(c["chave"]) == "":
		return false
	return true

## Rótulo curto para o botão da Corte.
static func descricao_estado() -> String:
	if not ativa():
		return "desligada"
	var c := config()
	return str(PROVEDORES[str(c["provedor"])]["nome"]).split(" — ")[0]

## Compatibilidade com o gate antigo (`Llm.url() != ""`).
static func url() -> String:
	return str(config()["url"]) if ativa() else ""

# ---------------- geração ----------------

## Gera a fala do NPC no provedor configurado. "" em QUALQUER falha —
## o chamador cai no motor interno e o jogador nem percebe.
static func gerar(no_pai: Node, prompt: String, timeout_s: float = 12.0) -> String:
	if not ativa() or no_pai == null or not no_pai.is_inside_tree():
		return ""
	var c := config()
	var p: Dictionary = PROVEDORES[str(c["provedor"])]
	var base := str(c["url"]).trim_suffix("/")
	var modelo := str(c["modelo"])
	if modelo == "":
		modelo = str(p["modelo"])
	match str(p["protocolo"]):
		"llama":
			return await _post(no_pai, timeout_s, base + "/completion",
				["Content-Type: application/json"],
				{"prompt": prompt, "n_predict": 120, "temperature": 0.8,
					"stop": ["\n\n", "Jogador:"]},
				_ler_llama)
		"openai":
			return await _post(no_pai, timeout_s, base + "/chat/completions",
				["Content-Type: application/json",
					"Authorization: Bearer " + str(c["chave"])],
				{"model": modelo, "max_tokens": 200, "temperature": 0.8,
					"messages": [{"role": "user", "content": prompt}]},
				_ler_openai)
		"anthropic":
			# sem temperature: os modelos Claude atuais rejeitam parâmetros
			# de amostragem — a variação vem do próprio prompt
			return await _post(no_pai, timeout_s, base + "/messages",
				["Content-Type: application/json",
					"x-api-key: " + str(c["chave"]),
					"anthropic-version: 2023-06-01"],
				{"model": modelo, "max_tokens": 200,
					"messages": [{"role": "user", "content": prompt}]},
				_ler_anthropic)
	return ""

static func _post(no_pai: Node, timeout_s: float, url_alvo: String,
		cabecalhos: PackedStringArray, corpo: Dictionary, leitor: Callable) -> String:
	var req := HTTPRequest.new()
	req.timeout = timeout_s
	no_pai.add_child(req)
	var erro := req.request(url_alvo, cabecalhos, HTTPClient.METHOD_POST,
		JSON.stringify(corpo))
	if erro != OK:
		req.queue_free()
		return ""
	var resultado: Array = await req.request_completed
	req.queue_free()
	# resultado = [result, response_code, headers, body]
	if resultado[0] != HTTPRequest.RESULT_SUCCESS or resultado[1] != 200:
		return ""
	var json = JSON.parse_string(resultado[3].get_string_from_utf8())
	if json == null:
		return ""
	return str(leitor.call(json)).strip_edges()

static func _ler_llama(json) -> String:
	if json is Dictionary and json.has("content"):
		return str(json["content"])
	return ""

static func _ler_openai(json) -> String:
	if json is Dictionary and json.get("choices", []) is Array \
			and not (json["choices"] as Array).is_empty():
		var msg = json["choices"][0].get("message", {})
		return str(msg.get("content", ""))
	return ""

static func _ler_anthropic(json) -> String:
	if not (json is Dictionary):
		return ""
	# recusa dos classificadores de segurança: sem texto, sem drama —
	# devolve vazio e o motor interno assume a fala
	if str(json.get("stop_reason", "")) == "refusal":
		return ""
	var saida := ""
	for bloco in json.get("content", []):
		if bloco is Dictionary and str(bloco.get("type", "")) == "text":
			saida += str(bloco.get("text", ""))
	return saida
