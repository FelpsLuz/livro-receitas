# Pipeline Hi-Bit

Como a arte entra no jogo depois do visual strip. Descreve o **estado real**
do repositório. Se divergir do código, o código está certo.

Guarda: `tests/teste_hibit.gd`.

---

## Frente 1 — renderização

### `project.godot`

Três das quatro chaves pedidas **já estavam certas** antes desta leva:

| chave | valor | estado |
|---|---|---|
| `display/window/stretch/mode` | `viewport` | já estava |
| `display/window/stretch/aspect` | `keep` | já estava |
| `rendering/.../default_texture_filter` | `0` (Nearest) | já estava |
| `display/window/stretch/scale_mode` | `integer` | **novo** |

`scale_mode` era o buraco real. Sem ele a escala é fracionária: uma janela de
1500×844 escala 960×540 por 1,5625, e um pixel de arte vira ora 1, ora 2
pixels de tela — a grade fica irregular e a arte "ferve" ao redimensionar.
Em `integer` a Godot escala por 1×, 2×, 3× e deixa borda. A borda é o preço,
e num Hi-Bit é o preço certo.

`mode = viewport` (e não `canvas_items`) porque **este jogo é texto**: dez
abas de economia com fontes de pixel de 12×20 e 8×16, escolhidas por medida
em `ferramentas/FONTES.md`. Em `viewport` a interface inteira vive na mesma
grade de 960×540 que a arte, e a fonte cai em múltiplo inteiro. Em
`canvas_items` a interface renderiza na resolução da janela e a fonte de
pixel sai em tamanho fracionário.

### `EnvironmentManager` (autoload)

Ciclo de luz por `CanvasModulate`. **O efeito é por viewport, não global**, e
isso não é detalhe: `CanvasModulate` multiplica todo o `CanvasLayer` em que
vive, e um autoload que o pusesse na raiz deixaria a interface de pergaminho
azul às 3h da manhã e ilegível. A cena é quem registra:

```gdscript
var amb := Ambiente.gerente()      # resolve o autoload em runtime
if amb != null:
    amb.registrar(mundo)           # CanvasModulate NESTE viewport
    amb.definir_mes(estado["mes"])
```

`Ambiente.gerente()` em vez do identificador global pelo mesmo motivo de
`scripts/sinais.gd`: os testes rodam com `godot --script`, e nesse modo o
autoload não é registrado — citar o nome derruba a suíte em tempo de
**compilação**.

A hora vem do **mês do jogo**, não do relógio de parede. O turno aqui é
mensal; um sol que nasce e se põe enquanto o jogador lê um contrato não tem
relação nenhuma com a partida. Inverno tem dia curto e frio, verão tem dia
longo e quente.

A rampa da noite desloca para o **azul**, não só escurece — é o efeito
Purkinje, a regra clássica de pixel art de que o olho perde sensibilidade ao
vermelho no escuro. Testado: `noite.b > noite.r`.

### `CameraMundo`

A câmera que estava inline na `VilaCena`, agora componente. Três coisas que
ela resolve:

- **limites** em pixels de *viewport*, não de mundo — erro fácil numa cena
  que desenha em escala 1:2;
- **espaço do alvo**: `seguir(no, escala)` converte, porque o herói vive no
  espaço do `mundo` (0,5) e a câmera no do viewport;
- **enquadramento inteiro**: suavização produz coordenada fracionária, e
  câmera em meio pixel desalinha a grade inteira da cena. `arredondar` trava
  em pixel cheio. É isso que separa uma câmera de pixel art de uma câmera.

---

## Frente 2 — IA e shaders

### `AIVisualBridge`

`HTTPRequest` para o PixelLab v2, com o prompt montado a partir do **estado
da entidade**:

```gdscript
var ponte := AIVisualBridge.novo(self)
ponte.pronto.connect(func(id, tex): sprite.texture = tex)
ponte.pedir("heroi", {"tipo": "character", "acao": "walking down",
        "quadro": 1, "descricao": "young knight", "tamanho": 32})
```

A assinatura Hi-Bit fica gravada num lugar só (`montar_prompt`): mudar o
estilo é mudar uma função, não caçar strings por dez cenas.

> ### ⚠️ A chave não pode ir no jogo
>
> Chave de API embutida num binário de cliente é chave **pública**: qualquer
> um extrai a string do executável ou do `.pck` com um editor hexadecimal e
> passa a gastar a sua cota. Não existe ofuscação que resolva — só não
> embarcar.
>
> Por isso `chave()` lê, nesta ordem: `PIXELLAB_SECRET` do ambiente, depois
> `user://pixellab.key` (fora do projeto, nunca vai para o build). **Nunca**
> um literal no código. Faltando as duas, `disponivel()` é false e todo
> pedido falha limpo sem tocar na rede.
>
> `disponivel()` também devolve false em build exportada
> (`OS.has_feature("template")`). Geração de arte é etapa de produção, não de
> partida: o jogador não deve esperar a rede para ver um sprite.

Freio de custo: `teto_usd` (padrão US$ 0,25) barra o pedido **antes** do
request. `simular = true` roda o fluxo inteiro devolvendo caixote, custo zero.

### Os três shaders

