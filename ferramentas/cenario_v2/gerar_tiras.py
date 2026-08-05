#!/usr/bin/env python3
"""Tiras de largura/altura fixa para floresta e terreno (spec v4 §C).

Cada tira é UMA chamada de API que rende muitas peças: 5 variantes de
árvore numa tira de 128×64 custam o mesmo que um objeto isolado. As tiras
saem com alpha (`no_background`) e são fatiadas na Godot por AtlasTexture.

    python3 ferramentas/cenario_v2/gerar_tiras.py --floresta
    python3 ferramentas/cenario_v2/gerar_tiras.py --terreno trilhas
"""

import argparse
import base64
import io
import sys
from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from estilo_cena import corpo_objeto  # noqa: E402
from pipeline_cenario import SAIDA, _chamar  # noqa: E402

TIRAS = {
    "floresta": dict(
        w=160, h=64, seed=4101, arquivo="tiras/floresta_variantes.png",
        prompt="a horizontal row of five separate trees standing side by "
               "side with clear gaps between them, from left to right: a "
               "tall narrow pine, a short wide pine, a medium pine, a round "
               "leafy oak, a smaller leafy birch; each tree complete from "
               "trunk base to crown, five distinct silhouettes, no ground, "
               "no grass, no soil under the trunks"),
    "trilhas": dict(
        w=400, h=64, seed=4102, arquivo="tiras/terreno_trilhas.png",
        prompt="a top-down band of bare packed dirt ground on transparent "
               "background: a wide beaten earth road running left to right "
               "with soft irregular edges, a cobbled open square, and small "
               "patches of trampled bare soil; only the dirt shapes, "
               "surrounded by full transparency, no grass, no buildings, "
               "no people, no fence"),
    "cultivo": dict(
        w=400, h=64, seed=4103, arquivo="tiras/terreno_cultivo.png",
        prompt="a band of small medieval vegetable garden plots on "
               "transparent background: rectangular tilled beds with rows of "
               "green crops, low wooden post-and-rail fences around them, "
               "a few hay piles; only the plots and fences, surrounded by "
               "full transparency, no ground fill, no buildings"),
    "sub_bosque": dict(
        w=400, h=24, seed=4104, arquivo="tiras/terreno_sub_bosque.png",
        prompt="a horizontal band of forest undergrowth on transparent "
               "background: low leafy bushes, ferns, mossy rocks and cut "
               "tree stumps of varied heights scattered with irregular "
               "spacing and gaps; only the plants and rocks, surrounded by "
               "full transparency, no ground fill, no trees, no sky"),
}


def gerar(nome: str) -> Path:
    spec = TIRAS[nome]
    alvo = SAIDA / spec["arquivo"]
    if alvo.exists():
        print(f"  ⏭️  {alvo.name} já existe — apague para regerar")
        return alvo
    corpo = corpo_objeto(spec["prompt"], spec["w"], spec["h"],
                         seed=spec["seed"])
    dados = _chamar("/create-image-pixflux", corpo,
                    f"tira {nome} {spec['w']}x{spec['h']}", 0.008)
    img = Image.open(io.BytesIO(base64.b64decode(dados["image"]["base64"])))
    alvo.parent.mkdir(parents=True, exist_ok=True)
    img.save(alvo)
    print(f"  💾 {alvo.relative_to(SAIDA)} ({img.width}x{img.height})")
    return alvo


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("tiras", nargs="+", choices=sorted(TIRAS))
    for t in ap.parse_args().tiras:
        gerar(t)
