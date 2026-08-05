#!/usr/bin/env python3
"""
REQUANTIZAR — força TODA a arte do jogo a viver dentro de uma paleta só.

O problema que isto resolve
---------------------------
Cada ativo foi gerado numa chamada independente da API. Modelo de pixel art sem
referência travada inventa um estilo por prompt — sempre. O resultado medido no
repositório: um tile de chão com milhares de cores e saturação de jogo em Flash,
ao lado de um retrato com algumas dezenas de cores e saturação de metade disso.
Não é "estilo diferente": é uma camada que é pixel art de verdade e outra que é
uma imagem raster reamostrada fingindo ser.

O que a ferramenta faz
----------------------
1. `--medir`     — tabula cores únicas, saturação e pixels órfãos de cada PNG.
                   Diagnóstico antes de tocar em nada.
2. `--aplicar`   — mapeia cada pixel para a cor da paleta, em OKLab (distância
                   perceptual, não euclidiana em RGB — RGB erra feio em verdes e
                   em tons de pele), SOB RESTRIÇÃO DE ORDEM: se o pixel A era
                   mais escuro que B no original, continua mais escuro depois.
3. `--orfaos`    — apaga o "confete": pixel cuja cor não aparece em NENHUM dos 8
                   vizinhos vira a cor dominante da vizinhança. É o que remove a
                   estática de pixels soltos laranja/cinza no meio da grama.
4. `--conferir-ordem` — regra fixa, testável: a água tem que ser mais escura que
                   a areia. Sai com código 1 se falhar.

Nunca faz dithering. Dithering é ruído com nome bonito, e o relatório de
auditoria apontou exatamente isso como um dos defeitos das ilustrações.

Por que a escolha é monotônica (e não o vizinho mais próximo)
-------------------------------------------------------------
Medido neste repositório, com o vizinho mais próximo livre em OKLab: 9,74% dos
pares de cores (ponderados por pixel) saíam com a ORDEM DE LUMINÂNCIA INVERTIDA
em relação ao original, e 16,04% saíam achatados no mesmo tom. Pior asset:
33,45% de inversão. A faixa global quase não se movia (−3,9% em média) — o que
quebrava não eram as pontas, era o MIOLO. Sombra virava luz dentro do mesmo
objeto, e o volume sumia.

A causa é que OKLab pesa L, a e b igual. Uma cor saturada aceita andar 8 pontos
de L* para economizar 8 pontos de croma, porque a distância não sabe que L*
carrega a leitura da forma e croma não.

A correção aqui NÃO é escolher cor por cor com um viés. É resolver o asset
INTEIRO de uma vez, com programação dinâmica exata (ver `mapear_monotonico`).

Segurança
---------
Sempre grava um espelho do original em `.original/` antes da primeira alteração,
e nunca sobrescreve um espelho já existente — então rodar duas vezes não degrada
a arte em cascata. `--restaurar` desfaz tudo.

Uso
---
    python3 ferramentas/requantizar.py --medir
    python3 ferramentas/requantizar.py --aplicar --paleta ferramentas/paleta.hex
    python3 ferramentas/requantizar.py --aplicar --orfaos --so assets_v2/tilesets
    python3 ferramentas/requantizar.py --conferir-ordem
    python3 ferramentas/requantizar.py --restaurar
"""

from __future__ import annotations

import argparse
import colorsys
import shutil
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
PROJETO = RAIZ / "reino-por-conquista-godot"
PASTAS = [
    "assets/sprites",
    "assets_v2/icons",
    "assets_v2/ui",
    "assets_v2/tilesets",
    "assets_v2/objects",
    "assets_v2/characters",
    "assets_v2/vfx",
]
ESPELHO = PROJETO / ".original"

# Largura do degrau de luminância de ORIGEM, em L*. Duas cores dentro do mesmo
# degrau não têm ordem entre si — abaixo de ~1 JND, "mais escuro" é ruído do
# gerador, não intenção. Forçar ordem aí inventaria uma restrição falsa.
NIVEL_L = 1.5

# Tolerância para agrupar cores da PALETA no mesmo tom. Com 1,5 as 48 cores
# viram 27 baldes de no máximo 5 membros: dentro de um balde a escolha é só de
# matiz, e o erro de ordem residual é limitado a 1,5 L* por construção.
BALDE_L = 1.5

