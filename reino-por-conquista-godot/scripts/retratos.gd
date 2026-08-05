# ============================================================
# RETRATOS — quem aparece na Corte, na marcha e nos modais.
#
# VISUAL STRIP: este arquivo tinha 386 linhas, e ~250 delas desenhavam
# rostos pixel a pixel (pele, cabelo, barba, cicatriz, chapéu) mais um
# recolorizador que trocava o matiz do tecido preservando luz e sombra.
# Tudo isso era ARTE gerada em código, e saiu junto com os PNG.
#
# O que ficou é o CONTRATO: as mesmas funções, com as mesmas assinaturas e
# os mesmos tamanhos de textura, devolvendo caixote cinza. Quem chama não
# muda uma linha, e a próxima leva de arte entra por aqui sem tocar na UI.
#
# O que ficou de LÓGICA, não de arte:
#   humor_de(state, id)   lê a relação e devolve "raiva"/"neutro"/"feliz".
#                         É estado de jogo — a UI mostra isso em texto
#                         também, e o cálculo continua valendo.
#
# Tamanhos preservados da arte antiga, porque são eles que seguram o layout:
#   retrato de pessoa e de tropa .... 64×64
#   ilustração de evento (faixa) .... 128×128
# ============================================================
extends RefCounted

const Arte = preload("res://scripts/arte.gd")

const LADO_RETRATO := 64
const LADO_EVENTO := 128

## Os eventos que têm ilustração. Continua sendo uma LISTA FECHADA mesmo sem
## arte: `ilustracao("emboscda")` com typo tem que devolver null como antes,
## senão o erro só apareceria quando a arte voltasse.
const EVENTOS := ["cerco", "coroacao", "derrota", "emboscada", "fome",
	"inverno", "juramento", "rebeliao", "saque", "traicao"]


## Antes carregava o PNG de assets/sprites/. Agora todo id resolve para o
## caixote de retrato — inclusive ids que nunca tiveram arte.
static func sprite_gerado(_id: String) -> Texture2D:
	return Arte.caixa(LADO_RETRATO)


## Retrato de um personagem do elenco fixo (reis, NPCs, chefes, tropas).
## `humor` continua no contrato: é ele que a arte nova vai usar para trocar
## a expressão. Hoje não muda o caixote.
static func textura(_id: String, _humor: String = "neutro") -> Texture2D:
	return Arte.caixa(LADO_RETRATO)


## Humor pela relação — LÓGICA DE ESTADO, não arte. Fica.
static func humor_de(state: Dictionary, id: String) -> String:
	var rel: int = state["tags"].get(id, {"relacao": 0})["relacao"]
	if rel <= -25:
		return "raiva"
	if rel >= 25:
		return "feliz"
	return "neutro"


## Retrato de um cidadão/lorde criado durante a partida.
## `n` é o dicionário de cidadaos.gd (nome, genero, oficio, riqueza…).
static func textura_cidadao(_n: Dictionary) -> Texture2D:
	return Arte.caixa(LADO_RETRATO)


## Retrato da tropa. O id da arte é SEMPRE "tropa_" + a chave de Dados.TROPAS,
## então a UI acha a imagem por cálculo — sem tabela paralela que envelhece
## toda vez que uma unidade nova entra no catálogo.
static func textura_tropa(tipo: String) -> Texture2D:
	return textura("tropa_" + tipo)


## Ilustração de evento para os modais (cerco, emboscada, inverno…).
## Devolve null para evento desconhecido: o modal segue só com texto.
static func ilustracao(evento: String) -> Texture2D:
	if not EVENTOS.has(evento):
		return null
	return Arte.caixa(LADO_EVENTO)


## Retrato de quem lidera a marcha. Resolve pela IDENTIDADE primeiro — um
## lorde que subiu de cidadão leva a cara que ele já tinha na Corte — e só
## cai no perfil quando não há pessoa por trás do cargo.
##
## A cadeia de resolução some com o caixote, mas o CONTRATO de "comandante
## vazio não tem retrato" é do chamador, não da arte: o card do comandante
## esconde o slot quando isto devolve null.
static func textura_comandante(_state: Dictionary, cmd: Dictionary) -> Texture2D:
	if cmd.is_empty():
		return null
	return Arte.caixa(LADO_RETRATO)
