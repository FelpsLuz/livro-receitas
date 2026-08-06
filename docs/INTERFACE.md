# Interface — o guia de estilo, implementado

Não é proposta: são os valores que `scripts/tema.gd` usa agora. Guarda:
`tests/teste_hibit.gd`.

---

## A regra que organiza tudo

**Terreno em quatro degraus. Texto em três pesos. Um acento quente.**

A ousadia mora num lugar só — o latão. Todo o resto fica quieto, e é por
isso que o número saltou: ele é a única coisa colorida numa tela de slate.

O tema anterior era pergaminho, madeira e ouro. Bonito de descrever, errado
para o que esta tela é: um jogo de gerenciamento passa a partida inteira em
tabela, e textura de madeira atrás de número é ruído competindo com o dado.

---

## Paleta

### Terreno

| token | hex | onde |
|---|---|---|
| `FUNDO` | `#12151A` | a tela por trás de tudo, aba inativa, trilho de rolagem |
| `SUPERFICIE` | `#1B2027` | painel, aba ativa |
| `ELEVADO` | `#232A33` | linha de tabela, campo de entrada, botão em repouso, modal |
| `BORDA` | `#333C48` | separador de 1px |

Quatro degraus e não três: a linha de tabela precisa de um plano próprio
acima do painel, senão vinte linhas seguidas viram um bloco. É a **borda**,
não o preenchimento, que faz vinte linhas lerem como vinte itens.

### Texto

| token | hex | contraste sobre `SUPERFICIE` | onde |
|---|---|---|---|
| `TEXTO` | `#E4E9EF` | 13,0:1 | corpo, número, rótulo de botão |
| `TEXTO_2` | `#98A3B0` | 5,9:1 | unidade, apoio, aba inativa |
| `TEXTO_3` | `#5F6B79` | 2,7:1 | dica de campo, desabilitado |

Nenhum é branco puro. Branco sobre escuro vibra e cansa em sessão longa; um
off-white levemente frio assenta com o slate sem perder contraste.

### Acento — o único quente

| token | hex | onde |
|---|---|---|
| `ACENTO` | `#E0A93B` | latão: ouro no HUD, título de seção, borda de foco, aba ativa |
| `ACENTO_FORTE` | `#F0C060` | hover de botão |

Latão sobre slate lê como moeda sem precisar de tábua nem de rebite. É o que
carrega a identidade de reino depois que a madeira saiu.

### Semântico — separado do acento de propósito

| token | hex | onde |
|---|---|---|
| `GANHO` | `#57B98B` | variação positiva, estação favorável |
| `PERIGO` | `#E0664A` | moral ≤ 35, celeiro vazio, perda |

Cor semântica não é cor de marca. Se o ganho fosse o mesmo latão do título,
"subiu" e "isto é um cabeçalho" leriam igual.

---

## Tipografia

| token | tamanho | fonte | onde |
|---|---|---|---|
| `MICRO` | 12 | Sans | rótulo de aba, unidade, legenda |
| `CORPO` | 15 | Sans | texto corrido, item de lista |
| `NUMERO` | 16 | **Mono** | dígito em tabela e HUD |
| `CORPO_G` | 19 | Sans | destaque dentro de painel |
| `TITULO_SECAO` | 24 | Sans Bold | cabeçalho de aba |
| `TITULO_JOGO` | 40 | Sans Bold | só a tela de título |

Tamanhos em unidades da viewport base (960×540). Razão ~1,25 entre degraus:
o suficiente para hierarquia sem degrau intermediário que ninguém distingue.

**DejaVu Sans** para texto, **DejaVu Sans Mono** para número, **DejaVu Sans
Bold** para título. Uma família só — hierarquia por peso, não por troca de
tipo. Duas famílias numa interface de gerenciamento já são uma a mais.

A monoespaçada no número não é gosto: é o que faz a coluna de preço alinhar
sozinha. Num jogo em que se compara 1.240 com 980 na vertical, isso é
leitura. `teste_hibit` mede — se `1`, `8` e `W` não tiverem a mesma largura,
o teste cai.

Licença Bitstream Vera / DejaVu, uso comercial liberado.

---

## Forma

**Canto reto, em tudo.** Antes era imposição da pixel art (curva
anti-aliased no canto gritava "isto é CSS"). A pixel art saiu, então agora é
**escolha**: canto vivo e borda de 1px leem como instrumento e como
livro-razão, que é o que o jogo é. Raio de canto puxaria para app de celular.

**Borda de 1px, não de 2.** Com a paleta escura o contraste entre planos já
separa as regiões; 2px vira moldura.

**Botão chapado.** A versão anterior desenhava rampa de sombra — 1px claro em
cima, 3px escuro embaixo, invertidos ao apertar. É skeuomorfismo, e num tema
chapado é a peça que denuncia que o resto foi só recolorido. O estado vem do
**preenchimento**; o apertado ainda desce 1px, porque o deslocamento é a
única pista tátil que sobrevive ao achatamento e sem ela o clique não
confirma nada.

**Sem sombra.** A do `StyleBoxFlat` é um borrão gaussiano, e borrão numa
interface chapada é a peça que não pertence.

---

## Placeholder

`Arte.caixa()` devolve `#28303880` sobre borda `#3D4653` — um degrau acima da
superfície, **quieto**.

Ele era cinza `0,62`, escolhido quando o tema era pergaminho claro, onde
some. Sobre o slate o mesmo cinza virava o elemento mais claro da tela: a
ausência de arte gritava mais alto que a arte. Placeholder tem que dizer
"falta uma peça aqui", não roubar a leitura da tabela ao lado.

---

## O que falta

**Ícones de recurso.** São os retângulos vazios no HUD e nas linhas de
mercado, quartel e clãs. Trigo, madeira, ferro, sal, moedas, população,
moral, ataque, defesa, equipamento.

Direção para o gerador, agora que a paleta existe:

```
flat vector icon, single color #E0A93B on transparent background,
minimal geometric shape, 2px uniform stroke, no gradient, no shadow,
no outline box, centered, 64x64, medieval resource: <trigo | madeira | ...>
```

Um traço só e uma cor só: o ícone não deve competir com o número que está do
lado dele. Se precisar de estado (alerta, ganho), quem tinge é a interface —
o arquivo nasce monocromático.

**A ilustração da aba "Sua Terra".** Seis imagens, uma por nível de terra,
na mesma paleta. É a única superfície do jogo onde arte ilustrada cabe.
