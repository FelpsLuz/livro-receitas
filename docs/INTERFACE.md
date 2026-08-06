# Interface — o guia de estilo, implementado

Não é proposta: são os valores que `scripts/tema.gd` e `scripts/icones.gd`
usam agora. Guarda: `tests/teste_hibit.gd`.

---

## A regra que organiza tudo

**Terreno em quatro degraus de umbra. Texto em três pesos. Um acento de
latão. Cada ícone na cor da coisa que ele é.**

A tela é escura porque um jogo de gerenciamento passa a partida inteira em
tabela, e fundo claro por trás de vinte linhas cansa. Mas escura em **umbra**,
não em slate: a primeira versão desta paleta era cinza azulado, que é o
vocabulário de painel de controle industrial. Um reino medieval precisa de
terra queimada, não de aço frio.

O que saiu junto foi a *textura* de madeira e pergaminho — tábua atrás de
número é ruído competindo com o dado. O calor ficou; o entalhe não.

---

## Paleta

### Terreno

| token | hex | onde |
|---|---|---|
| `FUNDO` | `#1A1613` | a tela por trás de tudo, aba inativa, trilho de rolagem |
| `SUPERFICIE` | `#241E19` | painel, aba ativa |
| `ELEVADO` | `#2F2721` | linha de tabela, campo de entrada, botão em repouso, modal |
| `BORDA` | `#453A2E` | separador de 1px |

Quatro degraus e não três: a linha de tabela precisa de um plano próprio
acima do painel, senão vinte linhas seguidas viram um bloco. É a **borda**,
não o preenchimento, que faz vinte linhas lerem como vinte itens.

**Como se mede "quente mas não madeira".** Os quatro têm `r > b` — isso é o
calor. E o croma de todos fica abaixo de **0,12**, medido como amplitude
absoluta dos canais (`max − min`), não como saturação HSV.

A distinção importa e custou uma asserção errada: saturação HSV divide pelo
canal máximo, então quanto mais escura a cor, maior o número para a mesma
diferença física. Pelo HSV, `#010000` é "100% saturado" — e é preto. Num
terreno que vive entre valor 0,10 e 0,27, medir por HSV mede o escuro, não o
colorido. O `BORDA` atual dá 0,33 de saturação HSV e 0,09 de croma real.

O teto de 0,12 não é arbitrário nem foi ajustado até caber: o teste também
verifica que ele **reprova** `#6B4423`, `#8B5A2B` e `#A0522D` — madeira de
verdade, que dá 0,28 a 0,45. Sobra um fator de três de folga para os dois
lados.

### Texto

| token | hex | contraste sobre `SUPERFICIE` | onde |
|---|---|---|---|
| `TEXTO` | `#F0E7D8` | 13,4:1 | corpo, número, rótulo de botão |
| `TEXTO_2` | `#B5A48C` | 6,8:1 | unidade, apoio, aba inativa |
| `TEXTO_3` | `#7A6B58` | — | dica de campo, desabilitado |

Nenhum é branco puro. Branco sobre escuro vibra e cansa em sessão longa; um
off-white de osso assenta com a umbra sem perder contraste.

### Acento — o latão

| token | hex | onde |
|---|---|---|
| `ACENTO` | `#E8B04B` | ouro no HUD, título de seção, borda de foco, aba ativa |
| `ACENTO_FORTE` | `#F5C86B` | hover de botão |

É a cor da **marca**, não a de nenhum item. Nada na tela é mais saturado que
ele — o teste verifica.

### Semântico — separado do acento de propósito

| token | hex | onde |
|---|---|---|
| `GANHO` | `#8FBF6A` | variação positiva, estação favorável |
| `PERIGO` | `#D9603F` | moral ≤ 35, celeiro vazio, perda |

Cor semântica não é cor de marca. Se o ganho fosse o mesmo latão do título,
"subiu" e "isto é um cabeçalho" leriam igual.

---

## Ícones

42 arquivos em `assets/sprites/icone_*.png`, 192×192, gerados pela API do
PixelLab e tratados por `ferramentas/hibit/tratar_assets.py`.

### O arquivo é branco; a cor entra em runtime

Cada PNG é **silhueta branca com alfa binário** — nada de tom, nada de
sombra, nada de anti-alias. A cor vem da tabela `COR` em `icones.gd`.

Isso não é economia de arquivo. É o que deixa a paleta ser decidida num lugar
só: mudar o tom do trigo é uma linha, não 42 imagens regeradas. E é o que
permite um ícone mudar de cor por **estado** — o trigo em terracota quando o
celeiro está vazio — sem um segundo arquivo.

### Cada ícone na cor da coisa

