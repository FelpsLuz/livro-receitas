#!/usr/bin/env python3
"""
GERAR PANORAMA — as camadas da vila em ELEVAÇÃO.

Por que camadas e não uma imagem por local
-------------------------------------------
Uma ilustração única por assentamento não escala: cada estação, cada evento
(cerco, fome, rebelião) e cada nível de evolução multiplicariam o número de
imagens. Aqui a cena é uma PILHA — céu, montanhas, floresta, muralha, castelo,
campo, rio — e trocar o inverno é trocar UMA camada, não regerar tudo.

A perspectiva atmosférica (quanto mais longe, menos saturado e mais claro) NÃO
é pedida ao modelo: é aplicada por código na Godot, com `modulate` por camada.
Pedir ao modelo daria resultado diferente a cada geração; um multiplicador de
cor dá o mesmo sempre, e permite calibrar sem gastar crédito.

Cada faixa é gerada na LARGURA FINAL da cena, não num tile repetido: repetição
horizontal de um strip não-costurável aparece como padrão, e o olho pega na
hora. É mais caro por chamada e mais barato no total, porque não precisa de
tentativa e erro para fechar a costura.

  export PIXELLAB_SECRET="..."
  python3 gerar_panorama.py --listar
  python3 gerar_panorama.py --apenas pan_ceu_dia
  python3 gerar_panorama.py --tudo
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
import time
from io import BytesIO
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent
BASE = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
DESTINO = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "panorama"

# ------------------------------------------------------------------
# A cena vive numa tela de arte de 400x144 e é desenhada a 2x → 800x288.
# Dois é fator INTEIRO: meio pixel de escala é o que faz pixel art tremer.
# ------------------------------------------------------------------
LARGURA = 400
ALTURA = 144

# O DNA visual. Sem "saturated", sem "16-bit", sem "flat OR cel" — o "ou" dava
# a escolha ao modelo, e cada chamada escolhia diferente. Um estilo só, fixo.
ESTILO = ("muted limited palette, clean pixel clusters, hard shading with a "
          "3-4 tone ramp, no dithering noise, defined silhouette, "
          "single light source from upper left, medieval low fantasy")

# Vai no CAMPO negative_description, não no prompt positivo. Enfiar "no
# watercolor" no texto positivo injeta o token no embedding e pode AUMENTAR a
# chance do defeito.
NEGATIVO = ("watercolor, sketch, blurry, anti-aliased, gradient, glow, "
            "soft shading, photorealistic, text, watermark, ui frame, "
            "vibrant neon colors, dithering")

# tipo: "faixa" = fundo opaco de largura total · "peça" = sprite recortado
CAMADAS = {
    # ---------------- céu ----------------
    "pan_ceu_dia": dict(w=LARGURA, h=96, tipo="faixa", ordem=0,
        desc="wide panoramic sky, clear blue daylight sky with a few flat "
             "cumulus clouds in horizontal bands, lighter near the horizon at "
             "the bottom, empty, no ground, no mountains, no sun"),
    "pan_ceu_entardecer": dict(w=LARGURA, h=96, tipo="faixa", ordem=0,
        desc="wide panoramic sky at dusk, warm amber and dusty rose bands near "
             "the horizon fading to deep blue at the top, thin flat clouds, "
             "empty, no ground, no sun disc"),
    "pan_ceu_inverno": dict(w=LARGURA, h=96, tipo="faixa", ordem=0,
        desc="wide panoramic overcast winter sky, flat pale grey and cold "
             "off-white cloud banks, low contrast, empty, no ground, no sun"),
    "pan_ceu_tempestade": dict(w=LARGURA, h=96, tipo="faixa", ordem=0,
        desc="wide panoramic storm sky, heavy dark slate cloud masses with a "
             "few pale breaks, oppressive, empty, no ground, no rain streaks"),

    # ---------------- sol e lua ----------------
    # rampa de 3 degraus, sem halo radial: gradiente suave sobre pixel art é
    # exatamente o que a auditoria proibiu
    "pan_sol": dict(w=48, h=48, tipo="peca", ordem=1,
        desc="single pale yellow sun disc with a THREE-STEP concentric halo in "
             "hard flat rings, no smooth gradient, no rays, isolated"),
    "pan_lua": dict(w=48, h=48, tipo="peca", ordem=1,
        desc="single pale bone-white crescent moon with a two-step hard halo "
             "ring, no smooth gradient, isolated"),

    # ---------------- montanhas ----------------
    "pan_montanha_longe": dict(w=LARGURA, h=52, tipo="peca", ordem=2,
        desc="distant mountain range silhouette across the full width, "
             "desaturated blue-grey, simple triangular peaks with flat snow "
             "caps, only the upper part of the range, nothing below, "
             "no trees, no buildings"),
    "pan_montanha_perto": dict(w=LARGURA, h=56, tipo="peca", ordem=3,
        desc="nearer mountain range across the full width, grey-green rocky "
             "slopes with visible ridges and a few flat snow patches, "
             "only the range itself, no trees, no buildings"),

    # ---------------- floresta ----------------
    "pan_floresta_verao": dict(w=LARGURA, h=40, tipo="peca", ordem=4,
        desc="dense band of conifer treetops across the full width, dark green "
             "layered pine canopy seen from the side, uneven top edge, "
             "flat bottom edge, no trunks visible, no ground"),
    "pan_floresta_outono": dict(w=LARGURA, h=40, tipo="peca", ordem=4,
        desc="dense band of treetops across the full width, autumn ochre rust "
             "and olive foliage seen from the side, uneven top edge, "
             "flat bottom edge, no trunks, no ground"),
    "pan_floresta_inverno": dict(w=LARGURA, h=40, tipo="peca", ordem=4,
        desc="dense band of snow-laden conifer treetops across the full width, "
             "dark green under heavy white snow caps, uneven top edge, "
             "flat bottom edge, no trunks, no ground"),
    "pan_floresta_queimada": dict(w=LARGURA, h=40, tipo="peca", ordem=4,
        desc="band of burnt bare tree skeletons across the full width, charred "
             "black trunks and broken branches, no foliage, uneven top edge, "
             "flat bottom edge, no ground"),

    # ---------------- muralha e castelo ----------------
    "pan_muralha": dict(w=LARGURA, h=44, tipo="peca", ordem=5,
        desc="UNIFORM medieval stone curtain wall seen from the FRONT in elevation, "
             "the SAME crenellated pattern repeating from the left edge to the "
             "right edge, square merlons, weathered grey blocks with mortar "
             "lines, absolutely NO gate, NO door, NO arch, NO tower, NO "
             "gatehouse, NO opening anywhere, flat bottom edge, no ground"),
    "pan_castelo": dict(w=192, h=136, tipo="peca", ordem=6,
        desc="medieval castle gatehouse seen from the FRONT in elevation, tall "
             "central keep with a red pennant on top, two flanking round "
             "towers with conical red roofs, arched gate with a raised iron "
             "portcullis below, grey stone, symmetrical, isolated, no ground"),

    # ---------------- terreno e rio ----------------
    "pan_campo_verao": dict(w=LARGURA, h=56, tipo="faixa", ordem=7,
        desc="the ENTIRE image is solid grass meadow, deep green, filling every "
             "pixel from the top edge to the bottom edge and from the left "
             "edge to the right edge, small darker grass tufts and a few grey "
             "stones scattered on it, completely OPAQUE, absolutely no sky, "
             "no horizon, no pale or white areas, no mist, no water, "
             "no buildings, no trees"),
    "pan_campo_outono": dict(w=LARGURA, h=56, tipo="faixa", ordem=7,
        desc="wide band of dry ochre autumn ground seen in near-elevation, "
             "harvested stubble and bare patches, a dirt path down the middle, "
             "no buildings, no trees, no water"),
    "pan_campo_inverno": dict(w=LARGURA, h=56, tipo="faixa", ordem=7,
        desc="wide band of snow-covered ground seen in near-elevation, white "
             "drifts with dark earth showing through, a trodden path down the "
             "middle, no buildings, no trees, no water"),
    "pan_rio": dict(w=LARGURA, h=64, tipo="faixa", ordem=8,
        desc="the ENTIRE image is deep blue river water seen from the front, "
             "filling every pixel top to bottom and edge to edge, flat "
             "horizontal pale highlight lines on the surface, completely "
             "OPAQUE, absolutely no grass, no bank, no shore, no sky, "
             "no bridge, no boats, no buildings"),
    "pan_ponte": dict(w=88, h=52, tipo="peca", ordem=9,
        desc="a single wooden plank bridge ALONE on an empty transparent "
             "background, seen from the front crossing toward the viewer, "
             "side rails and support posts, weathered timber, nothing else "
             "in the image, absolutely no water, no river, no ground, "
             "no grass, no sky, no scenery"),
}

CUSTO_BASE = 0.0079      # 64x64 em US$, referência do fornecedor
PX_BASE = 64 * 64


def custo(spec: dict) -> float:
    """Preço estimado, proporcional à área. Só serve para o orçamento."""
    return CUSTO_BASE * (spec["w"] * spec["h"]) / PX_BASE


def montar(spec: dict) -> str:
    return ", ".join([spec["desc"], ESTILO])


def gerar(pid: str, spec: dict, segredo: str, forcar: bool) -> float:
    alvo = DESTINO / f"{pid}.png"
    if alvo.exists() and not forcar:
        print(f"  ⏭️  {pid} — já existe")
        return 0.0
    corpo = {
        "description": montar(spec),
        "negative_description": NEGATIVO,
        "image_size": {"width": spec["w"], "height": spec["h"]},
        "text_guidance_scale": 7.5,
        "no_background": spec["tipo"] == "peca",
        "outline": "selective outline",
        "shading": "flat shading",
        "detail": "medium detail",
        # elevação, não vista de cima: é o que separa panorama de tilemap
        "view": "side",
    }
    r = requests.post(f"{BASE}/create-image-pixflux", json=corpo,
                      headers={"Authorization": f"Bearer {segredo}"}, timeout=300)
    if r.status_code >= 400:
        print(f"  ❌ {pid} — HTTP {r.status_code}: {r.text[:200]}")
        return 0.0
    dados = r.json()
    b64 = dados["image"]["base64"]
    alvo.parent.mkdir(parents=True, exist_ok=True)
    alvo.write_bytes(base64.b64decode(b64))
    gasto = float(dados.get("usage", {}).get("usd", 0.0))
    print(f"  ✅ {pid} → {spec['w']}x{spec['h']}  (US$ {gasto:.4f})")
    return gasto


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apenas", action="append", default=[])
    ap.add_argument("--tudo", action="store_true")
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--forcar", action="store_true")
    args = ap.parse_args()

    if args.listar:
        total = 0.0
        for pid, s in sorted(CAMADAS.items(), key=lambda x: x[1]["ordem"]):
            c = custo(s)
            total += c
            print(f"  {s['ordem']}  {pid:26} {s['w']:>4}x{s['h']:<4} "
                  f"{s['tipo']:6} ~US$ {c:.4f}")
        print(f"\n  {len(CAMADAS)} camadas · estimativa total ~US$ {total:.2f}")
        minimo = [p for p in CAMADAS if not any(
            p.endswith(x) for x in ("_entardecer", "_inverno", "_tempestade",
                                    "_outono", "_queimada")) and p != "pan_lua"]
        print(f"  mínimo viável (verão/dia): {len(minimo)} camadas ~US$ "
              f"{sum(custo(CAMADAS[p]) for p in minimo):.2f}")
        return

    segredo = os.environ.get("PIXELLAB_SECRET", "")
    if not segredo:
        sys.exit("defina PIXELLAB_SECRET")

    ids = list(CAMADAS) if args.tudo else args.apenas
    faltando = [i for i in ids if i not in CAMADAS]
    if faltando:
        sys.exit(f"id desconhecido: {faltando}")

    gasto = 0.0
    for pid in sorted(ids, key=lambda p: CAMADAS[p]["ordem"]):
        gasto += gerar(pid, CAMADAS[pid], segredo, args.forcar)
        time.sleep(0.4)
    print(f"\n📊 gasto real US$ {gasto:.4f}")


if __name__ == "__main__":
    main()
