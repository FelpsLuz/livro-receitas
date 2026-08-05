# ADDENDUM v3.3 — Blockout antes de asset

**Status:** §F passos 1–4 do v3.2 aprovados integralmente. Passos 6 e 7 aprovados, com **um passo novo de custo zero inserido antes**.

**Precedência:** v3.3 > v3.2 > v3.1 > v3 > v2.1 > spec original.

---

## A. Ratificações

| Item | Veredito |
|---|---|
| `auditar_luz.py` — instrumento de medição em vez de inspeção visual | ✅ **Resposta de engenharia correta.** Manter no repositório permanentemente; rodar contra qualquer asset ou placa futura. |
| Nota de método: média por flanco e gradiente se cancelam em maciço listrado; contagem de pares horizontais sobrevive | ✅ **Achado técnico real.** Documentar no cabeçalho do auditor — é armadilha que volta. |
| Achado maior que o reportado: placa inteira à esquerda, 4 bandas vermelhas | ✅ Meu diagnóstico estava certo e incompleto. |
| Espelho global em vez de véu ou flip por banda | ✅ Raciocínio correto: véu destruiria troncos de ΔL 26; flip por banda racharia árvore que cruza fatia. |
| `placa_modelo.png` preservando o original | ✅ |
| Véu de recessão só no maciço, laterais intactas | ✅ Granularidade certa. |
| Água: medição de organização espacial → 3 cores cicladas | ✅ Diagnóstico, não palpite. Aceito. |
| Ruído fundido em `valor_banda` (um material por CanvasItem) | ✅ Restrição correta da engine, bem resolvida. |

**Regra permanente derivada:** toda vez que a placa base ou qualquer asset de fundo mudar, `auditar_luz.py` roda antes do merge. A placa base não é dogma — é asset como outro qualquer e tem o mesmo direito de estar errada.

---

## B. PASSO NOVO — Blockout do N5

### Por que agora

Você está a um aval de gerar 19 objetos sem nunca ter validado **onde eles vão**. E o terreno (trilhas, praça, canteiros) não pode ser autorado antes disso: trilha tem que **ligar coisa**. Sem layout definido, gera-se estrada para lugar nenhum.

Prática padrão de arte técnica de jogo: greybox antes de asset final.

### B.1 O que fazer

Cena `tests/blockout_n5.tscn`, custo $0,00:

- `ColorRect` cinza médio para cada construção planejada, no tamanho previsto em pixels nativos
- Retângulo para a muralha (largura cheia, altura 16px, topo em Y≥88)
- Retângulo para o castelo (base Y≈104, topo Y≈40)
- Marcador de 6×10px para cada aldeão (15 no N5)
- Traço para as trilhas planejadas
- Tudo por cima da placa corrigida, no `SubViewport` real

### B.2 As três perguntas que o blockout responde

**1. O castelo colide com o pico?**

O espelho tirou o cume do centro — ele está agora em ~42% da largura. O castelo ancora no centro e sobe até Y≈40. **Vai pousar no ombro direito do maciço.**

Na referência, o castelo tem montanha flanqueando dos dois lados e **vale atrás dele**. Se o blockout confirmar colisão, três saídas, todas $0,00:
- deslocar o castelo horizontalmente até cair num vale entre picos
- espelhar **só a banda de montanha** de volta (a auditoria pós-espelho passa a exigir véu nela — checar)
- aceitar o pico atrás e garantir separação por valor (castelo claro contra rocha média)

Decidir **agora**, não depois de 19 assets posicionados.

**2. A distribuição lê como povoado ou como fileira?**

Aplicar as regras da spec §5: 10–20% de sobreposição horizontal entre vizinhos, escalonamento de Y ±6px, ordenação de desenho por Y crescente.

**3. Teste de silhueta — agora informativo.**

Com uma casa só ele não disse nada. Com 15 construções + muralha + castelo, ele responde se a vila lê como forma projetada ou como objetos espalhados. Rodar em preto puro sobre branco.

### B.3 Critério de aceite do blockout

- [ ] Castelo não pousa sobre pico; há separação de valor entre castelo e o que está atrás
- [ ] Nenhuma construção isolada com ar em volta — todas em agrupamento
- [ ] Trilhas conectam ponte → praça → portão, e ramificam para as construções
- [ ] Silhueta lê como assentamento, não como fileira
- [ ] Banda de campo continua respeitando o mínimo de 48px normalizado
- [ ] Densidade de aldeões conforme a tabela (N5 = 15)