| família | exemplos |
|---|---|
| metais | ferro `#A9B2BA` · correntes `#8D949B` · gema `#6FBFB4` |
| campo e mesa | trigo `#DCC067` · pão `#D4A05F` · cerveja `#D09A4A` · sal `#E2DED2` · madeira `#B07A4A` · tecidos `#A382BD` |
| guerra | espada e lança `#BCC4CC` · escudo `#9FB0C2` · cerco `#D0705A` |
| papel | pergaminho, carta, calendário `#D8C9A8` · coroa `#F5C86B` |
| gente | população, família, aliança `#86A9C4` · moral `#8FBF6A` |
| sombra | espião e intriga `#9B8BB5` · neblina `#8B96A3` |

**Por que não tudo em latão.** Num mercado com doze linhas, doze ícones da
mesma cor viram uma coluna de manchas iguais, e o olho é obrigado a ler o
texto para saber o que é cada linha. Com trigo dourado, ferro em aço e
madeira em castanho, a linha se acha pela cor **antes** de se ler a palavra —
que é o trabalho que um ícone tem numa tabela.

**Duas regras, ambas medidas.** Toda cor passa de 3:1 de contraste sobre o
painel — uma cor bonita no editor que some no escuro é pior que o latão
uniforme, porque some sem avisar. E nenhuma é mais saturada que o `ACENTO`: o
latão continua sendo a coisa mais forte da tela. Foi essa segunda regra que
reprovou o `#D8952F` da cerveja e o `#D9603F` do cerco, hoje suavizados.

### Modulado ou assado

`Icones.imagem()` tinge por `modulate` — barato, e o `TextureRect` aceita.

`Icones.textura_tingida()` **assa a cor nos pixels**, com cache. É o caminho
obrigatório para `TabContainer.set_tab_icon` e `Button.icon`: os dois desenham
a textura crua e não passam por `modulate`, então uma silhueta branca chegaria
branca na aba.

### Filtro LINEAR, não NEAREST

O ícone é forma vetorial rasterizada em 192px e a interface o mostra em 20–48.
Nearest numa redução de 4× serrilha a curva inteira. O filtro que a pixel art
do cenário exige é justamente o que estraga o ícone — por isso o
`texture_filter` é setado por nó, e não herdado do projeto.

### O gerador mente às vezes

Dois dos 42 pedidos voltaram com status `completed` e uma imagem **192×192 de
alfa zero**. Um "sucesso" que é um arquivo vazio entra no projeto e só aparece
como um buraco no HUD. `gerar_assets.py` agora mede a cobertura antes de
aceitar, descarta o vazio e repete o pedido com outra semente — repetir com a
mesma semente devolveria a mesma imagem vazia para sempre.

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

**DejaVu Sans** para texto, **DejaVu Sans Mono** para número, **DejaVu Sans
Bold** para título. Uma família só — hierarquia por peso, não por troca de
tipo. Licença Bitstream Vera / DejaVu, uso comercial liberado.

A monoespaçada no número não é gosto: é o que faz a coluna de preço alinhar
sozinha. Num jogo em que se compara 1.240 com 980 na vertical, isso é leitura.
`teste_hibit` mede — se `1`, `8` e `W` não tiverem a mesma largura, cai.

**Anti-alias LIGADO** (`FONT_ANTIALIASING_GRAY` + `HINTING_LIGHT`). Isto é o
oposto do que fonte de pixel quer, e ficou desligado por herança depois que as
fontes de pixel saíram — serrilhando DejaVu a 15px e jogando fora o ganho do
`stretch/mode = canvas_items` sem que nada acusasse. O teste agora trava.

---

## Forma

**Canto reto, em tudo.** Antes era imposição da pixel art. A pixel art da
interface saiu, então agora é **escolha**: canto vivo e borda de 1px leem como
instrumento e como livro-razão, que é o que o jogo é. Raio de canto puxaria
para app de celular.

**Borda de 1px, não de 2.** Com a paleta escura o contraste entre planos já
separa as regiões; 2px vira moldura.

**Botão chapado.** A versão anterior desenhava rampa de sombra — 1px claro em
cima, 3px escuro embaixo, invertidos ao apertar. É skeuomorfismo, e num tema
chapado é a peça que denuncia que o resto foi só recolorido. O estado vem do
**preenchimento**; o apertado ainda desce 1px, porque o deslocamento é a única
pista tátil que sobrevive ao achatamento — sem ela o clique não confirma nada.

**Sem sombra.** A do `StyleBoxFlat` é um borrão gaussiano, e borrão numa
interface chapada é a peça que não pertence.

---

## Placeholder