# Quanto o erro de TOM pesa contra o erro de matiz na distância OKLab.
# Calibrado por varredura, não por gosto (números na tabela abaixo, medidos
# sobre os 87 assets de tilesets/ e objects/ contra o espelho .original/):
#
#   PESO_L   inversão   achatamento   Δfaixa    pior asset   acima de 15%
#     livre     1,29%        11,07%    −3,01%      −45,4%          1
#      2,0      0,32%        11,74%    −4,79%      −61,0%          1
#      4,0      0,30%         8,34%    −2,27%      −23,8%          1
#      8,0      0,19%         7,93%    −1,31%      −14,9%          0   ← aqui
#     12,0      0,07%         8,61%    −1,31%      −14,9%          0
#     20,0      0,03%         9,43%    −0,86%      −14,9%          0
#
# Acima de 8 a inversão ainda cai, mas o achatamento volta a subir e o erro de
# matiz cresce sem comprar faixa nenhuma: de 8 para 20 o erro em (a,b) sobe de
# 0,045 para 0,052 e a faixa melhora 0,45 ponto. 8,0 é onde a curva vira.
#
# O custo do peso alto é matiz: erro em (a,b) sobe de 0,028 para 0,045, e o
# erro em L cai de 0,026 para 0,012. Para pixel art essa é a troca certa —
# valor carrega a leitura da forma, matiz não. E a pré-compressão de croma
# (`suavizar_croma`) já resolve o desvio de matiz que de fato incomodava.
PESO_L = 8.0


# ------------------------------------------------------------------
# OKLab — o espaço em que "parecido" quer dizer parecido para o olho
# ------------------------------------------------------------------
def _srgb_para_linear(c: np.ndarray) -> np.ndarray:
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def para_oklab(rgb: np.ndarray) -> np.ndarray:
    """rgb: (..., 3) uint8 → (..., 3) float em OKLab."""
    lin = _srgb_para_linear(rgb.astype(np.float64))
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    ], axis=-1)


def lstar(rgb: np.ndarray) -> np.ndarray:
    """rgb: (..., 3) uint8 → L* do CIELAB, 0 (preto) a 100 (branco).

    Não uso o L do OKLab aqui de propósito. O que se mede e se promete ao
    usuário é "claridade", e L* é a escala em que 1 unidade ≈ 1 JND em toda a
    faixa. Os números do relatório precisam ser comparáveis entre assets.
    """
    lin = _srgb_para_linear(rgb.astype(np.float64))
    y = 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]
    return np.where(y > 0.008856, 116.0 * np.cbrt(y) - 16.0, 903.3 * y)


def faixa_luminancia(arr: np.ndarray) -> dict:
    """Mín / máx / faixa / desvio de L* dos pixels OPACOS. Passo (a) do plano."""
    op = arr[arr[..., 3] > 10][:, :3] if arr.ndim == 3 else arr
    if op.size == 0:
        return {"min": 0.0, "max": 0.0, "faixa": 0.0, "dp": 0.0, "med": 0.0}
    lum = lstar(op)
    return {
        "min": float(lum.min()), "max": float(lum.max()),
        "faixa": float(lum.max() - lum.min()),
        "dp": float(lum.std()), "med": float(lum.mean()),
    }


def baldes_paleta(pal: np.ndarray, tol: float = BALDE_L) -> list[np.ndarray]:
    """Agrupa a paleta em TONS: faixas de L* estreitas, em ordem crescente.

    Dentro de um balde as cores têm praticamente a mesma claridade e diferem
    só em matiz — então a escolha de matiz não pode inverter nada. Entre
    baldes existe ordem de verdade, e é essa ordem que a DP respeita.
    """
    lum = lstar(pal)
    ordem = np.argsort(lum, kind="stable")
    grupos: list[list[int]] = []
    base = -1e9
    for k in ordem:
        if lum[k] - base > tol:
            grupos.append([int(k)])
            base = float(lum[k])
        else:
            grupos[-1].append(int(k))
    return [np.array(g, dtype=np.int64) for g in grupos]


def ler_paleta(caminho: Path) -> np.ndarray:
    """Lê um .hex do Lospec (um RRGGBB por linha, '#' opcional, '//' comenta)."""
    cores = []
    for linha in caminho.read_text(encoding="utf-8").splitlines():
        linha = linha.split("//")[0].split("#!")[0].strip().lstrip("#")
        if len(linha) < 6:
            continue
        token = linha.split()[0].lstrip("#")
        if len(token) != 6:
            continue
        try:
            cores.append(tuple(int(token[i:i + 2], 16) for i in (0, 2, 4)))
        except ValueError:
            continue
    if not cores:
        raise SystemExit(f"paleta vazia ou ilegível: {caminho}")
    return np.array(cores, dtype=np.uint8)


