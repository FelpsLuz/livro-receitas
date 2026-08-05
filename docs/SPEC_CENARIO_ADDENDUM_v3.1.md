# ADDENDUM v3.1 — Correção de perspectiva, sequência e vida

**Status:** §I passos 1–4 do v3 aprovados. Este documento **corrige a §B.1 do v3** (erro meu), reordena a §I e acrescenta a camada de vida.

**Precedência:** v3.1 > v3 > v2.1 > spec original.

---

## A. Ratificações do relatório

| Item | Veredito |
|---|---|
| Sinal do skew: `−0.55` para cair baixo-esquerda | ✅ **Correção sua ratificada.** Meu snippet tinha o sinal errado. Congelar o valor testado no render, não o do documento. |
| Véu multiply em gradiente no lugar de `modulate` por fatia | ✅ **Solução melhor que a minha.** Resolve a emenda nas copas que eu não previ. Adotar como padrão para qualquer ajuste de valor que cruze fatia. |
| `bandas.gd` gerado de `bandas.py` | ✅ Fonte única. Manter. |
| C2 em `experimental/` com o achado documentado | ✅ |
| 447 checagens verdes; `teste_cenas.tscn` travando por limite de container | ✅ Aceito. Documentar no README para não virar caça-fantasma depois. |

---

## B. CORREÇÃO — a §B.1 do v3 estava errada

### O erro

Mandei forçar `strict flat side elevation, orthographic front view`. **A referência não é isso.**

Em `docs/referencia.png`: as casas mostram face frontal + sliver de parede lateral + inclinação frontal do telhado. O chão é um plano recuando. É **projeção oblíqua suave**, não ortográfica pura.

Executar a §B.1 literal produz 19 objetos achatados brigando com o plano de chão da placa. Problema novo, não solução.

### O defeito real da casa do piloto

Não é o ângulo. É o **pedestal**: um losango de grama e terra assado no sprite — footprint isométrico de tileset. É a origem do vão entre o pé e a sombra, e é o que denuncia o asset como vindo de outro sistema.

### SUFIXO_PERSPECTIVA — substituir

```
SUFIXO_PERSPECTIVA = "slight oblique view showing the front facade,
a narrow sliver of one side wall, and the front slope of the roof;
building ends exactly at its own footprint;
NO ground plinth, NO base platform, NO grass or dirt patch under the building,
NO isometric diamond base, transparent alpha below the footprint"
```

### Critério de rejeição — binário, sem julgamento

Rejeitar e regerar qualquer asset onde:
- exista pixel de grama, terra ou pedra **abaixo da linha do pé**
- a base tenha formato de losango/diamante
- a **superfície superior** do telhado seja visível (isso é 3/4 forte, não oblíquo suave)

### Perspectiva se trava por referência, não por prosa

`view: side` já falhou uma vez. Prosa não é mecanismo confiável. Sequência obrigatória:

1. Gerar **1 objeto** (`casa_sape`) com `create-image-pixflux` + sufixo novo. **$0,008.**
2. Aplicar o critério de rejeição acima. Se falhar, regerar (até 3 tentativas, ~$0,024).
3. Aprovado, esse sprite vira `arte/referencia_estilo.png`.
4. Os **18 restantes** via `POST /v2/create-image-bitforge` com `style_image = referencia_estilo.png`. Área máx 200×200 — toda construção sua cabe com folga. **$0,008 cada.**

Isso troca 19 apostas independentes por 1 aposta + 18 cópias de estilo.

---

## C. REORDENAÇÃO — terreno antes de objetos

O campo ocupa ~35% do quadro e está 100% vazio. Na referência, essa mesma faixa é a **área mais densa** da imagem.

**O terreno define onde os objetos vão.** Gerar 19 objetos primeiro significa posicioná-los na grama vazia e reposicionar tudo quando o terreno chegar.

Ordem correta: **terreno → objeto de referência → lote.**

### C.1 Camadas de terreno

Tiras de largura cheia, `create-image-pixflux` 400×64 (área 25.600, cabe):

