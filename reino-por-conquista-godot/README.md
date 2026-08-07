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
- **Sons** (`scripts/sfx.gd`): pacote RPG Essentials em `assets/audio/sfx/` (moedas,
  alerta, batalha, abas e modais) com fallback para o WAV gerado em código — apagar a
  pasta de áudio devolve os bipes, nunca quebra. Trilha da tela de título em loop
  (`assets/audio/musica_titulo.mp3`, fade ao entrar no jogo); créditos em
  `assets/audio/CREDITOS.md`
- **🧠 IA Local** (`scripts/llm.gd`): botão na Corte configura a URL do llama.cpp rodando
  no SEU processador; as falas dos NPCs passam a ser geradas pelo modelo GGUF, com
  fallback automático para o motor interno
- **Save/load** automático em JSON (`user://save.json`)
- **Presets de exportação** prontos: Windows .exe, Android .apk e Web (PWA)

### Sistema de luz e água — `scripts/atmosfera.gd` + `environment_manager.gd`

A vila é uma cena de referência estática; a vida em cima dela é 100% código:

- **`scripts/environment_manager.gd`** (autoload) — a HORA e a ESTAÇÃO do
  mundo viram cor de ambiente por `CanvasModulate`, POR VIEWPORT: a vila
  escurece à noite e esfria no inverno, a interface nunca. A hora vem do MÊS
  do jogo (inverno = dia curto), não do relógio de parede.
- **`scripts/atmosfera.gd`** — consome o gerente e acrescenta o que a arte
  não tem: **água viva** (shader por máscara — ondulação de brilho e
  cintilação de sol, sem nunca distorcer UV), **janelas que acendem** ao
  anoitecer (com compensação da tinta ambiente, para a luz EMITIR em vez de
  refletir), **fumaça de chaminé** em partículas (mais fumaça no inverno),
  **nuvens em parallax** geradas por semente, **haze** no horizonte, e
  **neve/folhas** por estação. A máscara de água nasce da própria arte em
  runtime: cor da paleta medida ∩ bbox medida — porque azul também mora em
  telhado, e cor sozinha não identifica água.
- **Engine configurada contra mixels**: `default_texture_filter = Nearest`
  e snapping 2D (ver `project.godot`).

Rodar os testes de cena:
```
godot --headless --path . res://tests/teste_cenas.tscn
```

> ⚠️ `teste_cenas.tscn` trava em containers de CI/cloud sem áudio/GPU reais
> (verificado: trava inclusive em commits antigos — não é regressão de
> código). As demais suítes (`--script res://tests/teste_*.gd` e
> `teste_barramento.tscn`) rodam headless normalmente; num desktop com
> editor o `teste_cenas` roda. Não caçar fantasma aqui.

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

## Fase 3 — auditoria visual, concluída

A tela era funcional e parecia protótipo. A auditoria foi feita sobre as
imagens renderizadas por `tests/render_ui.gd`, e o que ela mediu:

| defeito | medida |
|---|---|
| linha de mercado sem coluna: nome, preço e carga numa string só | **481px contíguos de vazio** numa linha de 910 — 53% |
| card com altura mínima de 56px + 10 de padding | **4 itens por tela** num mercado de 10 |
| retrato de toda pessoa do jogo | **caixote cinza** — reis, clãs, corte, conversa |
| gasto do cerco com formato `%d%d%d` | os três valores saíam colados: **"gasto 1285656"** |
| HUD sem terreno próprio | os números flutuavam sobre o fundo da janela |
| botão de ação esticado | "Conversar" com **830px** de largura |
| barra de abas | as duas últimas abas escondidas atrás de setas |

O que entrou: `tema.gd` reescrito como sistema, `kit.gd` novo, retratos
gerados, e as onze telas remontadas sobre os dois.

Ideias que continuam abertas:

- [ ] Animações de transição entre abas e nos modais
- [ ] Trilha sonora procedural (harpa/alaúde)
- [ ] Educação de herdeiros e eventos de assassino na UI
- [ ] Controles de toque dedicados no Android (gestos, haptics)
- [ ] Os dois ícones que faltam: `icone_pedra` e `icone_prata`

## Por que Godot (e não Unity)

