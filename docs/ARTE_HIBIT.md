# Arte Hi-Bit — geração, tratamento e integração

Estado real do repositório. Guarda: `tests/teste_arte.gd` (44 asserções).

```bash
python3 ferramentas/hibit/gerar_assets.py --listar     # plano e saldo
python3 ferramentas/hibit/gerar_assets.py --tudo       # gera (gasta API)
python3 ferramentas/hibit/gerar_assets.py --recolher   # busca job já pago
python3 ferramentas/hibit/tratar_assets.py             # trata (custo zero)
```

Cru em `ferramentas/hibit/cru/`; tratado em `assets/sprites/`. Separar as
duas etapas é o que permite re-tratar mil vezes sem gastar um centavo.

**Gasto real desta leva: US$ 0,1027 em 22 chamadas.**

---

## O que existe

| asset | tamanho | endpoint |
|---|---|---|
| `campo_terra_atlas` | 128×128 (4×4 de 32) | `/create-tileset` |
| `grama_pedra_atlas` | 128×128 | `/create-tileset` |
| `praia_agua_atlas` | 128×128 | `/create-tileset` |
| `prop_arvore_carvalho` | 64×80 | `/create-image-pixflux` |
| `prop_pedra` | 48×40 | `/create-image-pixflux` |
| `prop_arbusto` | 32×32 | `/create-image-pixflux` |
| `prop_tronco` | 48×32 | `/create-image-pixflux` |
| `aldeao_{south,east,north,west}` | 48×68 | `/create-character-with-4-directions` |

O que ainda não tem desenho (casa, muralha, moinho, tenda, ponte, torre)
continua na planta da vila como **caixote cinza**, por `TAMANHO_PENDENTE`.
É de propósito: peça faltando que some da tela some também da cabeça de quem
está priorizando. Caixote na tela é lista de tarefas.

---

## Três coisas que o pedido presumia e a API não faz assim

### 1. Um tileset multi-material não existe

O prompt pedia grama + caminho de terra + borda d'água numa folha só.
`/create-tileset` gera a transição **Wang entre dois materiais**
(`lower_description` × `upper_description`). O pedido virou três chamadas —
grama×terra, grama×pedra, areia×água — e o resultado é melhor: cada par tem
borda de verdade, e os três nomes já eram os que `MapaV2.ATLAS` esperava.

E a resposta é ainda melhor que uma folha: vêm **16 tiles com a máscara de
cantos explícita** em cada um. O atlas 4×4 é montado pondo cada tile na
célula que `MapaV2.WANG` vai procurar — correto **por construção**, sem
depender de a API e a engine terem escolhido a mesma convenção, que é onde
esse tipo de integração quebra em silêncio.

### 2. `#FF00FF` não volta como `#FF00FF`

O modelo devolve o magenta que ele achou parecido, e **um diferente por
imagem**:

```
arbusto (221, 71,171)   árvore (253, 99,138)
pedra   (174, 46,151)   tronco (196, 53,145)
```

`if cor == (255,0,255)` recortaria zero pixels nas quatro. A chave é
**medida** em cada imagem (moda do anel de borda) e o corte é por distância,
em cinco passadas — inundação da borda, ilha interna, franja de anti-alias,
família de matiz conectada ao fundo, e mancha isolada. Cada passada existe
porque uma imagem real derrubou a anterior; os motivos estão em
`tratar_assets.py`.

### 3. Pedir fundo magenta TINGE o personagem

Este foi o achado que mudou a abordagem. Os três primeiros aldeões saíram
com túnica em `rgb(91,52,85)` e botas em `rgb(43,22,48)` — **roxo**, não
marrom. O modelo puxa a paleta do sujeito para a do fundo pedido. Aí não
existe limiar que separe um do outro, porque não são coisas diferentes: o
chroma key comia o personagem junto e sobravam 5% de silhueta.

Some-se que três chamadas independentes davam **três pessoas** — cabelo,
roupa e altura mudando de uma direção para a outra.

`/create-character-with-4-directions` resolve os dois de uma vez: as quatro
rotações do **mesmo** personagem, fundo transparente e alfa já **binário**
(medido: 0 pixels parciais). Nenhum chroma key é necessário.

> `no_background=true` no pixflux também foi testado, e não é substituto:
> devolveu a imagem 100% opaca, com uma floresta desenhada atrás.

---

## Tratamento

**Alfa binário sempre.** Meio-alfa com filtro Nearest não suaviza nada — só
deixa borda suja que aparece contra qualquer fundo.

**Os `.import` são escritos pelo pipeline**, não deixados no default:

| chave | valor | por quê |
|---|---|---|
| `compress/mode` | `0` | Lossless. O default comprime em VRAM com perda por bloco — num sprite de 32px isso muda cor de pixel, sem erro no console |
| `process/fix_alpha_border` | `false` | Ele sangra a cor do sprite para dentro do transparente, para o filtro linear não puxar preto. Com Nearest não há esse problema, e o sangramento altera justo os pixels de borda que o recorte acabou de definir |
| `mipmaps/generate` | `false` | mipmap de pixel art é borrão |
| `detect_3d/compress_to` | `0` | desliga a heurística que recomprime a textura sozinha |

---

## Integração

**TileSet** (`mapa_v2.gd`): carrega o atlas real, mantém camada de física com
polígono de colisão nos tiles sólidos e camada de navegação nos caminháveis,
e ganhou **terrain set** de 2 terrenos em `TERRAIN_MODE_MATCH_CORNERS` para
auto-tiling no editor. Modo de cantos e não `CORNER_AND_SIDES`: o atlas é
Wang de 4 cantos, e declarar lados que a arte não tem faria a Godot procurar
tile inexistente e deixar buraco.

**Personagem** (`personagens_v2.gd`): `AgenteMovel.direcao_de` devolve 8
direções porque o vetor tem 8 octantes; a arte tem 4. O mapa 8→4 vive aqui,
não lá — é o que mantém a mecânica ignorando quantos desenhos existem. As
diagonais caem na **lateral**, não na frontal: num top-down é a leitura de
perfil que vende o movimento.

**Grade** (`vila_cena.gd`): `ESCALA_MUNDO` foi de 0.5 para **1.0**. Antes o
mundo era montado em 1920×1080 e reduzido pela metade, o que mostrava um
tile de 32px com 16 — metade da resolução que se pagou para gerar. Agora a
janela é 480×270 de arte (×2 no container) e a câmera passeia pelos 60×34
tiles do mundo. `ESCALA_HEROI` e `ESCALA_ALDEAO` foram para 1.0: escala
fracionária reamostra o sprite e quebra a grade.

**Y-Sort** em `mundo` e nas camadas de terreno. Toda origem nos pés — é o Y
do ponto que toca o chão que o sort compara.

**Vento** (`vento_folhagem.gdshader`) nas árvores e arbustos, com material
**compartilhado**: um `ShaderMaterial` por árvore seria um uniform buffer por
árvore, e a fase de cada uma já sai da posição no mundo, dentro do shader.

---

## O que falta

- **Quadros de caminhada.** A estrutura `<dir>_walk` existe e roda mais
  rápido que a pose parada, mas com um quadro só. `/animate-with-text-v3`
  preenche isso sem tocar em `VisualController`.
- **Os props pendentes**: casa, ferraria, moinho, muralha, portão, torre,
  tenda, carroça, poço, ponte, barril, saco, baú, fogueira, tocha.
- **As outras três estações** dos tilesets.
