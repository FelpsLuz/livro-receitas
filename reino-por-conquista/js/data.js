// ============================================================
// REINO POR CONQUISTA — dados do mundo
// 6 reinos, NPCs com personalidade, mercadorias, nomes
// ============================================================
'use strict';

const MERCADORIAS = {
  trigo:   { nome: 'Trigo',   precoBase: 10, icone: '🌾' },
  madeira: { nome: 'Madeira', precoBase: 14, icone: '🪵' },
  ferro:   { nome: 'Ferro',   precoBase: 30, icone: '⛏️' },
  sal:     { nome: 'Sal',     precoBase: 22, icone: '🧂' },
  tecidos: { nome: 'Tecidos', precoBase: 26, icone: '🧵' },
  cavalos: { nome: 'Cavalos', precoBase: 80, icone: '🐴' },
  armas:   { nome: 'Armas',   precoBase: 45, icone: '⚔️' },
};

// producao: o que o reino produz bem (oferta alta = preço baixo lá)
// ERA DO AÇO, SEM MAGIA. O IMPÉRIO é o mais forte: 10 Lordes Comandantes,
// nenhum com recursos completos (um tem o ferro, outro o grão, outro os rios).
const REINOS_BASE = [
  {
    id: 'imperio', nome: 'Império Central', cor: '#1a4a2a', imperial: true, nobres: 10,
    producao: ['ferro', 'cavalos'], capital: 'Trono Verde',
    rei: { id: 'rei_imperio', nome: 'Felps, o Destruidor', genero: 'm', personalidade: 'cruel',
           desc: 'Gênio da logística e do direito de conquista. Expandiu a ferro (trabucos e balistas) e a tinta (tratados de anexação que sufocam antes da batalha). Dez Lordes Comandantes governam em seu nome — nenhum com recursos completos.' },
  },
  {
    id: 'touros', nome: 'Touros Negros', cor: '#1c1c22', nobres: 3,
    producao: ['madeira', 'sal'], capital: 'Covil Negro',
    rei: { id: 'rei_touros', nome: 'Touro Bill', genero: 'm', personalidade: 'orgulhoso',
           desc: 'Não é um rei: é um senhor do crime e líder de proscritos dos pântanos. Veterano desiludido que acolhe desertores e camponeses arruinados. Não liga para leis dinásticas — só lealdade e sobrevivência.' },
  },
  {
    id: 'alvorecer', nome: 'Alvorecer Dourado', cor: '#c9a227', nobres: 6,
    producao: ['trigo', 'tecidos'], capital: 'Aurora Alta',
    rei: { id: 'rei_alvorecer', nome: 'Enzo Noites', genero: 'm', personalidade: 'calculista',
           desc: 'Mestre da guerra econômica e da espionagem. Não tem o maior exército — tem os cofres mais cheios. Sorri em jantares diplomáticos enquanto financia mercenários para queimar as colheitas dos rivais.' },
  },
  {
    id: 'leoes', nome: 'Leões Carmesins', cor: '#8b1a1a', nobres: 5,
    producao: ['ferro', 'trigo'], capital: 'Chama Rubra',
    rei: { id: 'rei_leoes', nome: 'Fogo no Leão', genero: 'm', personalidade: 'honrado',
           desc: 'Arquiteto de campanhas: estuda terreno, clima e moral. Governa em diarquia com a irmã, Leoa Vermelha, comandante da vanguarda. Lei marcial estrita: covardia é morte, mérito faz plebeu virar nobre.' },
  },
  {
    id: 'aguias', nome: 'Águias Prateadas', cor: '#9aa4ae', nobres: 4,
    producao: ['tecidos', 'cavalos'], capital: 'Ninho de Prata',
    rei: { id: 'rei_aguias', nome: 'Fred Prateado', genero: 'm', personalidade: 'orgulhoso',
           desc: 'Monarca absolutista das montanhas de prata e ferro, paranoico com a pureza da linhagem. Arrogante e isolacionista: vê os outros reinos como bárbaros que acabarão se destruindo sozinhos.' },
  },
  {
    id: 'rosa', nome: 'Rosa Azul', cor: '#2d4a8a', nobres: 5,
    producao: ['sal', 'madeira'], capital: 'Jardim Azul',
    rei: { id: 'rei_rosa', nome: 'Eva Rosada', genero: 'f', personalidade: 'calculista',
           desc: 'Governa uma sociedade matriarcal das planícies fluviais. Estrategista cínica: casamentos e diplomacia são armas. Sempre ajuda o reino mais fraco — para que o mais forte jamais vença.' },
  },
];