# ------------------------------------------------------------------
# medição
# ------------------------------------------------------------------
def _orfaos(arr: np.ndarray) -> int:
    """Pixels cuja cor não aparece em nenhum dos 8 vizinhos."""
    h, w = arr.shape[:2]
    if h < 3 or w < 3:
        return 0
    chave = (arr[..., 0].astype(np.int64) << 16) | \
            (arr[..., 1].astype(np.int64) << 8) | arr[..., 2].astype(np.int64)
    opaco = arr[..., 3] > 10
    solitario = np.ones((h - 2, w - 2), dtype=bool)
    centro = chave[1:-1, 1:-1]
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            viz = chave[1 + dy:h - 1 + dy, 1 + dx:w - 1 + dx]
            solitario &= (viz != centro)
    return int((solitario & opaco[1:-1, 1:-1]).sum())


def medir(png: Path) -> dict:
    arr = np.array(Image.open(png).convert("RGBA"))
    op = arr[arr[..., 3] > 10]
    if op.size == 0:
        return {"arquivo": png, "cores": 0, "sat_med": 0.0, "sat_max": 0.0,
                "v_med": 0.0, "orfaos": 0, "px": 0}
    cores = {tuple(c) for c in op[:, :3]}
    hsv = np.array([colorsys.rgb_to_hsv(*(c / 255.0)) for c in op[:, :3]])
    return {
        "arquivo": png,
        "cores": len(cores),
        "sat_med": float(hsv[:, 1].mean()),
        "sat_max": float(hsv[:, 1].max()),
        "v_med": float(hsv[:, 2].mean()),
        "orfaos": _orfaos(arr),
        "px": int(op.shape[0]),
    }


# ------------------------------------------------------------------
# aplicação
# ------------------------------------------------------------------
def suavizar_croma(arr: np.ndarray) -> np.ndarray:
    """Puxa o croma para dentro da faixa da paleta ANTES de encaixar nela.

    Sem este passo o encaixe erra o matiz em vez de errar o brilho. O verde de
    grama do projeto (#73C31F, S84% V76%) não tinha vizinho verde igualmente
    claro na paleta, e a cor mais próxima em OKLab virava AREIA — a grama do
    jogo inteiro ficava bege. Comprimindo a saturação primeiro, o pixel chega
    ao encaixe já perto da família certa, e aí a decisão é só de tom.

    Matiz e valor são preservados; só a saturação encolhe.
    """
    rgb = arr[..., :3].astype(np.float64) / 255.0
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    dif = mx - mn
    s = np.divide(dif, mx, out=np.zeros_like(mx), where=mx > 0)
    # escuro pode carregar mais saturação sem gritar; claro não pode
    teto = np.where(mx >= 0.45, 0.55, 0.62)
    fator = np.divide(teto, s, out=np.ones_like(s), where=s > teto)
    fator = np.minimum(fator, 1.0)
    # encolher a saturação = aproximar cada canal do máximo, mantendo mx (=V)
    novo = mx[..., None] - (mx[..., None] - rgb) * fator[..., None]
    saida = arr.copy()
    saida[..., :3] = np.clip(np.rint(novo * 255.0), 0, 255).astype(np.uint8)
    return saida


def mapear(arr: np.ndarray, pal: np.ndarray, pal_lab: np.ndarray) -> np.ndarray:
    """Cada pixel opaco vira a cor da paleta mais próxima em OKLab."""
    h, w = arr.shape[:2]
    rgb = arr[..., :3].reshape(-1, 3)
    alfa = arr[..., 3].reshape(-1)
    # só resolve as cores DISTINTAS: um tile de 32×32 com 900 cores custa 900
    # comparações, não 1024 — e um sprite grande com poucas cores fica de graça
    unicas, inverso = np.unique(rgb, axis=0, return_inverse=True)
    lab = para_oklab(unicas)
    d = ((lab[:, None, :] - pal_lab[None, :, :]) ** 2).sum(axis=2)
    escolha = pal[d.argmin(axis=1)]
    saida = escolha[inverso]
    saida = np.where(alfa[:, None] > 10, saida, rgb)     # transparente não muda
    return np.concatenate([saida, alfa[:, None]], axis=1) \
             .reshape(h, w, 4).astype(np.uint8)