| Camada | Conteúdo | Escala por nível |
|---|---|---|
| `terreno_trilhas` | terra batida, caminho da ponte ao portão, praça empedrada | N0 trilha fina → N5 estrada larga + praça |
| `terreno_cultivo` | canteiros cercados, hortas, cercas de madeira | quantidade cresce por nível |

**Regra de posicionamento:** todo objeto assenta **sobre** uma mancha de terra já existente. Nada assenta em grama virgem. É assim que o pé some sem precisar de anel de blend.

### C.2 Linha de mato — corrige o corte de navalha da floresta

Os troncos param numa linha horizontal reta atravessando os 400px. Sem contato com o chão.

Gerar tira `terreno_sub_bosque` 400×16: mato baixo, arbustos, samambaia, tocos, pedras. Posicionar na junção floresta/campo com **jitter de Y de ±3px**.

Custo: 3 tiras ≈ **$0,032**. Resolve mais do que 5 objetos novos resolveriam.

---

## D. Hierarquia de valor — segunda passada

A primeira passada escureceu a floresta. Não foi suficiente: **o campo continua sendo a massa mais clara do quadro.**

Na referência o campo é meio-tom e as construções é que são claras.

- **Escurecer o campo ~10% e dessaturar ~8%** (véu em gradiente, §A). Não clareie a casa — ela é escura por natureza e +8% não vence.
- O gradiente do véu vai do topo (mais claro, recuando) ao pé (mais escuro, próximo). Isso também quebra os estratos retangulares.
- Depois disso, refazer o **teste de silhueta**: composto em preto puro sobre branco. A vila tem que ler como forma distinta.

### D.1 Estratos retangulares do campo

Visíveis como blocos horizontais de verde divergente no zoom. Duas frentes:
- O gradiente do §D acima suaviza a transição
- O terreno do §C.1 povoa e quebra as bordas retas

Se persistir: ruído sutil ±4% de luminância em textura tileável, aplicada só na banda de campo.

---

## E. Juncos — contenção e quebra

O problema não é só valor. É **uniformidade nos 400px**, mesmo defeito da floresta.

1. Véu de −12% na banda
2. **Quebrar a densidade:** abrir clareiras onde a margem é terra nua, adensar em 2–3 touceiras maiores
3. Se a tira atual for PNG único, fatiar em 4–5 variantes e distribuir com espaçamento irregular

---

## F. Sombra — recalibrar

O sol está **alto** no quadro. Sol alto = sombra curta. `scale.y −0,28` com `skew −0,55` produz sombra de sol rasante — contradiz a própria placa.

```gdscript
const SOMBRA_ESCALA_Y := -0.19   # era -0.28
const SOMBRA_SKEW     := -0.35   # era -0.55 (sinal correto, magnitude reduzida)
const SOMBRA_ALPHA    :=  0.40   # era 0.35 (sombra mais curta pede mais densidade)
```

Recalibrar **depois** que o objeto de referência sem pedestal existir — o vão atual é defeito do plinto, não do nó. Congelar como constantes globais, uma calibração só.

---

## G. Vida — Godot, custo zero de API

Cenário estático lê como ilustração. Três shaders transformam a percepção. Prioridade nesta ordem.

### G.1 Palette cycling na água — o de maior retorno

Técnica de época e autêntica. É o que faz rio de pixel art parecer vivo sem animar frame.

```glsl
shader_type canvas_item;

uniform sampler2D rampa : filter_nearest;   // 4×1 com os 4 azuis da água
uniform float velocidade = 1.6;
uniform vec3 alvos[4];                      // as 4 cores de água na textura
uniform float tolerancia = 0.02;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    for (int i = 0; i < 4; i++) {
        if (distance(c.rgb, alvos[i]) < tolerancia) {
            int j = (i + int(TIME * velocidade)) % 4;
            c.rgb = texelFetch(rampa, ivec2(j, 0), 0).rgb;
            break;
        }
    }
    COLOR = c;
}
```

Extrair as 4 cores dominantes de água da placa (já tem a média medida: `115,175,171`) e montar a rampa. Ciclar apenas as cores de specular — não o corpo d'água inteiro, senão pulsa.