// LORDES nomeados de cada reino (profundidade de personagem).
// Cada um recebe uma cidade sorteada a cada novo jogo.
const LORDES_BASE = {
  imperio: [
    { nome: 'Armando Golpes', fem: false, papel: 'Estrategista-chefe: táticas de pinça e flanqueamento nas planícies.' },
    { nome: 'Geraldo Dano', fem: false, papel: 'General de artilharia pesada: mestre de trabucos e balistas de cerco.' },
    { nome: 'Gil Tine', fem: false, papel: 'Juiz e executor imperial: sufoca rebeliões pela raiz.' },
    { nome: 'Rolando Ladeira', fem: false, papel: 'Comandante da cavalaria de choque: atropela do terreno elevado.' },
    { nome: 'Sara Cura', fem: true, papel: 'Intendente geral: logística de suprimentos, bandagens e rações.' },
    { nome: 'Mário Netos', fem: false, papel: 'Mestre espião: manipula prefeitos como marionetes via chantagem.' },
    { nome: 'Décio Teto', fem: false, papel: 'Engenheiro de fortificações: túneis de sapadores colapsam muralhas.' },
    { nome: 'Lino Coro', fem: false, papel: 'Mestre de armas: treina recrutas a chicote e disciplina de ferro.' },
    { nome: 'Simas Prato', fem: false, papel: 'Feitor de terras: tributos de grão que esvaziam os pratos do povo.' },
    { nome: 'César K. Beca', fem: false, papel: 'Interrogador-chefe: extrai segredos de desertores e espiões.' },
  ],
  touros: [
    { nome: 'Zeca Peta', fem: false, papel: 'Guerrilheiro brutal: emboscadas incendiárias em florestas densas.' },
    { nome: 'Tina Tralha', fem: true, papel: 'Engenheira de sucata: transforma ferro-velho em armadilhas mortais.' },
    { nome: 'Beto Mando', fem: false, papel: 'Capitão de saques: invade rotas logísticas dos reinos maiores.' },
  ],
  alvorecer: [
    { nome: 'Grana Dobre', fem: false, papel: 'Banqueiro-mor: multiplica o tesouro com juros sobre reinos menores.' },
    { nome: 'Oscar Lote', fem: false, papel: 'Diplomata astuto: alianças falsas e calotes militares na hora H.' },
    { nome: 'Ana Lise', fem: true, papel: 'Chefe de inteligência: prevê a economia inimiga por dados de colheita.' },
    { nome: 'Ed Dívida', fem: false, papel: 'Cobrador mercenário: asfixia cidades neutras com taxas de "segurança".' },
    { nome: 'Hélio Lucro', fem: false, papel: 'Mercador monopolista: infla o preço de ferro e madeira no inverno.' },
    { nome: 'Lara Pido', fem: true, papel: 'Falsificadora real: forja selos militares para desviar tropas do alvo.' },
  ],
  leoes: [
    { nome: 'Armando Guerra', fem: false, papel: 'Veterano das falanges: vive exclusivamente para o combate aberto.' },
    { nome: 'Marco Bate', fem: false, papel: 'Campeão da vanguarda: quebra a linha de escudos nos primeiros minutos.' },
    { nome: 'Vitor Ioso', fem: false, papel: 'Estrategista pragmático: calcula baixas aceitáveis pelo território.' },
    { nome: 'Bárbara Dano', fem: true, papel: 'Líder dos invasores de choque: rompe portões com aríetes.' },
    { nome: 'Hugo Piar', fem: false, papel: 'Instrutor de combate: lanceiros de precisão em formação fechada.' },
  ],
  aguias: [
    { nome: 'Altair Fino', fem: false, papel: 'Aristocrata das altitudes: arqueiros de longo alcance nas encostas.' },
    { nome: 'Muro Forte', fem: false, papel: 'Arquiteto militar: desfiladeiros bloqueados por fortalezas.' },
    { nome: 'Nando Joias', fem: false, papel: 'Controlador das minas de prata: compra o melhor aço do continente.' },
    { nome: 'Paty Cínica', fem: true, papel: 'Diplomata defensiva: recusa propostas com desdém elitista.' },
  ],
  rosa: [
    { nome: 'Eva Ziva', fem: true, papel: 'Comandante de bater e correr: recuos falsos que atraem para o pântano.' },
    { nome: 'Vera Cida', fem: true, papel: 'Mestra dos batedores: nenhuma informação falsa passa por ela.' },
    { nome: 'Rita Tática', fem: true, papel: 'Estrategista de flancos: cerca suprimentos, ignora a tropa principal.' },
    { nome: 'Gina Ginete', fem: true, papel: 'A melhor amazona do reino: cavalaria ultrarrápida na retaguarda.' },
    { nome: 'Bela Dona', fem: true, papel: 'Sabotadora silenciosa: envenena poços e celeiros de fortes sitiados.' },
  ],
};

