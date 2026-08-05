# ADDENDUM v3.5 — Laterais, paleta em runtime e a placa como artefato derivado

**Status:** §E passos 1–2 do v3.4 aprovados. 20/20 critérios verdes, folga de 16px medida, castelo 2,2× a casa.

**Precedência:** v3.5 > v3.4 > v3.3 > v3.2 > v3.1 > v3 > v2.1 > spec original.

---

## A. Ratificações

| Item | Veredito |
|---|---|
| Quatro abordagens erradas documentadas com o modo de falha de cada | ✅ **Manter no repositório.** Cada uma parecia razoável; o log evita que voltem. |
| Descoberta: mediana de duas cores de paleta gera cor fora da paleta | ✅ **Achado de princípio.** Ver §B — generaliza. |
| Bug de salvar antes do selo, achado e corrigido sozinho | ✅ Operação destrutiva com estado inconsistente em falha. Correção certa (selo primeiro). |
| "Cume y=44" era copa de árvore; detector trocado para run mais longo | ✅ Desconfiar da medida, não do resultado. |
| Solução final: pixel de rocha recebe conteúdo de 20 linhas acima | ✅ **Melhor que o especificado.** Não preenche, não inventa cor, base contínua por construção, 0 cores novas. |
| Extensão do maciço registrada no selo (propriedade do momento da transformação) | ✅ Reconhecer que a detecção deixa de ser possível pós-transformação é raciocínio correto. |
| `z_index` = linha do pé nos aldeões | ✅ Ordenação de profundidade correta, não estava na spec. |
| Ressalva sobre a tabela de dente de serra pressupor ~18 construções | ✅ **Julgamento correto.** Você separou o princípio (nenhuma alta adjacente) da ilustração (a tabela). |
| Reportar a perda das laterais como consequência medida, com opção | ✅ |

---

## B. O princípio por trás da mediana — e o que ele expõe

Você provou que **qualquer operação que faz média introduz cor fora da paleta.**

Isso não vale só para o preenchimento. Vale para tudo que roda em runtime:

| Shader | Operação | Consequência |
|---|---|---|
| `valor_banda` | véu em gradiente + ruído multiplicativo | cores contínuas |
| `recessao_atmosferica` | `mix()` com cor de horizonte | cores contínuas |
| `modulate` nos tiers da floresta | multiplicação | cores contínuas |

**As renderizações atuais não são pixel art de paleta limitada.** Parecem certas porque a arte de origem era limitada e os véus são sutis, mas a restrição já quebrou.

### B.1 Medida obrigatória, antes de qualquer coisa

Contar **cores únicas do render N0 atual**, em 1× nativo.

| Resultado | Leitura |
|---|---|
| ≤ ~80 | os véus estão caindo em cores existentes por acaso — improvável |
| centenas a milhares | esperado; confirma que o snap é estrutural |

### B.2 O shader de snap sobe de prioridade

Estava no passo 11. **Vai para logo depois da floresta.** Dois motivos:

1. Ele não é rede de segurança, é **estrutural** — é o que devolve a cena à condição de pixel art.
2. Se a quantização quebrar algum véu (banding em degrau no gradiente do campo, por exemplo), é melhor descobrir agora do que depois de construir terreno, 19 objetos e castelo em cima.

**Critério de aceite do snap:** aplicado, o N0 tem ≤64 cores únicas e nenhum gradiente vira degrau visível. Se virar, a solução é dither ordenado 2×2 na transição — não afrouxar a paleta.

---

## C. DECISÃO — restaurar as serras laterais

### C.1 Veredito: restaurar

Dois motivos, o segundo mais forte que o primeiro:

1. A referência tem montanha flanqueando dos dois lados.
2. **O castelo está em x=272, à direita do centro; o maciço à esquerda.** Sem as laterais, a borda direita do quadro fica sem âncora — só floresta e céu. A composição pende para a esquerda.

Restaurar as pontas desconectadas (`x<35` e `x>358`) à posição original. Como há vão natural de céu separando-as da cordilheira conectada, não há costura a reintroduzir.

### C.2 Janela de validação obrigatória

A hierarquia vertical estabelecida é: **castelo y=36 → maciço y=52 → laterais**. As laterais não podem competir com o maciço nem sumir atrás da mata.

| Limite | Valor | Motivo |
|---|---|---|
| Mais alto que podem ficar | **y = 56** | 4px abaixo do cume do maciço |
| Mais baixo que podem ficar | **y = 74** | 4px acima do topo da mata (y≈78) |

