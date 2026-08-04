# assets_v2 — assets Pro do PixelLab

Gerados por `generate_assets_v2.py` (raiz do repositório), organizados por tipo:

| pasta        | endpoint da API v2                | conteúdo                          |
| ------------ | --------------------------------- | --------------------------------- |
| `ui/`        | `POST /generate-ui-v2`            | molduras 9-slice, botões, barras  |
| `tilesets/`  | `POST /create-tileset` (modo pro) | terreno contínuo em atlas         |
| `objects/`   | `POST /map-objects`               | árvores, casas, baús, poços       |
| `characters/`| `POST /create-character-v3`       | personagem com 8 rotações         |

## Estado atual

Só `ui/painel_madeira.png` está gerado — a cota do trial (40 gerações) acabou
no meio do lote. O catálogo completo tem 18 assets.

## Custo medido na prática (a API não publica tabela)

| endpoint                | gerações por asset |
| ----------------------- | ------------------ |
| `create-image-pixflux`  | ~1                 |
| `generate-ui-v2` (Pro)  | ~10                |

Ou seja: os endpoints **Pro custam cerca de 10× um sprite comum**. Planeje a
recarga por aí — o catálogo inteiro em Pro passa de 100 gerações.

## Como continuar quando houver crédito

```bash
python3 generate_assets_v2.py --saldo     # confere a cota primeiro
python3 generate_assets_v2.py --listar    # catálogo e custo estimado
python3 generate_assets_v2.py --grupo objects   # o mais barato por impacto
python3 generate_assets_v2.py --grupo ui        # o mais caro, maior impacto visual
godot --headless --path reino-por-conquista-godot --import
```

O script para sozinho ao receber HTTP 402 (cota esgotada), para não desperdiçar
chamadas, e sempre imprime a cota restante ao terminar.
