#!/usr/bin/env python3
"""PIPELINE DE CENÁRIO v2 — inpaint-then-diff em janela de contexto.

A técnica (spec §2 + addendum §B): os objetos NÃO nascem em chamadas isoladas
— nascem DENTRO da cena. Recorta-se uma janela da placa base ao redor da
posição final, o /inpaint desenha o objeto ali com o entorno real à vista, e
a camada sai por DIFERENÇA contra a placa. Luz, paleta, escala e sombra de
contato vêm corretas por construção, porque o modelo viu a grama em que o
objeto pisa.

Limite duro do /v2/inpaint: área ≤ 40.000px (200×200). O canvas tem 80.000 —
por isso a janela, nunca o canvas cheio (addendum §A/§B, o 422 documentado).

    python3 pipeline_cenario.py --placa
    python3 pipeline_cenario.py --piloto          # 1 objeto, para e reporta
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
# addendum §B — janela, máscara, inpaint, diff, sombra
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


def _componentes_pequenos(mask: np.ndarray, minimo: int = 4) -> np.ndarray:
    """Remove componentes conexos com área < minimo (mata ruído de dither)."""
    try:
        from scipy import ndimage
        rot, n = ndimage.label(mask)
        tam = np.bincount(rot.ravel())
        ruim = np.isin(rot, np.nonzero(tam < minimo)[0])
        return mask & ~ruim
    except ImportError:
        # BFS 4-conexo em numpy puro: janelas são pequenas, custo irrelevante
        vis = np.zeros_like(mask, bool)
        out = mask.copy()
        H, W = mask.shape
        for yy in range(H):
            for xx in range(W):
                if mask[yy, xx] and not vis[yy, xx]:
                    pilha = [(yy, xx)]
                    comp = []
                    vis[yy, xx] = True
                    while pilha:
                        a, b = pilha.pop()
                        comp.append((a, b))
                        for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            na, nb = a + da, b + db
                            if 0 <= na < H and 0 <= nb < W and \
                                    mask[na, nb] and not vis[na, nb]:
                                vis[na, nb] = True
                                pilha.append((na, nb))
                    if len(comp) < minimo:
                        for a, b in comp:
                            out[a, b] = False
        return out


def _fechamento(mask: np.ndarray) -> np.ndarray:
    """binary_closing raio 1 (dilata e erode com cruz 3×3): fecha buracos."""
    def _dilata(m):
        r = m.copy()
        r[1:, :] |= m[:-1, :]; r[:-1, :] |= m[1:, :]
        r[:, 1:] |= m[:, :-1]; r[:, :-1] |= m[:, 1:]
        return r
    def _erode(m):
        r = m.copy()
        r[1:, :] &= m[:-1, :]; r[:-1, :] &= m[1:, :]
        r[:, 1:] &= m[:, :-1]; r[:, :-1] &= m[:, 1:]
        return r
    return _erode(_dilata(mask))


def _luminancia(rgb: np.ndarray) -> np.ndarray:
    lin = (rgb / 255.0) ** 2.2
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def _matiz(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0] / 255.0, rgb[..., 1] / 255.0, rgb[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = mx - mn
    h = np.zeros_like(mx)
    seg = d > 1e-6
    h = np.where(seg & (mx == r), ((g - b) / np.where(d == 0, 1, d)) % 6, h)
    h = np.where(seg & (mx == g), (b - r) / np.where(d == 0, 1, d) + 2, h)
    h = np.where(seg & (mx == b), (r - g) / np.where(d == 0, 1, d) + 4, h)
    return h / 6.0


def extrair(base_j: np.ndarray, gerada_j: np.ndarray,
            masc_inpaint: np.ndarray, debug_dir: Path | None = None,
            rotulo: str = "") -> dict:
    """Diff, canário, separação de sombra — addendum §B.3/§B.4, literal."""
    d = np.abs(gerada_j.astype(int) - base_j.astype(int)).sum(axis=2)   # 0..765

    # ---- canário: o modelo mexeu FORA da máscara? ----
    fora = ~masc_inpaint
    fora_alterado = float(((d > TOL_DIFF) & fora).sum() / max(1, fora.sum()))
    tol = TOL_DIFF
    if fora_alterado > CANARIO_LIMITE:
        # o endpoint requantizou o global: recalibrar TOL DENTRO da região
        # pelo piso de ruído medido fora dela (addendum §B.3)
        ruido = np.percentile(d[fora], 99)
        tol = max(TOL_DIFF, int(ruido) + 2)
        print(f"  \033[91m🔴 canário {rotulo}: {fora_alterado:.1%} fora da "
              f"máscara (> {CANARIO_LIMITE:.0%}) — TOL recalibrado para {tol}"
              f"\033[0m")
    else:
        print(f"  🟢 canário {rotulo}: {fora_alterado:.2%} fora da máscara")

    mask = (d > tol) & masc_inpaint
    mask = _componentes_pequenos(mask, 4)
    mask = _fechamento(mask)

    # ---- sombra separada (spec §2.4): mesma cor, só escurecida ----
    Lb = _luminancia(base_j)
    Lg = _luminancia(gerada_j)
    razao = Lg / np.maximum(Lb, 1e-6)
    dh = np.abs(_matiz(gerada_j) - _matiz(base_j))
    dh = np.minimum(dh, 1.0 - dh)                    # matiz é circular
    sombra = mask & (razao >= 0.55) & (razao <= 0.92) & (dh < 0.06)
    objeto = mask & ~sombra

    if debug_dir is not None:
        debug_dir.mkdir(parents=True, exist_ok=True)
        Image.fromarray((d.clip(0, 255)).astype(np.uint8)).save(
            debug_dir / f"{rotulo}_diff.png")
        Image.fromarray((mask * 255).astype(np.uint8)).save(
            debug_dir / f"{rotulo}_mask.png")
    return {"objeto": objeto, "sombra": sombra, "fora_pct": fora_alterado,
            "tol": tol}


# ------------------------------------------------------------------
# catálogo de objetos: posição FINAL nas bandas + prompts
# (o piloto usa só casa_sape; o lote completo espera o aval do passo 5)
# ------------------------------------------------------------------
CAMPO_A, CAMPO_B = BANDAS["campo"]
OBJETOS = {
    "casa_sape": dict(
        cx=112, base=CAMPO_A + 44, bw=48, bh=44, janela=JANELA_PADRAO,
        seed_sprite=77, seed_anel=1003,
        prompt_sprite="a charming small medieval peasant cottage, thatched "
                      "straw roof, timber frame walls, wooden door and one "
                      "window, game sprite floating ALONE on a transparent "
                      "background, nothing else",
        prompt_anel="a small medieval peasant cottage standing in a green "
                    "meadow, trampled grass and a soft contact shadow at "
                    "its base cast to the lower left"),
}

FOLGA_ANEL = 10             # o anel harmonizador em volta do bbox do sprite


def gerar_objeto(objeto: str) -> None:
    """Técnica C2 — a EMENDA à spec §2, validada no piloto (addendum §B.5).

    O /v2/inpaint básico NÃO INSERE objeto semântico na máscara — comprovado
    em 3 tentativas registradas no gasto: guidance 7.5 → só grama; guidance
    10.0 (máximo da API; 15 → 422) → borrão; sprite colado DENTRO da máscara
    → apagado, porque pixels mascarados são regenerados do zero. O endpoint
    só harmoniza/completa contexto.

    O fluxo que funciona (2 chamadas, ~US$ 0.016/objeto — o dobro do
    estimado na spec):
      1. sprite isolado no /create-image-pixflux (no_background, luz §D);
      2. sprite COLADO na janela da placa; máscara em ANEL = bbox+10 por
         fora MENOS a silhueta erodida 1px — o modelo vê a casa como
         CONTEXTO intocável e repinta só o entorno: grama pisada + sombra
         de contato na direção da luz;
      3. diff contra a placa LIMPA com a máscara CHEIA (bbox+10): captura o
         sprite colado + o que o anel desenhou; canário mede fora dela.
    """
    spec = OBJETOS[objeto]
    placa = Image.open(SAIDA / "base" / "placa_base.png").convert("RGB")
    base = np.array(placa)
    deb = Path("/tmp/piloto_cenario")
    deb.mkdir(parents=True, exist_ok=True)

    # ---- 1. sprite isolado (cacheado: regenerar mudaria o diff já aceito) ----
    sprite_arq = SAIDA / "sprites" / f"{objeto}.png"
    if sprite_arq.exists():
        sprite = Image.open(sprite_arq).convert("RGBA")
        print(f"  ⏭️  sprite cacheado ({sprite_arq.name})")
    else:
        corpo = corpo_base(spec["prompt_sprite"], spec["bw"], spec["bh"],
                           seed=spec["seed_sprite"])
        corpo["no_background"] = True
        dados = _chamar("/create-image-pixflux", corpo,
                        f"sprite {objeto} {spec['bw']}x{spec['bh']}", 0.008)
        sprite = Image.open(io.BytesIO(base64.b64decode(
            dados["image"]["base64"]))).convert("RGBA")
        sprite_arq.parent.mkdir(parents=True, exist_ok=True)
        sprite.save(sprite_arq)
    bw, bh = sprite.width, sprite.height

    # ---- 2. janela + colagem + máscara em anel ----
    cy = spec["base"] - bh // 2
    jx, jy, jw, jh = _janela_para(spec["cx"], cy, bw, bh, spec["janela"])
    print(f"  janela: offset=({jx},{jy}) tam={jw}x{jh} "
          f"área={jw * jh} ≤ {JANELA_MAX_AREA}")
    base_j = base[jy:jy + jh, jx:jx + jw]
    ox, oy = spec["cx"] - jx - bw // 2, spec["base"] - jy - bh
    colada = Image.fromarray(base_j.copy()).convert("RGBA")
    colada.alpha_composite(sprite, (ox, oy))
    colada_rgb = colada.convert("RGB")

    F = FOLGA_ANEL
    cheia = np.zeros((jh, jw), bool)                    # bbox+F: p/ diff
    cheia[max(0, oy - F):oy + bh + F, max(0, ox - F):ox + bw + F] = True
    sil = np.zeros((jh, jw), bool)
    sa = np.array(sprite)[..., 3] > 10
    sil[oy:oy + bh, ox:ox + bw] = sa
    er = sil.copy()                                     # erode 1px: o modelo
    er[1:, :] &= sil[:-1, :]; er[:-1, :] &= sil[1:, :]  # pode retocar a borda
    er[:, 1:] &= sil[:, :-1]; er[:, :-1] &= sil[:, 1:]
    anel = cheia & ~er
    masc_img = Image.fromarray((anel * 255).astype(np.uint8)).convert("RGB")

    # ---- 3. harmonização do anel ----
    corpo = corpo_base(spec["prompt_anel"], jw, jh, seed=spec["seed_anel"])
    corpo["inpainting_image"] = _img_para_b64(colada_rgb)
    corpo["mask_image"] = _img_para_b64(masc_img)
    dados = _chamar("/inpaint", corpo, f"anel {objeto}", 0.008)
    gerada_j = np.array(_b64_para_img(dados["image"]["base64"]))

    # ---- 4. diff contra a PLACA com a máscara CHEIA ----
    res = extrair(base_j, gerada_j, cheia, deb, f"{objeto}_anel")

    rgba = np.dstack([gerada_j, (res["objeto"] * 255).astype(np.uint8)])
    camada = SAIDA / "camadas" / f"{objeto}.png"
    camada.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(camada)
    sombra_a = (res["sombra"] * 255).astype(np.uint8)
    sombra_rgba = np.dstack([np.zeros_like(gerada_j), sombra_a])
    sombra_arq = SAIDA / "sombras" / f"{objeto}.png"
    sombra_arq.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sombra_rgba, "RGBA").save(sombra_arq)

    manif_arq = SAIDA / "manifesto.json"
    manif = json.loads(manif_arq.read_text()) if manif_arq.exists() else {}
    manif[objeto] = {
        "camada": f"camadas/{objeto}.png", "sombra": f"sombras/{objeto}.png",
        "janela": [jx, jy, jw, jh], "fora_pct": round(res["fora_pct"], 4),
        "tol": res["tol"], "px_objeto": int(res["objeto"].sum()),
        "px_sombra": int(res["sombra"].sum()),
        "tecnica": "C2: sprite colado FORA da máscara + anel harmonizador",
    }
    manif_arq.write_text(json.dumps(manif, indent=1))

    # material do relatório (addendum §B.5)
    Image.fromarray(base_j).save(deb / f"{objeto}_janela.png")
    colada_rgb.save(deb / f"{objeto}_colada.png")
    Image.fromarray(gerada_j).save(deb / f"{objeto}_anel_retorno.png")
    masc_img.save(deb / f"{objeto}_anel_mascara.png")
    print(f"  💾 camada {camada.name}: {int(res['objeto'].sum())}px de objeto, "
          f"{int(res['sombra'].sum())}px de sombra")


def piloto(objeto: str = "casa_sape") -> None:
    gerar_objeto(objeto)
    print(f"  📋 manifesto atualizado — PARANDO no piloto (addendum §B.5)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--placa", action="store_true")
    ap.add_argument("--piloto", action="store_true")
    ap.add_argument("--forcar-placa", action="store_true")
    args = ap.parse_args()
    assert not validar(), "bandas inválidas"
    if args.placa or args.forcar_placa:
        gerar_placa(args.forcar_placa)
    if args.piloto:
        piloto()


if __name__ == "__main__":
    main()