// bandeiras que o jogador pode escolher ao fundar o próprio reino
const BANDEIRAS_JOGADOR = [
  { id: 'jogador_1', nome: 'Martelo e Atalaia', desc: 'Verde-escuro com picareta e martelo cruzados sob a torre de vigia. Para quem construiu tudo do zero.' },
  { id: 'jogador_2', nome: 'Balança de Ouro e Grão', desc: 'Púrpura com a balança pesando moeda e trigo. Para quem venceu pelo comércio.' },
  { id: 'jogador_3', nome: 'Âncora Acorrentada', desc: 'Rubro e branco esquartelado com âncora e corrente. Para quem domina rios e rotas.' },
];
const CUSTO_FUNDAR_REINO = 50000;

// cidades dos nobres: sorteadas a cada novo jogo
const NOMES_CIDADES = ['Pedraverde', 'Vau do Sol', 'Ravina Alta', 'Porto Cinza', 'Vila das Brumas',
  'Colina do Falcão', 'Forte Aurora', 'Passo do Lobo', 'Baía Rubra', 'Campo Largo', 'Torre Velha',
  'Vale Fundo', 'Ponte Queimada', 'Outeiro Real', 'Foz Dourada', 'Serra do Espinho', 'Lago Prata',
  'Rocha Negra', 'Vinha Alta', 'Charco Frio', 'Encosta Rubra', 'Moinho Velho', 'Cruz do Vento',
  'Porto das Andorinhas', 'Muralha Baixa', 'Clareira do Cervo', 'Poço Fundo', 'Alto do Trovão',
  'Ermida Azul', 'Curva do Rio'];

// NPCs menores que aparecem na taverna / corte
const NPCS_BASE = [
  { id: 'taverneiro', nome: 'Bram, o Taverneiro', genero: 'm', personalidade: 'ganancioso',
    desc: 'Sabe de tudo que acontece na estrada. Informação custa cerveja... ou ouro.' },
  { id: 'capitao', nome: 'Capitã Renna', genero: 'f', personalidade: 'honrado',
    desc: 'Mercenária veterana. Pode treinar suas tropas — se te respeitar.' },
  { id: 'espiao', nome: 'O Corvo', genero: 'm', personalidade: 'calculista',
    desc: 'Ninguém sabe seu nome real. Vende segredos para quem paga melhor.' },
];

const NOMES_M = ['Edmund','Rowan','Cedric','Tomas','Garrick','Alaric','Bran','Osric','Doran','Wilfred'];
const NOMES_F = ['Mira','Elysia','Sable','Anora','Gwen','Isolde','Runa','Catrin','Lyra','Maren'];

const SOBRENOMES = ['de Vale Frio','Mãos-de-Ferro','o Errante','de Ravenport','Colina Verde','Sangue-Velho'];

// Tipos de tropa: custo, manutenção, ataque, defesa
const TROPAS = {
  campones:  { nome: 'Camponeses',  custo: 5,   manut: 1, atq: 1, def: 1, icone: '🧑‍🌾' },
  lanceiro:  { nome: 'Lanceiros',   custo: 20,  manut: 2, atq: 3, def: 4, icone: '🗡️' },
  arqueiro:  { nome: 'Arqueiros',   custo: 25,  manut: 2, atq: 4, def: 2, icone: '🏹' },
  cavaleiro: { nome: 'Cavaleiros',  custo: 120, manut: 6, atq: 8, def: 7, icone: '🐎' },
};

// Formações: pedra-papel-tesoura tático
// linha > cunha (segura a carga), cunha > cerco (rompe), cerco > linha (envolve)
const FORMACOES = {
  linha: { nome: 'Linha de Escudos', venceDe: 'cunha', desc: 'Defensiva. Segura cargas de cavalaria.' },
  cunha: { nome: 'Cunha', venceDe: 'cerco', desc: 'Ofensiva. Rompe o centro inimigo.' },
  cerco: { nome: 'Envolvimento', venceDe: 'linha', desc: 'Flanqueia linhas estáticas.' },
};

// Níveis do assentamento — progressão visual da cidade
const NIVEIS_TERRA = [
  { nome: 'Acampamento', custoOuro: 0,    custoMadeira: 0,   desc: 'Mato e algumas tendas.' },
  { nome: 'Aldeia',      custoOuro: 200,  custoMadeira: 60,  desc: 'Casas de madeira e uma paliçada.' },
  { nome: 'Vila',        custoOuro: 500,  custoMadeira: 150, desc: 'Moinho, campos organizados, paliçada reforçada.' },
  { nome: 'Burgo',       custoOuro: 1200, custoMadeira: 300, desc: 'Muros de pedra, mercado movimentado.' },
  { nome: 'Cidade',      custoOuro: 2500, custoMadeira: 600, desc: 'Torres de vigia, mercado cheio de NPCs.' },
  { nome: 'Castelo',     custoOuro: 5000, custoMadeira: 1200, desc: 'Um castelo digno de um rei.' },
];

const MESES = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
               'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

function rnd(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function ri(a, b) { return a + Math.floor(Math.random() * (b - a + 1)); }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
