# assets_v2 — vazio por decisão

O projeto está em **visual strip**: nenhuma arte é carregada. O que sobrou
aqui é `characters/animacoes.json`, que não é arte — é o manifesto que diz
quantos quadros tem cada caminhada e em que direções. É dele que
`PersonagensV2.quadros()` monta o `SpriteFrames`, e é por isso que o herói
continua com as 8 direções paradas e andando mesmo sem um pixel de imagem.

Toda textura do jogo vem de `scripts/arte.gd`. Ver a seção
"Visual strip" no README e `tests/teste_strip.gd`.
