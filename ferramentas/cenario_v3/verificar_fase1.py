#!/usr/bin/env python3
"""Verifica as asserções da Fase 1 MEDINDO, não afirmando.

Cada critério vira um número impresso. Vermelho é portão: se algum falhar,
o processo sai com código 1 e a fase não avança.

    python3 ferramentas/cenario_v3/verificar_fase1.py --estacao verao
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
ARTE = RAIZ / "reino-por-conquista-godot" / "assets"
NATIVO = (480, 270)
PALETA_ALVO = 54
NOMES = [f"estagio_{i:02d}" for i in range(1, 7)]

_verdes = 0
_vermelhos = 0


def ok(cond: bool, nome: str, obs: str) -> bool:
    global _verdes, _vermelhos
    print(f"  {'✅' if cond else '❌'} {nome} — {obs}")
    if cond:
        _verdes += 1
    else:
        _vermelhos += 1
    return cond


def _lum(a: np.ndarray) -> np.ndarray:
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def _desloc(a: np.ndarray, b: np.ndarray, y0: int, y1: int,
            alcance: int = 6) -> tuple:
    """Deslocamento vertical inteiro que melhor alinha `a` a `b`.

    Mede DIRETO, por erro absoluto médio na banda de fundo — céu, montanha,
    nuvens e sol, que a construção não altera. É o que a asserção quer
    saber: se o recorte de moldura ou o de proporção moveu o conteúdo.

    A primeira versão disto media a "linha do horizonte" (primeira linha
    não-céu por coluna) e acusava 33px de deslocamento. Era artefato: o céu
    tem DEGRADÊ, as 3 primeiras linhas dão só 2 das suas cores, e o
    detector achava a fronteira da segunda faixa do degradê, não o
    horizonte. Correlação direta não depende de classificar pixel nenhum.
    """
    a = a.astype(int)
    b = b.astype(int)
    erros = {}
    for s in range(-alcance, alcance + 1):
        erros[s] = float(np.abs(a[y0 + s:y1 + s] - b[y0:y1]).mean())
    melhor = min(erros, key=erros.get)
    return melhor, erros[melhor], erros[0]


def _rio_topo(rgb: np.ndarray) -> int:
    """Topo da faixa de água CONTÍGUA que encosta na base."""
    a = rgb.astype(int)
    r, b = a[..., 0], a[..., 2]
    agua = (b > r + 10) & (_lum(a) <= 150)
    linhas = [y for y in range(rgb.shape[0]) if agua[y].mean() >= 0.30]
    if not linhas:
        return -1
    fim = max(linhas)
    ini = fim
    while ini - 1 in linhas:
        ini -= 1
    return ini


def _sol(rgb: np.ndarray) -> tuple:
    """Centroide do disco solar: o aglomerado mais claro do terço superior.

    Limiar por percentil, não absoluto — o sol é o mais claro que existe
    ali, mas o valor exato depende da paleta que saiu do E6.
    """
    topo = rgb[: NATIVO[1] // 3].astype(int)
    L = _lum(topo)
    lim = np.percentile(L, 99.5)
    ys, xs = np.nonzero(L >= lim)
    if not len(ys):
        return (-1, -1, 0)
    return (float(xs.mean()), float(ys.mean()), int(len(ys)))


def _moldura(rgb: np.ndarray) -> float:
    """Fração de pixels dourados no anel de 2px da borda."""
    a = rgb.astype(int)
    dourado = (a[..., 0] > 140) & (a[..., 0] > a[..., 2] + 40)
    anel = np.concatenate([dourado[:2].ravel(), dourado[-2:].ravel(),
                           dourado[:, :2].ravel(), dourado[:, -2:].ravel()])
    return float(anel.mean())


def main(estacao: str) -> int:
    dest = ARTE / "estagios" / estacao
    caminho_pal = ARTE / "paletas" / f"{estacao}.png"

    print(f"\nFASE 1 · {estacao}\n" + "=" * 58)

    # ---- 1. formato ----
    print("\n[1] os 6 em 480×270, PNG-8 indexado")
    ims = {}
    for n in NOMES:
        p = dest / f"{n}.png"
        if not p.exists():
            ok(False, n, "arquivo ausente")
            continue
        im = Image.open(p)
        ims[n] = im
        ok(im.size == NATIVO and im.mode == "P", n,
           f"{im.size[0]}×{im.size[1]} modo {im.mode}")

    if len(ims) != 6:
        return 1

    # ---- 2. mesma paleta ----
    print(f"\n[2] os 6 com a MESMA paleta de {PALETA_ALVO} cores")
    tabelas = {n: im.getpalette()[: PALETA_ALVO * 3] for n, im in ims.items()}
    base = tabelas[NOMES[0]]
    ok(all(t == base for t in tabelas.values()), "tabela idêntica nos 6",
       "as 54 primeiras entradas batem byte a byte")
    # a paleta gravada tem que ser a mesma que está dentro dos estágios
    pal_im = Image.open(caminho_pal)
    ok(pal_im.size == (64, 1) and pal_im.mode == "P", "tira de paleta",
       f"{pal_im.size[0]}×{pal_im.size[1]} modo {pal_im.mode}")
    ok(pal_im.getpalette()[: PALETA_ALVO * 3] == base,
       "tira bate com os estágios", "mesmas 54 entradas na mesma ordem")
    cores = {tuple(base[i * 3:i * 3 + 3]) for i in range(PALETA_ALVO)}
    ok(len(cores) == PALETA_ALVO, "sem cor repetida na paleta",
       f"{len(cores)} cores distintas de {PALETA_ALVO} entradas")
    # nenhum pixel usando índice fora das 54
    for n, im in ims.items():
        mx = int(np.array(im).max())
        ok(mx < PALETA_ALVO, f"{n} só usa índices < {PALETA_ALVO}",
           f"índice máximo {mx}")

    rgbs = {n: np.array(im.convert("RGB")) for n, im in ims.items()}

    # ---- 3. deslocamento vertical ----
    print("\n[3] deslocamento vertical introduzido pelo pipeline = 0px")
    ref = rgbs[NOMES[-1]]
    for n in NOMES:
        s, e_s, e_0 = _desloc(rgbs[n], ref, 8, 110)
        ok(s == 0, f"{n} · alinhamento contra o estagio_06",
           f"melhor deslocamento {s:+d}px · erro {e_s:.1f} contra "
           f"{e_0:.1f} em 0px (ganho {e_0 - e_s:.2f})")

    # ---- 3b. o que o pipeline NÃO controla: a deriva da fonte ----
    print("\n[3b] registro dos landmarks entre estágios (medida, não asserção)")
    topos = {n: _rio_topo(rgbs[n]) for n in NOMES}
    sois = {n: _sol(rgbs[n]) for n in NOMES}
    ys = [round(s[1]) for s in sois.values()]
    xs = [round(s[0]) for s in sois.values()]
    tv = list(topos.values())
    ok(max(tv) - min(tv) == 0, "topo do rio igual nos 6",
       " · ".join(f"{n[-2:]}:{y}" for n, y in topos.items())
       + f" · amplitude {max(tv) - min(tv)}px")
    ok(max(ys) - min(ys) == 0, "centro do sol na mesma linha nos 6",
       " · ".join(f"{n[-2:]}:y={round(s[1])}" for n, s in sois.items())
       + f" · amplitude {max(ys) - min(ys)}px")
    ok(max(xs) - min(xs) == 0, "centro do sol na mesma coluna nos 6",
       " · ".join(f"{n[-2:]}:x={round(s[0])}" for n, s in sois.items())
       + f" · amplitude {max(xs) - min(xs)}px")
    for n in NOMES[:-1]:
        igual = float((rgbs[n][8:110] == ref[8:110]).all(axis=-1).mean())
        print(f"      {n} · {igual * 100:5.1f}% do fundo idêntico ao estagio_06")

    # ---- 4. sol no quadrante superior direito ----
    print("\n[4] sol no quadrante superior direito em todos")
    for n, (x, y, px) in sois.items():
        ok(x > NATIVO[0] / 2 and y < NATIVO[1] / 2, n,
           f"centroide ({x:.0f},{y:.0f}) em {px}px · "
           f"quadrante exige x>{NATIVO[0] // 2} e y<{NATIVO[1] // 2}")

    # ---- 5. sem moldura ----
    print("\n[5] nenhuma moldura remanescente")
    for n in NOMES:
        f = _moldura(rgbs[n])
        ok(f < 0.10, n, f"{f * 100:.1f}% do anel de borda é dourado "
                        f"(limite 10%)")

    print("\n" + "=" * 58)
    print(f"{_verdes} verdes · {_vermelhos} vermelhos")
    return 1 if _vermelhos else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--estacao", default="verao")
    sys.exit(main(ap.parse_args().estacao))
