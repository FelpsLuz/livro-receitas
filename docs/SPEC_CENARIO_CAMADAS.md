# SPEC — Pipeline de Cenário em Camadas (v2)

**Status:** substitui a abordagem atual de geração de camadas isoladas.
**Escopo:** não altera a arquitetura de camadas nem o sistema de níveis. Altera **onde as camadas nascem** e **como o composto é finalizado**.

---

## 0. Antes de escrever qualquer linha

1. Leia `https://api.pixellab.ai/v2/llms.txt` e o OpenAPI em `https://api.pixellab.ai/v2/openapi.json`. Confirme os nomes reais de endpoint e parâmetro antes de codar. Não assuma assinatura de memória.
2. Leia a imagem de referência anexada. Ela é o alvo visual. Toda decisão ambígua resolve olhando pra ela.
3. Faça inventário do estado atual: liste as 12 camadas existentes, a resolução nativa do canvas, e onde a quantização acontece hoje no pipeline. **Reporte antes de mudar qualquer coisa.**

### Guarda de orçamento — obrigatória

- Saldo disponível: **US$ 7,97**.
- Teto desta implementação: **US$ 1,50**.
- Implemente um contador de gasto acumulado. Ao atingir US$ 1,50, **pare, reporte o que foi gerado e aguarde autorização**.
- Antes de qualquer lote de geração, imprima o custo estimado e o número de chamadas.

### Regra de não-regressão

- Os 441 testes atuais devem continuar passando. Se algum quebrar, é sinal de mudança não intencional — investigue, não ajuste o teste pra passar.
- Trabalhe em branch. Não commite direto na principal.

---

## 1. Canvas e orçamento vertical de faixa

O bug de layout atual (campo espremido, floresta engolida pela muralha) tem causa única: **não existe orçamento de Y**. Todas as camadas disputam o mesmo espaço vertical e a faixa de campo perdeu.

### Referência de proporção (canvas normalizado 320×180)

| Banda | Y início | Y fim | Altura | Regra |
|---|---|---|---|---|
| Céu | 0 | 52 | 52 | camada trocável (4 variantes) |
| Montanhas | 42 | 74 | 32 | overlap com céu é intencional |
| Floresta | 70 | 96 | 26 | **terreno permanente, não asset de nível** |
| Muralha | 88 | 104 | 16 | altura máx 16px; topo nunca acima de Y=88 |
| Campo / vila | 100 | 152 | **52** | **banda dominante, mínimo inviolável 48px** |
| Rio | 150 | 170 | 20 | |
| Margem frontal | 168 | 180 | 12 | |

**Castelo é a única exceção autorizada a quebrar banda.** Ancora a base em Y≈104 e sobe até Y≈40, invadindo montanha e céu. É isso que gera profundidade na referência — o castelo furando a linha do horizonte.

### Como aplicar

- **Se o canvas nativo do projeto não for 320×180:** converta as faixas por **razão proporcional** (`y_real = y_tabela / 180 * altura_nativa`). Não copie os inteiros.
- Trate os números como **hipótese inicial derivada da referência**, não como lei. Renderize N5, compare com a referência lado a lado na mesma escala, ajuste, **e só então congele como constantes**.
- Depois de congelar: exponha como um único módulo de constantes (`BANDAS`), consumido por todas as camadas. Nenhum Y hardcodado fora dele.

---

## 2. Origem das camadas: inpaint-then-diff

**Problema atual:** cada camada foi gerada em chamada isolada, sem contexto das outras. Resultado: direção de luz divergente, paletas independentes, zero sombra de contato, escala inconsistente.

**Solução:** manter as camadas separadas, mas **gerar cada uma dentro da cena** e recortá-la de volta.

### 2.1 Placa base (gerar uma vez, cachear, nunca regenerar)

Uma única chamada a `create-image-pixflux-background`:
- Conteúdo: céu + montanhas + floresta + campo **vazio** + rio + margem.
- Sem construções, sem pessoas, sem estradas.
- Trave e registre: seed, projeção (side-view), paleta, guidance, e **luz vinda do canto superior direito**.
- Salve como `base/placa_base.png` junto de um JSON com todos os parâmetros. Essa imagem é a **verdade fundamental**. Todo diff depende dela ser byte-idêntica.

