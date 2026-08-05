# Cenário — a terra do jogador

Documento único do cenário. Descreve o **estado real** do repositório, não
um plano. Se algo aqui divergir do código, o código está certo e este texto
está velho.

---

## O que a cena é

Cada estágio de evolução da terra é **uma imagem única de 480×270 já
pintada**, em `reino-por-conquista-godot/assets_v3/estagios/<estacao>/`. Não
há montagem em camadas, não há posicionamento de peças na engine, não há
placa de fundo com objetos por cima.

Seis estágios, na ordem narrativa:

| # | Arquivo | Nível de terra correspondente |
|---|---|---|
| 0 | `e1_virgem.png` | Acampamento |
| 1 | `e2_acampamento.png` | Aldeia |
| 2 | `e3_assentamento.png` | Vila |
| 3 | `e4_forte.png` | Burgo |
| 4 | `e5_muralha.png` | Cidade |
| 5 | `e6_completo.png` | Castelo |

Seis estágios para os seis degraus de `Dados.NIVEIS_TERRA` — a correspondência
é 1:1 e é por isso que a tradução nível→estágio é uma atribuição direta.

**Princípio que governa a arte:** fidelidade vem de recortar, não de gerar.
Todo pixel que puder sair da imagem original sai dela; só se gera o que a
imagem não contém.

---

## Por que não é mais em camadas

Duas arquiteturas anteriores foram removidas na branch `cenario-v4`:

1. **Panorama em 12 camadas** (`assets_v2/panorama/`, `panorama_cena.gd`).
   Cada camada nasceu de uma chamada independente da API e trazia o seu
   próprio estilo. A coesão tinha que ser reconstruída na engine com véus,
   neblina e sombras — e mesmo assim a costura aparecia.

2. **Placa + tiras** (`assets_v2/cenario/`, `ferramentas/cenario_v2/`). Uma
   placa de fundo gerada e transformada por receita declarativa, com tiras
   de floresta e terreno coladas por cima. Resolveu a coesão de cor, mas
   custava um pipeline inteiro de construção e auditoria para produzir um
   quadro que uma imagem única entrega pronta.

O que as duas tentativas ensinaram e continua valendo está registrado
abaixo, em **Armadilhas medidas**.

---

## O pipeline

### Pixelização — `ferramentas/cenario_v3/processar_estagios.py`

De mockup em alta resolução para asset usável. A ordem é inegociável:
quantizar antes de reduzir gera lixo, porque a quantização fixa a cor de
pixels que ainda vão ser mesclados.

```
1. recorte de moldura e de proporção 16:9
2. redução para 480×270 por BOX (média de área) — nunca bicúbica ou lanczos
3. paleta derivada do estágio 6 DESTA estação, 48–56 cores
4. quantização dos 6 com A MESMA paleta
5. ampliação nearest ×2 (fator inteiro) só para exibição
```

```
python3 ferramentas/cenario_v3/processar_estagios.py <dir> --estacao verao --ordem 6,1,2,3,4,5
```

A `--ordem` é explícita de propósito. Duas métricas automáticas foram
testadas e as duas erram: densidade de detalhe põe a E6 antes da E4, e massa
de pedra não separa E4/E5/E6 porque a rocha da montanha cai na mesma faixa
de cinza. Um argumento explícito é mais honesto que um heurístico que erra
em silêncio.

A paleta sai por **rampa em OKLab**, não por k-means. O mockup traz milhares
de cores por causa do anti-aliasing; k-means nelas devolve paleta lamacenta.
As conversões estão em `ferramentas/cenario_v3/oklab.py`.

### Medição — `ferramentas/cenario_v3/medir_estagios.py`

Duas saídas, com propósitos distintos:

- `coordenadas.json` — **registro** de onde estão o rio, a margem e as cores
  de água e junco na E6. Não é posicionamento: a cena já vem pintada. Serve
  para ancorar overlay, alimentar os shaders e depurar.
- `transicoes.json` — o que muda de um estágio para o próximo, em **células
  de 30px ordenadas por densidade de mudança**. É o que a poeira de obra usa.

---

## Vida — `shaders/vida_estagio.gdshader`

Um shader só, sobre a imagem achatada, com duas animações que operam por
**correspondência de cor**, não por camada:

- **Ciclo de paleta na água.** As cores claras do rio rodam numa rampa; as
  escuras ficam paradas, senão o corpo d'água pulsa em vez de correr.
- **Balanço do junco.** Peso quadrático pela altura — pé cravado, topo
  balançando — com deslocamento arredondado para **pixel inteiro**, porque
  fração vira tremulação.

Duas ressalvas que só apareceram na imagem achatada:

- O balanço **não pode ir no vertex**. Num quad de tela cheia, deslocar
  `VERTEX.x` move a imagem inteira. O deslocamento tem que ser na
  **amostragem**: decide-se pela cor original se o pixel é junco e, se for,
  lê-se de uma UV deslocada.
