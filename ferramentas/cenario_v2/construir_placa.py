#!/usr/bin/env python3
"""CONSTRUIR A PLACA — artefato derivado, nunca mutado (addendum v3.5 §D).

    placa_origem.png          fonte imutável (saída da repintura por API),
                              nunca editada
      └── transformacoes.json lista ORDENADA e declarativa
            └── este script
                  └── placa_base.png   reconstruída do zero, toda vez

Por que trocar a mutação in-place por isto: idempotência deixa de ser um
selo que se pode esquecer de checar e vira propriedade grátis (sempre
reconstrói da origem); a ordem das transformações fica auditável; e uma
transformação nova é uma entrada na lista, não uma mutação nova com selo
novo. O bug que motivou: uma exceção entre o save e o selo deixou a placa
alterada e destravada, e a execução seguinte aplicou o deslocamento duas
vezes.

    python3 ferramentas/cenario_v2/construir_placa.py
    python3 ferramentas/cenario_v2/construir_placa.py --conferir
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
BASE = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario" / "base"
ORIGEM = BASE / "placa_origem.png"
RECEITA = BASE / "transformacoes.json"
DESTINO = BASE / "placa_base.png"

# Paleta da ROCHA, medida no miolo do maciço: 4 cores cobrem 94% dos pixels
# não-céu de lá. Nenhuma operação aqui faz média — só cópia (v3.5 §G).
#
# QUATRO ABORDAGENS QUE FALHARAM antes desta, cada uma de um jeito, e o
# registro fica para nenhuma delas voltar:
#   1. preencher o buraco com o vizinho de céu mais próximo na linha
#      → copiava a cor da borda: listra vertical;
#   2. preencher com a MEDIANA de "tudo que não é maciço"
#      → nas linhas baixas do fundo os pixels livres são árvore e serra,
#        não céu, e pintava uma faixa VERDE sobre a montanha;
#   3. preencher com a mediana só de pixels de céu
#      → a média de (175,233,241) com (185,231,241) dá (180,232,241), cor
#        que NÃO EXISTE na paleta, e virou uma linha de 1px atravessando o
#        maciço. É o princípio do v3.5 §B: toda média inventa cor;
#   4. máscara recortada numa janela de colunas
#      → costura vertical em x0/x1, porque as saias do maciço se fundem
#        com as serras laterais.
# A que funciona não preenche nada: cada pixel de rocha recebe o conteúdo
# de N linhas acima dele.
PALETA_ROCHA = ((220, 207, 145), (100, 164, 164), (147, 211, 191),
                (106, 195, 202))


def _mascara_rocha(img: np.ndarray, ate_y: int) -> np.ndarray:
    m = np.zeros(img.shape[:2], bool)
    for c in PALETA_ROCHA:
        m |= (img == np.array(c)).all(axis=2)
    m[ate_y:] = False
    # fechamento de 1px: tapa buraco de dither sem engordar a silhueta
    d = m.copy()
    d[1:, :] |= m[:-1, :]; d[:-1, :] |= m[1:, :]
    d[:, 1:] |= m[:, :-1]; d[:, :-1] |= m[:, 1:]
    e = d.copy()
    e[1:, :] &= d[:-1, :]; e[:-1, :] &= d[1:, :]
    e[:, 1:] &= d[:, :-1]; e[:, :-1] &= d[:, 1:]
    return e


def espelho_global(img: np.ndarray, **_) -> np.ndarray:
    """v3.2 §B: a auditoria mediu luz pela ESQUERDA em 4 bandas."""
    return img[:, ::-1].copy()


def descer_cordilheira(img: np.ndarray, px: int, nucleo: list,
                       extensao: list, ate_y: int = 104, **_) -> np.ndarray:
    """v3.4 §B + v3.5 §C: desce a cordilheira com RAMPA.

    Cada pixel de rocha recebe o conteúdo de N linhas acima dele — não se
    preenche nada e não se inventa cor, e a base fica contínua por
    construção (o pixel mais baixo do footprint recebe rocha de N linhas
    acima, também rocha).

    N varia por coluna: `px` cheio no NÚCLEO (o maciço, que precisa recuar
    para o castelo dominar) e afinando linearmente até 0 nas bordas da
    cordilheira. Deslocamento uniforme levava as serras laterais junto para
    trás da mata; recortar a máscara em colunas para poupá-las devolvia
    costura vertical. A rampa não tem costura por construção — o
    deslocamento é contínuo — e deixa as laterais na altura de origem.
    """
    fora = img.copy()
    m = _mascara_rocha(img, ate_y)
    x0, x1 = extensao
    n0, n1 = nucleo
    for x in range(img.shape[1]):
        if x < x0 or x > x1:
            continue
        if n0 <= x <= n1:
            desloc = px
        elif x < n0:
            desloc = round(px * (x - x0) / max(1, n0 - x0))
        else:
            desloc = round(px * (x1 - x) / max(1, x1 - n1))
        if desloc <= 0:
            continue
        ys = np.nonzero(m[:, x])[0]
        if len(ys) == 0:
            continue
        fora[ys, x] = img[np.maximum(0, ys - desloc), x]
    return fora


OPS = {"espelho_global": espelho_global,
       "descer_cordilheira": descer_cordilheira}


def extensao_macico() -> tuple[int, int]:
    """O núcleo do maciço, lido da RECEITA — quem deriva não redetecta.

    Detectar o maciço depois da transformação não funciona: o corte de
    crista que separava maciço (32..52) de serra lateral (60..73) deixa de
    separar quando o maciço passa a 52..72. A extensão é decisão declarada
    em transformacoes.json, e é de lá que ela vem.
    """
    for passo in json.loads(RECEITA.read_text()):
        if passo.get("op") == "descer_cordilheira" and passo.get("nucleo"):
            n = passo["nucleo"]
            if n[1] - n[0] > 40:            # o núcleo do maciço, não a ponta
                return int(n[0]), int(n[1])
    sys.exit("transformacoes.json sem descer_cordilheira do maciço")


def mascara_macico(faixa: np.ndarray, ate_y: int = 104):
    """Silhueta do maciço central + (x0, x1, cume_y, cume_x), na placa
    JÁ construída. Serve ao véu de recessão e ao critério de folga."""
    x0, x1 = extensao_macico()
    rocha = _mascara_rocha(faixa, ate_y)
    m = np.zeros_like(rocha)
    m[:, x0:x1 + 1] = rocha[:, x0:x1 + 1]
    crista = np.array([np.nonzero(m[:, x])[0].min() if m[:, x].any() else 999
                       for x in range(faixa.shape[1])])
    pico = x0 + int(np.argmin(crista[x0:x1 + 1]))
    return m, (x0, x1, int(crista[pico]), pico)


def construir(conferir: bool = False) -> np.ndarray:
    img = np.array(Image.open(ORIGEM).convert("RGB"))
    cores_origem = {tuple(c) for c in np.unique(img.reshape(-1, 3), axis=0)}
    receita = json.loads(RECEITA.read_text())
    for i, passo in enumerate(receita):
        op = passo.get("op")
        if op not in OPS:
            sys.exit(f"op desconhecida em transformacoes.json[{i}]: {op!r}")
        img = OPS[op](img, **{k: v for k, v in passo.items() if k != "op"})
        print(f"  {i + 1}. {op} {({k: v for k, v in passo.items() if k != 'op'})}")

    novas = {tuple(c) for c in np.unique(img.reshape(-1, 3), axis=0)} - cores_origem
    if novas:
        sys.exit(f"🛑 {len(novas)} cores fora da paleta de origem: {sorted(novas)[:4]}"
                 f" — alguma operação fez média (v3.5 §G proíbe)")
    print(f"  ✅ 0 cores novas ({len(cores_origem)} na origem)")

    if conferir:
        atual = np.array(Image.open(DESTINO).convert("RGB"))
        igual = np.array_equal(atual, img)
        print(f"  {'✅' if igual else '❌'} placa_base.png "
              f"{'confere' if igual else 'DIVERGE'} da receita")
        if not igual:
            sys.exit(1)
    else:
        Image.fromarray(img).save(DESTINO)
        print(f"  💾 {DESTINO.name} reconstruída do zero")
    return img


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--conferir", action="store_true",
                    help="não escreve: só verifica se a placa versionada "
                         "bate com a receita")
    construir(ap.parse_args().conferir)
