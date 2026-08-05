#!/usr/bin/env python3
"""Paleta mestra por EXTENSÃO DE RAMPA em OKLab (spec v4 §C.2).

Não é k-means. O render tem >1000 cores porque os véus são operações
contínuas sobre ~60 cores de arte; rodar k-means no render envernizado
produziria dezenas de quase-duplicatas e uma paleta lamacenta. O método
correto parte da ARTE:

  1. reúne as cores de todos os assets autorais (placa de origem + tiras
     geradas + sprites), que são poucas e limpas;
  2. agrupa em RAMPAS por matiz/croma em OKLab — cada rampa é uma família
     (verde de copa, azul de água, tan de rocha, creme de nuvem…);
  3. ESTENDE cada rampa com degraus intermediários onde há vão de
     luminosidade, que é exatamente onde os véus vão pousar;
  4. corta em 56 no máximo — passar disso é sinal de rampa esticada demais.

Saída: paleta_mestra.png (N×1) + as 5 paletas de estação, cada uma a
mestra passada pelo grade da estação e deduplicada, para a cor de saída
cair EXATAMENTE numa entrada.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
CEN = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario"
SAIDA = CEN / "paletas"

ALVO_MIN, ALVO_MAX = 48, 64   # 64 é o teto duro do v4 §C.2; o campo
#   precisa dos degraus extras: com 56 o gradiente do véu virava plateau
#   de 11px, e dither não resolve (dentro do plateau os dois vizinhos de
#   paleta não empatam — falta degrau, não desempate).
# Vagas reservadas para onde os VÉUS pousam. A arte é fundida até
# ARTE_MAX para sobrar espaço: sem isso as 103 cores autorais comiam a
# paleta inteira e o campo, empurrado pelo véu de valor, ia parar num tom
# amarelado por falta de degrau verde escuro. Medido no render.
ARTE_MAX = 38
_PESO = np.zeros(0, dtype=np.int64)   # pixels por cor, preenchido em construir()
TETO = 64
VAO_MINIMO = 0.055        # vão de L em OKLab que merece degrau intermediário

# Presets de estação (v3 §D.3): tint, saturação, luminância.
ESTACOES = {
    "verao":      ((1.00, 1.00, 1.00), 1.00, 1.00),
    "entardecer": ((1.12, 0.94, 0.80), 1.05, 0.95),
    "tempestade": ((0.88, 0.92, 1.05), 0.70, 0.85),
    "outono":     ((1.08, 0.96, 0.82), 1.10, 1.00),
    "inverno":    ((0.92, 0.96, 1.06), 0.65, 1.05),
}


def srgb_para_oklab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype(float) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
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


def oklab_para_srgb(lab: np.ndarray) -> np.ndarray:
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = np.stack([
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ], axis=-1)
    lin = np.clip(lin, 0.0, 1.0)
    srgb = np.where(lin <= 0.0031308, lin * 12.92,
                    1.055 * lin ** (1 / 2.4) - 0.055)
    return np.round(srgb * 255).astype(np.uint8)


def cores_da_arte() -> tuple[np.ndarray, np.ndarray]:
    """Cores autorais + QUANTOS pixels cada uma ocupa.

    A contagem importa na fusão: sem ela, a escolha dentro da rampa era
    por ordem de luminosidade e podia descartar justamente o verde de
    campo que cobre 35% do quadro, mantendo uma quase-duplicata rara de
    uma copa. Cor frequente é cor estrutural."""
    fontes = [CEN / "base" / "placa_origem.png"]
    fontes += sorted((CEN / "tiras").glob("*.png"))
    fontes += sorted((CEN / "sprites").glob("*.png"))
    contagem: dict[tuple, int] = {}
    for f in fontes:
        if not f.exists():
            continue
        a = np.array(Image.open(f).convert("RGBA"))
        vis = a[a[..., 3] > 10][:, :3]
        if not len(vis):
            continue
        cs, ns = np.unique(vis, axis=0, return_counts=True)
        for c, n in zip(cs, ns):
            k = tuple(int(v) for v in c)
            contagem[k] = contagem.get(k, 0) + int(n)
        print(f"    {f.name}: {len(cs)} cores")
    chaves = sorted(contagem)
    return (np.array(chaves, dtype=np.uint8),
            np.array([contagem[k] for k in chaves], dtype=np.int64))


def rampas(cores: np.ndarray) -> list[list[int]]:
    """Agrupa por matiz em OKLab. Cinza/quase-neutro vai para um grupo só."""
    lab = srgb_para_oklab(cores)
    croma = np.hypot(lab[:, 1], lab[:, 2])
    matiz = np.degrees(np.arctan2(lab[:, 2], lab[:, 1])) % 360
    grupos: dict[str, list[int]] = {}
    for i in range(len(cores)):
        chave = "neutro" if croma[i] < 0.02 else f"h{int(matiz[i] // 30)}"
        grupos.setdefault(chave, []).append(i)
    for g in grupos.values():
        g.sort(key=lambda i: lab[i, 0])
    return [g for _, g in sorted(grupos.items())]


def _reduzir(arte: np.ndarray, lab: np.ndarray, grupos: list[list[int]],
             limiar: float) -> list[int]:
    """Dentro de cada rampa, mantém cores separadas por ≥ limiar em OKLab.

    As gerações trazem quase-duplicatas (a tira de floresta e o sprite do
    piloto repetem verdes que já existem na placa). Sem fundir, as 103
    cores autorais estouram o teto antes de qualquer extensão.
    """
    mantidos: list[int] = []
    for g in grupos:
        eleitos: list[int] = []
        for i in sorted(g, key=lambda k: -int(_PESO[k])):
            if all(np.linalg.norm(lab[i] - lab[j]) >= limiar for j in eleitos):
                eleitos.append(i)
        if not eleitos and g:
            eleitos = [g[0]]
        mantidos += eleitos
    return mantidos


def construir() -> np.ndarray:
    global _PESO
    print("  cores autorais:")
    arte, _PESO = cores_da_arte()
    lab = srgb_para_oklab(arte)
    grupos = rampas(arte)
    print(f"  {len(arte)} cores em {len(grupos)} rampas")

    # busca binária no limiar de fusão até cair na faixa alvo
    lo, hi, mantidos = 0.0, 0.40, list(range(len(arte)))
    for _ in range(40):
        meio = (lo + hi) / 2
        m = _reduzir(arte, lab, grupos, meio)
        if len(m) > ARTE_MAX:
            lo = meio
        else:
            hi = meio
            mantidos = m
        if ARTE_MAX - 4 <= len(m) <= ARTE_MAX:
            mantidos = m
            break
    print(f"  fusão de quase-duplicatas: {len(arte)} → {len(mantidos)} "
          f"(limiar OKLab {hi:.3f})")
    saida = [tuple(int(v) for v in arte[i]) for i in mantidos]
    grupos = [[i for i in g if i in set(mantidos)] for g in grupos]
    # candidatos a degrau intermediário, do maior vão para o menor
    vaos = []
    for g in grupos:
        for a, b in zip(g, g[1:]):
            d = float(lab[b, 0] - lab[a, 0])
            if d >= VAO_MINIMO:
                vaos.append((d, a, b))
    vaos.sort(reverse=True)
    for d, a, b in vaos:
        if len(saida) >= ALVO_MAX:      # alvo 48–56; TETO é o limite duro
            break
        meio = (lab[a] + lab[b]) / 2.0
        cor = tuple(int(v) for v in oklab_para_srgb(meio[None, :])[0])
        if cor not in saida:
            saida.append(cor)
    # ---- extensão ONDE OS VÉUS POUSAM (v4 §C.2) ----
    # Só os degraus intermediários da arte não bastam: o véu de valor
    # empurra o campo para uma luminosidade que não existe em rampa
    # nenhuma, e o snap ia parar num tom amarelado. Aqui as cores mais
    # FREQUENTES do render pré-snap que ainda estão longe da paleta viram
    # entradas. Não é k-means no render: é medir onde o véu caiu e abrir
    # degrau exatamente ali, com a paleta de arte já fixada.
    pre = Path("/root/.local/share/godot/app_userdata/Reino por Conquista")
    for arq in sorted(pre.glob("cenario_v2_n*_presnap.png")):
        a = np.array(Image.open(arq).convert("RGB")).reshape(-1, 3)
        cs, ns = np.unique(a, axis=0, return_counts=True)
        ordem = np.argsort(-ns)
        for i in ordem:
            if len(saida) >= ALVO_MAX:
                break
            if ns[i] < 60:             # cor rara não estrutura nada
                break
            cor = tuple(int(v) for v in cs[i])
            if cor in saida:
                continue
            d = np.linalg.norm(
                srgb_para_oklab(np.array(saida, dtype=np.uint8))
                - srgb_para_oklab(cs[i][None, :]), axis=1).min()
            if d > 0.016:      # denso o bastante para o gradiente do campo
                saida.append(cor)
        print(f"    véus de {arq.name}: paleta em {len(saida)}")

    paleta = np.array(saida, dtype=np.uint8)
    print(f"  paleta mestra: {len(paleta)} cores (teto {TETO})")

    SAIDA.mkdir(parents=True, exist_ok=True)
    Image.fromarray(paleta[None, :, :], "RGB").save(SAIDA / "mestra.png")

    for nome, (tint, sat, lum) in ESTACOES.items():
        c = paleta.astype(float) / 255.0
        c = c * np.array(tint) * lum
        cinza = (c * np.array([0.2126, 0.7152, 0.0722])).sum(axis=1, keepdims=True)
        c = cinza + (c - cinza) * sat
        est = np.round(np.clip(c, 0, 1) * 255).astype(np.uint8)
        # dedup preservando ordem: a saída do grade tem que cair EXATAMENTE
        # numa entrada, então entradas colididas viram uma só
        vistos: dict[tuple, None] = {}
        for cor in est:
            vistos.setdefault(tuple(int(v) for v in cor), None)
        arr = np.array(list(vistos), dtype=np.uint8)
        Image.fromarray(arr[None, :, :], "RGB").save(SAIDA / f"{nome}.png")
        print(f"    {nome}: {len(arr)} cores")

    (SAIDA / "paletas.json").write_text(json.dumps(
        {"mestra": len(paleta), "estacoes": sorted(ESTACOES)}, indent=1))
    return paleta


if __name__ == "__main__":
    construir()
