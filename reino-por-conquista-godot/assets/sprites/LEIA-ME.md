# Sprites de personagem (PixelLab)

Esta pasta recebe os PNG gerados por `generate_assets.py` (na raiz do repositório).
Ela vem **vazia de propósito**: sem os arquivos, o jogo desenha os retratos
procedurais de sempre. Assim que um PNG aparece aqui, ele passa a ser usado
automaticamente — sem mexer em código.

## Como gerar

```bash
export PIXELLAB_SECRET="sua-chave"      # pixellab.ai → Account → API
python3 generate_assets.py --listar      # vê o elenco e os prompts
python3 generate_assets.py --simular     # testa o pipeline sem gastar crédito
python3 generate_assets.py --tudo        # gera os 18 sprites de verdade
```

Depois de gerar, importe uma vez no Godot (ou apenas abra o editor):

```bash
godot --headless --path reino-por-conquista-godot --import
```

## Como o jogo usa

- `scripts/retratos.gd` → `textura(id, humor)` carrega `res://assets/sprites/<id>.png`
  se existir; senão desenha o retrato procedural de reserva.
- `scripts/sprites_personagens.gd` → `criar_sprite(id)` devolve um `Sprite2D` pronto
  (filtro NEAREST, escala inteira) e `aplicar_em(no, id)` troca a arte de um nó existente.
- `cenas/galeria_sprites.tscn` mostra o elenco inteiro para conferência visual.

## Nomes de arquivo esperados

`rei_imperio`, `rei_touros`, `rei_alvorecer`, `rei_leoes`, `rei_aguias`, `rei_rosa`,
`taverneiro`, `capitao`, `espiao`,
`cla_lobos`, `cla_corvos`, `cla_estepe`, `cla_machados`,
`tropa_campones`, `tropa_lanceiro`, `tropa_arqueiro`, `tropa_cavaleiro`, `inimigo_bandido`
