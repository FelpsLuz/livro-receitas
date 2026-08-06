# 🎨 Guia de Entrega de Arte — Reino por Conquista

Este documento diz **exatamente** o que produzir, em que tamanho, com que nome
de arquivo e como entregar. Qualquer PNG entregue **substitui automaticamente**
a arte procedural do jogo — sem mexer em código. O que não for entregue continua
usando a arte atual como fallback.

## Regras gerais (valem para tudo)

1. **PNG-24 com fundo transparente** (exceto onde indicado).
2. **Pixel art pura**: sem anti-aliasing, sem desfoque, sem mixels
   (todos os "pixels" do desenho devem ter o mesmo tamanho). Desenhe no
   tamanho nativo indicado — o jogo amplia com `nearest neighbor`.
3. **Contorno**: elementos interativos (personagens) levam contorno escuro
   `#26160e`. Cenário de fundo NÃO leva contorno.
4. **Hue-shifting**: sombras puxam para azul/frio, luzes para amarelo/quente.
   Nunca sombreie com preto ou cinza puro.
5. **Luz direcional**: fonte de luz vem da direita-superior.
6. Paleta de referência do jogo (grama verão): `#55a52e / #4e9c29 / #357c3e`;
   madeira `#a3703c / #8a5a2e / #6b4423`; pedra `#c2c3c9 / #9799a3 / #63667a`.

## Como entregar

Um único **.zip** anexado aqui no chat, com esta estrutura de pastas
(nomes de arquivo EXATOS, tudo minúsculo):

```
img/
  retratos/
  edificios/
```

Pode entregar por partes — cada zip que chegar eu integro e mando o jogo
atualizado. Prioridade sugerida: retratos dos 6 reis → nobres → edifícios.

---

## FASE 1A — Retratos (64×64 px, fundo pode ser opaco)

Aparecem nas conversas, ao lado do texto. Enquadramento: busto
(ombros + cabeça), olhando levemente para a esquerda, espaço de 4px no topo.

### Os 6 reis — `img/retratos/`

| Arquivo | Personagem | Direção de arte |
|---|---|---|
| `rei_imperio.png` | **Felps, o Destruidor** — Imperador | Cruel e imponente. Coroa de ferro escura, manto **verde-escuro** (cor do brasão imperial), cicatriz, olhar de desprezo. O mais forte do continente. |
| `rei_touros.png` | **Yami Sukehiro** — Touros Negros | Bruto e direto. Cabelo preto espetado, barba rala, capa preta surrada, katana ao ombro, sorriso confiante. Cor do esquadrão: **preto**. |
| `rei_alvorecer.png` | **William Vangeance** — Alvorecer Dourado | Sereno e indecifrável. Máscara cobrindo parte do rosto, cabelo claro, manto **dourado/branco**. Sorriso gentil que não chega aos olhos. |
| `rei_leoes.png` | **Fuegoleon Vermillion** — Leões Carmesins | Honrado e ardente. Cabelo ruivo-chama comprido, postura de general, armadura com detalhes **carmesim**. Olhar firme e justo. |
| `rei_aguias.png` | **Nozel Silva** — Águias Prateadas | Altivo e gélido. Cabelo **prateado** com a trança característica sobre o rosto, gola alta, ombreiras de prata. Desdém aristocrático. |
| `rei_rosa.png` | **Charlotte Roselei** — Rosa Azul | Bela e reservada. Cabelo loiro trançado, armadura leve **azul** com motivos de rosas e espinhos. Expressão contida. |

### NPCs da taverna/corte — `img/retratos/`

| Arquivo | Personagem | Direção de arte |
|---|---|---|
| `taverneiro.png` | Bram, o Taverneiro | Gorducho, avental sujo, sorriso malandro, caneca na mão. |
| `capitao.png` | Capitã Renna | Mercenária veterana, cicatriz, armadura de couro, olhar duro. |
| `espiao.png` | O Corvo | Capuz escuro, rosto na penumbra, só o queixo visível. |

### Nobres/Condes genéricos — `img/retratos/`

Os 30 nobres do jogo têm **nome e cidade sorteados a cada partida**, então
usam 8 retratos genéricos rotativos (o jogo escolhe por hash — sempre o
mesmo rosto para o mesmo nobre dentro de uma partida):

`nobre_1.png` … `nobre_8.png` — 64×64. Faça variedade: 4-5 homens e 3-4
mulheres, idades e tons de pele variados, roupas nobres (gola de pele,
broche, veludo). Sem coroa (coroa é só de rei).

---

## FASE 1B — Edifícios da terra (48×48 px, fundo transparente)

Aparecem nos cartões da aba "Sua Terra". Cada edifício evolui do nível 1 ao
30, mudando de sprite **a cada 5 níveis** → 6 estágios por edifício.
O estágio 6 deve parecer claramente mais rico/grande que o 1.

`img/edificios/` — 4 edifícios × 6 estágios = 24 arquivos:

```
fazenda_1.png  … fazenda_6.png    (canteiros → campos + silo + celeiro)
serraria_1.png … serraria_6.png   (toco e machado → serraria com roda d'água)
mina_1.png     … mina_6.png       (buraco na rocha → entrada com trilhos e vagonete)
ferreiro_1.png … ferreiro_6.png   (bigorna ao ar livre → forja com chaminé acesa)
```

---

## FASE 2 — Cenário do horizonte (negociamos depois da Fase 1)

O jogo mostra a cidade em **vista de horizonte**: céu com sol/lua, serras ao
fundo, vila em silhueta lateral. Quando a Fase 1 estiver integrada, eu mando
o gabarito das camadas (céu 640×140, serra distante, serra próxima, chão
640×220) e a lista de construções da vila com posições. Também ficam para a
Fase 2: brasões dos 6 reinos (24×24), aldeões 16×32 (2 quadros de caminhada)
e bichos.

---

## Checklist rápido antes de enviar

- [ ] Tamanho exato (64×64 retratos, 48×48 edifícios)
- [ ] Nome de arquivo exato, minúsculo, sem acento
- [ ] Sem anti-aliasing / sem mixels
- [ ] Sombras frias, luzes quentes, nada de preto puro
- [ ] Zip com a pasta `img/` na raiz