def travar_familia(arr: np.ndarray) -> np.ndarray:
    """Puxa o AZUL para dentro da faixa de luminância que a paleta reserva a ele.

    A restrição de ordem resolve o dentro-do-asset; ela não sabe nada sobre a
    relação ENTRE assets. O tile de água nasceu com ciano em L*87 — mais claro
    que a areia (L*67) e que a própria grama. A paleta, por decisão de design,
    não tem azul acima de L*61 justamente porque a regra é "água mais escura
    que areia". Sem este passo o encaixe faz a única coisa que pode: troca o
    matiz e devolve creme.

    Aqui o pixel azul é REBAIXADO antes de escolher a cor, preservando a ordem
    relativa dentro da própria água. Matiz e saturação ficam; só a claridade
    encolhe, e ela encolhe para caber num lugar que existe.
    """
    rgb = arr[..., :3].astype(np.float64) / 255.0
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    dif = mx - mn
    sat = np.divide(dif, mx, out=np.zeros_like(mx), where=mx > 0)
    # matiz só para saber QUEM é azul; o cálculo é o padrão de HSV
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    seg = (dif > 1e-6)
    h = np.where(seg & (mx == r), ((g - b) / np.where(dif == 0, 1, dif)) % 6, h)
    h = np.where(seg & (mx == g), (b - r) / np.where(dif == 0, 1, dif) + 2, h)
    h = np.where(seg & (mx == b), (r - g) / np.where(dif == 0, 1, dif) + 4, h)
    graus = (h * 60.0) % 360.0
    # azul-ciano com saturação de verdade — céu, rio, mar. Cinza-azulado de
    # pedra tem saturação baixa e fica de fora de propósito.
    azul = (graus >= 165.0) & (graus <= 255.0) & (sat >= 0.20)
    if not azul.any():
        return arr
    lum = lstar(arr[..., :3])
    TETO = 61.0                      # o azul mais claro da paleta
    alto = azul & (lum > TETO)
    if not alto.any():
        return arr
    # compressão linear da faixa acima do teto, para não achatar tudo num tom
    pico = float(lum[alto].max())
    fator = np.ones_like(lum)
    escala = TETO / pico
    fator = np.where(alto, escala, 1.0)
    saida = arr.copy()
    saida[..., :3] = np.clip(np.rint(arr[..., :3] * fator[..., None]), 0, 255) \
                       .astype(np.uint8)
    return saida


