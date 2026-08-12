# ============================================================
# REINO POR CONQUISTA — dados do mundo (port GDScript)
# Espelho fiel de js/data.js: 6 reinos, mercadorias, tropas,
# formações e níveis do assentamento.
# ============================================================
extends RefCounted

## Matriz econômica v2 (PATCH CONSOLIDADO, Parte II · Estágio 1). `cavalos`
## saiu — nenhum reino o produzia como monopólio, e a Seção 4 precisava de um
## material novo para os degraus 5-8 da terra (pedra) que não competisse com
## a madeira que a construção já consome inteira. `pedra` ≈ 1,5× o preço da
## madeira (instrução do patch); `prata` é de propósito a mais cara das 7 —
## era o preço que `cavalos` ocupava, agora reservado ao monopólio de
## Frederico (Seção 13: prata vira desconto/sobretaxa na contratação de clãs,
## Estágio futuro — aqui ela só precisa EXISTIR como bem negociável).
const MERCADORIAS := {
	"trigo":   {"nome": "Trigo",   "preco_base": 10},
	"madeira": {"nome": "Madeira", "preco_base": 14},
	"ferro":   {"nome": "Ferro",   "preco_base": 30},
	"sal":     {"nome": "Sal",     "preco_base": 22},
	"tecidos": {"nome": "Tecidos", "preco_base": 26},
	"pedra":   {"nome": "Pedra",   "preco_base": 21},
	"prata":   {"nome": "Prata",   "preco_base": 90},
}

# Mundo oficial (Era do Aço, sem magia) — em paridade com a build HTML5.
#
# Nomes de casa e de rei alinhados ao PATCH CONSOLIDADO v2 (Parte IV, Estágio
# 0). Só nome e rei.nome mudam — id, cor, capital, nobres ficam EXATAMENTE
# como estavam. É rename puro: nenhum outro arquivo lê estes reinos por
# string de exibição (conferido — só dois comentários e dois fixtures de
# teste citavam os nomes antigos, nenhum por lógica).
#
# `producao` MUDOU (PATCH CONSOLIDADO v2, Parte II · Estágio 1): a v1 do
# patch dava Pedra como monopólio exclusivo do Império — softlock, porque a
# Seção 4 usa pedra pra construção e o Império é o reino mais hostil do
# mapa. A correção: Ursos de Ferro (vizinhos do jogador, só 3 nobres) também
# produzem Pedra, no lugar de Sal — e Sal vira monopólio único das Víboras.
# O encaixe continua sendo 5 bens com 2 produtores + 2 bens com 1 produtor
# (sal, prata) = 12 slots = 6 reinos × 2, como a regra do código já exige.
const REINOS_BASE := [
	{"id": "imperio", "nome": "Império Central", "cor": "#1a4a2a", "imperial": true, "nobres": 10,
	 "producao": ["ferro", "pedra"], "capital": "Trono Verde",
	 "rei": {"id": "rei_imperio", "nome": "Felippe, o Sangrento", "genero": "m", "personalidade": "cruel"}},
	{"id": "touros", "nome": "Ursos de Ferro", "cor": "#1c1c22", "nobres": 3,
	 "producao": ["madeira", "pedra"], "capital": "Covil Negro",
	 "rei": {"id": "rei_touros", "nome": "Bjorne, o Orgulhoso", "genero": "m", "personalidade": "orgulhoso"}},
	{"id": "alvorecer", "nome": "Sol de Bronze", "cor": "#c9a227", "nobres": 6,
	 "producao": ["trigo", "tecidos"], "capital": "Aurora Alta",
	 "rei": {"id": "rei_alvorecer", "nome": "Enzo Tenebris", "genero": "m", "personalidade": "calculista"}},
	{"id": "leoes", "nome": "Cervos Escarlates", "cor": "#8b1a1a", "nobres": 5,
	 "producao": ["ferro", "trigo"], "capital": "Chama Rubra",
	 "rei": {"id": "rei_leoes", "nome": "Ignis, o Escarlate", "genero": "m", "personalidade": "honrado"}},
	{"id": "aguias", "nome": "Garças de Prata", "cor": "#9aa4ae", "nobres": 4,
	 "producao": ["tecidos", "prata"], "capital": "Ninho de Prata",
	 "rei": {"id": "rei_aguias", "nome": "Frederico Silver", "genero": "m", "personalidade": "orgulhoso"}},
	{"id": "rosa", "nome": "Víboras de Safira", "cor": "#2d4a8a", "nobres": 5,
	 "producao": ["sal", "madeira"], "capital": "Jardim Azul",
	 "rei": {"id": "rei_rosa", "nome": "Eva, a Víbora", "genero": "f", "personalidade": "calculista"}},
]