### 2.2 Geração de cada objeto

Para cada asset (moinho, ferraria, casa de sapê, barraca, poço, carroça, castelo, muralha...):

1. Construa a máscara retangular na **posição final exata** dentro da banda correta.
2. `POST /inpaint` sobre a placa base, com essa máscara.
3. Prompt do objeto **+ o mesmo sufixo de estilo em 100% das chamadas** (mesma luz, mesma projeção, mesma paleta).

### 2.3 Extração da camada por diferença

```
base     = placa_base (RGB)
gerada   = resultado do inpaint (RGB)
d        = soma por pixel de |gerada - base| nos 3 canais   # 0..765
mask     = d > TOL                                          # TOL inicial = 12
mask     = mask AND mascara_inpaint                         # restringe à região
mask     = remover componentes conexos com area < 4 px      # mata ruído de dither
mask     = binary_closing(mask, raio=1)                     # fecha buracos internos
camada   = gerada com canal alpha = mask
```

**Armadilha crítica — trate explicitamente:** o modelo de inpaint pode devolver a imagem inteira levemente alterada (re-quantização global), inclusive fora da máscara. Se isso acontecer, o diff vira lixo.

**Verificação obrigatória:** meça a fração de pixels alterados **fora** da máscara.
- Se ≤ 2%: pipeline normal acima.
- Se > 2%: o endpoint alterou o global. Descarte tudo fora da máscara e trabalhe **só dentro dela**, com TOL recalibrado sobre a região.
- Logue esse percentual em toda extração. É o seu canário.

**Por que isso resolve de uma vez:** o objeto nasceu dentro da cena. Luz, paleta e escala já vêm corretas por construção. E a **sombra de contato já vem desenhada na grama**, capturada de graça pelo diff — exatamente o que se tentava colar depois e nunca ficava certo.

### 2.4 Separação da sombra (obrigatório para o sistema de estações)

Sombra **não pode** ser RGB assado na camada, senão sombra-de-grama-de-verão aparece em cima da neve.

Dentro da máscara, classifique como **sombra** (não objeto) o pixel que satisfaça as duas condições:
- razão de luminância `L_gerada / L_base` entre **0,55 e 0,92**
- delta de matiz em relação ao pixel da base **abaixo do limiar** (mesma cor, só escurecida)

Esses pixels saem da camada de objeto e vão para uma **máscara de sombra separada**, exportada como alpha puro, aplicada em **blend multiply a ~40%**. Assim funciona sobre qualquer estação.

### 2.5 Custo

1 placa base + ~15 inpaints + 1 tira de aldeões ≈ **US$ 0,30**. Dentro do teto.

---

## 3. Camadas faltantes: tecido conectivo

Hoje existem construções mas nenhuma malha ligando elas. É a diferença entre "casas num gramado" e "um povoado". Na referência, é a estrada saindo da ponte e chegando no portão que amarra a composição inteira.

Criar duas camadas novas, ambas escalando por nível:

**`trilhas`**
- N0: trilha fina de terra batida
- N1–N2: caminho alargando, ramificações até as casas
- N3–N5: estrada larga da ponte até o portão do castelo + praça de mercado empedrada

**`cercas_hortas`**
- Canteiros cercados preenchendo a banda de campo, quantidade crescendo por nível.

**Ordem de trabalho:** trilhas e cercas são desenhadas **antes** do posicionamento das construções. Os prédios se encaixam no traçado — não o contrário.

---

## 4. Aldeões — camada de densidade populacional

**Não gerar um por chamada.** Gere **em tira única**: um `create-image-pixflux` de 128×16 com 8 aldeões lado a lado, depois fatie programaticamente. Assim compartilham luz e paleta por construção.

Densidade por nível:

| Nível | Figuras |
|---|---|
| N0 | 2 |
| N1 | 4 |
| N2 | 6 |
| N3 | 9 |
| N4 | 12 |
| N5 | 15 |