### G.2 Balanço dos juncos

```glsl
shader_type canvas_item;
uniform float amplitude = 1.2;   // em pixels
uniform float freq = 1.1;

void vertex() {
    float base = 1.0 - UV.y;                       // 0 no pé, 1 no topo
    VERTEX.x += sin(TIME * freq + VERTEX.y * 0.08) * amplitude * base * base;
}
```

Amplitude quadrática por altura: pé cravado, topo balançando. Aplicar na banda de juncos e, com amplitude menor (0,6), nas copas da floresta.

**Atenção pixel-perfect:** amplitude tem que ser inteira em pixels ou vira tremulação. Com `snap_2d_vertices_to_pixel` ON, a Godot já arredonda — validar visualmente em 1× antes de aprovar.

### G.3 Deriva de nuvem

```gdscript
# nuvens em Sprite2D com texture_repeat = ENABLED
func _process(delta):
    material.set_shader_parameter("offset_x",
        fmod(material.get_shader_parameter("offset_x") + delta * 1.5, 400.0))
```

Duas camadas com velocidades diferentes (1,5 e 0,7 px/s) dão paralaxe de céu de graça.

---

## H. §E do v3 — floresta em TileMapLayer, ainda pendente

Não foi executada. A floresta segue conífera única, altura única, espaçamento único.

Manter como especificado no v3 §E: 1 tira de 5 variantes ($0,008) → `TileSet` com alternative tiles → 3 `TileMapLayer` com jitter de Y e `modulate` por tier.

**Executar depois do terreno, antes do lote de construções.** É 1 chamada de API para resolver o segundo defeito mais visível do quadro.

---

## I. Sequência revisada

| # | Passo | Custo API |
|---|---|---|
| 1 | §D — véu de valor no campo + teste de silhueta | $0,00 |
| 2 | §E — contenção e quebra dos juncos | $0,00 |
| 3 | §G.1 — palette cycling na água | $0,00 |
| 4 | §G.2 e §G.3 — balanço e deriva | $0,00 |
| 5 | **PARAR E REPORTAR** — render N0 com valor corrigido + GIF/frames da vida | — |
| 6 | §C — 3 tiras de terreno (trilhas, cultivo, sub-bosque) | $0,032 |
| 7 | §H — floresta em 3 tiers com 5 variantes | $0,008 |
| 8 | **PARAR** — render N0 com terreno e floresta | — |
| 9 | §B — 1 objeto de referência + critério de rejeição | $0,008–0,024 |
| 10 | **PARAR** — aprovar o sprite de referência | — |
| 11 | §B — 18 objetos via bitforge com style reference | $0,144 |
| 12 | §F — recalibrar sombra sobre objeto sem pedestal | $0,00 |
| 13 | Paleta mestre OKLab + shader de grade (v3 §D) | $0,00 |
| 14 | Muralha tileável + aldeões | $0,040 |
| 15 | **PARAR** — aceite N5/verão/dia contra referência + silhueta | — |

**Gasto projetado:** $0,077 já gasto + $0,232 + contingência 30% ≈ **$0,38 de $1,50**.

Note que os **4 primeiros passos custam zero** e mexem mais na percepção do quadro do que os 19 objetos vão mexer. Composição e movimento batem quantidade de asset.

---

## J. Proibições — atualizadas

- ❌ Não usar `strict flat side elevation` — foi revogado nesta versão
- ❌ Não aceitar asset com plinto, base em losango, ou qualquer pixel de chão abaixo do pé
- ❌ Não aceitar asset com superfície superior de telhado visível
- ❌ Não gerar os 18 antes do objeto de referência ser aprovado
- ❌ Não gerar construção antes do terreno existir
- ❌ Não posicionar objeto em grama virgem — assenta sobre mancha de terra
- ❌ Não usar amplitude fracionária nos shaders de movimento
- ❌ Não ciclar o corpo d'água inteiro — só o specular
- ❌ Não recalibrar sombra sobre o placeholder com plinto
