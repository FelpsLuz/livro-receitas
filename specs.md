# specs.md — manifesto de arte

Regras absolutas para qualquer asset gerado a partir daqui. Quem gera arte
lê este arquivo antes; quem revisa cobra por ele.

Guardas automáticas: `tests/teste_arte.gd` e `ferramentas/hibit/tratar_assets.py`.
Regra que não tem guarda é regra que vai ser quebrada em silêncio — se
adicionar uma linha aqui, adicione a medida junto.

---

## 1. Estilo

**Stardew Valley Hi-Bit.** Pixel art limpa e orgânica, paleta terrosa
vibrante, iluminação chapada (`flat lighting`), silhueta legível ao primeiro
olhar.

Assinatura obrigatória no fim de todo prompt — vive em
`AIVisualBridge.montar_prompt` e em `gerar_assets.ESTILO`, num lugar só:

```
Stardew Valley aesthetic, hi-bit pixel art, vibrant earthy colors,
flat lighting, clean readable silhouette
```

Vai no **fim** do prompt de propósito: o modelo pesa mais o começo para o
assunto e o fim para o acabamento.

---

## 2. Resolução e grade

| coisa | grade | canvas real | por quê |
|---|---|---|---|
| tile de terreno | **32×32** | 128×128 (4×4 Wang) | `MapaV2.TILE` |
| personagem | **32×48** | 48×68 | ver a nota abaixo |
| prop pequeno | 32×32 | — | arbusto |
| prop médio | 48×40 | — | pedra, tronco |
| prop grande | 64×80 | — | árvore |
| mundo | 60×34 tiles | 1920×1080 | câmera passeia |
| janela | — | 480×270 (×2 na tela) | 15×8 tiles visíveis |

> ### Nota sobre "personagens em 16×32"
>
> O manifesto pedia 16×32. **Não foi adotado, e a razão é medida.** A 16px de
> largura o aldeão fica com ~6px de tronco e ~3px por braço: o ciclo de
> caminhada não lê — os quadros ficam idênticos entre si porque não há pixel
> onde pôr a diferença de passo.
>
> O padrão é **32×48 de personagem**. É o que Stardew usa de fato (o
> personagem dele tem ~16×32 de corpo mas mora num tile de 16px; aqui o tile
> é 32, então dobra tudo). O canvas sai 48×68 porque
> `/create-character-with-4-directions` reserva ~40% a mais para a animação
> caber — e isso é bom, o espaço já está pago.
>
> Se a decisão for reverter para 16×32, o tile precisa cair para 16 junto, e
> aí toda a tabela acima muda.

**Escala sempre inteira.** Escala fracionária reamostra o sprite e quebra a
grade de pixel. `ESCALA_MUNDO`, `ESCALA_HEROI` e `ESCALA_ALDEAO` são 1.0.

---

## 3. Renderização

| chave | valor | onde |
|---|---|---|
| `default_texture_filter` | `0` (Nearest) | `project.godot` |
| `window/stretch/mode` | `viewport` | `project.godot` |
| `window/stretch/aspect` | `keep` | `project.godot` |
| `window/stretch/scale_mode` | `integer` | `project.godot` |
| `snap_2d_transforms_to_pixel` | `true` | `project.godot` |

E por asset, no `.import` — escritos pelo pipeline, **nunca deixados no
default**:

| chave | valor | por quê |
|---|---|---|
| `compress/mode` | `0` | Lossless. O default comprime em VRAM com perda por bloco e muda cor de pixel num sprite de 32px, sem um erro no console |
| `process/fix_alpha_border` | `false` | Sangra a cor do sprite para dentro do transparente. Com Nearest não há o problema que ele resolve, e o sangramento altera justo os pixels de borda que o recorte definiu |
| `mipmaps/generate` | `false` | mipmap de pixel art é borrão |
| `detect_3d/compress_to` | `0` | desliga a recompressão automática |

**Zero anti-aliasing. Alfa binário (0 ou 255), sempre.** Meio-alfa com filtro
Nearest não suaviza nada — só deixa borda suja que aparece contra qualquer
fundo.

### Fundo: preferir quem já devolve alfa

Ordem de preferência, e não é gosto — é resultado medido:

1. **Endpoint que devolve transparência.**
   `/create-character-with-4-directions` e `/animate-character` devolvem alfa
   já binário (medido: 0 pixels parciais em 32 arquivos). **Nenhum chroma key.**