**PARAR e reportar o blockout + a silhueta antes de gerar qualquer asset.**

---

## C. Floresta — aprovada, $0,008

Executar **depois** do blockout aprovado.

Com a montanha recuada, a floresta virou o defeito nº1 isolado: **barra escura sólida de 26px atravessando 400px**. Lê como muro, não como mata.

### C.1 Checklist de aceite

- [ ] 5 variantes: 3 coníferas de alturas distintas + 2 decíduas
- [ ] 3 `TileMapLayer` com `modulate` de recessão por tier
- [ ] Jitter de Y ±4px — **a linha do topo tem que ondular**
- [ ] Nenhuma silhueta idêntica adjacente
- [ ] Tier de fundo usando o shader `recessao_atmosferica` (coerência com o maciço)
- [ ] `auditar_luz.py` verde nas copas — lado claro à **direita**
- [ ] **Clareiras:** 2–3 aberturas na barra, quebrando a leitura de muro contínuo

O último item é o mais importante e não estava no v3. Uma barra dark sem interrupção é artificial mesmo com 5 variantes. A referência tem a mata abrindo e fechando.

### C.2 Linha do horizonte

A base da floresta e o topo do campo são hoje **a mesma linha horizontal perfeita através de 400px**. É um dos tells mais fortes de arte gerada que restam no quadro.

Resolve-se na tira de sub-bosque (§D), com jitter de Y ±3px e arbustos cruzando a fronteira nos dois sentidos.

---

## D. Terreno — aprovado condicionado, $0,032

Liberado **após** o blockout aprovado. As trilhas são autoradas contra o layout do blockout, não inventadas.

Ordem interna: `terreno_trilhas` → `terreno_cultivo` → `terreno_sub_bosque` (por último, contra a floresta já em 3 tiers).

---

## E. Estratos do campo — encerrar o assunto

Persiste retângulo mais claro no campo superior, terminando em **aresta vertical reta**.

**Ruído quebra chapado, não quebra aresta geométrica.** Não aumente a amplitude — 0,045 já está no limite antes de virar chuvisco de TV.

Quem mata isso é o terreno cobrindo por cima. **Deixar como está e reavaliar no passo 8.** Se sobreviver ao terreno, aí sim ataca-se a aresta especificamente (transição em dither de 2px na fronteira).

---

## F. Água — aceite final

A medição foi feita e a decisão está fundamentada. Falta só o teste de leitura:

Assista **10 segundos em 1×, velocidade real**, olhando para o campo. **Seu olho é puxado para a água?** Se for, ainda está alto — reduza a velocidade do ciclo em 30% ou tire o branco-gelo do ciclo. A água é ambiente, não sujeito.

Verificar também: o espelho global inverteu a placa. Se as fitas de onda tinham direção, o sentido do ciclo pode estar contra a leitura visual. Um sinal trocado resolve.

---

## G. Sequência

| # | Passo | Custo |
|---|---|---|
| 1 | §B — blockout do N5 + silhueta | $0,00 |
| 2 | **PARAR** — aprovar layout e posição do castelo | — |
| 3 | §C — floresta 5 variantes, 3 tiers, com clareiras | $0,008 |
| 4 | §D — 3 tiras de terreno contra o layout aprovado | $0,032 |
| 5 | **PARAR** — render N0 povoado | — |
| 6 | Objeto de referência + critério de rejeição | $0,008–0,024 |
| 7 | **PARAR** — aprovar sprite de referência | — |
| 8 | 18 objetos via bitforge | $0,144 |
| 9 | Recalibrar sombra (−0,19 / −0,35 / 0,40) | $0,00 |
| 10 | Paleta mestre + shader de grade | $0,00 |
| 11 | Muralha tileável + aldeões | $0,040 |
| 12 | **PARAR** — aceite N5 + silhueta final | — |

---

## H. Proibições — acrescentar

- ❌ Não gerar terreno antes do blockout aprovado — trilha tem que ligar coisa
- ❌ Não gerar construção antes de saber onde ela vai
- ❌ Não aumentar a amplitude do ruído de estrato
- ❌ Não aceitar floresta como barra contínua sem clareira
- ❌ Não posicionar o castelo sem verificar colisão com o pico