def mapear_monotonico(arr: np.ndarray, ref: np.ndarray, pal: np.ndarray,
                      pal_lab: np.ndarray, baldes: list[np.ndarray],
                      peso_l: float = PESO_L) -> np.ndarray:
    """Encaixa na paleta PRESERVANDO A ORDEM DE LUMINÂNCIA do original.

    `arr` é o array já com o croma comprimido (é dele que sai a cor).
    `ref` é o array ORIGINAL, antes da compressão (é dele que sai a ORDEM —
    a compressão de croma mexe um pouco no L*, e quem manda na ordem é a
    intenção do desenho, não um efeito colateral do passo anterior).

    Como funciona
    -------------
    1. Cores distintas do asset, com peso = quantos pixels cada uma cobre.
    2. Cada cor cai num DEGRAU de luminância de origem (`NIVEL_L`). Cores no
       mesmo degrau não têm ordem entre si.
    3. Programação dinâmica escolhe UM balde de tom da paleta por degrau,
       minimizando  (erro de cor)  +  PESO_PASSO · (distorção do degrau),
       sob a restrição de que o índice do balde nunca decresce enquanto o
       degrau sobe. A restrição impede sombra virar luz; o segundo termo
       impede que ela seja obedecida do jeito preguiçoso, empatando tudo no
       mesmo tom — "não decrescer" é satisfeito por uma constante.
    4. Dentro do balde escolhido, cada cor pega o matiz mais próximo em OKLab.

    Por que DP e não o guloso sugerido
    ----------------------------------
    O guloso ("vai subindo o índice conforme precisa") é ordem-dependente e
    cascateia: uma escolha ruim no degrau mais escuro trava o piso de todos os
    degraus acima dele e arrasta o asset inteiro para o claro, sem volta. A DP
    aqui é EXATA — minimiza o custo total ponderado por pixel sobre todas as
    atribuições monotônicas — e custa nada: 27 baldes × ~60 degraus.

    Também não uso o índice da cor: uso o índice do BALDE. Ordenar as 48 cores
    da paleta uma a uma por L* criaria ordem entre cores que têm a MESMA
    claridade e só diferem em matiz (o azul #445e8a e o marrom #7a5838 estão a
    0,6 L* um do outro). Forçar "o azul tem que vir antes do marrom" é uma
    restrição inventada, e ela custa matiz sem comprar contraste nenhum.

    O que foi tentado e MEDIDO COMO PIOR (não repetir)
    --------------------------------------------------
    Somar ao custo da DP um termo que penalizasse a diferença entre o degrau
    de entrada e o degrau de saída, para atacar o achatamento diretamente.
    Piorou justo o que era para melhorar: achatamento 11,7% → 14,3% e Δfaixa
    −4,8% → −6,1%, com peso 1,2. A razão é que quando a paleta não tem o passo
    pedido, o termo é pago de qualquer jeito, e a DP paga onde é mais barato —
    juntando OUTROS degraus. Objetivo mal-condicionado. O achatamento cede a
    PESO_L, não a um termo próprio: subir PESO_L de 2 para 8 levou o mesmo
    número de 11,7% para 7,9%.
    """
    h, w = arr.shape[:2]
    rgb = arr[..., :3].reshape(-1, 3)
    alfa = arr[..., 3].reshape(-1)
    op = alfa > 10
    if not op.any():
        return arr.copy()

    unicas, inverso, contagem = np.unique(
        rgb[op], axis=0, return_inverse=True, return_counts=True)
    inverso = inverso.reshape(-1)
    n = len(unicas)

    # L* de referência de cada cor única = média do L* ORIGINAL dos pixels que
    # caíram nela. Se duas cores originais colapsaram numa só na compressão de
    # croma, já não há ordem a preservar entre elas — a média é o resumo certo.
    lum_px = lstar(ref[..., :3].reshape(-1, 3)[op])
    lum_ref = np.zeros(n, dtype=np.float64)
    np.add.at(lum_ref, inverso, lum_px)
    lum_ref /= contagem

    degrau = np.floor(lum_ref / NIVEL_L).astype(np.int64)
    niveis = np.unique(degrau)
    idx_nivel = np.searchsorted(niveis, degrau)
    k_niveis, n_baldes = len(niveis), len(baldes)

    # distância OKLab com o eixo L pesado: errar o TOM custa mais que o matiz
    lab = para_oklab(unicas)
    dif = lab[:, None, :] - pal_lab[None, :, :]
    dist = peso_l * dif[..., 0] ** 2 + dif[..., 1] ** 2 + dif[..., 2] ** 2

    # melhor cor dentro de cada balde, por cor de origem; e o custo do degrau
    melhor = np.zeros((n, n_baldes), dtype=np.int64)
    custo = np.zeros((k_niveis, n_baldes), dtype=np.float64)
    linhas = np.arange(n)
    for b, membros in enumerate(baldes):
        sub = dist[:, membros]
        j = sub.argmin(axis=1)
        melhor[:, b] = membros[j]
        np.add.at(custo, (idx_nivel, np.full(n, b, dtype=np.int64)),
                  sub[linhas, j] * contagem)

    # DP: dp[b] = custo mínimo de resolver os degraus até aqui terminando em b.
    # A transição de b' para b só é legal se b >= b' — é aí que mora a
    # monotonicidade —, e como toda transição legal custa o mesmo (zero), o
    # mínimo sobre b' <= b é só um mínimo de prefixo. O(degraus × baldes).
    dp = custo[0].copy()
    veio_de = np.zeros((k_niveis, n_baldes), dtype=np.int64)
    passos = np.arange(n_baldes)
    for k in range(1, k_niveis):
        corrida = np.minimum.accumulate(dp)
        # índice do PRIMEIRO balde que atinge o mínimo do prefixo — empatar
        # para o balde mais escuro deixa mais espaço para os degraus de cima
        novo = np.concatenate(([True], corrida[1:] < corrida[:-1]))
        veio_de[k] = np.maximum.accumulate(np.where(novo, passos, -1))
        dp = custo[k] + corrida

    escolhido = np.zeros(k_niveis, dtype=np.int64)
    escolhido[-1] = int(np.argmin(dp))
    for k in range(k_niveis - 1, 0, -1):
        escolhido[k - 1] = veio_de[k][escolhido[k]]

    cor = pal[melhor[linhas, escolhido[idx_nivel]]]
    saida = rgb.copy()
    saida[op] = cor[inverso]
    return np.concatenate([saida, alfa[:, None]], axis=1) \
             .reshape(h, w, 4).astype(np.uint8)


# Um pixel que é mais escuro (ou mais claro) que TODOS os 8 vizinhos por esta
# margem em L* não é confete: é sombra ou brilho desenhado de propósito.
MARGEM_ACENTO = 6.0


