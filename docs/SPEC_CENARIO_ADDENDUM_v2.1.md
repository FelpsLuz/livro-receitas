# ADDENDUM v2.1 — SPEC_CENARIO_CAMADAS

**Status:** aprovação da §0 concedida. Este documento **corrige a §2 da spec original** e trava parâmetros que estavam soltos. Onde houver conflito, **este addendum prevalece**.

**Contexto:** o inventário confirmou canvas nativo **400×200** (não 320×180). Isso invalida a §2.2 como escrita.

---

## A. BLOQUEADOR — a §2.2 original não executa

`POST /v2/inpaint` tem **área máxima 200×200 = 40.000 px**.
Canvas do projeto: **400×200 = 80.000 px**. **2× acima do limite.** Retorna 422.

### Alternativas avaliadas e rejeitadas

| Opção | Cabe? | Custo × 20 objetos | Veredito |
|---|---|---|---|
| `/v2/inpaint` no canvas cheio | ❌ 422 | — | impossível |
| `/v2/inpaint-v3` (Pro) no canvas cheio | ✅ | **$2,50 – $3,70** | estoura o teto de $1,50 em 2,5× |
| `/v2/edit-image` no canvas cheio | ✅ | $0,236 | sem máscara — controle espacial insuficiente |
| **`/v2/inpaint` em janela recortada** | ✅ | **$0,16** | **adotado** |

---

## B. §2.2 REESCRITA — inpaint em janela de contexto

Não inpaintar o canvas inteiro. Recortar uma **janela de contexto** ao redor da posição final do objeto, inpaintar a janela, extrair o diff dentro dela, recolocar no offset.

A janela carrega grama, floresta e céu reais em volta do alvo. **O objeto continua nascendo dentro da cena** — que era o ponto inteiro da técnica. Luz, paleta, escala e sombra de contato seguem corretas por construção.

### B.1 Regra da janela

```
JANELA_MAX_AREA = 40_000        # limite duro de /v2/inpaint
JANELA_PADRAO   = (128, 128)    # 16.384 — folga confortável
JANELA_GRANDE   = (192, 160)    # 30.720 — para castelo/torreão
```

1. Dado o objeto e sua posição final `(cx, cy)` na banda correta (§1), recorte da **placa base** uma janela centrada, com margem mínima de **24px de contexto** em todos os lados do bounding box previsto do objeto.
2. Se a janela vazar o canvas, **desloque para dentro** — não faça padding. Padding artificial envenena o contexto do modelo.
3. Valide `w * h <= JANELA_MAX_AREA` **antes** da chamada. Assert, não warning.
4. Registre `(offset_x, offset_y, w, h)` no manifesto da camada. É o que devolve o recorte à posição.

### B.2 Máscara dentro da janela

A máscara de inpaint é **relativa à janela**, não ao canvas. Cubra apenas o bounding box do objeto + 4px de folga — não a janela inteira. O modelo precisa ver o entorno intacto para casar luz e paleta.

### B.3 Extração por diferença (revisada)

```
base_j   = recorte da placa base na janela          (RGB)
gerada_j = retorno do inpaint                        (RGB)
d        = soma por pixel de |gerada_j - base_j|      # 0..765
mask     = d > TOL                                    # TOL inicial = 12
mask     = mask AND mascara_inpaint
mask     = remover componentes conexos com area < 4 px
mask     = binary_closing(mask, raio=1)
camada   = gerada_j com alpha = mask
manifesto: offset (x, y) da janela no canvas 400×200
```

**Canário obrigatório:** medir a fração de pixels alterados **fora** da máscara, dentro da janela.
- `<= 2%` → pipeline normal.
- `> 2%` → o modelo alterou o global. Descarte tudo fora da máscara, recalibre TOL só na região, e **logue em vermelho**.

Logar esse percentual em toda extração, sem exceção.

### B.4 Separação da sombra — inalterada da §2.4

Dentro da máscara, classificar como **sombra** o pixel com:
- razão de luminância `L_gerada / L_base` entre **0,55 e 0,92**
- delta de matiz abaixo do limiar (mesma cor, só escurecida)

Sai da camada de objeto, vai para máscara de sombra separada, alpha puro, blend **multiply ~40%**. Nunca RGB assado.

### B.5 Piloto antes do lote

**Antes de gerar os 20**, rode **1 objeto** (sugestão: `casa_sape`) e apresente:
- a janela recortada
- o retorno do inpaint
- a máscara de diff
- a camada extraída com alpha
- a máscara de sombra separada
- o percentual do canário

