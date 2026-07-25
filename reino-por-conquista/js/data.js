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
// O IMPÉRIO é o mais forte: exército maior e 10 nobres vassalos.
const REINOS_BASE = [
  {
    id: 'imperio', nome: 'Império de Felps', cor: '#1a4a2a', imperial: true, nobres: 10,
    producao: ['ferro', 'cavalos'], capital: 'Trono Verde',
    rei: { id: 'rei_imperio', nome: 'Felps, o Destruidor', genero: 'm', personalidade: 'cruel',
           desc: 'O Imperador do brasão verde-escuro. Dez nobres governam cidades em seu nome. Nunca perdeu uma guerra — e faz questão de lembrar.' },
  },
  {
    id: 'touros', nome: 'Touros Negros', cor: '#1c1c22', nobres: 4,
    producao: ['madeira', 'sal'], capital: 'Covil Negro',
    rei: { id: 'rei_touros', nome: 'Yami Sukehiro', genero: 'm', personalidade: 'orgulhoso',
           desc: 'Bruto, direto e mais forte do que parece. "Supere seus limites. Aqui e agora." Odeia rodeios.' },
  },
  {
    id: 'alvorecer', nome: 'Alvorecer Dourado', cor: '#c9a227', nobres: 4,
    producao: ['trigo', 'tecidos'], capital: 'Aurora Alta',
    rei: { id: 'rei_alvorecer', nome: 'William Vangeance', genero: 'm', personalidade: 'calculista',
           desc: 'Gentil na voz, insondável nos planos. Ninguém sabe o que há atrás da máscara.' },
  },
  {
    id: 'leoes', nome: 'Leões Carmesins', cor: '#8b1a1a', nobres: 4,
    producao: ['ferro', 'trigo'], capital: 'Chama Rubra',
    rei: { id: 'rei_leoes', nome: 'Fuegoleon Vermillion', genero: 'm', personalidade: 'honrado',
           desc: 'Honra em brasa. Sua irmã Mereoleona comanda a vanguarda — e é ainda mais assustadora.' },
  },
  {
    id: 'aguias', nome: 'Águias Prateadas', cor: '#9aa4ae', nobres: 4,
    producao: ['tecidos', 'cavalos'], capital: 'Ninho de Prata',
    rei: { id: 'rei_aguias', nome: 'Nozel Silva', genero: 'm', personalidade: 'orgulhoso',
           desc: 'Altivo como a prata do brasão. Despreza plebeus — até que provem seu valor.' },
  },
  {
    id: 'rosa', nome: 'Rosa Azul', cor: '#2d4a8a', nobres: 4,
    producao: ['sal', 'madeira'], capital: 'Jardim Azul',
    rei: { id: 'rei_rosa', nome: 'Charlotte Roselei', genero: 'f', personalidade: 'romantica',
           desc: 'Espinhos por fora, segredos por dentro. Rainha guerreira que ninguém jamais viu corar. Quase ninguém.' },
  },
];

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