# ---------------------------------------------------------------
# TROPAS — três defesas separadas, uma para cada fase do combate.
#
#   classe : em QUAL fase a unidade ATACA (arq → cav → inf)
#   dg/dc/da : defesa contra infantaria / cavalaria / arqueiros
#   comida/madeira/manut : upkeep POR MÊS. Cavalo come três vezes mais que
#            homem e arqueiro gasta madeira em flecha — manter exército é
#            uma decisão econômica, não um número de status.
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
	"campones":   {"nome": "Camponeses",       "custo": 5,   "manut": 1, "comida": 1, "madeira": 0, "pop": 1,
		"classe": "inf", "atq": 5,   "dg": 8,   "dc": 4,  "da": 6,   "saque": 12, "vel": 20},
	"lanceiro":   {"nome": "Lanceiros",        "custo": 20,  "manut": 2, "comida": 1, "madeira": 1, "pop": 1,
		"classe": "inf", "atq": 10,  "dg": 15,  "dc": 45, "da": 20,  "saque": 25, "vel": 18},
	"espadachim": {"nome": "Espadachins",      "custo": 30,  "manut": 3, "comida": 1, "madeira": 1, "pop": 1,
		"classe": "inf", "atq": 25,  "dg": 50,  "dc": 15, "da": 40,  "saque": 15, "vel": 22},
	"barbaro":    {"nome": "Bárbaros",         "custo": 28,  "manut": 3, "comida": 1, "madeira": 1, "pop": 1,
		"classe": "inf", "atq": 40,  "dg": 10,  "dc": 5,  "da": 10,  "saque": 10, "vel": 18},
	"arqueiro":   {"nome": "Arqueiros",        "custo": 32,  "manut": 3, "comida": 1, "madeira": 2, "pop": 1,
		"classe": "arq", "atq": 15,  "dg": 50,  "dc": 40, "da": 5,   "saque": 10, "vel": 18},
	"explorador": {"nome": "Exploradores",     "custo": 18,  "manut": 2, "comida": 1, "madeira": 0, "pop": 2,
		"classe": "inf", "atq": 0,   "dg": 2,   "dc": 1,  "da": 2,   "saque": 0,  "vel": 9},
	"cav_leve":   {"nome": "Cavalaria Leve",   "custo": 130, "manut": 8, "comida": 3, "madeira": 1, "pop": 4,
		"classe": "cav", "atq": 130, "dg": 30,  "dc": 40, "da": 30,  "saque": 80, "vel": 10},
	"arq_cavalo": {"nome": "Arq. a Cavalo",    "custo": 160, "manut": 10, "comida": 3, "madeira": 2, "pop": 5,
		"classe": "arq", "atq": 120, "dg": 40,  "dc": 30, "da": 50,  "saque": 50, "vel": 10},
	"cav_pesada": {"nome": "Cavalaria Pesada", "custo": 260, "manut": 14, "comida": 4, "madeira": 2, "pop": 6,
		"classe": "cav", "atq": 150, "dg": 200, "dc": 80, "da": 180, "saque": 50, "vel": 11},
}

