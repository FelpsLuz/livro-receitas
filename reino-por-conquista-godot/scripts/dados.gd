# ============================================================
# REINO POR CONQUISTA — dados do mundo (port GDScript)
# Espelho fiel de js/data.js: 6 reinos, mercadorias, tropas,
# formações e níveis do assentamento.
# ============================================================
extends RefCounted

const MERCADORIAS := {
	"trigo":   {"nome": "Trigo",   "preco_base": 10},
	"madeira": {"nome": "Madeira", "preco_base": 14},
	"ferro":   {"nome": "Ferro",   "preco_base": 30},
	"sal":     {"nome": "Sal",     "preco_base": 22},
	"tecidos": {"nome": "Tecidos", "preco_base": 26},
	"cavalos": {"nome": "Cavalos", "preco_base": 80},
}

# Mundo oficial (Era do Aço, sem magia) — em paridade com a build HTML5.
const REINOS_BASE := [
	{"id": "imperio", "nome": "Império Central", "cor": "#1a4a2a", "imperial": true, "nobres": 10,
	 "producao": ["ferro", "cavalos"], "capital": "Trono Verde",
	 "rei": {"id": "rei_imperio", "nome": "Felps, o Destruidor", "genero": "m", "personalidade": "cruel"}},
	{"id": "touros", "nome": "Touros Negros", "cor": "#1c1c22", "nobres": 3,
	 "producao": ["madeira", "sal"], "capital": "Covil Negro",
	 "rei": {"id": "rei_touros", "nome": "Touro Bill", "genero": "m", "personalidade": "orgulhoso"}},
	{"id": "alvorecer", "nome": "Alvorecer Dourado", "cor": "#c9a227", "nobres": 6,
	 "producao": ["trigo", "tecidos"], "capital": "Aurora Alta",
	 "rei": {"id": "rei_alvorecer", "nome": "Enzo Noites", "genero": "m", "personalidade": "calculista"}},
	{"id": "leoes", "nome": "Leões Carmesins", "cor": "#8b1a1a", "nobres": 5,
	 "producao": ["ferro", "trigo"], "capital": "Chama Rubra",
	 "rei": {"id": "rei_leoes", "nome": "Fogo no Leão", "genero": "m", "personalidade": "honrado"}},
	{"id": "aguias", "nome": "Águias Prateadas", "cor": "#9aa4ae", "nobres": 4,
	 "producao": ["tecidos", "cavalos"], "capital": "Ninho de Prata",
	 "rei": {"id": "rei_aguias", "nome": "Fred Prateado", "genero": "m", "personalidade": "orgulhoso"}},
	{"id": "rosa", "nome": "Rosa Azul", "cor": "#2d4a8a", "nobres": 5,
	 "producao": ["sal", "madeira"], "capital": "Jardim Azul",
	 "rei": {"id": "rei_rosa", "nome": "Eva Rosada", "genero": "f", "personalidade": "calculista"}},
]

# ---------------------------------------------------------------
# TROPAS — três defesas separadas, uma para cada fase do combate.
#
#   classe : em QUAL fase a unidade ATACA (arq → cav → inf)
#   dg/dc/da : defesa contra infantaria / cavalaria / arqueiros
#   pop    : o que ela custa da população — é AQUI que mora o equilíbrio.
#            Comparar unidade por unidade engana: 1 Cav. Pesada (pop 6) vale
#            6 lanceiros, e 6 lanceiros dão 270 de defesa anticavalaria
#            contra os 150 de ataque dela. A lança vence o cavalo por preço.
#   saque  : capacidade de carga na pilhagem
#   vel    : MINUTOS POR CAMPO — número MENOR é mais rápido (escala Tribal
#            Wars). A tropa mais lenta do exército é a de MAIOR vel.
# ---------------------------------------------------------------
const TROPAS := {
	# milícia da própria terra: não é uma das oito, mas é de onde todo
	# senhor tira gente quando o dinheiro acaba
	"campones":   {"nome": "Camponeses",       "custo": 5,   "manut": 1, "pop": 1,
		"classe": "inf", "atq": 5,   "dg": 8,   "dc": 4,  "da": 6,   "saque": 12, "vel": 20},
	"lanceiro":   {"nome": "Lanceiros",        "custo": 20,  "manut": 2, "pop": 1,
		"classe": "inf", "atq": 10,  "dg": 15,  "dc": 45, "da": 20,  "saque": 25, "vel": 18},
	"espadachim": {"nome": "Espadachins",      "custo": 30,  "manut": 3, "pop": 1,
		"classe": "inf", "atq": 25,  "dg": 50,  "dc": 15, "da": 40,  "saque": 15, "vel": 22},
	"barbaro":    {"nome": "Bárbaros",         "custo": 28,  "manut": 3, "pop": 1,
		"classe": "inf", "atq": 40,  "dg": 10,  "dc": 5,  "da": 10,  "saque": 10, "vel": 18},
	"arqueiro":   {"nome": "Arqueiros",        "custo": 32,  "manut": 3, "pop": 1,
		"classe": "arq", "atq": 15,  "dg": 50,  "dc": 40, "da": 5,   "saque": 10, "vel": 18},
	"explorador": {"nome": "Exploradores",     "custo": 18,  "manut": 2, "pop": 2,
		"classe": "inf", "atq": 0,   "dg": 2,   "dc": 1,  "da": 2,   "saque": 0,  "vel": 9},
	"cav_leve":   {"nome": "Cavalaria Leve",   "custo": 130, "manut": 8, "pop": 4,
		"classe": "cav", "atq": 130, "dg": 30,  "dc": 40, "da": 30,  "saque": 80, "vel": 10},
	"arq_cavalo": {"nome": "Arq. a Cavalo",    "custo": 160, "manut": 10, "pop": 5,
		"classe": "arq", "atq": 120, "dg": 40,  "dc": 30, "da": 50,  "saque": 50, "vel": 10},
	"cav_pesada": {"nome": "Cavalaria Pesada", "custo": 260, "manut": 14, "pop": 6,
		"classe": "cav", "atq": 150, "dg": 200, "dc": 80, "da": 180, "saque": 50, "vel": 11},
}