**Pare e reporte.** Só depois libera o lote.

---

## C. Caso especial — muralha e paliçada

Atravessam os 400px. Não cabem em janela nenhuma. **Não force.**

Abordagem correta (e mais barata):
1. Gerar **um segmento tileável de 128×32** por inpaint em janela.
2. Verificar tileabilidade horizontal: a coluna 0 tem que casar com a coluna 127. Se não casar, espelhe ou ajuste as bordas manualmente — 32px de altura é trivial de corrigir à mão.
3. Gerar **portão** e **2 torres** como peças separadas.
4. Tilear o segmento e cravar portão/torres em posições **não uniformes**. Uniformidade denuncia tile.
5. Quebrar o padrão: estandartes, tochas, trecho danificado — em intervalos irregulares.

Custo: 4 chamadas ($0,032) em vez de tentar 3 janelas sobrepostas com costura visível.

Mesma lógica se aplica a qualquer elemento que atravesse o canvas.

---

## D. Trava de parâmetros de estilo — a causa raiz do bug de luz

O inventário mediu **8 peças iluminadas pela esquerda e 7 pela direita**. A causa não é o modelo. É que `outline`, `shading`, `detail` e `view` nunca foram travados.

Ambos os endpoints (`create-image-pixflux-background` e `inpaint`) aceitam esses parâmetros. Crie **um único dicionário congelado**, consumido por 100% das chamadas:

```python
ESTILO_CENA = {
    "view":    <fixo>,     # mesmo valor em toda chamada
    "outline": <fixo>,
    "shading": <fixo>,
    "detail":  <fixo>,
    "seed":    <fixo>,     # base plate; objetos podem variar seed, nunca o resto
}
SUFIXO_LUZ = "light source from upper right, shadows cast to lower left"
```

Regras:
- Nenhuma chamada monta esse dicionário localmente.
- Nenhum override permitido — teste que falha se qualquer chamada divergir.
- `SUFIXO_LUZ` concatenado em **todo** prompt, sem exceção.

---

## E. Paleta forçada na origem (`color_image`)

Descoberta não explorada: **Pixflux e Inpaint aceitam paleta forçada.**

Isso muda a ordem de trabalho:

1. Gerar a placa base **sem** paleta forçada. Ela define a linguagem cromática.
2. Derivar a **paleta mestre de 64 cores** dela usando o OKLab de `requantizar.py` — **não median cut**.
3. Passar essa paleta como `color_image` em **todas** as chamadas de objeto subsequentes.
4. A quantização final (etapa 15) vira quase no-op — vira rede de segurança, não correção.

**Correção à sua decisão nº3:** derive a paleta de **placa base + camadas extraídas em conjunto**, não só da base. Derivando só da base, os objetos introduzem cores fora dela e são esmagados na quantização. Ordem prática: gere o piloto (B.5), junte piloto + base, derive a mestre, aí sim force nas 19 restantes.

### E.1 Paleta por estação

Inverno precisa de rampa fria que o verão não tem. Não quantize as três estações contra a mesma paleta.

```
paleta_estacao = dedup( LUT_estacao( paleta_mestre ) )
composto_final = quantizar( LUT_estacao(composto), paleta_estacao, dither=OFF )
```

Passe a **paleta** pela LUT, não só a imagem. Assim a saída da LUT cai exatamente em entrada de paleta — erro de quantização zero.

---

## F. Densidade de pixel — os objetos em escala fracionária

O inventário confirmou objetos em `0,16–0,28×` ao lado de peças 1:1. **Isso viola o invariante da §8 e não tem conserto por rescale.**

Regra: **regenerar em 1:1 via janela, nunca reescalar.** O pipeline de janela já resolve isso por construção — o objeto nasce no tamanho final dentro da placa base.

Os assets de `assets_v2/objects` em escala fracionária ficam fora do panorama. Se forem usados em outro contexto do jogo, permanecem lá — mas não entram na cena.

---

## G. Orçamento recalculado

| Item | Chamadas | Endpoint | Custo |
|---|---|---|---|
| Placa base 400×200 | 1 | `create-image-pixflux-background` | $0,013 |
| Piloto (§B.5) | 1 | `inpaint` 128×128 | $0,008 |
| Objetos restantes | 19 | `inpaint` janela | $0,152 |
| Muralha (segmento+portão+2 torres) | 4 | `inpaint` janela | $0,032 |
| Trilhas | 3 | `inpaint` janela | $0,024 |
| Cercas / hortas | 2 | `inpaint` janela | $0,016 |
| Tira de aldeões 128×16 | 1 | `create-image-pixflux` | $0,008 |
| **Subtotal** | **31** | | **$0,253** |
| Contingência de retry (30%) | ~9 | | $0,076 |
| **TOTAL ESTIMADO** | | | **≈ $0,33** |