## Segundos de treino. Cavalaria demora muito mais que lança — é o que faz
## o jogador escolher entre um exército rápido e um exército bom.
## TEMPO DE TREINO, em minutos do relógio (200 = um dia, 600 = um mês).
##
## Os números antigos vinham de quando o quartel tinha relógio próprio em
## segundos reais. Com tudo em dias, 105 por arqueiro significava meio dia
## POR HOMEM: duzentos arqueiros levariam anos de calendário. Aqui o
## treino passa a ser por LOTE de cinco (é assim que o quartel recruta) e
## a escala cabe numa vida: um lote de camponeses sai no mesmo dia, um
## lote de cavalaria pesada leva pouco mais de um mês.
const TEMPO_TREINO := {
	"campones": 12, "lanceiro": 25, "espadachim": 35, "barbaro": 30,
	"arqueiro": 40, "explorador": 20, "cav_leve": 90, "arq_cavalo": 110,
	"cav_pesada": 150,
}

## NÍVEL DE TERRA que cada tropa exige. Cavalo pede pasto, ferreiro e
## cocheira — coisas que um acampamento de mercenário não tem. É a razão
## de a cavalaria não aparecer para quem ainda não comprou terra, e é o
## que dá degrau ao "comprar terra e evoluir".
##   2 = Aldeia (cavalaria leve)   3 = Vila (arqueiro a cavalo)
##   4 = Burgo (cavalaria pesada)
const NIVEL_MINIMO_TROPA := {
	"cav_leve": 2, "arq_cavalo": 3, "cav_pesada": 4,
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

	# ALÉM da borda: a fronteira selvagem, alcançável só pelas duas pontas
	# sem lei do mapa. Nenhuma estrada imperial chega até lá — é isso que
	# faz das Terras Bárbaras o único lugar onde não há trono para tomar.
	"barbaros_rosa":      {"distancia": 9,  "perigo": 0.30},
	"barbaros_sem_rei":   {"distancia": 6,  "perigo": 0.32},
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

# ---------------------------------------------------------------
# NÍVEIS DA TERRA — o PORTÃO DE PROGRESSÃO do jogo.
#
# `cap` é o teto de população militar que a infraestrutura sustenta, e
# `imposto` é quanto cada habitante ATIVO rende por mês. Os dois saem daqui
# e de nenhum outro lugar: é a construção que libera o exército e o ouro,
# não o tempo. Sem esse portão, nada impede o jogador de enfileirar dez mil
# homens no segundo dia.
#
# A tensão que isso cria é de propósito: subir de nível custa ouro e madeira
# AGORA para render teto e imposto DEPOIS.
#
# ---------------------------------------------------------------
# POR QUE NOVE DEGRAUS E NÃO SEIS
# ---------------------------------------------------------------
# A escada tinha seis, e o salto era grande demais: de TENDAS DE LONA para
# CASTELO DE PEDRA em cinco compras. Num jogo de gerenciamento isso custa
# caro de duas formas.
#
#   · Os degraus do meio ficam sem identidade. Se o jogador vai de aldeia a
#     cidade num pagamento, "Vila" e "Burgo" viram números de passagem, não
#     lugares — e a decisão de parar e acumular perde o sentido.
#   · A evolução parece MÁGICA. Faltava o degrau em que a madeira acumulada
#     vira pedra. Aparecia muralha sem que nada antes explicasse de onde ela
#     saiu.
#
# Nove degraus resolvem os dois, e a ordem agora tem uma lógica de MATERIAL,
# não só de tamanho:
#
#     0–1   lona          o acampamento se fixa e ganha cerca
#     2–4   madeira       casa, capela, moinho, mercado
#     5     PEDRA ENTRA   pedreira, primeira construção de pedra
#     6–7   muralha       o povoado vira praça fechada e depois cidade
#     8     castelo       a torre de menagem corta o morro
#
# O CUSTO TOTAL DO CAMINHO QUASE NÃO MUDOU (9.960 de ouro contra 9.400
# antes, 2.530 de madeira contra 2.310). Isso é deliberado: o pedido era
# mais degraus, não um jogo mais longo. O que muda é o TAMANHO de cada
# compra — a primeira subida custa 80 em vez de 200, então o jogador vê a
# terra mudar no primeiro mês em vez do quinto, e a recompensa visual chega
# com o dobro da frequência.
#
# `cap` e `imposto` continuam estritamente crescentes (teste_reino cobra).
# ---------------------------------------------------------------
## A ESCADA DA TERRA — e ela é cara de propósito.
##
## Terra custava 300 e o primeiro degrau, 80: quem trabalhava dois meses
## na taverna já era senhor, e a promessa de "começar do zero e escalar"
## virava um atalho de meia hora. Agora a primeira gleba custa 5.000 (é a
## meta de uma campanha inteira de trabalho e contrato) e cada degrau
## acima custa 35% mais que o anterior — a curva que o pedido definiu.
##
## Os números foram gerados por essa regra e escritos à mão aqui para a
## tabela continuar legível de bater o olho.
const PRECO_TERRA := 5000
const NIVEIS_TERRA := [
	{"nome": "Acampamento",   "custo_ouro": 0,     "custo_madeira": 0,    "cap": 30,  "imposto": 0.35},
	{"nome": "Paliçada",      "custo_ouro": 1200,  "custo_madeira": 60,   "cap": 50,  "imposto": 0.44},
	{"nome": "Aldeia",        "custo_ouro": 1620,  "custo_madeira": 110,  "cap": 85,  "imposto": 0.55},
	{"nome": "Vila",          "custo_ouro": 2187,  "custo_madeira": 180,  "cap": 135, "imposto": 0.70},
	{"nome": "Burgo",         "custo_ouro": 2952,  "custo_madeira": 280,  "cap": 200, "imposto": 0.88},
	{"nome": "Vila de Pedra", "custo_ouro": 3986,  "custo_madeira": 420,  "cap": 290, "imposto": 1.10},
	{"nome": "Cidade Murada", "custo_ouro": 5381,  "custo_madeira": 620,  "cap": 410, "imposto": 1.40},
	{"nome": "Cidadela",      "custo_ouro": 7264,  "custo_madeira": 900,  "cap": 590, "imposto": 1.80},
	{"nome": "Castelo",       "custo_ouro": 9807,  "custo_madeira": 1300, "cap": 900, "imposto": 2.40},
]

# ---------------------------------------------------------------
# ESTAÇÕES — o inverno é um inimigo que não se pode subornar.
#
# Dezembro, Janeiro e Fevereiro param as fazendas e dobram o custo de manter
# um exército acampado. É o que obriga jogador E NPCs a planejar guerra para
# a primavera, em vez de sitiar o ano inteiro.
# ---------------------------------------------------------------
const ESTACOES := {
	"primavera": {"nome": "Primavera", "meses": [3, 4, 5],    "comida": 1.15, "cerco": 1.0,
		"cor": "7fa650", "nota": "Os campos brotam. É a estação de marchar."},
	"verao":     {"nome": "Verão",     "meses": [6, 7, 8],    "comida": 1.30, "cerco": 1.0,
		"cor": "c9a227", "nota": "Colheita farta e estradas secas."},
	"outono":    {"nome": "Outono",    "meses": [9, 10, 11],  "comida": 0.85, "cerco": 1.3,
		"cor": "a5622d", "nota": "O celeiro enche, mas o frio se anuncia."},
	"inverno":   {"nome": "Inverno",   "meses": [12, 1, 2],   "comida": 0.0,  "cerco": 2.0,
		"cor": "8fb4d8", "nota": "As fazendas param. Manter homens em campo custa o dobro."},
}

const NOMES_M := ["Edmund", "Rowan", "Cedric", "Tomas", "Garrick", "Alaric", "Bran", "Osric", "Doran", "Wilfred"]
const NOMES_F := ["Mira", "Elysia", "Sable", "Anora", "Gwen", "Isolde", "Runa", "Catrin", "Lyra", "Maren"]
const SOBRENOMES := ["de Vale Frio", "Mãos-de-Ferro", "o Errante", "de Ravenport", "Colina Verde", "Sangue-Velho"]

static func rnd(arr: Array):
	return arr[randi() % arr.size()]

static func ri(a: int, b: int) -> int:
	return a + randi() % (b - a + 1)
