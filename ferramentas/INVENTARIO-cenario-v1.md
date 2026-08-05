# Inventário do pipeline de cenário v1 — antes de qualquer mudança

Data: 2026-08-05 · branch de trabalho: `cenario-v2` (a principal não recebe WIP)

## Saldo real da API
`GET /v2/balance` → **US$ 7,6918** (a spec assumia 7,97; a diferença é o gasto
da rodada de reproporção). Teto desta implementação: US$ 1,50, com contador
acumulado em `ferramentas/gasto_cenario.json`.

## Endpoints confirmados no OpenAPI (não assumidos)
- `POST /create-image-pixflux-background` — required: description, image_size;
  aceita `seed`, `view`, `outline`, `shading`, `detail`, `color_image`.
- `POST /inpaint` — required: description, image_size, `inpainting_image`,
  `mask_image`; aceita `seed`, `view`, `outline`, `shading`, `detail`.
- Largura máxima de image_size: 400 (medido empiricamente em erro 422 anterior;
  o schema não declara limites).

## Canvas nativo
- Arte: **400×200**, desenhada a 2× exatos (800×400) num SubViewport com
  NEAREST em tudo (`panorama_cena.gd`).
- Conversão da tabela de bandas (base 320×180): `y_real = y/180*200 = y×1,111…`
  Arredondado para inteiro par quando possível.
- **Desvio declarado**: o upscale final é ×2, não ×4. ×4 de 320×180 = 1280×720
  não cabe na área útil da aba (~920×430 de 960×540). A regra preservada é a
  que importa: fator inteiro, nearest, uma única vez, no canvas final.

## As camadas existentes (v1)
Faixas de fundo (400 de largura): `pan_ceu_dia`, `pan_ceu_inverno`,
`pan_montanha_longe`, `pan_montanha_perto`, `pan_floresta_{verao,outono,inverno}`,
`pan_campo_{verao,outono,inverno}`, `pan_rio`, `pan_palicada`, `pan_muralha`.
Peças: `pan_sol`, `pan_torreao`, `pan_castelo`, `pan_ponte`, `pan_caminho`,
`pan_tenda_circo`, `pan_tenda_verde`, `pan_academia_{treino,pedra}`,
`pan_moinho_madeira`, `pan_estabulo`, `pan_casa_vermelha`, `pan_horta`,
`pan_galinha`, `pan_porco`, `pan_cavalo` — mais objetos de `assets_v2/objects`
reutilizados em escala fracionária 0,16–0,28.

## Onde a quantização acontece hoje
- `ferramentas/requantizar.py` (48 cores, OKLab monotônico) roda sobre
  sprites/icons/ui/tilesets/objects/characters/vfx — **o panorama está
  excluído de propósito** (commit e4471df).
- Ou seja: hoje NÃO há quantização nenhuma no panorama, nem por camada nem no
  composto. A spec pede uma única, no composto final — será nova, não migrada.

## Defeitos do v1 que a spec ataca (confirmados no código)
1. **Sem orçamento de Y**: `BASE_*` são constantes soltas em `panorama_cena.gd`,
   disputadas a olho; o campo já foi espremido duas vezes por isso.
2. **Camadas nascidas isoladas**: cada PNG veio de uma chamada independente —
   luz divergente (o pacote de objects tem 8 peças iluminadas pela esquerda e
   7 pela direita, medido em auditoria), paletas independentes, zero sombra
   de contato desenhada na grama.
3. **Densidade de pixel mista**: objetos de `objects/` entram a 0,16–0,28 de
   escala ao lado de peças 1:1 — pixels de tamanhos diferentes na mesma cena.
4. **Sombra assada**: `Vfx.sombra_projetada` é um sprite preto translúcido,
   não uma máscara multiply — em cima de neve ficaria sombra de grama.
5. **Estações por regeneração**: 7 PNGs de variante; a spec troca por LUT
   global no composto (e as variantes v1 ficam como reserva/fallback).

## Luz
A spec fixa **canto superior direito** — bate com o sol da referência
(topo-direita). O DNA v1 dizia "upper left"; o v2 corrige na placa base e em
100% dos inpaints.
