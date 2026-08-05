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
2. `--aplicar`   — mapeia cada pixel para a cor mais próxima da paleta, em OKLab
                   (distância perceptual, não euclidiana em RGB — RGB erra feio
                   em verdes e em tons de pele).
3. `--orfaos`    — apaga o "confete": pixel cuja cor não aparece em NENHUM dos 8
                   vizinhos vira a cor dominante da vizinhança. É o que remove a
                   estática de pixels soltos laranja/cinza no meio da grama.

Nunca faz dithering. Dithering é ruído com nome bonito, e o relatório de
auditoria apontou exatamente isso como um dos defeitos das ilustrações.

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
    python3 ferramentas/requantizar.py --restaurar
"""

from __future__ import annotations

import argparse
import colorsys
import shutil
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


def limpar_orfaos(arr: np.ndarray) -> tuple[np.ndarray, int]:
    """Pixel isolado vira a cor dominante dos 8 vizinhos opacos."""
    h, w = arr.shape[:2]
    if h < 3 or w < 3:
        return arr, 0
    saida = arr.copy()
    trocas = 0
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if arr[y, x, 3] <= 10:
                continue
            atual = tuple(arr[y, x, :3])
            viz = []
            igual = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    p = arr[y + dy, x + dx]
                    if p[3] <= 10:
                        continue
                    c = tuple(p[:3])
                    viz.append(c)
                    if c == atual:
                        igual = True
            if igual or len(viz) < 5:
                continue
            saida[y, x, :3] = Counter(viz).most_common(1)[0][0]
            trocas += 1
    return saida, trocas


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
    ap.add_argument("--paleta", default=str(RAIZ / "ferramentas" / "paleta.hex"))
    ap.add_argument("--so", default=None, help="limita a uma pasta (ex.: tilesets)")
    ap.add_argument("--piores", type=int, default=15)
    ap.add_argument("--cru", action="store_true",
                    help="pula a pré-compressão de croma (encaixa direto na paleta)")
    args = ap.parse_args()

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
    print(f"paleta: {len(pal)} cores de {args.paleta}\n")

    for png in arquivos:
        antes = medir(png)
        arr = np.array(Image.open(png).convert("RGBA"))
        espelhar(png)
        trocas = 0
        if not args.cru:
            arr = suavizar_croma(arr)
        if args.orfaos:
            arr, trocas = limpar_orfaos(arr)
        if args.aplicar:
            arr = mapear(arr, pal, pal_lab)
        Image.fromarray(arr, "RGBA").save(png)
        depois = medir(png)
        marca = "  " if depois["cores"] <= len(pal) else "⚠️"
        print(f"{marca} {antes['cores']:6} → {depois['cores']:4} cores  "
              f"sat {antes['sat_med']:.0%}→{depois['sat_med']:.0%}  "
              f"órfãos −{trocas:<5} {png.relative_to(PROJETO)}")

    print(f"\n✅ {len(arquivos)} arquivos. Originais em {ESPELHO} "
          f"(--restaurar desfaz).")


if __name__ == "__main__":
    main()
