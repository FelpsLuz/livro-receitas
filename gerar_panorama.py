#!/usr/bin/env python3
"""
GERAR PANORAMA — as camadas da vila em ELEVAÇÃO, calibradas pela referência.

Por que camadas e não uma imagem por local
-------------------------------------------
Uma ilustração única por assentamento não escala: cada estação, cada evento
(cerco, fome, rebelião) e cada NÍVEL DE EVOLUÇÃO multiplicariam o número de
imagens. Aqui a cena é uma PILHA — céu, serra, floresta, muralha, castelo,
campo, rio — e evoluir a vila é trocar UMA peça: a paliçada de madeira vira
muralha de pedra, o torreão vira castelo, o campo de treino vira academia.

A luz
-----
A referência do usuário é QUENTE e VIVA: grama em torno de H85° S55% V65%,
luz dourada vinda de cima. Por isso o panorama NÃO passa pelo requantizador
de 48 cores da UI — o teto de croma de lá lavava a cena. A coesão vem de
todas as camadas nascerem deste catálogo, com o mesmo DNA de estilo.

  export PIXELLAB_SECRET="..."
  python3 gerar_panorama.py --listar
  python3 gerar_panorama.py --grupo evolucao
  python3 gerar_panorama.py --tudo
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
import time
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent
BASE = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
DESTINO = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "panorama"

# A cena vive numa tela de arte de 400x180 e é desenhada a 2x → 800x360.
# 400 é o teto de largura da API; 2x é fator inteiro (meio pixel treme).
LARGURA = 400

# O DNA visual — a LUZ da referência. Sem "muted": a cena é o único lugar do
# jogo autorizado a ser vivo, porque é uma ilustração emoldurada, não UI.
ESTILO = ("lush storybook medieval pixel art, warm golden afternoon sunlight "
          "from the upper left, rich warm greens, clean pixel clusters, hard "
          "shading with a 3-4 tone ramp, defined silhouettes, charming and "
          "inviting")

# Vai no CAMPO negative_description, nunca no prompt positivo.
NEGATIVO = ("watercolor, sketch, blurry, anti-aliased, smooth gradient, glow, "
            "soft airbrush shading, photorealistic, text, watermark, ui frame, "
            "neon, dithering noise, grim, dark, desaturated")

# grupo: "base" = a cena de verão · "evolucao" = variantes por nível ·
#        "estacao" = variantes de estação · "vida" = bichos e enfeites
# tipo:  "faixa" = fundo opaco de largura total · "peca" = sprite recortado
CAMADAS = {
    # ================= BASE (verão, dia) =================
    "pan_ceu_dia": dict(w=LARGURA, h=104, tipo="faixa", ordem=0, grupo="base",
        desc="wide panoramic summer sky filling the whole image, warm clear "
             "blue with several puffy white cumulus clouds with flat shaded "
             "undersides, slightly paler near the bottom edge, no ground, "
             "no mountains, no sun disc"),
    "pan_sol": dict(w=48, h=48, tipo="peca", ordem=1, grupo="base",
        desc="game asset sprite: one pale warm yellow sun disc with a three-step "
             "concentric halo of hard flat rings, floating ALONE on an empty "
             "transparent background like a sprite sheet, absolutely NO "
             "trees, NO forest, NO clouds, NO landscape, NO background"),
    "pan_montanha_longe": dict(w=LARGURA, h=60, tipo="peca", ordem=2, grupo="base",
        desc="distant rocky mountain range across the full width, grey stone "
             "peaks with angular hard-shaded faces and thin snow caps, hazy "
             "cool tone, only the range itself, no trees, no buildings"),
    "pan_montanha_perto": dict(w=LARGURA, h=60, tipo="peca", ordem=3, grupo="base",
        desc="nearer mountain range across the full width, grey rocky faces "
             "with warm green forested lower slopes, angular hard shading, "
             "only the range, no buildings"),
    "pan_floresta_verao": dict(w=LARGURA, h=44, tipo="peca", ordem=4, grupo="base",
        desc="dense band of dark green conifer treetops filling the width "
             "edge to edge, many overlapping pointed pine tops with layered "
             "hard shading, uneven top edge, flat bottom edge, no trunks, "
             "no ground"),
    "pan_campo_verao": dict(w=LARGURA, h=64, tipo="faixa", ordem=7, grupo="base",
        desc="the ENTIRE image is lush warm green summer meadow seen from a "
             "low angle, rich grass with scattered darker tufts, tiny yellow "
             "and white flowers and a few small grey stones, gentle mounds, "
             "completely OPAQUE edge to edge, no sky, no horizon, no water, "
             "no buildings, no trees"),
    "pan_rio": dict(w=LARGURA, h=48, tipo="faixa", ordem=8, grupo="base",
        desc="wide calm river running horizontally across the full width, DEEP "
             "NAVY BLUE muted water like the reference of an old storybook, "
             "pale flat ripple highlights, narrow grassy banks with small "
             "grey rocks along the top and bottom edges, completely OPAQUE, "
             "NOT cyan, NOT turquoise, NOT tropical, no bridge, no boats"),
    "pan_ponte": dict(w=56, h=48, tipo="peca", ordem=9, grupo="base",
        desc="game asset sprite of a wooden plank bridge, front view, receding "
             "walkway between side rail posts, warm weathered timber, "
             "floating ALONE on an empty transparent background like a "
             "sprite sheet, absolutely NO trees, NO water, NO grass, "
             "NO sky, NO scenery of any kind"),
    "pan_caminho": dict(w=44, h=52, tipo="peca", ordem=9, grupo="base",
        desc="vertical dirt path strip seen from the front, light warm brown "
             "packed earth with small stones and cart ruts, slightly wider "
             "at the bottom, ALONE on transparent background, no grass"),

    # ================= EVOLUÇÃO (a vila que cresce) =================
    # nível 1-2: paliçada de madeira · nível 3+: muralha de pedra (já existe)
    "pan_palicada": dict(w=LARGURA, h=32, tipo="peca", ordem=5, grupo="evolucao",
        desc="wooden palisade wall of vertical sharpened logs lashed with "
             "rope, seen from the front, the same pattern repeating from the "
             "left edge to the right edge, warm weathered timber, flat "
             "bottom edge, NO gate, NO towers, no ground"),
    # nível 4: torreão de pedra · nível 5: o castelo completo da referência
    "pan_torreao": dict(w=96, h=88, tipo="peca", ordem=6, grupo="evolucao",
        desc="small medieval stone keep seen from the FRONT in elevation, "
             "one square tower with crenellated top and a red pennant, "
             "arched wooden gate at the base, warm grey stone blocks, "
             "isolated, no ground"),
    "pan_castelo": dict(w=116, h=104, tipo="peca", ordem=6, grupo="evolucao",
        desc="medieval castle gatehouse seen from the FRONT in elevation, "
             "tall central keep with a red pennant flag on top, two flanking "
             "round towers with conical roofs, arched gate with a raised "
             "iron portcullis below, warm grey stone with moss patches, "
             "symmetrical, isolated, no ground"),
    # tendas: o acampamento do nível 0 e as tendas de feira da referência
    "pan_tenda_circo": dict(w=60, h=56, tipo="peca", ordem=8, grupo="evolucao",
        desc="round medieval fair tent with red and blue striped canvas, "
             "pointed top with a tiny pennant, dark open doorway, warm "
             "sunlight, isolated, nothing else"),
    "pan_tenda_verde": dict(w=56, h=48, tipo="peca", ordem=8, grupo="evolucao",
        desc="small market tent with a green and white striped awning over a "
             "wooden counter with goods, isolated, nothing else"),
    # academia militar: campo de treino (nível 2) → prédio de pedra (nível 4)
    "pan_academia_treino": dict(w=80, h=48, tipo="peca", ordem=8, grupo="evolucao",
        desc="game asset sprite: a round straw archery target on a wooden tripod "
             "next to a wooden training dummy, floating ALONE on an empty "
             "transparent background like a sprite sheet, absolutely NO "
             "trees, NO bushes, NO fence, NO ground, NO person"),
    "pan_academia_pedra": dict(w=88, h=76, tipo="peca", ordem=8, grupo="evolucao",
        desc="medieval stone barracks building seen from the front, two "
             "floors, arched wooden door with a banner showing crossed "
             "swords above it, small windows, slate roof, isolated"),
    # moinho: madeira (nível 2) → o de pedra dos objects entra no 4
    "pan_moinho_madeira": dict(w=56, h=84, tipo="peca", ordem=8, grupo="evolucao",
        desc="small wooden windmill seen from the front, timber tower on a "
             "low stone base, four cloth sails, warm brown wood, isolated"),
    "pan_estabulo": dict(w=84, h=64, tipo="peca", ordem=8, grupo="evolucao",
        desc="open medieval stable seen from the front, wooden frame with a "
             "red clay tile roof, a brown horse standing inside, hay bales "
             "beside it, isolated"),
    "pan_casa_vermelha": dict(w=76, h=72, tipo="peca", ordem=8, grupo="evolucao",
        desc="two-story medieval townhouse seen from the front, timber frame "
             "with cream plaster, red clay tiled roof, stone chimney, "
             "flower box under a window, isolated"),
    "pan_horta": dict(w=56, h=32, tipo="peca", ordem=8, grupo="evolucao",
        desc="small vegetable garden plot seen from a low angle, neat rows "
             "of green cabbages and orange carrots in dark soil inside a low "
             "wooden border, isolated"),

    # ================= VIDA =================
    "pan_galinha": dict(w=32, h=32, tipo="peca", ordem=10, grupo="vida", cobre=45,
        desc="one tiny white chicken with a red comb, side view, standing, "
             "isolated, nothing else"),
    "pan_porco": dict(w=32, h=32, tipo="peca", ordem=10, grupo="vida", cobre=50,
        desc="one tiny plump pink pig, side view, standing, isolated"),
    "pan_cavalo": dict(w=40, h=36, tipo="peca", ordem=10, grupo="vida", cobre=70,
        desc="one small brown horse with dark mane, side view, standing, "
             "isolated, nothing else"),

    # ================= ESTAÇÕES =================
    "pan_ceu_inverno": dict(w=LARGURA, h=104, tipo="faixa", ordem=0, grupo="estacao",
        desc="wide panoramic overcast winter sky, flat pale grey and cold "
             "off-white cloud banks, low contrast, no ground, no sun"),
    "pan_floresta_outono": dict(w=LARGURA, h=44, tipo="peca", ordem=4, grupo="estacao",
        desc="dense band of autumn treetops filling the width, warm ochre "
             "rust and olive foliage with layered hard shading, uneven top "
             "edge, flat bottom edge, no trunks, no ground"),
    "pan_floresta_inverno": dict(w=LARGURA, h=44, tipo="peca", ordem=4, grupo="estacao",
        desc="dense band of snow-laden conifer treetops filling the width, "
             "dark green under thick white snow caps, uneven top edge, flat "
             "bottom edge, no trunks, no ground"),
    "pan_campo_outono": dict(w=LARGURA, h=64, tipo="faixa", ordem=7, grupo="estacao",
        desc="the ENTIRE image is dry autumn meadow seen from a low angle, "
             "warm ochre and faded green grass with harvested stubble "
             "patches, completely OPAQUE edge to edge, no sky, no water, "
             "no buildings"),
    "pan_campo_inverno": dict(w=LARGURA, h=64, tipo="faixa", ordem=7, grupo="estacao",
        desc="the ENTIRE image is snow-covered meadow seen from a low angle, "
             "soft white drifts with dark earth and grass showing through in "
             "patches, completely OPAQUE edge to edge, no sky, no water, "
             "no buildings"),
}

CUSTO_BASE = 0.0079
PX_BASE = 64 * 64


def custo(spec: dict) -> float:
    return CUSTO_BASE * (spec["w"] * spec["h"]) / PX_BASE


def gerar(pid: str, spec: dict, segredo: str, forcar: bool) -> float:
    alvo = DESTINO / f"{pid}.png"
    if alvo.exists() and not forcar:
        print(f"  ⏭️  {pid} — já existe")
        return 0.0
    corpo = {
        "description": ", ".join([spec["desc"], ESTILO]),
        "negative_description": NEGATIVO,
        "image_size": {"width": spec["w"], "height": spec["h"]},
        "text_guidance_scale": 7.5,
        "no_background": spec["tipo"] == "peca",
        "outline": "selective outline",
        "shading": "flat shading",
        "detail": "medium detail",
        "view": "side",
    }
    r = requests.post(f"{BASE}/create-image-pixflux", json=corpo,
                      headers={"Authorization": f"Bearer {segredo}"}, timeout=300)
    if r.status_code >= 400:
        print(f"  ❌ {pid} — HTTP {r.status_code}: {r.text[:180]}")
        return 0.0
    dados = r.json()
    alvo.parent.mkdir(parents=True, exist_ok=True)
    alvo.write_bytes(base64.b64decode(dados["image"]["base64"]))
    gasto = float(dados.get("usage", {}).get("usd", 0.0))
    print(f"  ✅ {pid} → {spec['w']}x{spec['h']}  (US$ {gasto:.4f})")
    return gasto


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apenas", action="append", default=[])
    ap.add_argument("--grupo", choices=["base", "evolucao", "estacao", "vida"])
    ap.add_argument("--tudo", action="store_true")
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--forcar", action="store_true")
    args = ap.parse_args()

    if args.listar:
        total = 0.0
        for pid, s in sorted(CAMADAS.items(), key=lambda x: (x[1]["grupo"], x[1]["ordem"])):
            total += custo(s)
            print(f"  {s['grupo']:8} {pid:24} {s['w']:>4}x{s['h']:<4} ~US$ {custo(s):.4f}")
        print(f"\n  {len(CAMADAS)} camadas · estimativa total ~US$ {total:.2f}")
        return

    segredo = os.environ.get("PIXELLAB_SECRET", "")
    if not segredo:
        sys.exit("defina PIXELLAB_SECRET")

    if args.tudo:
        ids = list(CAMADAS)
    elif args.grupo:
        ids = [p for p, s in CAMADAS.items() if s["grupo"] == args.grupo]
    else:
        ids = args.apenas
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