def limpar_orfaos(arr: np.ndarray) -> tuple[np.ndarray, int]:
    """Pixel isolado vira a cor dominante dos 8 vizinhos opacos.

    Menos os ACENTOS. Confete e brilho são a mesma coisa para um contador de
    vizinhos — os dois são um pixel de cor única —, e a versão anterior comia
    os dois. Medido: com a limpeza cega, `praia_agua_14` perdia 23,6% da faixa
    de L* contra 13,0% sem ela; o que sumia era o fundo escuro do rio, pixel a
    pixel. A distinção que separa os dois casos é o EIXO em que o pixel destoa:
    confete destoa em matiz e fica dentro da faixa de luminância da vizinhança;
    sombra e brilho destoam justamente em luminância, para fora dela.
    """
    h, w = arr.shape[:2]
    if h < 3 or w < 3:
        return arr, 0
    lum = lstar(arr[..., :3])
    saida = arr.copy()
    trocas = 0
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if arr[y, x, 3] <= 10:
                continue
            atual = tuple(arr[y, x, :3])
            viz, viz_lum = [], []
            igual = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    p = arr[y + dy, x + dx]
                    if p[3] <= 10:
                        continue
                    viz.append(tuple(p[:3]))
                    viz_lum.append(lum[y + dy, x + dx])
                    if viz[-1] == atual:
                        igual = True
            if igual or len(viz) < 5:
                continue
            eu = lum[y, x]
            if eu < min(viz_lum) - MARGEM_ACENTO or eu > max(viz_lum) + MARGEM_ACENTO:
                continue      # acento de sombra ou de brilho: preservar
            saida[y, x, :3] = Counter(viz).most_common(1)[0][0]
            trocas += 1
    return saida, trocas