Saldo: $7,6918. Teto: $1,50. **Folga de 4,5×.**

**Trava dura:** contador acumulado em `ferramentas/gasto_cenario.json`, incrementado **antes** de cada chamada. Ao atingir $1,50, aborta e reporta. Se o gasto real divergir da estimativa em mais de 50% após 5 chamadas, **pare e reporte** — significa que o endpoint está cobrando por tier diferente do previsto.

---

## H. Decisões aprovadas do relatório

| # | Decisão | Veredito |
|---|---|---|
| 1 | Upscale ×2 (800×400) em vez de ×4 | ✅ **Aprovado.** Fator inteiro, NEAREST, uma vez, no composto. |
| 2 | PNGs de estação v1 | ⚠️ **Remover do runtime, preservar em `docs/referencia_estacoes/`.** Servem como alvo de calibração da LUT. Dois caminhos de código em runtime = drift. |
| 3 | Paleta 64 derivada da cena | ✅ **Aprovado com as correções da §E.** OKLab, não median cut. Base + camadas, não só base. Variante por estação. |

---

## I. Polimento visual — além da spec original

Aplicar depois que o pipeline base estiver verde:

1. **Rim light.** Sol no canto superior direito ⇒ toda construção com 1px mais claro na aresta superior-direita. Sai de graça pelo inpaint em janela se o `SUFIXO_LUZ` estiver aplicado. Auditar visualmente.
2. **Dither.** Permitido **apenas** no que o modelo produz na placa base (gradiente de céu). **Proibido** na etapa de quantização — ali `dither=OFF`, senão empilha ruído sobre ruído.
3. **Teste de silhueta.** Renderizar o composto como preto puro sobre branco. Se a vila lê como um borrão único, o espaçamento e a oclusão da §5 estão errados. Deve ser possível contar as construções pela silhueta.
4. **Anti-repetição.** Nenhum asset colado idêntico duas vezes na mesma cena. Se a peça se repete, gere 2–3 variantes ou espelhe + troque a cor do telhado.
5. **Profundidade atmosférica.** Floresta e montanha dessaturam 15–25% em direção ao azul do céu. A placa base deve trazer isso; se não trouxer, aplique como parte da LUT — nunca por camada.
6. **Passe opcional de harmonização.** `create-image-pixflux` aceita **init image** e roda em 400×200 por $0,0132. Se o composto ainda ler como colagem após tudo isso, um passe img2img com guidance baixa derrete as costuras por 1,3 centavo. **Só usar se necessário**, e sempre requantizar depois.

---

## J. Sequência de execução autorizada

1. §D — dicionário `ESTILO_CENA` congelado + teste de não-override
2. §1 da spec — módulo de constantes de banda, convertido para 400×200 (`y × 200/180`)
3. Placa base + JSON de parâmetros, cacheada
4. **§B.5 — piloto de 1 objeto → PARAR E REPORTAR**
5. *(aval)* Paleta mestre §E → lote completo de objetos
6. §C — muralha tileável
7. Trilhas e cercas (§3 da spec)
8. Aldeões (§4 da spec)
9. Composição na ordem canônica (§6 da spec)
10. LUT + quantização + upscale ×2
11. Render N5/verão/dia → **aceite visual contra `docs/referencia.png`, mesma escala**
12. Testes da §8 + §I.3 (silhueta)
13. Relatório de custo real

**Dois pontos de parada obrigatórios: passo 4 e passo 11.** Não pule nenhum.

---

## K. Proibições — acrescentar às da spec original

- ❌ Não chamar `/v2/inpaint` com área > 40.000
- ❌ Não migrar para `/v2/inpaint-v3` sem autorização explícita (custo 15×)
- ❌ Não montar `ESTILO_CENA` localmente nem sobrescrever qualquer campo
- ❌ Não fazer padding artificial em janela que vaza o canvas — desloque
- ❌ Não reescalar objeto de escala fracionária — regenere em 1:1
- ❌ Não quantizar as três estações contra a mesma paleta
- ❌ Não tilear muralha em intervalo uniforme
- ❌ Não prosseguir do passo 4 sem aval
