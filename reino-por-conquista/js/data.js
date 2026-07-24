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
};

// producao: o que o reino produz bem (oferta alta = preço baixo lá)
const REINOS_BASE = [
  {
    id: 'valdria', nome: 'Valdria', cor: '#8b2635',
    producao: ['trigo', 'cavalos'], capital: 'Pedravelha',
    rei: { id: 'rei_valdria', nome: 'Rei Aldric', genero: 'm', personalidade: 'orgulhoso',
           desc: 'Um veterano de guerra que valoriza honra acima de tudo — e não perdoa insultos.' },
  },
  {
    id: 'morvane', nome: 'Morvane', cor: '#2d4a6b',
    producao: ['ferro', 'madeira'], capital: 'Forjanegra',
    rei: { id: 'rei_morvane', nome: 'Rainha Iseld', genero: 'f', personalidade: 'calculista',
           desc: 'Fria e paciente. Dizem que cada palavra dela é uma peça num tabuleiro.' },
  },
  {
    id: 'soleara', nome: 'Soleara', cor: '#b8862d',
    producao: ['sal', 'tecidos'], capital: 'Porto do Sol',
    rei: { id: 'rei_soleara', nome: 'Rei Domenico', genero: 'm', personalidade: 'ganancioso',
           desc: 'Mercador coroado. Tudo tem um preço para ele — inclusive a lealdade.' },
  },
  {
    id: 'thornmar', nome: 'Thornmar', cor: '#3e5f3e',
    producao: ['madeira', 'trigo'], capital: 'Carvalho Alto',
    rei: { id: 'rei_thornmar', nome: 'Rei Godric', genero: 'm', personalidade: 'honrado',
           desc: 'Justo e querido pelo povo. Odeia intrigas e quem as fabrica.' },
  },
  {
    id: 'ashkar', nome: 'Ashkar', cor: '#6b3a2d',
    producao: ['ferro', 'sal'], capital: 'Cinzabruta',
    rei: { id: 'rei_ashkar', nome: 'Rei Vukan', genero: 'm', personalidade: 'cruel',
           desc: 'Tomou o trono do irmão à força. Respeita apenas força e teme veneno.' },
  },
  {
    id: 'lysande', nome: 'Lysande', cor: '#5a3a6b',
    producao: ['tecidos', 'cavalos'], capital: 'Torreluz',
    rei: { id: 'rei_lysande', nome: 'Rainha Elara', genero: 'f', personalidade: 'romantica',
           desc: 'Jovem e idealista. Sonha com alianças de casamento e teme a guerra.' },
  },
];

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
