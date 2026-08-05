#!/usr/bin/env python3
"""C2 — máscara em anel: EXPERIMENTO validado, REJEITADO para o lote.

Preservado pelo addendum v3 §A ("foi caro de descobrir, não se joga fora").
Este arquivo NÃO faz parte do pipeline de produção — o pipeline atual gera
objetos isolados com alpha (`create-image-pixflux`, `no_background`) e resolve
sombra/coesão dentro da Godot (addendum v3 §B/§C).

O QUE O EXPERIMENTO PROVOU (piloto casa_sape, 2026-08-05)
---------------------------------------------------------
1. O `/v2/inpaint` básico NÃO INSERE objeto semântico na máscara:
   - guidance 7.5 → devolveu só grama;
   - guidance 10.0 (máximo da API; 15 → HTTP 422) → borrão;
   - sprite colado DENTRO da máscara → apagado (pixels mascarados são
     regenerados do zero, o conteúdo colado ali não é visto como contexto).
   O endpoint só harmoniza/completa contexto — achado documentado, vale
   para qualquer uso futuro do inpaint.
2. A técnica que FUNCIONOU (este arquivo): colar o sprite na janela da placa
   e mascarar um ANEL em volta (bbox+10 MENOS a silhueta erodida 1px). O
   modelo vê o sprite como contexto intocável e repinta só o entorno —
   grama pisada + sombra de contato. Canário: 0,00% alterado fora da máscara.

POR QUE FOI REJEITADO PARA O LOTE (addendum v3 §A)
--------------------------------------------------
- O anel de blend é visível (mancha retangular de verde divergente).
- Quebra a matriz combinatória 6 níveis × 3 estações × 4 céus: cada camada
  carrega grama-de-verão assada de uma posição específica.
- Custo 2× por objeto (sprite + anel) para produzir esse problema.
- A "sombra extraída" pelo classificador L-ratio era ruído (salpicos na
  copa das árvores), não sinal.

Uso (por sua conta, fora do orçamento do pipeline):
    PIXELLAB_SECRET=... python3 ferramentas/experimental/c2_anel.py
"""

import base64
import io
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
import requests
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(RAIZ / "ferramentas" / "cenario_v2"))
from bandas import BANDAS                             # noqa: E402
from estilo_cena import corpo_base                    # noqa: E402
from pipeline_cenario import (                        # noqa: E402
    JANELA_PADRAO, SAIDA, _b64_para_img, _chamar, _img_para_b64,
    _janela_para,
)

TOL_DIFF = 12
CANARIO_LIMITE = 0.02
FOLGA_ANEL = 10


def _componentes_pequenos(mask: np.ndarray, minimo: int) -> np.ndarray:
    """Remove componentes 4-conexos com menos de `minimo` pixels."""
    H, W = mask.shape
    vis = np.zeros_like(mask, bool)
    out = mask.copy()
    for i in range(H):
        for j in range(W):
            if mask[i, j] and not vis[i, j]:
                pilha, comp = [(i, j)], []
                vis[i, j] = True
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
    """Diff + canário + classificador de sombra L-ratio (v2.1 §B.3/§B.4).

    O classificador de sombra foi REJEITADO (v3 §A: "a sombra extraída é
    ruído") — preservado aqui apenas como registro do experimento.
    """
    d = np.abs(gerada_j.astype(int) - base_j.astype(int)).sum(axis=2)

    fora = ~masc_inpaint
    fora_alterado = float(((d > TOL_DIFF) & fora).sum() / max(1, fora.sum()))
    tol = TOL_DIFF
    if fora_alterado > CANARIO_LIMITE:
        ruido = np.percentile(d[fora], 99)
        tol = max(TOL_DIFF, int(ruido) + 2)
        print(f"  🔴 canário {rotulo}: {fora_alterado:.1%} fora da máscara "
              f"— TOL recalibrado para {tol}")
    else:
        print(f"  🟢 canário {rotulo}: {fora_alterado:.2%} fora da máscara")

    mask = (d > tol) & masc_inpaint
    mask = _componentes_pequenos(mask, 4)
    mask = _fechamento(mask)

    Lb = _luminancia(base_j)
    Lg = _luminancia(gerada_j)
    razao = Lg / np.maximum(Lb, 1e-6)
    dh = np.abs(_matiz(gerada_j) - _matiz(base_j))
    dh = np.minimum(dh, 1.0 - dh)
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


def anel_casa_sape() -> None:
    """A execução exata do piloto aprovado como experimento (§B.5 do v2.1)."""
    sprite = Image.open(SAIDA / "sprites" / "casa_sape.png").convert("RGBA")
    placa = Image.open(SAIDA / "base" / "placa_base.png").convert("RGB")
    base = np.array(placa)
    campo_a, _ = BANDAS["campo"]
    cx, base_y, bw, bh = 112, campo_a + 44, sprite.width, sprite.height
    jx, jy, jw, jh = _janela_para(cx, base_y - bh // 2, bw, bh, JANELA_PADRAO)
    base_j = base[jy:jy + jh, jx:jx + jw]
    colada = Image.fromarray(base_j.copy()).convert("RGBA")
    ox, oy = cx - jx - bw // 2, base_y - jy - bh
    colada.alpha_composite(sprite, (ox, oy))
    colada_rgb = colada.convert("RGB")

    F = FOLGA_ANEL
    m = np.zeros((jh, jw), bool)
    m[max(0, oy - F):oy + bh + F, max(0, ox - F):ox + bw + F] = True
    sil = np.zeros((jh, jw), bool)
    sa = np.array(sprite)[..., 3] > 10
    sil[oy:oy + bh, ox:ox + bw] = sa
    er = sil.copy()
    er[1:, :] &= sil[:-1, :]; er[:-1, :] &= sil[1:, :]
    er[:, 1:] &= sil[:, :-1]; er[:, :-1] &= sil[:, 1:]
    m &= ~er

    corpo = corpo_base("a small medieval peasant cottage standing in a green "
                       "meadow, trampled grass and a soft contact shadow at "
                       "its base cast to the lower left", jw, jh, seed=1003)
    corpo["inpainting_image"] = _img_para_b64(colada_rgb)
    corpo["mask_image"] = _img_para_b64(
        Image.fromarray((m * 255).astype(np.uint8)).convert("RGB"))
    dados = _chamar("/inpaint", corpo, "anel casa_sape (experimental)", 0.008)
    gerada = np.array(_b64_para_img(dados["image"]["base64"]))

    m_total = np.zeros((jh, jw), bool)
    m_total[max(0, oy - F):oy + bh + F, max(0, ox - F):ox + bw + F] = True
    res = extrair(base_j, gerada, m_total, Path("/tmp/piloto_cenario"),
                  "casa_anel")
    print(f"objeto {int(res['objeto'].sum())}px · "
          f"sombra {int(res['sombra'].sum())}px")


if __name__ == "__main__":
    anel_casa_sape()