2. **Chroma key sobre fundo chapado**, só para o que não tem endpoint com
   alfa (os props via pixflux).

> ### Nunca pedir fundo MAGENTA para personagem
>
> Custou uma leva inteira. Pedir `#FF00FF` fez o modelo **tingir o
> personagem**: túnica em `rgb(91,52,85)`, botas em `rgb(43,22,48)` — roxo,
> não marrom. Não existe limiar que separe sujeito de fundo quando os dois
> são a mesma cor: o chroma key comia o personagem e sobravam 5% de
> silhueta.
>
> E `#FF00FF` **não volta como `#FF00FF`**. Cada imagem traz o magenta que o
> modelo achou parecido: `(221,71,171)`, `(253,99,138)`, `(174,46,151)`,
> `(196,53,145)`. Comparação por igualdade recorta zero pixels.
>
> Para prop, o fundo é **verde `#00FF00`** e a chave é **medida** em cada
> imagem (moda do anel de borda), com corte por distância em cinco passadas.
> Ver `tratar_assets.py`.

---

## 4. Tilesets

**Proibido bloco Wang liso.** Todo terreno tem que ter imperfeição orgânica:
pedrinhas, flores miúdas, folhas caídas, raízes, conchas na areia.

Dois parâmetros do `/create-tileset` decidem isso, e ambos têm default
errado para este uso:

| parâmetro | default | usar | efeito |
|---|---|---|---|
| `transition_size` | **0.0** | **0.5** | 0.0 = borda dura entre os materiais, sem área de mistura. Foi o que deixou a primeira leva "matemática" |
| `detail` | — | `highly detailed` | `medium detail` achata a textura |
| `shading` | — | `medium shading` | `basic shading` tira o volume |
| `outline` | — | `lineless` | contorno duro em tile de chão vira grade visível |

`mode="pro"` (que expõe `raggedness` e `spread_x`) foi testado e **não
serve**: é marcado como experimental, e os três jobs disparados voltaram
`tileset_id` mas nunca persistiram — 404 no `GET /tilesets/{id}` e ausentes
da listagem da conta. Ficar em `standard` com `transition_size=0.5`.

O tileset **não vem como folha**: vêm 16 tiles com a máscara de cantos
explícita. O atlas 4×4 é montado pondo cada tile na célula que
`MapaV2.WANG` procura — correto por construção, sem depender de a API e a
engine terem escolhido a mesma convenção.

---

## 5. Animação

**Nenhum personagem estático.** Todo personagem entrega:

- 4 rotações paradas (`south`, `east`, `north`, `west`);
- **ciclo de caminhada de 4 a 7 quadros por direção**, em laço, rodando mais
  rápido que a pose parada.

O caminho é `/animate-character` com o `character_id` **do personagem que já
existe** — não `/animate-with-text-v3` a partir de um quadro solto. A razão é
identidade: chamadas independentes por direção davam três pessoas
diferentes, com cabelo, roupa e altura mudando de um lado para o outro.

`/animate-with-text-v3` continua útil para animar um objeto avulso (fumaça,
bandeira, roda de moinho), onde não há personagem a preservar.

**As 8 direções da mecânica caem em 4 desenhos.** `AgenteMovel.direcao_de`
devolve 8 nomes porque o vetor tem 8 octantes; a arte tem 4. O mapa vive em
`PersonagensV2.MAPA_8_PARA_4`, não na mecânica. Diagonal cai na **lateral**,
não na frontal: num top-down é o perfil que vende movimento.

---

## 6. Custo

Toda chamada é registrada com o valor **real** que a resposta informa, em
`ferramentas/hibit/gasto.json`. O id de job assíncrono vai para
`ids.json` **antes** do poll — se a sessão cair, o trabalho já foi pago e
`--recolher` o busca sem gerar de novo.

---

## 7. O que uma peça precisa ter para entrar

Checklist do `tests/teste_arte.gd`:

- [ ] existe em `assets/sprites/` e carrega como `Texture2D`
- [ ] tem o tamanho exato da tabela da §2
- [ ] alfa binário: zero pixels parciais
- [ ] sem resíduo da cor de chave
- [ ] `.import` com as quatro chaves da §3
- [ ] personagem: 4 rotações + ciclo com mais de um quadro por direção
- [ ] tileset: 16 máscaras distintas, física e navegação preservadas
