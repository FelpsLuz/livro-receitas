# ⚔️ Reino por Conquista — port Godot 4.3

Port oficial do jogo para o motor **Godot 4.3** (gratuito e open-source).

## Estado atual: Fases 1 e 2 concluídas ✅ (56 testes passando)

**Fase 2 — o jogo está jogável no Godot:** abra o projeto e aperte F5.

- **Tela de título** com a cidade-vitrine animada em pixel art
- **Cidade pixel art** (`scripts/cidade_view.gd`): 480×270 via `_draw()`, estações do ano
  (neve no inverno!), rio animado, moinho girando, muralhas, castelo, fumaça e NPCs passeando
- **Retratos 64×64** (`scripts/retratos.gd`): gerados pixel a pixel via `Image`, com humor
  que muda conforme a relação (raiva/neutro/simpatia)
- **Conversa viva**: o NPC "pondera..." (tempo proporcional à resposta) e **digita letra a
  letra**; entrada trava enquanto ele fala
- **10 abas de gestão**: Terra, Mapa, Mercado, Taverna, Corte, Exército, Clãs, Intrigas,
  Família e Crônica — todas funcionais
- **Modais**: rebelião, traição da guarda, relatório de batalha por rodadas, fim de jogo
- **Sons** (`scripts/sfx.gd`): moedas, tambor, fanfarras — WAV gerado em código, zero assets
- **🧠 IA Local** (`scripts/llm.gd`): botão na Corte configura a URL do llama.cpp rodando
  no SEU processador; as falas dos NPCs passam a ser geradas pelo modelo GGUF, com
  fallback automático para o motor interno
- **Save/load** automático em JSON (`user://save.json`)
- **Presets de exportação** prontos: Windows .exe, Android .apk e Web (PWA)

Rodar os testes de cena:
```
godot --headless --path . res://tests/teste_cenas.tscn
```

## Fase 1 concluída ✅

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

## Como exportar (no seu PC, com o editor Godot)

1. **Editor → Export...** → instale os *export templates* quando o Godot pedir (download único).
2. Escolha o preset (**Windows**, **Android** ou **Web** — já configurados em `export_presets.cfg`).
3. **Export Project** → o executável sai em `dist/`.
   - Windows: `ReinoPorConquista.exe` único (pck embutido).
   - Android: requer o Android SDK configurado no editor (Editor Settings → Export → Android).
   - Web: hospede a pasta `dist/web` em qualquer servidor estático (itch.io funciona).

## Fase 3 — ideias de polimento

- [ ] Fonte pixel medieval e ornamentos no tema
- [ ] Animações de transição entre abas e nos modais
- [ ] Trilha sonora procedural (harpa/alaúde)
- [ ] Educação de herdeiros e eventos de assassino na UI
- [ ] Controles de toque dedicados no Android (gestos, haptics)

## Por que Godot (e não Unity)

- Gratuito, open-source, leve (~100 MB), excelente para 2D pixel art.
- GDScript é próximo do JS original — o port do núcleo foi 1:1.
- Exporta nativamente para Windows, Android, iOS e Web a partir de um único projeto.
- A versão web original (`../reino-por-conquista`) continua sendo a referência jogável
  enquanto a fase 2 avança.