## Segundos de treino. Cavalaria demora muito mais que lança — é o que faz
## o jogador escolher entre um exército rápido e um exército bom.
const TEMPO_TREINO := {
	"campones": 20, "lanceiro": 60, "espadachim": 90, "barbaro": 75,
	"arqueiro": 105, "explorador": 45, "cav_leve": 240, "arq_cavalo": 300,
	"cav_pesada": 420,
}

## Nome das três fases do combate, para o relatório de batalha.
const FASES_NOME := {"arq": "Disparo", "cav": "Choque", "inf": "Corpo a corpo"}

## Chaves antigas → novas, para saves anteriores à Fase 3.
const TROPAS_RENOMEADAS := {"cavaleiro": "cav_leve"}

# ---------------------------------------------------------------
# GRAFO DE ROTAS — o mapa é uma REDE, não um plano cartesiano.
#
# Só existem as ligações listadas aqui. Isso cria gargalos de verdade: o
# Império fica entre os Touros e o sul, então quem quiser bater nos Leões
# saindo do norte passa por terras imperiais — ou dá a volta pelo Jardim.
#
#   distancia : campos a percorrer (o tempo sai daqui × velocidade da tropa)
#   perigo    : chance POR DIA de estrada de um encontro ruim
#
# A chave é "A_B"; a rota vale nos dois sentidos, e `Rotas.entre()` procura
# "B_A" antes de desistir.
# ---------------------------------------------------------------
const ROTAS := {
	# a vizinhança do jogador — os Touros são o quintal dele
	"jogador_touros":     {"distancia": 5,  "perigo": 0.06},
	"jogador_alvorecer":  {"distancia": 9,  "perigo": 0.10},
	"jogador_sem_rei":    {"distancia": 7,  "perigo": 0.22},

	# o eixo norte-sul passa pelo Império: é o gargalo do mapa
	"touros_imperio":     {"distancia": 8,  "perigo": 0.08},
	"touros_rosa":        {"distancia": 11, "perigo": 0.12},
	"imperio_alvorecer":  {"distancia": 6,  "perigo": 0.05},
	"imperio_leoes":      {"distancia": 9,  "perigo": 0.09},

	# o sul, mais fechado e mais perigoso
	"alvorecer_aguias":   {"distancia": 7,  "perigo": 0.07},
	"leoes_aguias":       {"distancia": 6,  "perigo": 0.10},
	"leoes_rosa":         {"distancia": 10, "perigo": 0.13},

	# as bordas do mundo, onde a lei não chega
	"rosa_sem_rei":       {"distancia": 8,  "perigo": 0.20},
	"aguias_sem_rei":     {"distancia": 12, "perigo": 0.25},
}

## Rota de fallback quando o par não existe no grafo: caro e arriscado, como
## deve ser atravessar terra que ninguém mapeou.
const ROTA_DESCONHECIDA := {"distancia": 20, "perigo": 0.30}

## O "Reino sem Rei": destino que não é um dos seis, e por isso não está
## em REINOS_BASE. É a porta para fundar o próprio reino.
const SEM_REI := {"id": "sem_rei", "nome": "Reino sem Rei", "capital": "Trono Vazio"}

# linha vence cunha; cunha vence cerco; cerco vence linha
const FORMACOES := {
	"linha": {"nome": "Linha de Escudos", "vence_de": "cunha"},
	"cunha": {"nome": "Cunha", "vence_de": "cerco"},
	"cerco": {"nome": "Envolvimento", "vence_de": "linha"},
}

const NIVEIS_TERRA := [
	{"nome": "Acampamento", "custo_ouro": 0,    "custo_madeira": 0},
	{"nome": "Aldeia",      "custo_ouro": 200,  "custo_madeira": 60},
	{"nome": "Vila",        "custo_ouro": 500,  "custo_madeira": 150},
	{"nome": "Burgo",       "custo_ouro": 1200, "custo_madeira": 300},
	{"nome": "Cidade",      "custo_ouro": 2500, "custo_madeira": 600},
	{"nome": "Castelo",     "custo_ouro": 5000, "custo_madeira": 1200},
]

const NOMES_M := ["Edmund", "Rowan", "Cedric", "Tomas", "Garrick", "Alaric", "Bran", "Osric", "Doran", "Wilfred"]
const NOMES_F := ["Mira", "Elysia", "Sable", "Anora", "Gwen", "Isolde", "Runa", "Catrin", "Lyra", "Maren"]
const SOBRENOMES := ["de Vale Frio", "Mãos-de-Ferro", "o Errante", "de Ravenport", "Colina Verde", "Sangue-Velho"]

static func rnd(arr: Array):
	return arr[randi() % arr.size()]

static func ri(a: int, b: int) -> int:
	return a + randi() % (b - a + 1)