- Gratuito, open-source, leve (~100 MB), excelente para 2D pixel art.
- GDScript é próximo do JS original — o port do núcleo foi 1:1.
- Exporta nativamente para Windows, Android, iOS e Web a partir de um único projeto.
- A versão web original (`../reino-por-conquista`) continua sendo a referência jogável
  enquanto a fase 2 avança.

## Sistema de design — `tema.gd` + `kit.gd`

A interface é construída inteiramente em código. Duas peças a sustentam:

| peça | o que é |
|---|---|
| `scripts/tema.gd` | o SISTEMA: paleta (umbra quente + latão), escala de espaço `E1..E6`, escala tipográfica, e as variantes de `StyleBox` (painel, card, linha de tabela, cabeçalho, chip, medidor, botão primário/fantasma/perigo) |
| `scripts/kit.gd` | os COMPONENTES: `tabela()`/`linha()` com colunas medidas, `medidor()`, `chip()`, `selo()`, `secao()`/`subsecao()`, `duas_colunas()`, `retrato()`, `ilustracao()` |

Regra da casa: **nenhum arquivo fora de `tema.gd` inventa um valor de espaço
ou uma cor.** Espaçamento vem de `Tema.E1..E6`; cor vem das constantes da
paleta. Foi a ausência dessa regra que produziu uma tela em que cada função
escolhia a sua própria margem.

Três decisões que valem para toda tela nova:

- **Número vive em COLUNA.** A monoespaçada (`Tema.fonte_numero()`) só
  alinha preço se houver coluna para alinhar — use `Kit.tabela()`, não uma
  string com `·` no meio.
- **Um primário por região.** `Kit.botao(..., "primario")` é latão
  preenchido e marca o verbo pelo qual aquela região existe. Os demais são
  `"fantasma"`; o irreversível é `"perigo"`.
- **Estado é medidor ou selo, não prosa.** Moral, felicidade, relação e
  fase de cerco são `Kit.medidor()`; "casus belli" e "a ferros" são
  `Kit.selo()`.

### Arte

Os PNG de ícone (`icone_*`), tropa (`tropa_*`), evento (`evento_*`) e
cenário (`estagio_*`) estão em `assets/sprites/` e são carregados
normalmente. Duas coisas nascem **geradas em código**, porque são
combinatórias e nunca poderiam ser arquivos:

- **Retratos de gente** (`scripts/retratos.gd`) — 64×64 desenhados pixel a
  pixel a partir de uma semente derivada do id (ou do nome, para os notáveis
  criados durante a partida). Pele, cabelo, barba, toucado e roupa saem da
  semente; a expressão sai da RELAÇÃO. `textura_pequena()` devolve a
  redução 2× por média de blocos, para lista e linha de tabela.
- **Ícone ausente** (`scripts/icones.gd`) — um losango na cor própria do
  item, em vez do caixote cinza. Dois dos 43 nomes de `TODOS` (`pedra` e
  `prata`) ainda não têm arquivo.

As dimensões da arte são constantes porque são elas que seguram o layout:
`UIv2.MARGENS` (9-slice), `Icones.LADO`, `Retratos.LADO_RETRATO`. Arte nova
tem que respeitar esses números, ou a cena se mexe.

```bash
# a verificação VISUAL: renderiza as 21 telas em PNG
xvfb-run godot --path reino-por-conquista-godot --rendering-driver opengl3 \
  --script res://tests/render_ui.gd
```

## Pipeline Hi-Bit

O que existe DE VERDADE no repositório (a versão anterior deste README
listava seis arquivos que nunca chegaram a entrar — `camera_mundo.gd`,
`ai_visual_bridge.gd`, `agente_movel.gd`, `visual_controller.gd`,
`shaders/`, `docs/PIPELINE_HIBIT.md` — e prometia uma ponte PixelLab que
não faz parte do projeto):

| peça | onde |
|---|---|
| ciclo de luz por `CanvasModulate`, hora × estação | `scripts/environment_manager.gd` (autoload) |
| água viva, janelas, fumaça, nuvens, haze, neve | `scripts/atmosfera.gd` |
| a vila em seis cenas de referência + escada de nível | `scripts/cenario_v3_cena.gd` / `_view.gd` |

```bash
godot --path reino-por-conquista-godot --script res://tests/teste_hibit.gd
```