Restaurar à origem e **medir o pico de cada ponta**. Se cair fora de 56..74, ajustar o deslocamento **só dessas colunas** até entrar. Medir, não assumir.

### C.3 Verificações pós-restauração

- [ ] Pico de cada lateral dentro de 56..74
- [ ] Castelo continua sendo a silhueta mais alta da cena (incluindo copas de borda)
- [ ] `auditar_luz.py` verde nas laterais restauradas
- [ ] 0 cores novas introduzidas
- [ ] Nenhuma costura vertical nova (mesmo teste de salto usado na junção maciço/mata)
- [ ] As laterais mantêm a bruma original — não aplicar o véu de recessão nelas (já nascem hazy)

---

## D. A placa como artefato derivado, não mutado

Hoje a placa é **mutação in-place com selo de idempotência**. Funciona, mas é frágil — você já provou isso quando uma exceção deixou o estado alterado e destravado.

E vêm mais transformações: a restauração das laterais é a próxima, e as variantes de estação podem exigir outras.

### D.1 Arquitetura alvo

```
placa_modelo.png              ← fonte, imutável, nunca editada
  └── transformacoes.json     ← lista ordenada e declarativa
        └── construir_placa.py
              └── placa_base.png   ← artefato derivado, sempre reconstruído do zero
```

`transformacoes.json`, hoje, conteria:
```json
[
  { "op": "espelho_global" },
  { "op": "descer_cordilheira", "px": 20, "extensao": [63, 323] },
  { "op": "restaurar_pontas", "colunas": [[0,35],[358,400]] }
]
```

**Vantagens:** idempotência vira propriedade grátis (sempre reconstrói da origem); a ordem das transformações fica auditável; qualquer transformação futura é uma entrada na lista, não uma nova mutação com novo selo; e se a placa precisar ser regerada por API algum dia, o pipeline replaya inteiro.

`placa_base.png` passa a ser artefato de build. Pode continuar versionado por conveniência, mas com a garantia de ser reproduzível.

---

## E. Nota para a floresta (próximo passo)

Com o maciço rebaixado e as laterais restauradas apenas nas pontas, **a floresta agora é a linha do horizonte em boa parte da largura**. Antes a montanha quebrava o topo dela em mais colunas.

Isso eleva a importância de dois itens que já estavam no checklist:

- **O topo tem que ondular.** Sem montanha atrás para quebrar, uma copa reta vira linha de régua.
- **As clareiras ficam mais críticas.** Sugestão de posicionamento: nas regiões onde as laterais foram perdidas, para que a variação de horizonte exista mesmo onde não há mais montanha.

---

## F. Sequência

| # | Passo | Custo |
|---|---|---|
| 1 | §B.1 — contar cores únicas do N0 | $0,00 |
| 2 | §C — restaurar laterais + verificações §C.3 | $0,00 |
| 3 | §D — converter a placa em artefato derivado | $0,00 |
| 4 | **PARAR** — render N0 + contagem de cores + picos medidos | — |
| 5 | Floresta: 5 variantes, 3 tiers, clareiras, topo ondulado | $0,008 |
| 6 | **§B.2 — shader de snap de paleta + paleta mestre OKLab** | $0,00 |
| 7 | **PARAR** — N0 com ≤64 cores, sem banding | — |
| 8 | 3 tiras de terreno (trilha ≥10px no tronco) | $0,032 |
| 9 | **PARAR** — N0 povoado | — |
| 10 | Objeto de referência + critério de rejeição | $0,008–0,024 |
| 11 | **PARAR** — aprovar sprite de referência | — |
| 12 | 18 objetos via bitforge | $0,144 |
| 13 | Castelo em 5 peças | $0,040 |
| 14 | Recalibrar sombra; muralha; aldeões | $0,040 |
| 15 | **PARAR** — aceite N5 + silhueta final | — |

---

## G. Proibições — acrescentar

- ❌ Não aplicar véu de recessão nas laterais restauradas
- ❌ Não aceitar lateral com pico fora da janela 56..74
- ❌ Não seguir para o terreno antes do snap de paleta estar verde
- ❌ Não afrouxar a paleta para resolver banding — usar dither ordenado 2×2
- ❌ Não fazer nova mutação in-place na placa; toda transformação entra em `transformacoes.json`
- ❌ Não usar média/mediana em nenhuma operação de pixel — moda ou cópia
