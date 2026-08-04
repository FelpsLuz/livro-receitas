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

const TROPAS := {
	"campones":  {"nome": "Camponeses", "custo": 5,   "manut": 1, "atq": 1, "def": 1, "pop": 1},
	"lanceiro":  {"nome": "Lanceiros",  "custo": 20,  "manut": 2, "atq": 3, "def": 4, "pop": 1},
	"arqueiro":  {"nome": "Arqueiros",  "custo": 25,  "manut": 2, "atq": 4, "def": 2, "pop": 1},
	"cavaleiro": {"nome": "Cavaleiros", "custo": 120, "manut": 6, "atq": 8, "def": 7, "pop": 4},
}

## Segundos de treino por unidade. Cavalaria demora muito mais que lança —
## é o que faz o jogador escolher entre um exército rápido e um exército bom.
const TEMPO_TREINO := {
	"campones": 20, "lanceiro": 60, "arqueiro": 105, "cavaleiro": 240,
}

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
