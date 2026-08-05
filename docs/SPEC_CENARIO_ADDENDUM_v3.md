# ADDENDUM v3 — Coesão na Godot, não na API

**Status:** piloto C2 aprovado como experimento, **rejeitado para o lote**. Este documento substitui a §B do addendum v2.1 e as etapas 14–15 da spec original.

**Precedência:** v3 > v2.1 > spec original.

---

## A. Veredito do piloto

| Item | Veredito |
|---|---|
| Canário 0,00% fora da máscara | ✅ excelente |
| Descoberta: `/inpaint` regenera, não insere | ✅ achado válido, documentar no README |
| Janela ≤ 40.000px, `ESTILO_CENA` congelado, contador de gasto | ✅ manter |
| Técnica C2 (anel) para o lote | ❌ **rejeitada** |
| Máscara de sombra por classificador L-ratio | ❌ **deletar o caminho** |
| Sprite em 3/4 | ❌ **corrigir** |

### Por que o C2 não escala

1. **O anel de blend é visível.** Confirmado no `prova_recomposicao_zoom.png`: mancha retangular de verde divergente em volta da casa. Não é imperceptível.
2. **Quebra a matriz combinatória.** 6 níveis × 3 estações × 4 céus = 72 estados. Cada camada carrega grama-de-verão assada de uma posição específica. Em qualquer estado onde o terreno mude, o remendo aparece.
3. **Custo 2×** para produzir esse problema.
4. **A sombra extraída é ruído**, não sinal. O painel 9 do piloto mostra salpicos dentro da copa das árvores. Não há o que apertar.

**Manter no repositório:** o código C2 fica como `ferramentas/experimental/c2_anel.py`, documentado, fora do pipeline. Foi caro de descobrir, não se joga fora.

---

## B. Nova §B — geração de objeto isolado

```
1 chamada:  POST /v2/create-image-pixflux
            no_background = true
            image_size    = tamanho final em pixels do canvas (1:1, nunca reescalar)
            color_image   = paleta mestre (após derivá-la)
            ESTILO_CENA   (congelado, §D do v2.1)
            prompt        = descrição + SUFIXO_LUZ + SUFIXO_PERSPECTIVA
```

Custo: **$0,008/objeto.** Sem janela, sem placa, sem diff, sem extração. O objeto sai com alpha limpo, modular, agnóstico de estação.

### B.1 SUFIXO_PERSPECTIVA — correção do 3/4

`view: side` não segurou sozinho. Concatenar em **todo** prompt de objeto:

```
SUFIXO_PERSPECTIVA = "strict flat side elevation, orthographic front view,
no perspective, no three-quarter angle, no visible roof top surface,
no visible ground plane, facade parallel to picture plane"
```

**Reforço por referência:** assim que sair 1 objeto em elevação estrita correta, use-o como style reference nos demais via `POST /v2/create-image-bitforge` (aceita referência de estilo, área ≤ 200×200 — cabe em qualquer construção sua) ou mantenha pixflux e valide visualmente.

**Teste de aceite da perspectiva:** se o topo do telhado é visível como superfície, está em 3/4. Rejeitar e regerar.

### B.2 Integração com o chão — resolvida por terreno, não por objeto

O que o anel do C2 entregava (grama pisada) passa a ser **camada de terreno autorada uma vez**, não propriedade de cada objeto.

Gerar como tira de largura cheia, `create-image-pixflux` 400×64 (área 25.600, cabe):
- `terreno_terra_batida` — manchas de terra, trilhas, chão pisado
- `terreno_hortas_cercas` — canteiros cercados

Os objetos são posicionados **em cima** das manchas de terra já existentes. É assim que jogo de pixel art de verdade faz. Custo: ~2 chamadas ($0,021) para todos os objetos, em vez de 1 chamada extra por objeto.

---

## C. GODOT — sombra de contato

Deletar o classificador L-ratio. Sombra vira nó.

### C.1 Construções — cópia achatada e inclinada

```gdscript
# ferramentas/godot/sombra_contato.gd
static func criar_sombra(sprite: Sprite2D) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture       = sprite.texture
    s.centered      = sprite.centered
    s.offset        = sprite.offset
    s.modulate      = Color(0.0, 0.0, 0.0, 0.35)
    s.scale         = Vector2(1.0, -0.28)   # achata e espelha para baixo
    s.skew          = 0.55                  # sol superior-DIREITA -> sombra baixo-ESQUERDA
    s.z_index       = sprite.z_index - 1
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return s
```

Ancoragem: a sombra compartilha a posição do sprite; o `scale.y` negativo espelha a partir da base. Ajustar `skew` uma única vez até bater com a referência e **congelar como constante global** — mesma direção em 100% dos objetos, por construção.

### C.2 Objetos pequenos (aldeões, barris, poço) — elipse

Cópia achatada em sprite de 8px vira borrão. Use elipse:

