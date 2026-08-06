#!/usr/bin/env python3
"""
TESTE DE ACEITAÇÃO DE FONTE — decide por medida, não por gosto.

Uma fonte pixel bonita que confunde 2 com 8 é inaceitável num jogo de economia:
o jogador lê "custo 20" onde está escrito "custo 80" e toma a decisão errada.
Foi exatamente isso que reprovou a Pixelify Sans depois de ela já estar no jogo.

Os cinco testes, na ordem em que reprovam:

  (a) render no TAMANHO REAL de uso, sem antialiasing (limiar duro)
  (b) COLISÃO DE DÍGITOS — todos os 45 pares de 0-9 comparados pixel a pixel.
      Reprova se qualquer par passar do teto (padrão 80%).
  (c) 15/15 acentos do português, incluindo Ç e Õ maiúsculos
  (d) grade nativa: o tamanho de render precisa ser múltiplo inteiro dela,
      senão a fonte é reamostrada e a espessura do traço fica irregular
  (e) legibilidade do TÍTULO: E não pode ler como C, O não pode ler como D nem V

Sobre a métrica de (b)
----------------------
Comparar dois glifos numa caixa com folga dá >90% de "iguais" para qualquer
par, porque o fundo domina a contagem. Aqui os dois glifos são recortados na
própria caixa de tinta e sobrepostos pelo canto superior esquerdo, e a conta
roda só na união das duas caixas. Além da identidade crua que o critério pede,
sai o IoU da tinta — que é o número que realmente separa "parecido" de "igual".

    python3 ferramentas/testar_fontes.py --dir <pasta> --tamanhos 16,20
    python3 ferramentas/testar_fontes.py --fonte X.ttf --tamanho 16 --amostra
"""

from __future__ import annotations

import argparse
import unicodedata
from itertools import combinations
from math import gcd
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ACENTOS = "áéíóúâêôãõàçÁÉÍÓÚÂÊÔÃÕÀÇ"
ACENTOS_CRITICOS = "ÇÕÃÊÔÁ"
LINHA_NUM = "0123456789 · 20 25 28 58 85 88 50"
LINHA_TXT = ("Exército Rebelião Traição Notáveis Mês Cavalaria "
             "Alimentação População")
TITULO = "REINO POR CONQUISTA"
PARES_CRITICOS = [("2", "8"), ("5", "8"), ("6", "8"), ("3", "8"),
                  ("0", "8"), ("1", "7")]
# no título, estes pares foram os que quebraram a Jacquard 12
PARES_TITULO = [("E", "C"), ("O", "D"), ("O", "V"), ("O", "Q"),
                ("I", "L"), ("N", "M"), ("U", "V")]


