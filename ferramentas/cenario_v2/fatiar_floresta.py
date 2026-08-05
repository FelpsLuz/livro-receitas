#!/usr/bin/env python3
"""Fatia a tira de floresta em variantes soltas (spec v4 §C.1).

Duas correções feitas por medida, não por olho:

1. A tira veio com uma FAIXA DE CHÃO ligando os troncos — o mesmo defeito
   de plinto que o v3.1 §B proíbe nos objetos. Ela é detectada por
   cobertura opaca por linha (≥70% da largura = chão, uma árvore sozinha
   nunca cobre isso) e removida. Sem removê-la as árvores nem se separam:
   ficam uma componente só de x=5 a x=154.
2. Só então as colunas se separam em variantes. Cada variante é recortada
   pelo seu próprio bbox opaco, para o pé ser o pé de verdade.

Saída: tiras/floresta_arvores.png (as variantes lado a lado, com alpha) +
tiras/floresta_arvores.json (bbox de cada variante e altura).
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from pipeline_cenario import SAIDA  # noqa: E402

TIRA = SAIDA / "tiras" / "floresta_variantes.png"
ALVO = SAIDA / "tiras" / "floresta_arvores.png"
META = SAIDA / "tiras" / "floresta_arvores.json"
CHAO_COBERTURA = 0.70
MIN_LARGURA = 6


def fatiar() -> None:
    im = Image.open(TIRA).convert("RGBA")
    a = np.array(im)
    op = a[..., 3] > 10

    # o chão é a faixa contígua de cobertura alta que ENCOSTA NA BASE.
    # Pegar o mínimo global cortava em y=40, que é copa densa, não chão.
    ultimo = int(np.nonzero(op.any(axis=1))[0].max())
    corte = ultimo + 1
    y = ultimo
    while y >= 0 and op[y].mean() >= CHAO_COBERTURA:
        corte = y
        y -= 1
    linhas_chao = list(range(corte, ultimo + 1)) if corte <= ultimo else []
    a = a[:corte]
    op = op[:corte]
    print(f"  faixa de chão nas linhas {linhas_chao} → cortada em y={corte}")

    cols = op.any(axis=0)
    grupos: list[list[int]] = []
    for x in range(len(cols)):
        if cols[x]:
            if grupos and x - grupos[-1][-1] <= 1:
                grupos[-1].append(x)
            else:
                grupos.append([x])
    grupos = [g for g in grupos if len(g) >= MIN_LARGURA]
    print(f"  {len(grupos)} variantes separadas")

    recortes = []
    for g in grupos:
        sub = a[:, g[0]:g[-1] + 1]
        so = sub[..., 3] > 10
        ys = np.nonzero(so.any(axis=1))[0]
        recortes.append(sub[ys.min():ys.max() + 1])

    larg = sum(r.shape[1] for r in recortes)
    alt = max(r.shape[0] for r in recortes)
    folha = np.zeros((alt, larg, 4), np.uint8)
    meta = []
    x = 0
    for i, r in enumerate(recortes):
        # ancorado no PÉ: as variantes têm alturas diferentes e a base
        # tem que ficar alinhada para a Godot poder posar todas no chão
        folha[alt - r.shape[0]:, x:x + r.shape[1]] = r
        meta.append({"x": x, "y": alt - r.shape[0], "w": r.shape[1],
                     "h": r.shape[0]})
        x += r.shape[1]
    Image.fromarray(folha, "RGBA").save(ALVO)
    META.write_text(json.dumps({"altura_folha": alt, "variantes": meta},
                               indent=1))
    alturas = [m["h"] for m in meta]
    print(f"  💾 {ALVO.name} {larg}x{alt} · alturas {alturas}")
    distintas = len(set(alturas))
    print(f"  {'✅' if distintas >= 3 else '❌'} {distintas} alturas distintas")


if __name__ == "__main__":
    fatiar()