Aldeões não são enfeite — são **régua de escala**. Sem eles a cena lê como maquete, não como lugar. São também os que mais dependem de sombra de contato: sem ela, flutuam de forma óbvia.

---

## 5. Oclusão e escalonamento em Y

Construções hoje estão enfileiradas com ar entre elas. Na referência, elas se ocluem.

- Permitir **10–20% de sobreposição horizontal** entre construções vizinhas.
- Escalonar Y em **±6px** entre elas dentro da banda de campo.
- Ordenar o desenho por Y crescente (mais ao fundo primeiro) para a oclusão sair correta.

---

## 6. Ordem canônica de composição

Esta é a única ordem válida. **Remova qualquer quantização por camada que exista hoje** — ela passa a acontecer uma única vez, no final.

```
1.  Céu (variante de horário)
2.  Montanhas
3.  Floresta
4.  Campo base
5.  Trilhas
6.  Cercas e hortas
7.  Rio
8.  Muralha (se nível >= 3)
9.  Sombras de contato        [multiply ~40%]
10. Construções               (ordenadas por Y crescente)
11. Castelo                   (se nível >= 4, quebra banda)
12. Aldeões + sombras deles
13. Margem frontal
--- composto pronto ---
14. LUT global de estação/horário
15. Quantização em paleta fixa, dither DESLIGADO
16. Upscale nearest-neighbor ×4
```

Nenhum resample bilinear, bicúbico ou lanczos em **nenhuma** etapa.

---

## 7. Estações e horários: color grade, não regeneração

Não regenerar camadas por horário. Aplicar **LUT global no composto**, etapa 14:

- **Entardecer:** shift quente, sombras levantadas, rim light laranja
- **Tempestade:** −30% saturação, shift frio, −15% luminância
- **Inverno:** shift frio + overlay de neve nos telhados (máscara gerada uma vez por prédio, reutilizada)
- **Outono:** shift da paleta de folhagem apenas nas camadas floresta e campo

**Efeito colateral valioso:** o grade global unifica cromaticamente todas as camadas de graça. É harmonização sem custo de API.

---

## 8. Testes

### Não quebrar

Os 441 testes atuais continuam passando.

### Adicionar — invariantes de layout

Adaptar os nomes ao código real. O que precisa ser verificado:

- altura da banda de campo `>= 48px` (ou o equivalente proporcional no canvas nativo)
- topo da muralha nunca acima de `Y = 88` normalizado
- floresta permanece visível acima da muralha em todos os níveis `>= 3`
- toda camada de objeto possui máscara de sombra de contato associada e não-vazia
- contagem de aldeões por nível bate com a tabela da seção 4
- todos os assets compartilham a mesma densidade de pixel (nenhum foi upscalado antes da composição)
- diff fora da máscara registrado `<= 2%` em toda extração

**Não escreva teste que passa vazio.** Se a variável não existe no código, crie a função de medição de verdade.

### Aceite visual

Renderizar **N5 / verão / dia**, colocar lado a lado com a imagem de referência **na mesma escala**, e iterar no orçamento de faixa até a proporção bater. Só depois congelar as constantes.

---

## 9. Proibições

- ❌ Não gerar asset em chamada isolada, fora da placa base
- ❌ Não regenerar a placa base entre extrações
- ❌ Não fazer upscale de sprite individual — só do canvas final
- ❌ Não quantizar por camada
- ❌ Não usar interpolação suave em nenhuma etapa
- ❌ Não assar sombra em RGB dentro da camada de objeto
- ❌ Não hardcodar Y fora do módulo de constantes
- ❌ Não passar do teto de US$ 1,50 sem autorização
- ❌ Não ajustar teste existente pra fazer passar

---

## 10. Entregável

1. Relatório do inventário inicial (seção 0.3) — **antes de mudar código**
2. Módulo de constantes de banda
3. Placa base cacheada + JSON de parâmetros
4. Pipeline inpaint-then-diff com log de diff-fora-da-máscara
5. Camadas `trilhas` e `cercas_hortas`
6. Camada de aldeões por densidade
7. Composição na ordem canônica da seção 6
8. Testes novos da seção 8
9. Render N5/verão/dia para aceite visual
10. Custo total gasto