```gdscript
var e := Sprite2D.new()
e.texture  = preload("res://arte/fx/sombra_elipse.png")  # 16x6, gradiente radial
e.modulate = Color(0, 0, 0, 0.30)
e.scale.x  = largura_pe_do_objeto / 16.0
e.z_index  = sprite.z_index - 1
```

Um único PNG de 16×6 serve para todos, escalado por largura de pé.

**Vantagens sobre a extração por IA:** consistência absoluta, custo zero, funciona sobre grama/neve/terra/pedra sem alteração, e o `alpha` é ajustável em runtime (sombra mais fraca em dia nublado, mais forte ao meio-dia).

---

## D. GODOT — paleta e estação por shader de tela

**Substitui as etapas 14 e 15 da spec.** Nada de LUT assada em PNG, nada de quantização por composto.

### D.1 Arquitetura

```
SubViewport (400×200, NEAREST)
└── Cena
    ├── ceu / montanhas / floresta / campo / terreno / rio / construções / aldeões
    └── CanvasLayer (layer = 100)
        └── ColorRect (full rect)
            └── material: grade_estacao.gdshader
```

### D.2 Shader

```glsl
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D paleta : filter_nearest;   // 64×1, cores da estação alvo
uniform float mistura : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float saturacao : hint_range(0.0, 2.0) = 1.0;
uniform float luminancia : hint_range(0.0, 2.0) = 1.0;

vec3 snap_paleta(vec3 c) {
    float melhor = 1e9;
    vec3 saida = c;
    for (int i = 0; i < 64; i++) {
        vec3 p = texelFetch(paleta, ivec2(i, 0), 0).rgb;
        float d = dot(c - p, c - p);
        if (d < melhor) { melhor = d; saida = p; }
    }
    return saida;
}

void fragment() {
    vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    c *= tint * luminancia;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, saturacao);
    COLOR = vec4(mix(c, snap_paleta(c), mistura), 1.0);
}
```

64 comparações por pixel em 400×200 = 5,1M operações. Irrelevante em qualquer GPU, inclusive integrada.

### D.3 Presets

| Estado | tint | saturacao | luminancia | paleta |
|---|---|---|---|---|
| Verão / dia | (1.00, 1.00, 1.00) | 1.00 | 1.00 | `pal_verao.png` |
| Entardecer | (1.12, 0.94, 0.80) | 1.05 | 0.95 | `pal_entardecer.png` |
| Tempestade | (0.88, 0.92, 1.05) | 0.70 | 0.85 | `pal_tempestade.png` |
| Outono | (1.08, 0.96, 0.82) | 1.10 | 1.00 | `pal_outono.png` |
| Inverno | (0.92, 0.96, 1.06) | 0.65 | 1.05 | `pal_inverno.png` |

**Benefício que a versão assada não tem:** transição de estação vira `Tween` nos uniforms. Vira feedback de progressão animado em vez de troca seca de PNG.

### D.4 Paleta por estação — derivação

1. Derivar **paleta mestre de 64** com o OKLab de `requantizar.py`, sobre placa base + todos os objetos gerados **em conjunto**.
2. Cada paleta de estação = paleta mestre passada pelo mesmo grade da tabela D.3, deduplicada.
3. Salvar como PNG 64×1. A cor cai exatamente em entrada de paleta — erro de quantização zero.

**Descarte os 7 PNGs de estação v1 do runtime.** Vão para `docs/referencia_estacoes/` e servem só para calibrar os presets acima.

---

## E. GODOT — floresta e muralha por TileMapLayer

Problema confirmado no render: conífera única, altura única, espaçamento único, topo em linha reta através dos 400px.

### E.1 Floresta

1. Gerar **1 tira de 128×64** com 5 variantes de árvore lado a lado (1 chamada, $0,008): 3 coníferas de alturas distintas, 2 decíduas.
2. Fatiar em tiles, montar `TileSet` com as 5 como **alternative tiles**.
3. `TileMapLayer` preenchendo a banda de floresta com escolha aleatória por célula e **jitter de Y de ±4px**.
4. **Três tiers de profundidade**, cada um em seu `TileMapLayer`:

| Tier | modulate | z | escala |
|---|---|---|---|
| Fundo | `Color(0.72, 0.80, 0.86)` | -3 | 0,80 |
| Meio | `Color(0.88, 0.92, 0.95)` | -2 | 0,90 |
| Frente | `Color(1, 1, 1)` | -1 | 1,00 |

O `modulate` azulado/dessaturado nos tiers de fundo dá perspectiva atmosférica de graça, sem gerar arte nova.

**A linha do topo tem que ondular.** Se sair reta, o jitter de Y está desligado.

### E.2 Muralha

1. Gerar **1 segmento tileável 128×32** + portão + 2 torres (4 chamadas, $0,032).
2. `TileMapLayer` com o segmento, portão e torres em posições **não uniformes**.
3. Quebrar o padrão: estandartes, tochas, um trecho danificado — intervalos irregulares.

