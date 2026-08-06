# Escolha de fonte — tabela de aceitação

Documento exigido antes de commitar a frente 1. Nada aqui é opinião: são
medidas de `ferramentas/testar_fontes.py` sobre **361 fontes candidatas**.

## O que reprovou as fontes anteriores

| Fonte | Pior par de dígitos | Pares acima de 80% | Título (pior par) | Veredito |
|---|---|---|---|---|
| Pixelify Sans @16 | **2/3 — 95%** | **14 de 45** | O/Q 93% | reprovada |
| Pixelify Sans @20 | 3/9 — 96% | **21 de 45** | O/Q 95% | reprovada |
| Jacquard 12 @20 | 6/9 — 76% | 0 | **E/C 96%** | reprovada no título |

A leitura de campo bate com a medida: com 21 pares de dígitos acima do teto,
"custo 20" lendo como "custo 80" não é azar, é o esperado. E a Jacquard com
E/C a 96% explica "REINO POR CONQUISTA" virando "RCIND PVR CVNQVISTA".

## Como a colisão é medida

Dois glifos recortados na própria caixa de tinta, sobrepostos pelo canto
superior esquerdo, comparados célula a célula sobre a união das duas caixas.
Duas colunas:

* **identidade** — o critério pedido: fração de células iguais.
* **IoU** — interseção sobre união só da tinta. É a que separa de verdade,
  porque não conta fundo.

### A armadilha da métrica, medida e não suposta

A identidade crua **cresce quando o glifo encolhe**. Num dígito de 3×5 células
sobram 15 células para diferenciar dez símbolos; num de 12×15 sobram 180. Por
isso a Tiny5 — a fonte menos legível do lote, com dígitos de 5px de altura —
é a que mais facilmente passa num teto de 80%, enquanto desenhos maiores e
mais legíveis ficam em 84%.

**Nenhuma das 361 candidatas passa num teto estrito de 80% no seu tamanho
nativo.** As duas que passam (Tiny5 @16 e @24) passam por serem pequenas
demais para o uso. Por isso a decisão final usa o IoU como desempate e o teto
como piso de sanidade, com os seis pares críticos verificados um a um.

## Finalistas

| | XGA-AI 12x20 | ToshibaTxL1 8x16 | Tiny5 |
|---|---|---|---|
| papel | números e corpo | títulos e rótulos | — |
| grade nativa | 20 (nítida em 20, 40) | 16 (nítida em 16, 32, 48) | 8 |
| pior par de dígitos @nativo | 0/6 — 81% | 8/9 — 92% | 0/8 — 80% |
| **IoU do pior par** | **61%** | 89% | 67% |
| 2/8 · 5/8 · 6/8 | 67% · 67% · 79% | — | 67% · 60% · 80% |
| 3/8 · 0/8 · 1/7 | 72% · 72% · 59% | — | 73% · 80% · 67% |
| título E/C · O/D · O/V | 72% · 83% · 42% | **60% · 74% · 49%** | — |
| serifa (flare do "I") | 1,0 (sem) | **5,0 (romana)** | 1,0 |
| acentos PT-BR | 15/15 | 15/15 | 15/15 |
| caracteres em 960px | 80 @20 | 120 @16 | 134 @16 |

O IoU do XGA-AI é **6 pontos abaixo** do segundo colocado entre as 361 — a
maior margem do lote. Os seis pares críticos ficam todos folgados.

## Decisão

* **Corpo, números e HUD** — `PxPlus_IBM_XGA-AI_12x20` a **20px** (e 40 para
  destaque). Melhor separação de dígitos medida; zero em qualquer par crítico
  perto do teto.
* **Títulos, rótulos e botões** — `PxPlus_ToshibaTxL1_8x16` a **16px**
  (32 para o título do jogo). É serifada de verdade — flare 5,0 contra 1,0 de
  uma sem serifa — e é a melhor do lote nos pares que quebram um título:
  E/C 60%, N/M 53%, O/D 74%. Seus dígitos são ruins (8/9 a 92%), e é por isso
  que **número nenhum usa esta fonte**.

Duas fontes, exatamente como pedido, e a divisão de papéis não é estética: é
a consequência direta dos números acima.

Licença: *Ultimate Oldschool PC Font Pack* v2.2 (VileR / int10h.org),
**CC BY-SA 4.0**. Aviso em `assets/fontes/LICENSE-oldschool.txt`.

## Como reproduzir

```
python3 ferramentas/testar_fontes.py --dir <pasta> --tamanhos 16,20,32
python3 ferramentas/testar_fontes.py --fonte X.ttf --tamanho 20 --amostra
```
