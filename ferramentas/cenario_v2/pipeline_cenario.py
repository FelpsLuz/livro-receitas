#!/usr/bin/env python3
"""PIPELINE DE CENÁRIO v2 — objetos isolados; coesão na Godot (addendum v3).

O piloto C2 (inpaint-then-diff com máscara em anel) foi aprovado como
experimento e REJEITADO para o lote — o anel de blend é visível e quebra a
matriz 6 níveis × 3 estações × 4 céus (v3 §A). O código vive documentado em
ferramentas/experimental/c2_anel.py, junto com o achado que vale guardar: o
/v2/inpaint básico NÃO INSERE objeto semântico — só harmoniza contexto.

O pipeline de produção (v3 §B): 1 chamada por objeto, create-image-pixflux
com no_background, tamanho 1:1, ESTILO_CENA congelado + SUFIXO_LUZ +
SUFIXO_PERSPECTIVA. Sombra de contato é nó da Godot (v3 §C); paleta e
estação são shader de tela (v3 §D); integração com o chão é camada de
terreno autorada uma vez (v3 §B.2).

Limite duro do /v2/inpaint, se algum uso futuro precisar dele: área ≤
40.000px (o canvas tem 80.000 — o 422 está documentado no v2.1 §A).

    python3 pipeline_cenario.py --placa
    python3 pipeline_cenario.py --objeto casa_sape
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import sys
import os
import time
from pathlib import Path

import numpy as np
import requests
from PIL import Image

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from bandas import BANDAS, CANVAS_H, CANVAS_W, CASTELO_BASE, CASTELO_TOPO, validar  # noqa: E402
from estilo_cena import NEGATIVO, corpo_base  # noqa: E402

RAIZ = AQUI.parent.parent
API = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
SAIDA = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario"
GASTO_ARQ = RAIZ / "ferramentas" / "gasto_cenario.json"

TETO_USD = 1.50
JANELA_MAX_AREA = 40_000
JANELA_PADRAO = (128, 128)
JANELA_GRANDE = (192, 160)
MARGEM_CONTEXTO = 24        # mínimo de cena real em volta do bbox (addendum §B.1)
FOLGA_MASCARA = 4           # a máscara cobre o bbox + isto (addendum §B.2)
TOL_DIFF = 12               # limiar inicial do diff (addendum §B.3)
CANARIO_LIMITE = 0.02       # >2% fora da máscara = endpoint mexeu no global


# ------------------------------------------------------------------
# guarda de orçamento — incrementa ANTES da chamada (addendum §G)
# ------------------------------------------------------------------
def _gasto_ler() -> dict:
    if GASTO_ARQ.exists():
        return json.loads(GASTO_ARQ.read_text())
    return {"total_usd": 0.0, "chamadas": []}


def _gasto_gravar(g: dict) -> None:
    GASTO_ARQ.write_text(json.dumps(g, indent=1))


def _guarda_orcamento(rotulo: str, estimado: float) -> dict:
    g = _gasto_ler()
    if g["total_usd"] + estimado > TETO_USD:
        sys.exit(f"🛑 TETO DE US$ {TETO_USD:.2f} atingido "
                 f"(acumulado {g['total_usd']:.4f} + {estimado:.4f}). "
                 f"Parando e aguardando autorização.")
    # o incremento acontece ANTES da chamada; o valor real substitui depois
    g["chamadas"].append({"rotulo": rotulo, "estimado": estimado, "real": None})
    g["total_usd"] += estimado
    _gasto_gravar(g)
    # divergência real vs estimado > 50% após 5 chamadas → parar (addendum §G)
    reais = [c for c in g["chamadas"] if c["real"] is not None]
    if len(reais) >= 5:
        est = sum(c["estimado"] for c in reais)
        real = sum(c["real"] for c in reais)
        if est > 0 and abs(real - est) / est > 0.5:
            sys.exit(f"🛑 gasto real US$ {real:.4f} diverge >50% do estimado "
                     f"US$ {est:.4f} — tier de cobrança diferente do previsto.")
    return g


def _gasto_confirmar(g: dict, real: float) -> None:
    ult = g["chamadas"][-1]
    g["total_usd"] += real - ult["estimado"]
    ult["real"] = real
    _gasto_gravar(g)


# ------------------------------------------------------------------
# HTTP
# ------------------------------------------------------------------
def _chamar(endpoint: str, corpo: dict, rotulo: str, estimado: float) -> dict:
    segredo = os.environ.get("PIXELLAB_SECRET", "")
    if not segredo:
        sys.exit("defina PIXELLAB_SECRET")
    g = _guarda_orcamento(rotulo, estimado)
    r = requests.post(f"{API}{endpoint}", json=corpo,
                      headers={"Authorization": f"Bearer {segredo}"}, timeout=300)
    if r.status_code >= 400:
        _gasto_confirmar(g, 0.0)
        sys.exit(f"❌ {rotulo}: HTTP {r.status_code} — {r.text[:300]}")
    dados = r.json()
    # llms.txt: "a maioria dos endpoints de geração é assíncrona — devolvem um
    # job id que se consulta até ficar pronto". O síncrono devolve `image`
    # direto; o assíncrono devolve job para /background-jobs/{id}.
    if "image" not in dados or dados.get("image") is None:
        job = dados.get("background_job_id") or dados.get("job_id") \
            or dados.get("id")
        if not job:
            _gasto_confirmar(g, 0.0)
            sys.exit(f"❌ {rotulo}: resposta sem imagem nem job: "
                     f"{json.dumps(dados)[:300]}")
        for tentativa in range(120):
            time.sleep(3)
            try:
                rj = requests.get(f"{API}/background-jobs/{job}",
                                  headers={"Authorization": f"Bearer {segredo}"},
                                  timeout=60)
                dj = rj.json()
            except requests.exceptions.RequestException:
                continue          # reset de conexão no polling não é fracasso
            estado = str(dj.get("status", "")).lower()
            if estado in ("completed", "done", "finished", "succeeded"):
                # a imagem vem em last_response; o usage vem na raiz do job
                dados = dj.get("last_response") or dj
                if dj.get("usage") and not dados.get("usage"):
                    dados["usage"] = dj["usage"]
                break
            if estado in ("failed", "error", "cancelled"):
                _gasto_confirmar(g, 0.0)
                sys.exit(f"❌ {rotulo}: job {estado}: {json.dumps(dj)[:300]}")
        else:
            _gasto_confirmar(g, 0.0)
            sys.exit(f"❌ {rotulo}: job não terminou em 6min")
    real = float((dados.get("usage") or {}).get("usd", 0.0))
    _gasto_confirmar(g, real)
    print(f"  ✅ {rotulo}  (US$ {real:.4f} · acumulado "
          f"US$ {_gasto_ler()['total_usd']:.4f} de {TETO_USD:.2f})")
    return dados


def _b64_para_img(b64: str) -> Image.Image:
    return Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")


def _img_para_b64(img: Image.Image) -> dict:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode()}


# ------------------------------------------------------------------
# §J passo 3 — a placa base
# ------------------------------------------------------------------
PROMPT_PLACA = (
    "wide medieval landscape in strict front elevation, composed in "
    "horizontal bands: warm blue summer sky with puffy clouds in the top "
    "quarter, a RANGE of several distant rocky peaks with hazy atmospheric "
    "blue tone across the upper middle, a dense unbroken band of dark green "
    "conifer forest below the peaks, then a wide FLAT EMPTY lush green "
    "meadow filling almost HALF of the image height from edge to edge, "
    "and a calm deep blue river as a NARROW straight horizontal strip "
    "along the very bottom edge, the river no taller than one tenth of "
    "the image, with a thin grassy near bank in front of it, "
    "COMPLETELY EMPTY of buildings, no people, no roads, no paths, no "
    "fences, no animals, NO tree in the foreground, NO tall grass in the "
    "corners, no bushes in the corners, no winding river, distant elements desaturated toward the "
    "sky color"
)


def gerar_placa(forcar: bool = False) -> Path:
    alvo = SAIDA / "base" / "placa_base.png"
    par = SAIDA / "base" / "placa_base.json"
    if alvo.exists() and not forcar:
        print(f"  ⏭️  placa base já existe ({alvo}) — NUNCA regenerar (spec §2.1)")
        return alvo
    if alvo.exists():
        sys.exit("🛑 --forcar-placa invalidaria TODOS os diffs já extraídos. "
                 "Apague o cache manualmente se for mesmo intencional.")
    corpo = corpo_base(PROMPT_PLACA, CANVAS_W, CANVAS_H)
    print(f"  lote: 1 chamada · estimado US$ 0.013")
    dados = _chamar("/create-image-pixflux-background", corpo,
                    "placa_base 400x200", 0.013)
    img = _b64_para_img(dados["image"]["base64"])
    alvo.parent.mkdir(parents=True, exist_ok=True)
    img.save(alvo)
    par.write_text(json.dumps({
        "endpoint": "/create-image-pixflux-background",
        "corpo": {k: v for k, v in corpo.items()},
        "usd": dados.get("usage", {}).get("usd"),
        "gerada_em": "2026-08-05",
    }, indent=1))
    print(f"  💾 {alvo} + parâmetros em {par.name}")
    return alvo


# ------------------------------------------------------------------
# janela de contexto ≤ 40.000px — infra mantida pelo veredito v3 §A
# (usos futuros de inpaint passam por aqui; o lote de objetos não usa)
# ------------------------------------------------------------------
def _janela_para(cx: int, cy: int, bw: int, bh: int,
                 tam: tuple[int, int]) -> tuple[int, int, int, int]:
    """Janela centrada no alvo, deslocada PARA DENTRO se vazar (sem padding —
    padding artificial envenena o contexto do modelo, addendum §B.1)."""
    w, h = tam
    assert w * h <= JANELA_MAX_AREA, f"janela {w}x{h} > {JANELA_MAX_AREA}"
    assert w >= bw + 2 * MARGEM_CONTEXTO and h >= bh + 2 * MARGEM_CONTEXTO, \
        f"janela {w}x{h} sem margem de {MARGEM_CONTEXTO}px para bbox {bw}x{bh}"
    x = max(0, min(CANVAS_W - w, cx - w // 2))
    y = max(0, min(CANVAS_H - h, cy - h // 2))
    return x, y, w, h


# ------------------------------------------------------------------
# addendum v3 §B — objeto ISOLADO com alpha; coesão é da Godot
# ------------------------------------------------------------------
CAMPO_A, CAMPO_B = BANDAS["campo"]

# posição FINAL nas bandas (para a composição na Godot) + prompt.
# O lote completo (19 objetos + variantes) entra aqui após o aval do §I.6.
OBJETOS = {
    "casa_sape": dict(
        cx=112, base=CAMPO_A + 44, w=48, h=44, seed=77,
        prompt="a charming small medieval peasant cottage, thatched straw "
               "roof, timber frame walls, wooden door and one window, game "
               "sprite floating ALONE on a transparent background, "
               "nothing else"),
}


def gerar_objeto_isolado(objeto: str, paleta_b64: dict | None = None) -> Path:
    """1 chamada por objeto (v3 §B): pixflux, no_background, tamanho 1:1.

    Sem janela, sem placa, sem diff, sem extração: o objeto sai com alpha
    limpo, modular e agnóstico de estação. Sombra de contato é nó da Godot
    (v3 §C); estação é shader de tela (v3 §D). `paleta_b64` recebe a paleta
    mestre como color_image quando ela existir (§D.4).

    Aceite de perspectiva (v3 §B.1): topo de telhado visível como
    superfície = 3/4 = rejeitar e regerar com outra seed.
    """
    spec = OBJETOS[objeto]
    alvo = SAIDA / "sprites" / f"{objeto}.png"
    if alvo.exists():
        print(f"  ⏭️  sprite já existe ({alvo.name}) — apague para regerar")
        return alvo
    corpo = corpo_objeto(spec["prompt"], spec["w"], spec["h"],
                         seed=spec["seed"])
    if paleta_b64 is not None:
        corpo["color_image"] = paleta_b64
    dados = _chamar("/create-image-pixflux", corpo,
                    f"sprite {objeto} {spec['w']}x{spec['h']}", 0.008)
    img = Image.open(io.BytesIO(base64.b64decode(
        dados["image"]["base64"])))
    alvo.parent.mkdir(parents=True, exist_ok=True)
    img.save(alvo)
    print(f"  💾 {alvo.name} ({img.width}x{img.height})")
    return alvo


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--placa", action="store_true")
    ap.add_argument("--forcar-placa", action="store_true")
    ap.add_argument("--objeto", help="gera 1 objeto isolado do catálogo "
                    "(v3 §B) — o lote completo espera o aval do §I.6")
    args = ap.parse_args()
    assert not validar(), "bandas inválidas"
    if args.placa or args.forcar_placa:
        gerar_placa(args.forcar_placa)
    if args.objeto:
        gerar_objeto_isolado(args.objeto)


if __name__ == "__main__":
    main()
