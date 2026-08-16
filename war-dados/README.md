# Dados do War 🎲

App mobile para rolar os dados do jogo **War**: até 3 dados de ataque contra até 3 de defesa,
com apuração automática das baixas de cada lado.

É um PWA (HTML/CSS/JS puro, sem dependências e sem build): abre no navegador do celular,
pode ser instalado na tela inicial e funciona offline.

## O que faz

- **1 a 3 dados** de cada lado, escolhidos com um toque.
- **Rolagem animada** com vibração (nos aparelhos que suportam).
- **Apuração pela regra oficial**: os dados são ordenados do maior para o menor e comparados
  par a par — maior do ataque contra maior da defesa, e assim por diante. **Empate é vitória
  da defesa.** O vencedor de cada duelo aparece destacado em verde e o perdedor esmaecido.
- **Contador de tropas** opcional (botão "Tropas"): as baixas da rodada são descontadas
  automaticamente de cada exército.
- **Histórico** das últimas 12 rodadas.
- Quantidade de dados, tropas e histórico ficam salvos no aparelho.

## Como usar

Abra `index.html` em qualquer navegador. Para instalar no celular e usar offline, é preciso
servir por HTTP (o service worker não roda em `file://`):

```bash
cd war-dados
python3 -m http.server 8000
```

Acesse `http://<ip-do-computador>:8000` no celular e use "Adicionar à tela de início".

Para publicar, basta subir a pasta em qualquer hospedagem estática (GitHub Pages, Netlify,
Vercel) — não há passo de build.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| `index.html` | Estrutura da tela |
| `styles.css` | Visual mobile-first, tema escuro, dados desenhados em CSS |
| `app.js` | Sorteio, regras do War, tropas, histórico e persistência |
| `sw.js` | Service worker (cache para uso offline) |
| `manifest.webmanifest` | Metadados de instalação do PWA |
| `icons/` | Ícones do app |

## Detalhes de implementação

- O sorteio usa `crypto.getRandomValues` com descarte dos valores que causariam viés
  (só aproveita 0–251, ou seja, 42 faixas exatas de 6), com queda para `Math.random()`
  em navegadores antigos.
- Os dados são desenhados com uma grade CSS de 9 células; as bolinhas visíveis mudam
  conforme o atributo `data-value`, sem imagens.
- A animação respeita `prefers-reduced-motion`.
