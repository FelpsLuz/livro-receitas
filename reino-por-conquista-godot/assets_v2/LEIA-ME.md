# assets_v2 — assets Pro do PixelLab

Gerados por `generate_assets_v2.py` (raiz do repositório), organizados por tipo:

| pasta        | endpoint da API v2                | conteúdo                          |
| ------------ | --------------------------------- | --------------------------------- |
| `ui/`        | `POST /generate-ui-v2`            | molduras 9-slice, botões, barras  |
| `tilesets/`  | `POST /create-tileset` (modo pro) | terreno contínuo em atlas         |
| `objects/`   | `POST /map-objects`               | árvores, casas, baús, poços       |
| `characters/`| `POST /create-character-v3`       | personagem com 8 rotações         |

## Custo (tabela oficial de preços do PixelLab)

Os preços são **por imagem, em centavos de dólar** — o catálogo inteiro de 18
assets custa cerca de **US$ 0,81**:

| endpoint                    | tamanho        | US$/asset |
| --------------------------- | -------------- | --------- |
| `create-image-pixflux`      | 64×64 alfa     | 0,0084    |
| `map-objects`               | por objeto     | 0,0099    |
| `create-tileset`            | tiles 32×32    | 0,0099    |
| `create-character-v3`       | 64×64, 8 rot.  | 0,041     |
| `generate-ui-v2` (Pro)      | até 256×256    | 0,095     |

A conta consome primeiro a cota mensal de *generations* do plano e só depois os
créditos em dólar. Rode `--saldo` antes de um lote grande e `--listar` para ver
o orçamento estimado.

## Estado atual

Só `ui/painel_madeira.png` está gerado — a cota de 40 gerações do trial acabou
no meio do lote de UI. Os outros 17 assets do catálogo aguardam saldo.

## Como continuar

```bash
python3 generate_assets_v2.py --saldo      # confere o saldo
python3 generate_assets_v2.py --listar     # catálogo com custo em US$
python3 generate_assets_v2.py --tudo       # o catálogo inteiro (~US$ 0,81)
godot --headless --path reino-por-conquista-godot --import
```

O script para sozinho no HTTP 402 (sem saldo) para não desperdiçar chamadas.
