#!/usr/bin/env python3
"""Conversão sRGB ⇄ OKLab, vetorizada em numpy.

Vive aqui porque é a única parte de `cenario_v2/paleta_mestra.py` que
sobreviveu ao expurgo da arte em camadas. O resto daquele arquivo — rampa
mestra, grades de estação, extensão de vão — servia a placa e as tiras, que
não existem mais. Estas duas funções servem à pixelização, que continua.

Por que OKLab e não HSV ou RGB: agrupar rampa por matiz em HSV separa mal
verdes escuros de marrons, e distância em RGB puxa a cor para o cinza mais
próximo em vez do vizinho de mesma família. OKLab é perceptualmente
uniforme — distância euclidiana ali corresponde ao que o olho chama de
"parecido", que é exatamente o critério que a paleta precisa.

Entrada e saída em uint8 [0,255]; a forma do array é preservada, então
funciona igual para uma cor, uma lista N×3 ou uma imagem H×W×3.
"""

import numpy as np


def srgb_para_oklab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype(float) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
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


def oklab_para_srgb(lab: np.ndarray) -> np.ndarray:
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = np.stack([
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ], axis=-1)
    lin = np.clip(lin, 0.0, 1.0)
    srgb = np.where(lin <= 0.0031308, lin * 12.92,
                    1.055 * lin ** (1 / 2.4) - 0.055)
    return np.round(srgb * 255).astype(np.uint8)
