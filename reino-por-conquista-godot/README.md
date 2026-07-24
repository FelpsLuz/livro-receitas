# ⚔️ Reino por Conquista — port Godot 4.3

Port oficial do jogo para o motor **Godot 4.3** (gratuito e open-source).

## Estado atual: Fase 1 concluída ✅

Todo o **núcleo de sistemas** foi portado de JavaScript para GDScript e validado
por uma bateria de **34 testes automatizados** (rodando em Godot headless):

| Sistema | Arquivo | Testado |
|---|---|---|
| Dados do mundo (6 reinos, tropas, formações) | `scripts/dados.gd` | ✅ |
| Diálogo livre: intenção + sentimento + memória por tags | `scripts/dialogo.gd` | ✅ |
| Economia viva: oferta×demanda, guerra, fome, rebelião | `scripts/economia.gd` | ✅ |
| Combate tático por formações | `scripts/combate.gd` | ✅ |
| Clãs mercenários via mensageiros | `scripts/clas.gd` | ✅ |
| Intrigas, chantagem, casus belli, casamento | `scripts/intriga.gd` | ✅ |
| Turno mensal, dinastia, morte e herança | `scripts/jogo.gd` | ✅ |

Rodar os testes:
```
godot --headless --path . --script res://tests/teste_nucleo.gd
```

## Como abrir

1. Baixe o Godot 4.3+ em https://godotengine.org/download (≈100 MB, sem instalação).
2. Abra o Godot → **Import** → selecione a pasta `reino-por-conquista-godot`.
3. F5 roda a cena atual da fase 1 (demonstração do núcleo no console).

## Fase 2 — cenas visuais (roteiro)

- [ ] Tela de título + tema medieval (Theme com pergaminho/madeira, fonte pixel)
- [ ] Cidade em pixel art: portar `city.js` para desenho via `_draw()`/TileMap, com estações
- [ ] Retratos 64×64: portar `portraits.js` para `Image`/`ImageTexture` geradas em código
- [ ] Tela de conversa com "ponderar" + máquina de escrever (`Timer` + `RichTextLabel`)
- [ ] Abas de gestão (Mercado, Exército, Clãs, Intrigas, Família, Crônica) com `TabContainer`
- [ ] Sons via `AudioStreamGenerator` (port do sfx.js)
- [ ] Adaptador LLM local: `HTTPRequest` → llama.cpp (prompt já pronto em `dialogo.gd`)
- [ ] Presets de exportação: **Windows .exe, Android .apk, HTML5** (um projeto → todas as plataformas)

## Por que Godot (e não Unity)

- Gratuito, open-source, leve (~100 MB), excelente para 2D pixel art.
- GDScript é próximo do JS original — o port do núcleo foi 1:1.
- Exporta nativamente para Windows, Android, iOS e Web a partir de um único projeto.
- A versão web original (`../reino-por-conquista`) continua sendo a referência jogável
  enquanto a fase 2 avança.