| arquivo | o que faz | a decisão que importa |
|---|---|---|
| `vento_folhagem.gdshader` | balanço de folhagem | vai no **vertex**, ao contrário do shader de vida da cena achatada. Lá a imagem era uma textura de tela cheia e deslocar `VERTEX.x` movia o quadro inteiro; aqui cada árvore é o seu nó. A fase sai da posição no mundo, senão o bosque balança em uníssono e vira esteira |
| `contorno.gdshader` | realce de interativo | **8 vizinhos, não 4**: com a cruz, a diagonal de uma silhueta serrilhada fica com buraco. O passo é `TEXTURE_PIXEL_SIZE` arredondado para inteiro — contorno em meio pixel vira linha cinza translúcida |
| `paleta_dinamica.gdshader` | troca de cor por clima | dois modos, e a diferença é pixel art contra "foto com filtro". **Lookup** (padrão) mapeia por tabela e o resultado fica exatamente dentro da paleta nova. **Matiz/croma** em HSV é barato e serve para um flash de dano, mas **inventa cor** — numa cena inteira é o que deixa a arte lavada |

Os três têm guarda de croma ou peso de altura pelo mesmo motivo: contorno
preto, metal e branco de olho são a leitura da silhueta e não devem seguir a
estação; tronco não balança, copa balança.

---

## Frente 3 — reacoplamento por sinal

### O acoplamento que existia

```gdscript
# vila_cena.gd, antes
heroi.position += dir * 80.0 * delta
PersonagensV2.mover(heroi, direcao_de(dir), true)   # ← heroi é o SPRITE
```

A regra de movimento escrevia no nó de arte. Trocar a arte significava mexer
no laço de movimento.

### O par que desfaz

**`AgenteMovel`** (mecânica) tem posição, velocidade e destino. Não tem
sprite, não conhece animação, não sabe o que é direção em nome de arquivo.
Emite `moveu(velocidade)`, `parou()`, `direcao_mudou(direcao)`, `chegou(i)`.

**`VisualController`** (visual) escuta e desenha. Lê da mecânica; a mecânica
nunca lê dele.

```gdscript
heroi = AgenteMovel.new()
heroi.definir_rota([...])
var vc := VisualController.novo(heroi)
vc.usar_personagem("heroi_jogador", ESCALA_HEROI)
vc.observar(heroi)          # por SINAL
```

O teste prova o desacoplamento lendo o **fonte** de `agente_movel.gd` e
falhando se ele citar `Sprite2D`, `AnimatedSprite2D`, `sprite_frames`,
`texture`, `PersonagensV2` ou `VisualController`.

`observar()` prefere sinal e cai na leitura por quadro só quando a fonte não
tem nenhum — que é o caso de um `CharacterBody2D` nativo, já que ele não
emite nada sobre a própria velocidade. Continua sendo dependência de uma via
só. Preferir sinal não é preciosismo: com leitura o nó roda todo quadro mesmo
parado; com sinal ele só acorda quando algo muda.

`acender()` dá `PointLight2D` com `GradientTexture2D` radial de **três
paradas** — com duas, a luz vira borrão sem centro. A textura é gerada:
gradiente é matemática, não arte.

---

## Duas coisas do pedido que não existem neste projeto

**`CharacterBody2D`.** Não há nenhum, nem `CollisionShape2D`, `Area2D` ou
`RayCast2D`. O movimento é rota em `_physics_process` sem colisão. O
`VisualController` foi escrito para funcionar com um corpo se aparecer — ele
plugará emitindo os mesmos três sinais, sem mudar uma linha do controlador —
mas nenhum foi inventado só para satisfazer a forma do pedido.

**`AnimationPlayer`.** Não há nenhum. A animação de personagem é
`SpriteFrames` num `AnimatedSprite2D`, montada por `PersonagensV2` a partir
de `animacoes.json`. Um `AnimationPlayer` por cima seria uma segunda máquina
de estados controlando a mesma coisa, com as duas podendo discordar.
`VisualController.aplicar_em(player, acao)` existe para o dia em que houver
animação de **propriedade** (ataque, dano, morte) — aí o player entra e o
controlador dispara nele pelo mesmo caminho.

---

## Base 16×16 / 32×32 — o que falta decidir

O pipeline está pronto; a **resolução base não foi migrada**, e migrar não é
de graça. Os placeholders herdaram a escala da arte antiga:

| coisa | hoje | Hi-Bit alvo |
|---|---|---|
| tile de terreno | 32 | 32 ✅ já está |
| personagem | 124×124 | ~32×48 |
| objeto de vila | 80–192 | 32–96 |
| cenário da aba Terra | 480×270 | 480×270 ✅ |

O tile já está em 32. O resto está em ~4× disso porque a arte antiga foi
gerada em 124/160. Baixar para 32×48 muda `VilaCena.TAMANHO_OBJ`,
`ESCALA_OBJ`, `ESCALA_HEROI`, a planta inteira da vila e `MUNDO` — e a planta
é o que decide quem cobre quem no Y-Sort.

Isso é uma leva de trabalho própria, e deve vir **junto com a primeira arte
real**, não antes: migrar a grade com caixotes só troca um conjunto de
números por outro sem nada para conferir contra.
