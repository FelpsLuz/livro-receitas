# ⚔️ Reino por Conquista

*De mercenário sem nome a rei — se as intrigas, a fome e as adagas deixarem.*

Protótipo jogável, **100% offline**, feito em HTML5 + JavaScript puro (zero dependências, zero servidor). Roda em qualquer PC fraco: basta abrir o `index.html` num navegador.

## Como jogar

**Windows (mais fácil, sem instalar nada):** duplo clique em `ReinoPorConquista.bat` — abre em janela própria de aplicativo (usa o Edge/Chrome que já vem no Windows).

**Qualquer sistema:** duplo clique em `index.html`.

**Como aplicativo desktop de verdade (Electron):**
```
# requer Node.js (https://nodejs.org)
cd reino-por-conquista
npm install
npm start          # roda como aplicativo desktop
npm run dist       # gera o INSTALADOR Windows em dist/ (cria atalho na área de trabalho)
```

O progresso salva automaticamente a cada mês passado.

**Objetivo:** conquistar um trono e segurá-lo por 12 meses. **Derrota:** morrer sem herdeiro adulto, ou ter a cabeça cortada por uma rebelião.

## Os 5 pilares do design (e onde estão no código)

### 1. Diálogo livre com memória por tags — `js/dialogue.js`
Digite **o que quiser** para qualquer NPC (aba Corte ou Taverna). O motor offline detecta *intenção* (insulto, elogio, ameaça, suborno, pedido de casamento, chantagem, negociação de paz...) e *sentimento*, e o NPC responde conforme sua **personalidade** (orgulhoso, calculista, ganancioso, honrado, cruel, romântica).

Cada conversa atualiza **tags de memória** — `[Odiado: -50]`, `[InsultouRei ×2]`, `[Chantageado]` — que vazam para o mundo:
- Xingou o rei? Os **preços no reino dele sobem** para você e ele pode **mandar um assassino**.
- Elogios repetidos rendem cada vez menos (bajulação tem retorno decrescente; calculistas nem ligam).
- Tentou subornar um rei honrado? Relação despenca. Um ganancioso? Negócio fechado.

### 2. Economia viva — `js/economy.js`
- **Oferta × demanda por reino:** cada reino produz bem certas mercadorias (compre barato lá, venda caro onde falta).
- **Guerra queima campos:** o preço do trigo dispara nos reinos em conflito. Levar comida para lá tem ágio de contrabando de +30% — e 20% de chance de patrulha confiscar a carga.
- **Fadiga de guerra:** camponeses convocados não plantam. Convoque demais e a colheita despenca → fome → **rebelião com foices e tochas atrás da SUA cabeça**.
- **Exportar a comida do próprio povo** dá ouro rápido e revolta na mesma medida.

### 3. Jornada de mercenário a rei — `js/combat.js`
- **Contratos e renome:** escoltas, caça a bandidos, queimar vilas (paga bem, mancha a alma e a reputação). Renome desbloqueia terra (25⭐) e casamento real (40⭐).
- **Combate tático:** formações em pedra-papel-tesoura (Linha ≻ Cunha ≻ Envolvimento ≻ Linha), equipamento, moral e debandada. Baixas são permanentes — **cada soldado conta**.
- **Casus belli:** atacar sem reivindicação legal une os 6 reinos contra você. Forje documentos, fabrique intrigas, case-se... ou sobreviva a um assassino e use a adaga com selo real como prova.

### 4. Intrigas, família e traições — `js/intrigue.js`
- **Espionar → segredo → chantagem:** descubra que o rei desvia ouro e diga a ele, em conversa, *"sei o que você fez"*. Ele cede UMA exigência: ouro, **casamento forçado** ou casus belli. Mas passa a te odiar.
- **Dinastia:** filhos herdam atributos (média dos pais ± sorte) e recebem educação (marcial/cortesã/administrativa/sombras). Pais cruéis criam herdeiros mimados — e **vassalos conspiram contra herdeiros mimados** quando você morre.
- **Traição por ouro:** tesouro zerado → tropas desertam → sua guarda de elite pode ser comprada para **abrir os portões na calada da noite**.

### 5. Imersão visual — `js/city.js` + `js/sfx.js` + `css/style.css`
- **Interface diegética:** livro-razão de pergaminho no mercado, cartas com selo de cera na mesa de intrigas, mural de contratos na taverna.
- **Cidade em pixel art procedural (480×270)** que evolui com seus investimentos: acampamento mercenário → tendas → aldeia com paliçada → vila com moinho de pás girando → burgo murado → cidade com torres e estandartes tremulando → castelo com torre de menagem.
- **Estações do ano**: primavera, verão dourado, outono alaranjado e inverno com neve nos telhados — a paisagem muda conforme os meses passam.
- **Vida na cena**: fumaça subindo das chaminés, bando de pássaros cruzando o céu, rio com correnteza, NPCs de capuz e túnica passeando (e parando para conversar), guardas no portão.
- **Efeitos sonoros** gerados por WebAudio (zero arquivos): moedas, espadas, tambor de batalha, fanfarra de vitória. Botão 🔊/🔇 no rodapé.

## Plugando uma IA local de verdade (GGUF)

O motor de diálogo interno funciona 100% offline e é a *fonte da verdade* das mecânicas (intenções, tags, consequências). Um LLM local pode assumir só a **superfície do texto** dos NPCs, mantendo as tags como memória:

1. Baixe um modelo pequeno quantizado (ex.: Qwen2.5-1.5B-Instruct Q4_K_M, ~1 GB, roda em CPU).
2. Rode o servidor do [llama.cpp](https://github.com/ggml-org/llama.cpp):
   ```
   ./llama-server -m qwen2.5-1.5b-instruct-q4_k_m.gguf --port 8080
   ```
3. No console do navegador (ou num script próprio):
   ```js
   Dialogo.llmAdapter = async (prompt) => {
     const r = await fetch('http://localhost:8080/completion', {
       method: 'POST', headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({ prompt, n_predict: 120, temperature: 0.8 }),
     });
     return (await r.json()).content;
   };
   ```
O jogo monta o prompt com personalidade, relação atual e memória de tags (`montarPromptLLM`), e usa a resposta gerada no lugar do template. Se o servidor não estiver rodando, o motor interno responde — o jogo **nunca depende** do LLM.

Para empacotar como jogo desktop de verdade: Electron/Tauri + [node-llama-cpp](https://github.com/withcatai/node-llama-cpp) embutindo o `.gguf` nos assets.

## Estrutura

```
reino-por-conquista/
├── index.html             # telas e carregamento
├── ReinoPorConquista.bat  # atalho Windows: abre como aplicativo (Edge/Chrome)
├── package.json           # app Electron: npm start / npm run dist (instalador)
├── electron-main.js       # janela desktop do Electron
├── css/style.css          # UI diegética (pergaminho, madeira, selos)
└── js/
    ├── data.js       # 6 reinos, NPCs, mercadorias, tropas, formações
    ├── sfx.js        # efeitos sonoros WebAudio (moedas, espadas, fanfarras)
    ├── dialogue.js   # motor de diálogo livre + memória por tags + adaptador LLM
    ├── economy.js    # mercados, guerras, colheita, fome, deserção
    ├── combat.js     # batalhas táticas + contratos e renome
    ├── intrigue.js   # segredos, chantagem, casus belli, dinastia, assassinos
    ├── city.js       # pixel art 480×270: estações, enxaimel, castelo, NPCs
    ├── game.js       # estado, turno mensal, morte/herança, save/load
    └── ui.js         # abas, conversa, modais, relatórios de batalha
```
