# Cenário — a terra do jogador

Documento único do cenário. Descreve o **estado real** do repositório, não
um plano. Se algo aqui divergir do código, o código está certo e este texto
está velho.

---

## Estado atual: visual strip

**Não há arte no projeto.** O cenário é um caixote cinza de 480×270 vindo de
`scripts/arte.gd`, como todo o resto do jogo. O nível da terra continua
aparecendo — em texto, pelo nome de `Dados.NIVEIS_TERRA` — e a mecânica de
evolução continua inteira.

O que sobrou de runtime, e por quê:

| peça | fica porque |
|---|---|
| `CenarioV3Cena.estagio` | espelha `estado.terra.nivel`, 1:1 nos seis degraus |
| `evoluir()` + crossfade de 0,8s | é a **duração** da transição. Sem ela `em_transicao()` responderia sempre false e a vista atropelaria uma evolução com outra |
| sinal `evolucao_terminou` | fecha o ciclo para quem escuta |
| `CenarioV3View` | o adaptador que o jogo pede: `SubViewportContainer` com `estado` e `semear_npcs()` |

Saiu tudo o que era aparência: as seis imagens pintadas, o shader de vida
(água ciclando por correspondência de cor, junco balançando na amostragem),
a poeira de obra por células de densidade e o flash da transição.

---

## Como a arte volta

O pipeline de pixelização continua em `ferramentas/cenario_v3/`. Ele não é
arte — é a receita — e por isso sobreviveu ao strip:

```
processar_estagios.py   mockup em alta → 480×270, PNG-8 indexado, paleta única
verificar_fase1.py      mede as asserções e imprime cada uma
medir_estagios.py       coordenadas.json (registro) + transicoes.json (diff)
oklab.py                conversão sRGB ⇄ OKLab
```

⚠️ **Rodar `processar_estagios.py` reintroduz arte no projeto**, e
`tests/teste_strip.gd` vai ficar vermelho — corretamente. Ou o strip acaba
ali de propósito, ou o destino da saída muda para fora de `res://`.

As imagens de origem do lote antigo saíram do repositório junto com o resto.
Elas estão no histórico, no commit `770a921`:

```bash
git checkout 770a921 -- entrada/
```

---

## O que o pipeline aprendeu

Cada uma destas custou uma tentativa errada. Valem para qualquer leva de arte
futura, com ou sem este pipeline.

**A ordem é inegociável.** Quantizar antes de reduzir gera lixo, porque a
quantização fixa a cor de pixels que ainda vão ser mesclados. Recorte →
redução por BOX → paleta → quantização.

**Moldura: recortar sem repor desloca o conteúdo.** Um dos seis mockups veio
com moldura dourada; recortá-la e seguir deixou a imagem 2px fora de registro
com as outras cinco. A correção é recortar e **repor a borda replicando a
linha adjacente**, mantendo a altura.

**Média inventa cor.** Qualquer operação que tire média produz um valor fora
da paleta. A mediana de duas cores de céu — (175,233,241) e (185,231,241) —
deu (180,232,241), que não existia, e desenhou uma linha de 1px atravessando
a montanha. Use **moda ou cópia**, nunca média.

**Fusão de paleta por luminância descarta o que ocupa área.** Mesclar em
ordem de luminância jogou fora o verde do campo, que cobria 35% do quadro. A
fusão tem que ser **ponderada por frequência de pixel**.

**A ordem narrativa não se infere.** Densidade de detalhe põe o estágio 6
antes do 4; massa de pedra não separa 4/5/6 porque a rocha da montanha cai na
mesma faixa de cinza. Um argumento explícito é mais honesto que um heurístico
que erra em silêncio.

**Escala fracionária destrói a grade.** Escalas de 0,8/0,9 para dar
profundidade reamostram o sprite e quebram o pixel. Ampliação para tela é
**fator inteiro**.

**"Linha do horizonte" não mede registro.** Detectar a primeira linha não-céu
por coluna acusou 33px de deslocamento onde não havia nenhum: o céu tem
degradê, e o detector achava a fronteira da segunda faixa do degradê. A medida
certa é **correlação direta** na banda de fundo, que não classifica pixel
nenhum.

**Os seis mockups não vinham registrados entre si.** Medido nos PNG crus: o
sol variava 17px, e dois dos seis tinham outra cordilheira e nenhuma faixa de
floresta. O pipeline não desloca nada — a deriva era da fonte. Se houver nova
leva, é isto que precisa ser exigido de quem gera.

---

## Dimensões que a arte nova tem que respeitar

Não são preferência: são o que segura o layout depois do strip.

| constante | valor | efeito se mudar |
|---|---|---|
| `CenarioV3Cena.NATIVO` | 480×270 | o enquadramento da aba "Sua Terra" |
| `VilaCena.TAMANHO_OBJ` | por objeto | `_ancorar()` põe a origem nos pés pela ALTURA; errar move a construção e fura o Y-Sort |
| `UIv2.MARGENS` | por peça | quanto a moldura come do retângulo, e portanto o layout de toda janela |
| `Icones.LADO` | 64 | o slot de inventário |
| `Retratos.LADO_RETRATO` | 64 | o card de personagem |
| `Retratos.LADO_EVENTO` | 128 | a faixa dos modais |
| `PersonagensV2.LADO` | 124 | a silhueta que a vila usa para escalar o herói contra as casas |