- Correspondência de cor sozinha não basta. As cores claras do rio também
  existem no céu, e sem a **porta espacial** (`agua_topo`) o ciclo mexia
  7792px da imagem inteira em vez dos ~850px da água.

---

## Evolução como recompensa — `scripts/cenario_v3_cena.gd`

Subir de nível não é corte seco. São três coisas simultâneas:

- **crossfade de 0,8s** entre a imagem velha (por baixo) e a nova (por cima,
  subindo de alpha 0);
- **poeira de obra** — `CPUParticles2D` emitindo só nas células onde o diff
  mediu mudança, no máximo 26 delas;
- **flash branco curto** de 0,18s a 30% de alpha, que marca o instante sem
  ofuscar.

São **dois tweens, não um**. Com `set_parallel(true)` num tween só, o
`chain()` do flash espera o crossfade inteiro e o clarão trava no pico por
0,8s.

A poeira sai das **células de obra**, não da bbox global: entre estágios a
quantização deixa pixel mudado espalhado e a caixa global cobre a tela toda.

---

## A ponte com o jogo — `scripts/cenario_v3_view.gd`

`principal.gd::_nova_cena()` pede sempre a mesma coisa de quem desenha a
terra: um `SubViewportContainer` com `estado` e `semear_npcs()`. O
`CenarioV3Cena` é um `Node2D` que não sabe nada de estado de jogo, então este
nó faz a ponte — e só isso.

- `estado.terra.nivel` → índice de estágio, direto.
- **Carregar um save não anima.** Só a subida de nível com o jogo já rodando
  entra pela recompensa. Sem essa distinção, abrir um save no nível 3
  disparava o crossfade na abertura como se o jogador tivesse acabado de
  subir.
- **Uma evolução em curso recusa outra.** Quem chama precisa saber disso
  (`cena.em_transicao()`): registrar como montado um pedido que foi recusado
  dessincroniza a vista do estado para sempre.
- `semear_npcs()` não faz nada, de propósito. Os aldeões estão pintados na
  imagem; não há nó para semear. O método existe porque o contrato pede.

A ordem de preferência em `_nova_cena()` é: **cenário v3 → vila em TileMap →
cenário procedural**.

---

## Armadilhas medidas

Cada uma destas custou uma tentativa errada e está aqui para não custar duas.

**Moldura.** Recortar sem repor **desloca o conteúdo**. A E6 veio com moldura
dourada; recortá-la e seguir deixou a imagem 2px fora de registro com as
outras cinco. A correção é recortar e **repor a borda replicando a linha
adjacente**, mantendo a altura.

**Média inventa cor.** Qualquer operação que tire média de cores produz um
valor que não existe na paleta. Ao baixar o maciço da placa v2, a mediana de
duas cores de céu — (175,233,241) e (185,231,241) — deu (180,232,241), que
não estava na paleta, e desenhou uma linha de 1px atravessando a montanha.
Use **moda ou cópia**, nunca média.

**Fusão de paleta por luminância descarta o que ocupa área.** Mesclar cores
em ordem de luminância jogou fora o verde do campo, que cobria 35% do quadro.
A fusão tem que ser **ponderada por frequência de pixel**.

**Escala fracionária destrói a grade.** Escalas de 0,8/0,9/1,0 para dar
profundidade reamostram o sprite e quebram o pixel. Profundidade vem de
escolha de variante, apoio e `modulate` — a escala fica em 1,0, e a ampliação
para tela é **fator inteiro**.

**Z-order do fundo.** Duas vezes um elemento novo nasceu atrás do fundo
porque o fundo estava em z=0. O fundo vai para z negativo bem baixo.

**Selo antes de salvar.** Uma transformação idempotente que salva a imagem e
só depois grava o selo deixa, se falhar no meio, a imagem modificada e sem
selo — e a rodada seguinte aplica a transformação de novo. Grava-se o **selo
primeiro**.

**Dither por erro, não por empate.** Disparar dither quando dois vizinhos de
paleta estão próximos faz ele disparar em quase todo pixel. O gatilho certo é
o **erro de quantização**.

**Direção de luz não se mede por média de flanco.** Num maciço listrado, a
média dos flancos e o gradiente médio se cancelam. O que sobrevive é
**contar pares horizontais** de transição (claro→escuro contra escuro→claro)
a uma distância fixa.

---

## O que ficou de fora

- **Estações.** Só verão existe. `processar_estagios.py` já aceita
  `--estacao`, mas as outras quatro esperam o jogo rodar com verão primeiro.
- **`assets_v3/estagios/verao/`** é a saída da pipeline anterior e continua no
  repositório como rede de segurança até a nova pixelização passar as suas
  asserções.