---

## F. Correções de composição — o que o render 2× revelou

Prioridade sobre qualquer asset novo.

### F.1 Hierarquia de valor está invertida — o problema nº1

Na referência, o castelo é a **massa mais clara** contra floresta escura, e a estrada é valor claro guiando o olho. No render atual, o sujeito é o objeto mais escuro do quadro e o fundo é o mais claro. **O olho não tem para onde ir.**

Correções:
- Escurecer e dessaturar a banda de floresta em **~15%** (`modulate` nos TileMapLayers, custo zero)
- Construções: telhado e fachada puxados para valores **mais claros** que o entorno
- Trilha de terra clara cortando o campo — é o vetor que conduz o olho até o castelo

**Teste de silhueta:** renderize o composto em preto puro sobre branco. Se a vila não lê como forma distinta, ainda está errado.

### F.2 O rio está gritando

É o elemento mais claro e mais contrastado do quadro, nos 20% de baixo onde nada importante acontece. Rouba o olho do sujeito.

- Reduzir contraste do specular em **~40%**
- Reduzir densidade dos pontos brancos em ~50%
- Escurecer a banda inteira em ~8%

Pode ser feito com `modulate` no nó do rio, sem regerar. Teste antes de gastar API.

### F.3 Campo com estratos retangulares

Blocos retangulares de verde divergente lendo como artefato. Origem: geração da placa base.

- Aplicar overlay de ruído sutil (shader ou textura tileável, ±4% de luminância) para quebrar as bordas retas
- Popular com as camadas de terreno da §B.2 — o vazio está denunciando os estratos

### F.4 Escala e povoamento

A casa lê como maquete porque não há régua de escala. Aldeões (§4 da spec) não são enfeite — são a régua. Priorizá-los.

---

## G. Configuração de projeto pixel-perfect (Godot 4)

Auditar e corrigir se divergente:

```
Display > Window > Stretch > Mode        = viewport
Display > Window > Stretch > Aspect      = keep
Rendering > 2D > Snap 2D Transforms to Pixel   = ON
Rendering > 2D > Snap 2D Vertices to Pixel     = ON
Rendering > Textures > Canvas Textures > Default Filter = Nearest
Importação de todo PNG de arte: Filter = OFF, Mipmaps = OFF
```

Sem isso, `skew` e `scale` fracionário nas sombras vão gerar tremulação de subpixel.

---

## H. Orçamento revisado

| Item | Chamadas | Custo |
|---|---|---|
| Já gasto (placa + piloto + tentativas) | — | $0,077 |
| 19 objetos isolados | 19 | $0,152 |
| Tira de 5 variantes de árvore | 1 | $0,008 |
| Muralha: segmento + portão + 2 torres | 4 | $0,032 |
| Terreno: terra batida + hortas/cercas | 2 | $0,021 |
| Tira de aldeões 128×16 | 1 | $0,008 |
| Contingência 30% | ~8 | $0,067 |
| **TOTAL** | | **≈ $0,37** |

Teto $1,50. Saldo $7,69. **Folga de 4×.**

Sombras, paleta, estações, quantização e variação de floresta passam a custar **$0,00** — são Godot.

---

## I. Sequência autorizada

1. Deletar do pipeline: classificador de sombra, extração por diff, C2 (mover para `experimental/`)
2. §G — auditar config de projeto pixel-perfect
3. §C — implementar sombra de contato + testar nos assets existentes
4. §F.1 e §F.2 — corrigir hierarquia de valor e rio **via `modulate`, sem gastar API**
5. **PARAR E REPORTAR** — render de N1 com as correções de composição, antes de gerar asset novo
6. *(aval)* §B — lote de 19 objetos em elevação estrita
7. §D.4 — derivar paleta mestre + paletas de estação
8. §D — shader de grade, presets, tween
9. §E — floresta em 3 tiers e muralha tileável
10. §B.2 — camadas de terreno
11. Aldeões
12. **PARAR** — aceite visual N5/verão/dia contra `docs/referencia.png`, mesma escala + teste de silhueta

**Pontos de parada obrigatórios: 5 e 12.**

---

## J. Proibições — atualizadas

- ❌ Não usar C2 / máscara em anel no lote
- ❌ Não extrair sombra por classificador — sombra é nó da Godot
- ❌ Não assar LUT nem quantização em PNG — é shader de tela
- ❌ Não aceitar objeto em 3/4; topo de telhado visível = rejeitar e regerar
- ❌ Não gerar asset novo antes do passo 5 (correção de composição é de graça)
- ❌ Não reescalar objeto — gerar em 1:1
- ❌ Não tilear floresta ou muralha em intervalo uniforme
- ❌ Não deletar o código C2 — mover para `experimental/` com documentação
