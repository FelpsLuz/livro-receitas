#!/usr/bin/env python3
"""Mede a E6 achatada e os diffs entre estágios consecutivos.

Duas saídas, com propósitos distintos:

  coordenadas.json  REGISTRO do que está onde na E6 (480×270). NÃO é
                    posicionamento: a cena achatada não coloca nada, ela
                    já vem pintada. Serve para ancorar overlay (bandeira,
                    fumaça, tocha), sombra de clique e depuração — e para
                    comparar com o layout_n5 antigo, que era posicionamento
                    de verdade e agora vira histórico.

  transicoes.json   BBOX do que MUDA de um estágio para o próximo. É o que
                    a recompensa de evolução usa: o crossfade cobre a tela,
                    mas a poeira e o flash saem só onde a obra aconteceu.

    python3 ferramentas/cenario_v3/medir_estagios.py
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
BASE = RAIZ / "reino-por-conquista-godot" / "assets_v3" / "estagios" / "verao"
NOMES = ["e1_virgem", "e2_acampamento", "e3_assentamento",
         "e4_forte", "e5_muralha", "e6_completo"]
TOL_DIFF = 26          # diferença RGB somada que conta como "mudou"
MIN_COMPONENTE = 40    # px: componente menor que isto é ruído de quantização


def _lum(a: np.ndarray) -> np.ndarray:
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def bandas(e6: np.ndarray) -> dict:
    """As faixas horizontais da cena achatada, por classificação de cor."""
    r, g, b = (e6[..., k].astype(int) for k in range(3))
    L = _lum(e6.astype(int))
    ceu = (b > r + 18) & (L > 120)
    agua = (b > r + 10) & (L <= 150) & ~ceu
    verde = (g >= r) & (g > b)
    H, W, _ = e6.shape

    def faixa(mask, minimo=0.35):
        linhas = [y for y in range(H) if mask[y].mean() >= minimo]
        return [min(linhas), max(linhas)] if linhas else None

    # o rio é a faixa de água CONTÍGUA que encosta na base
    linhas_agua = [y for y in range(H) if agua[y].mean() >= 0.30]
    rio = None
    if linhas_agua:
        fim = max(linhas_agua)
        ini = fim
        while ini - 1 in linhas_agua:
            ini -= 1
        rio = [ini, fim]
    return {
        "ceu": faixa(ceu, 0.55),
        "vegetacao": faixa(verde, 0.40),
        "rio": rio,
        "canvas": [W, H],
    }


def castelo(e6: np.ndarray, e5: np.ndarray) -> dict:
    """O castelo é o que existe na E6 e não existia na E3 — mas medir
    contra a E5 (que já tem o castelo com andaime) daria quase nada.
    Usa-se a E3, o último estágio sem castelo nenhum."""
    return {}


CELULA = 30            # px: lado da célula do mapa de densidade
CELULA_MIN = 0.10      # fração de pixels mudados para a célula contar


def diff_bbox(a: np.ndarray, b: np.ndarray) -> dict:
    """O que mudou, em três granularidades — e a útil é a terceira.

    bbox global: quase sempre a tela inteira, porque a quantização deixa
      pixel mudado espalhado por todo lado. Serve de contexto, não de
      emissor.
    componentes conexos: o maior vira um blob de 480x206 quando a vila
      inteira aparece de uma vez (E2→E3). Também não isola obra.
    CÉLULAS de 30px ordenadas por densidade de mudança: essas sim marcam
      onde a obra aconteceu. São elas que a poeira usa.
    """
    d = np.abs(a.astype(int) - b.astype(int)).sum(axis=2) > TOL_DIFF
    H, W = d.shape
    # rotulagem 4-conexa em varredura por pilha
    rot = np.zeros((H, W), np.int32)
    prox = 0
    caixas = []
    for i in range(H):
        for j in range(W):
            if d[i, j] and rot[i, j] == 0:
                prox += 1
                pilha = [(i, j)]
                rot[i, j] = prox
                y0 = y1 = i
                x0 = x1 = j
                n = 0
                while pilha:
                    y, x = pilha.pop()
                    n += 1
                    y0, y1 = min(y0, y), max(y1, y)
                    x0, x1 = min(x0, x), max(x1, x)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and d[ny, nx] \
                                and rot[ny, nx] == 0:
                            rot[ny, nx] = prox
                            pilha.append((ny, nx))
                if n >= MIN_COMPONENTE:
                    caixas.append({"x": x0, "y": y0, "w": x1 - x0 + 1,
                                   "h": y1 - y0 + 1, "px": n})
    if not caixas:
        return {"bbox": None, "grupos": []}
    x0 = min(c["x"] for c in caixas)
    y0 = min(c["y"] for c in caixas)
    x1 = max(c["x"] + c["w"] for c in caixas)
    y1 = max(c["y"] + c["h"] for c in caixas)
    caixas.sort(key=lambda c: -c["px"])

    celulas = []
    for cy in range(0, H, CELULA):
        for cx in range(0, W, CELULA):
            bloco = d[cy:cy + CELULA, cx:cx + CELULA]
            frac = float(bloco.mean())
            if frac >= CELULA_MIN:
                celulas.append({"x": cx, "y": cy,
                                "w": int(bloco.shape[1]),
                                "h": int(bloco.shape[0]),
                                "peso": round(frac, 3)})
    celulas.sort(key=lambda c: -c["peso"])
    return {"bbox": {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0},
            "grupos": caixas[:8],
            "celulas": celulas,
            "px_total": int(sum(c["px"] for c in caixas))}


def cores_de(e6: np.ndarray, faixa: list, teste) -> list:
    """As cores de uma família dentro de uma faixa, da mais frequente
    para a menos — é delas que o ciclo de água e o balanço vivem."""
    reg = e6[faixa[0]:faixa[1] + 1]
    m = teste(reg.astype(int))
    if not m.any():
        return []
    cs, ns = np.unique(reg[m], axis=0, return_counts=True)
    ordem = np.argsort(-ns)
    return [{"rgb": [int(v) for v in cs[i]], "px": int(ns[i])}
            for i in ordem[:8]]


def main() -> None:
    ims = {n: np.array(Image.open(BASE / f"{n}.png").convert("RGB"))
           for n in NOMES}
    e6 = ims["e6_completo"]
    bd = bandas(e6)
    print(f"  bandas: {bd}")

    def teste_agua(a):
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        return (b > r + 12) & (_lum(a) < 190)

    def teste_junco(a):
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        return (g >= r) & (g > b + 8)

    rio = bd["rio"] or [230, 269]
    agua = cores_de(e6, rio, teste_agua)
    # a faixa de junco é a borda do rio: 6px acima do topo da água
    margem = [max(0, rio[0] - 6), min(e6.shape[0] - 1, rio[0] + 6)]
    junco = cores_de(e6, margem, teste_junco)
    print(f"  água: {len(agua)} cores dominantes · junco: {len(junco)}")

    (BASE / "coordenadas.json").write_text(json.dumps({
        "_nota": ("REGISTRO de coordenadas da E6 achatada (480x270). Não é "
                  "posicionamento: a cena vem pintada. Serve para ancorar "
                  "overlay, depurar e comparar com o layout_n5 histórico."),
        "bandas": bd,
        "agua_cores": agua,
        "junco_cores": junco,
    }, indent=1, ensure_ascii=False))

    trans = {}
    for a, b in zip(NOMES, NOMES[1:]):
        r = diff_bbox(ims[a], ims[b])
        trans[f"{a}->{b}"] = r
        bb = r["bbox"]
        print(f"  {a} → {b}: bbox {bb['w']}x{bb['h']} · "
              f"{len(r['celulas'])} células de obra · {r.get('px_total', 0)}px")
    (BASE / "transicoes.json").write_text(json.dumps(trans, indent=1))
    print(f"  💾 coordenadas.json + transicoes.json")


if __name__ == "__main__":
    main()