# ------------------------------------------------------------------
# regra fixa: a água é mais escura que a areia
# ------------------------------------------------------------------
def _matiz_sat(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """HSV vetorizado — matiz em graus, saturação 0..1."""
    r = rgb.astype(np.float64) / 255.0
    mx, mn = r.max(axis=-1), r.min(axis=-1)
    d = mx - mn
    vermelho, verde, azul = r[..., 0], r[..., 1], r[..., 2]
    h = np.zeros_like(mx)
    tem = d > 1e-9
    sel = (mx == vermelho) & tem
    h[sel] = ((verde[sel] - azul[sel]) / d[sel]) % 6.0
    sel = (mx == verde) & tem
    h[sel] = (azul[sel] - vermelho[sel]) / d[sel] + 2.0
    sel = (mx == azul) & tem
    h[sel] = (vermelho[sel] - verde[sel]) / d[sel] + 4.0
    return h * 60.0, np.divide(d, mx, out=np.zeros_like(mx), where=mx > 0)


# faixas de matiz que definem cada material, em graus
MATERIAIS = {
    "agua":  (165.0, 260.0, 0.12),   # azul-ciano, saturação mínima
    "areia": (20.0, 70.0, 0.10),     # amarelo-laranja
}


def amostrar(arquivos: list[Path], material: str) -> np.ndarray:
    """Todos os L* dos pixels de um material, nos arquivos dados."""
    lo, hi, smin = MATERIAIS[material]
    tudo = []
    for png in arquivos:
        if not png.exists():
            continue
        arr = np.array(Image.open(png).convert("RGBA"))
        op = arr[arr[..., 3] > 10][:, :3]
        if op.size == 0:
            continue
        h, s = _matiz_sat(op)
        sel = (h >= lo) & (h <= hi) & (s > smin)
        if sel.any():
            tudo.append(lstar(op[sel]))
    return np.concatenate(tudo) if tudo else np.array([])


def conferir_ordem(verbose: bool = True) -> bool:
    """REGRA FIXA E TESTÁVEL: a água tem que ser mais escura que a areia.

    Mede o L* médio dos pixels azuis (água) e dos pixels amarelo-alaranjados
    (areia) do tileset `praia_agua`, que é o único asset onde os dois materiais
    aparecem lado a lado e sob a mesma luz — comparar a água de um tile com a
    areia de outro compararia iluminações diferentes e não provaria nada.

    Passa se a água for pelo menos MARGEM L* mais escura. A margem existe para
    que "passou" queira dizer "dá para ver", não "ganhou no terceiro decimal".
    """
    MARGEM = 4.0
    praia = sorted((PROJETO / "assets_v2" / "tilesets").glob("praia_agua*.png"))
    if not praia:
        print("⚠️  sem tiles praia_agua — nada a conferir")
        return True

    agua = amostrar(praia, "agua")
    areia = amostrar(praia, "areia")
    if agua.size == 0 or areia.size == 0:
        print(f"⚠️  amostra insuficiente (água {agua.size} px, areia {areia.size} px)")
        return False

    delta = float(agua.mean() - areia.mean())
    passou = delta <= -MARGEM
    if verbose:
        print(f"\n── REGRA: água mais escura que areia " + "─" * 34)
        print(f"  {len(praia)} tiles praia_agua")
        print(f"  ÁGUA   L* médio {agua.mean():5.1f}  "
              f"(mín {agua.min():5.1f}  máx {agua.max():5.1f})  {agua.size:6} px")
        print(f"  AREIA  L* médio {areia.mean():5.1f}  "
              f"(mín {areia.min():5.1f}  máx {areia.max():5.1f})  {areia.size:6} px")
        print(f"  delta água−areia = {delta:+.1f} L*   (exigido ≤ −{MARGEM:.0f})")
        print(f"  {'✅ PASSOU' if passou else '❌ FALHOU — água clara demais'}")
    return passou


def conferir_faixa(limite_pct: float = 15.0, verbose: bool = True) -> bool:
    """Nenhum asset pode ter perdido mais que `limite_pct` da faixa de L*.

    Compara sempre contra o espelho em .original/, então o veredito é sobre o
    acumulado desde a arte gerada, não sobre a última rodada.
    """
    piores, falhas = [], 0
    for png in pngs(None):
        orig = ESPELHO / png.relative_to(PROJETO)
        if not orig.exists():
            continue
        a = faixa_luminancia(np.array(Image.open(png).convert("RGBA")))
        o = faixa_luminancia(np.array(Image.open(orig).convert("RGBA")))
        if o["faixa"] < 1.0:
            continue
        pct = 100.0 * (a["faixa"] - o["faixa"]) / o["faixa"]
        piores.append((pct, png.relative_to(PROJETO), o, a))
        if pct < -limite_pct:
            falhas += 1
    if not piores:
        return True
    piores.sort(key=lambda t: t[0])
    if verbose:
        print(f"\n── REGRA: perda de faixa de L* < {limite_pct:.0f}% " + "─" * 30)
        for pct, nome, o, a in piores[:8]:
            print(f"  {pct:+6.1f}%  {o['faixa']:5.1f} → {a['faixa']:5.1f} L*   {nome}")
        media = sum(p[0] for p in piores) / len(piores)
        print(f"  {len(piores)} assets · Δfaixa médio {media:+.1f}% · "
              f"pior {piores[0][0]:+.1f}% · acima do limite: {falhas}")
        print(f"  {'✅ PASSOU' if falhas == 0 else f'❌ FALHOU — {falhas} assets'}")
    return falhas == 0


def espelhar(png: Path) -> None:
    """Guarda o original UMA vez. Rodar de novo não degrada em cascata."""
    rel = png.relative_to(PROJETO)
    destino = ESPELHO / rel
    if destino.exists():
        return
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(png, destino)


def pngs(filtro: str | None) -> list[Path]:
    saida: list[Path] = []
    for pasta in PASTAS:
        base = PROJETO / pasta
        if not base.is_dir():
            continue
        if filtro and filtro not in pasta:
            continue
        saida += sorted(base.rglob("*.png"))
    return saida


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--medir", action="store_true", help="só diagnostica")
    ap.add_argument("--aplicar", action="store_true", help="força a paleta")
    ap.add_argument("--orfaos", action="store_true", help="limpa pixels soltos")
    ap.add_argument("--restaurar", action="store_true", help="desfaz tudo")
    ap.add_argument("--conferir-ordem", action="store_true",
                    dest="conferir_ordem",
                    help="regra fixa: água mais escura que areia (+ faixa de L*)")
    ap.add_argument("--paleta", default=str(RAIZ / "ferramentas" / "paleta.hex"))
    ap.add_argument("--so", default=None, help="limita a uma pasta (ex.: tilesets)")
    ap.add_argument("--piores", type=int, default=15)
    ap.add_argument("--cru", action="store_true",
                    help="pula a pré-compressão de croma (encaixa direto na paleta)")
    ap.add_argument("--sem-ordem", action="store_true", dest="sem_ordem",
                    help="volta ao vizinho mais próximo livre (só para comparar)")
    ap.add_argument("--limite-faixa", type=float, default=15.0, dest="limite_faixa",
                    help="perda máxima de faixa de L%% tolerada, em %%")
    args = ap.parse_args()

    if args.conferir_ordem:
        ok_ordem = conferir_ordem()
        ok_faixa = conferir_faixa(args.limite_faixa)
        print()
        sys.exit(0 if (ok_ordem and ok_faixa) else 1)

    if args.restaurar:
        n = 0
        for orig in ESPELHO.rglob("*.png"):
            shutil.copy2(orig, PROJETO / orig.relative_to(ESPELHO))
            n += 1
        print(f"↩️  {n} arquivos restaurados de {ESPELHO}")
        return

    arquivos = pngs(args.so)
    if not arquivos:
        raise SystemExit("nenhum PNG encontrado")

    if args.medir or not (args.aplicar or args.orfaos):
        fichas = [medir(p) for p in arquivos]
        print(f"\n{len(fichas)} arquivos medidos\n")
        print("── piores por CORES ÚNICAS " + "─" * 44)
        for f in sorted(fichas, key=lambda x: -x["cores"])[:args.piores]:
            print(f"  {f['cores']:6}  sat {f['sat_med']:.0%}/{f['sat_max']:.0%}"
                  f"  órfãos {f['orfaos']:5}  {f['arquivo'].relative_to(PROJETO)}")
        print("\n── piores por SATURAÇÃO MÉDIA " + "─" * 41)
        for f in sorted(fichas, key=lambda x: -x["sat_med"])[:args.piores]:
            print(f"  sat {f['sat_med']:.0%} (máx {f['sat_max']:.0%})"
                  f"  {f['cores']:5} cores  {f['arquivo'].relative_to(PROJETO)}")
        tot = sum(f["cores"] for f in fichas)
        print(f"\ntotal de cores somadas: {tot}  ·  "
              f"órfãos somados: {sum(f['orfaos'] for f in fichas)}")
        return

    pal = ler_paleta(Path(args.paleta))
    pal_lab = para_oklab(pal)
    baldes = baldes_paleta(pal)
    lum_pal = lstar(pal)
    modo = "vizinho livre" if args.sem_ordem else f"monotônico ({len(baldes)} tons)"
    print(f"paleta: {len(pal)} cores de {args.paleta}")
    print(f"        L* de {lum_pal.min():.1f} a {lum_pal.max():.1f} · encaixe: {modo}\n")

    perdas: list[tuple[float, Path]] = []
    for png in arquivos:
        antes = medir(png)
        arr = np.array(Image.open(png).convert("RGBA"))
        espelhar(png)
        # a faixa "antes" sai do ESPELHO: o veredito é sobre o acumulado desde
        # a arte gerada, não sobre a última passada
        base = np.array(Image.open(ESPELHO / png.relative_to(PROJETO))
                        .convert("RGBA"))
        f_antes = faixa_luminancia(base)
        ref = arr.copy()
        trocas = 0
        if not args.cru:
            arr = suavizar_croma(arr)
            arr = travar_familia(arr)
        if args.orfaos:
            arr, trocas = limpar_orfaos(arr)
        if args.aplicar:
            if args.sem_ordem:
                arr = mapear(arr, pal, pal_lab)
            else:
                arr = mapear_monotonico(arr, ref, pal, pal_lab, baldes)
        Image.fromarray(arr, "RGBA").save(png)
        depois = medir(png)
        f_depois = faixa_luminancia(arr)

        pct = (100.0 * (f_depois["faixa"] - f_antes["faixa"]) / f_antes["faixa"]
               if f_antes["faixa"] > 1.0 else 0.0)
        perdas.append((pct, png.relative_to(PROJETO)))
        marca = "⚠️" if (depois["cores"] > len(pal) or pct < -args.limite_faixa) else "  "
        print(f"{marca} {antes['cores']:6} → {depois['cores']:4} cores  "
              f"L* {f_antes['min']:4.0f}-{f_antes['max']:4.0f}"
              f"→{f_depois['min']:4.0f}-{f_depois['max']:4.0f}"
              f" faixa {pct:+6.1f}%  órfãos −{trocas:<5} {png.relative_to(PROJETO)}")

    print(f"\n✅ {len(arquivos)} arquivos. Originais em {ESPELHO} "
          f"(--restaurar desfaz).")

    if perdas:
        vals = [p[0] for p in perdas]
        perdas.sort(key=lambda t: t[0])
        acima = [p for p in perdas if p[0] < -args.limite_faixa]
        print(f"\n── FAIXA DE LUMINÂNCIA " + "─" * 48)
        print(f"  Δfaixa médio {sum(vals)/len(vals):+.1f}%  ·  "
              f"pior {perdas[0][0]:+.1f}% ({perdas[0][1].name})")
        print(f"  acima do limite de {args.limite_faixa:.0f}%: "
              f"{len(acima)} de {len(perdas)}")
        for pct, nome in acima[:10]:
            print(f"    {pct:+6.1f}%  {nome}")
        if not acima:
            print("  ✅ meta batida: nenhum asset perdeu mais que "
                  f"{args.limite_faixa:.0f}% da faixa")


if __name__ == "__main__":
    main()