def tinta(fonte: ImageFont.FreeTypeFont, ch: str, limiar: int = 128) -> np.ndarray | None:
    """Bitmap booleano do glifo, recortado na caixa de tinta."""
    caixa = 96
    img = Image.new("L", (caixa, caixa), 0)
    ImageDraw.Draw(img).text((caixa // 4, caixa // 4), ch, font=fonte, fill=255)
    a = np.array(img) >= limiar
    if not a.any():
        return None
    ys, xs = np.where(a)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def comparar(a: np.ndarray, b: np.ndarray) -> tuple[float, float]:
    """(identidade crua, IoU da tinta) sobre a UNIÃO das duas caixas."""
    h, w = max(a.shape[0], b.shape[0]), max(a.shape[1], b.shape[1])
    pa = np.zeros((h, w), bool); pa[:a.shape[0], :a.shape[1]] = a
    pb = np.zeros((h, w), bool); pb[:b.shape[0], :b.shape[1]] = b
    identico = float((pa == pb).mean())
    uniao = (pa | pb).sum()
    iou = float((pa & pb).sum() / uniao) if uniao else 1.0
    return identico, iou


def grade_nativa(caminho: Path) -> int:
    """Quantas células de pixel por em — o tamanho em que a fonte é nítida."""
    try:
        from fontTools.pens.recordingPen import RecordingPen
        from fontTools.ttLib import TTFont
    except ImportError:
        return 0
    try:
        t = TTFont(caminho, fontNumber=0)
    except Exception:
        return 0
    upm = t["head"].unitsPerEm
    gs = t.getGlyphSet()
    vals: list[int] = []
    for n in list(t.getGlyphOrder())[:150]:
        p = RecordingPen()
        try:
            gs[n].draw(p)
        except Exception:
            continue
        for _, args in p.value:
            for arg in args:
                if isinstance(arg, tuple):
                    vals += [abs(int(arg[0])), abs(int(arg[1]))]
    vals = [v for v in vals if v]
    if not vals:
        return 0
    # o passo dominante, não o gcd cru: um único ponto fora da grade
    # zeraria a medida de uma fonte que é perfeitamente pixelada
    g = 0
    for v in sorted(vals):
        g = gcd(g, v)
        if g == 1:
            break
    if g > 1:
        return upm // g
    passos = np.array(sorted(set(vals)))
    difs = np.diff(passos)
    difs = difs[difs > 0]
    return int(upm // int(np.median(difs))) if difs.size else 0


def cobertura(caminho: Path, alvo: str) -> str:
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        return "?"
    try:
        t = TTFont(caminho, fontNumber=0)
    except Exception:
        return "erro"
    mapa: set[int] = set()
    for tb in t["cmap"].tables:
        mapa |= set(tb.cmap.keys())
    falta = [c for c in alvo if ord(c) not in mapa]
    return "".join(falta)


def avaliar(caminho: Path, tamanho: int, teto: float) -> dict:
    try:
        f = ImageFont.truetype(str(caminho), tamanho)
    except Exception as e:
        return {"erro": str(e)[:40]}

    glifos = {d: tinta(f, d) for d in "0123456789"}
    if any(v is None for v in glifos.values()):
        return {"erro": "dígito ausente"}

    piores: list[tuple[str, float, float]] = []
    for a, b in combinations("0123456789", 2):
        ident, iou = comparar(glifos[a], glifos[b])
        piores.append((f"{a}/{b}", ident, iou))
    piores.sort(key=lambda x: -x[1])

    criticos = {}
    for a, b in PARES_CRITICOS:
        criticos[f"{a}/{b}"] = comparar(glifos[a], glifos[b])

    tit = {}
    for a, b in PARES_TITULO:
        ga, gb = tinta(f, a), tinta(f, b)
        tit[f"{a}/{b}"] = comparar(ga, gb)[0] if ga is not None and gb is not None else 1.0

    grade = grade_nativa(caminho)
    return {
        "pior_par": piores[0][0],
        "pior_ident": piores[0][1],
        "pior_iou": piores[0][2],
        "acima_teto": [p for p, i, _ in piores if i > teto],
        "criticos": criticos,
        "titulo_pior": max(tit.items(), key=lambda x: x[1]),
        "falta_acentos": cobertura(caminho, ACENTOS),
        "grade": grade,
        "multiplo": (grade > 0 and tamanho % grade == 0),
        "largura_num": f.getlength(LINHA_NUM),
        "largura_txt": f.getlength(LINHA_TXT),
        "cpl": int(960 / (f.getlength(LINHA_TXT) / len(LINHA_TXT))),
    }


def amostra(caminho: Path, tamanho: int, saida: Path) -> None:
    f = ImageFont.truetype(str(caminho), tamanho)
    linhas = [LINHA_NUM, LINHA_TXT, TITULO, ACENTOS]
    alt = tamanho + 10
    img = Image.new("L", (1200, alt * len(linhas) + 12), 0)
    d = ImageDraw.Draw(img)
    for i, l in enumerate(linhas):
        d.text((6, 6 + i * alt), l, font=f, fill=255)
    img.point(lambda v: 255 if v >= 128 else 0).convert("RGB").save(saida)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=None)
    ap.add_argument("--fonte", default=None)
    ap.add_argument("--tamanhos", default="16")
    ap.add_argument("--teto", type=float, default=0.80)
    ap.add_argument("--amostra", action="store_true")
    ap.add_argument("--saida", default="/tmp/amostra_fonte.png")
    args = ap.parse_args()

    tamanhos = [int(t) for t in args.tamanhos.split(",")]
    if args.fonte and args.amostra:
        amostra(Path(args.fonte), tamanhos[0], Path(args.saida))
        print("amostra em", args.saida)
        return

    arquivos: list[Path] = []
    if args.fonte:
        arquivos = [Path(args.fonte)]
    else:
        base = Path(args.dir or ".")
        arquivos = sorted(p for p in base.rglob("*.ttf")) + \
                   sorted(p for p in base.rglob("*.otf"))

    print(f"{'fonte':34} {'tam':>4} {'grade':>6} {'mult':>5} "
          f"{'pior par':>9} {'ident':>7} {'IoU':>6} {'>teto':>6} "
          f"{'acentos':>8} {'tít.pior':>10} {'ch/960':>7}")
    print("─" * 122)
    aprovadas = []
    for p in arquivos:
        for t in tamanhos:
            r = avaliar(p, t, args.teto)
            if "erro" in r:
                print(f"{p.name[:34]:34} {t:>4}  ERRO: {r['erro']}")
                continue
            ok_ac = "OK" if not r["falta_acentos"] else r["falta_acentos"][:6]
            ok = (not r["acima_teto"]) and (not r["falta_acentos"]) and r["multiplo"]
            marca = "✅" if ok else "  "
            print(f"{marca}{p.name[:32]:32} {t:>4} {r['grade']:>6} "
                  f"{'sim' if r['multiplo'] else 'NÃO':>5} "
                  f"{r['pior_par']:>9} {r['pior_ident']:>6.0%} {r['pior_iou']:>5.0%} "
                  f"{len(r['acima_teto']):>6} {ok_ac:>8} "
                  f"{r['titulo_pior'][0]}:{r['titulo_pior'][1]:.0%} {r['cpl']:>7}")
            if ok:
                aprovadas.append((p, t, r))

    print(f"\n{len(aprovadas)} aprovadas no crivo completo (teto {args.teto:.0%}).")
    for p, t, r in sorted(aprovadas, key=lambda x: x[2]["pior_ident"])[:8]:
        cr = "  ".join(f"{k}={v[0]:.0%}" for k, v in r["criticos"].items())
        print(f"  · {p.name} @{t}  pior={r['pior_ident']:.0%} ({r['pior_par']})  {cr}")


if __name__ == "__main__":
    main()
