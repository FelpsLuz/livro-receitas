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

const REINOS_BASE := [
	{"id": "valdria", "nome": "Valdria", "producao": ["trigo", "cavalos"], "capital": "Pedravelha",
	 "rei": {"id": "rei_valdria", "nome": "Rei Aldric", "genero": "m", "personalidade": "orgulhoso"}},
	{"id": "morvane", "nome": "Morvane", "producao": ["ferro", "madeira"], "capital": "Forjanegra",
	 "rei": {"id": "rei_morvane", "nome": "Rainha Iseld", "genero": "f", "personalidade": "calculista"}},
	{"id": "soleara", "nome": "Soleara", "producao": ["sal", "tecidos"], "capital": "Porto do Sol",
	 "rei": {"id": "rei_soleara", "nome": "Rei Domenico", "genero": "m", "personalidade": "ganancioso"}},
	{"id": "thornmar", "nome": "Thornmar", "producao": ["madeira", "trigo"], "capital": "Carvalho Alto",
	 "rei": {"id": "rei_thornmar", "nome": "Rei Godric", "genero": "m", "personalidade": "honrado"}},
	{"id": "ashkar", "nome": "Ashkar", "producao": ["ferro", "sal"], "capital": "Cinzabruta",
	 "rei": {"id": "rei_ashkar", "nome": "Rei Vukan", "genero": "m", "personalidade": "cruel"}},
	{"id": "lysande", "nome": "Lysande", "producao": ["tecidos", "cavalos"], "capital": "Torreluz",
	 "rei": {"id": "rei_lysande", "nome": "Rainha Elara", "genero": "f", "personalidade": "romantica"}},
]

const TROPAS := {
	"campones":  {"nome": "Camponeses", "custo": 5,   "manut": 1, "atq": 1, "def": 1},
	"lanceiro":  {"nome": "Lanceiros",  "custo": 20,  "manut": 2, "atq": 3, "def": 4},
	"arqueiro":  {"nome": "Arqueiros",  "custo": 25,  "manut": 2, "atq": 4, "def": 2},
	"cavaleiro": {"nome": "Cavaleiros", "custo": 120, "manut": 6, "atq": 8, "def": 7},
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