`Arte.caixa()` devolve `#2F2721` sobre borda `#453A2E` — um degrau acima da
superfície, **quieto**. Placeholder tem que dizer "falta uma peça aqui", não
roubar a leitura da tabela ao lado.

---

## A terra — seis quadros, um por nível

`assets/sprites/estagio_0N.png`, 400×224, opacos. Um por degrau de
`Dados.NIVEIS_TERRA`: Acampamento, Aldeia, Vila, Burgo, Cidade, Castelo.

**400×224 e não os 480×270 de antes.** O endpoint recusa lado acima de 400 e
exige ambos divisíveis por 4. A alternativa era gerar menor e ampliar, mas
×1,2 não é fator inteiro e borraria a grade toda — então a grade nativa da
cena desceu até a arte. Zero reamostragem em qualquer ponto.

**O cartão é ×1, não ×2.** A aba tem ~330 unidades de canvas de altura útil;
em ×2 o cartão pede 448 e a rolagem cortava o pé do castelo. Ampliar também
não traria nitidez: com `stretch/mode = canvas_items` a janela já aplica o
fator dela (1,33 numa tela de 1280 sobre a base de 960) e nenhum inteiro
sobrevive a isso. Quem segura a grade de pixel é o filtro NEAREST do
viewport, não a escala.

### As seis são a MESMA terra

Seis chamadas independentes dariam seis vales diferentes, e subir de
Acampamento a Castelo leria como teletransporte. A cadeia amarra: cada
estágio usa o anterior como `init_image`, com a mesma câmera e a mesma
semente. O rio, a mata e a linha do horizonte vêm da imagem, não do texto.

**A força da cadeia é o número que decide tudo**, e foi medido:

| `init_image_strength` | resultado |
|---|---|
| 300 | a terra **não evolui** — os seis saem sendo o acampamento |
| 200 | ainda o acampamento, com uma bandeira a mais |
| 120 | o vale se mantém, mas a construção chega só a "aldeia com torres" |
| 60 | o castelo aparece inteiro **e o rio some** — virou outro lugar |

Nenhum valor fixo serve, e isso também custou uma leva: com 140 em todos os
degraus a cadeia anda até o estágio 3 e **empaca** — 04, 05 e 06 saem sendo a
mesma aldeia com telhados trocados. A força não pesa a distância que falta, e
"aldeia → burgo" precisa de mais liberdade que "acampamento → aldeia".

Daí a **rampa** — `170, 145, 115, 90, 70`. Os primeiros passos são pequenos e
a imagem manda; os últimos são saltos de escala e a descrição manda. O vale
sobrevive porque cada passo parte do anterior: o 70 do último degrau olha
para um burgo, não para o acampamento.

O tratamento mede dois pisos (nenhum degrau parado, e ponta-a-ponta acima de
12). São **guardas de regressão** calibradas na leva boa, não prova de
qualidade — prendem a cadeia de voltar a empacar sem ninguém notar. Para
julgar a arte continua valendo abrir a folha de contato e olhar. Foi olhando,
não medindo, que o platô apareceu: cada quadro isolado parecia certo.

---

## Retratos de tropa

`assets/sprites/tropa_<chave>.png`, 64×64, opacos, mostrados a 52px.

**Corpo inteiro, e não busto.** O pedido descrevia "bust shot, cropped at the
chest" e o gerador devolveu figura inteira — e fez bem. As nove unidades se
distinguem pela **arma** e pela **montaria**, e um corte no peito esconde
exatamente as duas; três das nove são cavalaria, que num busto seriam o mesmo
rosto com elmos diferentes.

Por isso também não dava para resolver com os ícones que já existem: três
cavalarias contra **um** ícone de cavalo, e três linhas idênticas na tabela é
pior que três caixotes — a repetição parece bug, o caixote parece pendência.

**Opacos, com o fundo normalizado para `#2F2721`.** O retrato é um quadro
pendurado na linha do quartel, não um sprite solto no terreno: nada é
recortado, então não há franja para errar. O gerador devolveu os nove com
fundos que não combinam (ardósia, cinza claro, esverdeado), e nove quadros
numa coluna com nove fundos diferentes não leem como elenco.

A normalização é por **inundação a partir da borda**, não por limiar global.
A diferença decide o resultado: o espadachim é armadura cinza sobre fundo
cinza, e um limiar global comeria a armadura junto. Só vira fundo o que
encosta na borda e chega até lá por vizinhança.

---

## O que falta

**As ilustrações de evento.** Dez faixas de 128px (`Retratos.EVENTOS`) —
cerco, fome, traição, coroação. Hoje em caixote, e o modal segue só com texto
para quem não tem arte, que é o comportamento correto enquanto elas não
existem.
