# Reino por Conquista — builds de teste

Baixe pelos links **raw**. O app do GitHub no celular intercepta links
`github.com/...` e abre o app em vez de baixar; o `raw.` baixa direto.

| build | link |
|---|---|
| **PC (Windows)** | [ReinoPorConquista-teste-pc.zip](https://raw.githubusercontent.com/FelpsLuz/livro-receitas/apk-teste/ReinoPorConquista-teste-pc.zip) |
| **Android** | [ReinoPorConquista-teste.apk](https://raw.githubusercontent.com/FelpsLuz/livro-receitas/apk-teste/ReinoPorConquista-teste.apk) |

---

## O PC é o build novo: Bloco 1 + Bloco 2

### O que fazer: exportar o CSV

O objetivo deste build é sair com **dado**, não com sensação.

1. Jogue uma partida qualquer. Não precisa jogar bem — precisa jogar
   **bastante**. Doze meses já dizem muita coisa; vinte e quatro dizem tudo.
2. Toda virada de mês abre o **Livro-Razão**: o que entrou e saiu, linha por
   linha, agrupado por moeda.
3. Nesse modal, o botão **"Exportar histórico (CSV)"** escreve a partida
   inteira — não só o mês.
4. O arquivo fica em
   `%APPDATA%\Godot\app_userdata\Reino por Conquista\livro_<seu_nome>.csv`
5. Me mande esse arquivo.

Uma linha por mês fechado: saldo de ouro, grão, madeira, moral, renome e
honra, mais cofre e efetivo. É com ele que o Bloco 3 nasce calibrado.

### O combate passou a existir

`tropas × moral × formação × aço por unidade` — três entradas suas onde
havia uma.

- **Formação**: os três botões da aba Tropas finalmente valem (±15%), e o
  relatório de batalha diz qual formação encontrou qual.
- **O espião virou arma de guerra**: revela em que formação o reino treina
  neste mês, e a informação vence na virada.
- **A Ferraria move o 0/3** — havia dois sistemas de equipamento; agora é um.
- **Pressão da vila**: acima de 70 os notáveis exigem, com escolha.

### O Livro-Razão

Passe o mouse sobre **"Fechar o mês" antes de clicar**: a dica mostra a conta
que a virada vai cobrar e pagar, e o cofre depois.

O que eu gostaria de saber: a previsão bateu? o relatório explica um mês
ruim, ou ainda falta linha? a formação mudou alguma batalha de forma
perceptível?

O SmartScreen vai avisar que o autor é desconhecido — o executável ainda não
é assinado. "Mais informações" → "Executar assim mesmo".

## Android

O APK é da rodada anterior (interface). Abre em **paisagem** — vire o
aparelho. Alvos de toque pequenos e dicas de mouse inalcançáveis são
conhecidos e esperados. Peça um APK novo quando quiser as mecânicas destes
dois blocos no celular.
