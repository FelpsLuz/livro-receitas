# Reino por Conquista — builds de teste

Branch de distribuição. Não tem código: só os binários e este aviso.

## Windows

**[ReinoPorConquista-teste-pc.zip](https://raw.githubusercontent.com/FelpsLuz/livro-receitas/apk-teste/ReinoPorConquista-teste-pc.zip)** (64 MB)

Extraia e rode `ReinoPorConquista.exe`. O SmartScreen avisa que o autor é
desconhecido — o executável ainda não é assinado. "Mais informações" →
"Executar assim mesmo". O `LEIA-ME.txt` dentro do zip diz o que testar.

**Apague o save antes de jogar.** A idade inicial mudou de 22 para 40–44, e
é justamente a nova escala de tempo que esta rodada existe para testar. Use
"Nova Saga", ou apague:

```
%APPDATA%\Godot\app_userdata\Reino por Conquista\save.json
```

Rodada: Blocos 3 a 6 (moedas vivas, o Aço, arcos de fim, crueldade como
eixo) mais os dentes do Aço, a escala de tempo da morte, as saídas da
catraca e o passe anti-exploit.

## Android

**[ReinoPorConquista-teste.apk](https://raw.githubusercontent.com/FelpsLuz/livro-receitas/apk-teste/ReinoPorConquista-teste.apk)** (58 MB)

Desatualizado — é da rodada do Bloco 1/2. Peça um APK novo se precisar.

---

O PCK destas builds **não** está criptografado: os templates oficiais do
Godot não carregam a chave do projeto, e um PCK cifrado sairia sem rodar.
Builds de loja levam a criptografia de volta.
