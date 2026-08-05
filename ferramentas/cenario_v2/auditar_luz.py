#!/usr/bin/env python3
"""Auditoria de LUZ da placa base (addendum v3.2 §B) — diagnóstico de $0.

O SUFIXO_LUZ congelado diz sol no canto superior-DIREITO. Para cada banda,
mede-se de que lado dos volumes está o claro:

  montanhas  — flanco esquerdo vs direito de cada maciço (componentes do
               mask de rocha), L médio por lado
  nuvens     — metade esquerda vs direita de cada blob extraído
  floresta   — perfil médio da árvore (dobra pelo período detectado por
               autocorrelação): posição do realce vs centro da copa
  juncos     — pixels claros (pontas) vs escuros por touceira do motivo
  troncos    — coluna esquerda vs direita de cada tronco marrom
  pedras     — metade esquerda vs direita do blob da pedra do rio

Veredito por banda: DIREITA (coerente com o estilo congelado), ESQUERDA
(contradiz) ou AMBÍGUO (|Δ| pequeno). Também mede cor_horizonte e meio_tom
para o shader de recessão (§B: "não chutar — medir").
"""

from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
CEN = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario"

LIMIAR_AMBIGUO = 4.0        # |ΔL| < isto = sem direcionalidade legível


def L(rgb: np.ndarray) -> np.ndarray:
    return (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1]
            + 0.0722 * rgb[..., 2]).astype(float)


def _rotular(mask: np.ndarray) -> tuple[np.ndarray, int]:
    H, W = mask.shape
    rot = np.zeros((H, W), int)
    n = 0
    for i in range(H):
        for j in range(W):
            if mask[i, j] and rot[i, j] == 0:
                n += 1
                pilha = [(i, j)]
                rot[i, j] = n
                while pilha:
                    a, b = pilha.pop()
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        na, nb = a + da, b + db
                        if 0 <= na < H and 0 <= nb < W and \
                                mask[na, nb] and rot[na, nb] == 0:
                            rot[na, nb] = n
                            pilha.append((na, nb))
    return rot, n


def _veredito(dL: float) -> str:
    if abs(dL) < LIMIAR_AMBIGUO:
        return "AMBÍGUO"
    return "DIREITA ✅" if dL > 0 else "ESQUERDA 🔴"


def _lados(lum: np.ndarray, mask: np.ndarray, rot: np.ndarray,
           comp: int) -> float:
    """ΔL = (metade direita − metade esquerda) do componente."""
    ys, xs = np.nonzero(rot == comp)
    cx = xs.mean()
    esq = lum[ys[xs < cx], xs[xs < cx]]
    dire = lum[ys[xs >= cx], xs[xs >= cx]]
    if len(esq) == 0 or len(dire) == 0:
        return 0.0
    return float(dire.mean() - esq.mean())


def montanhas(placa: np.ndarray) -> tuple[str, str]:
    """Pares horizontais tan/teal — a medida que funciona em listras.

    Médias por flanco e gradiente médio FALHARAM aqui (registrado): o
    maciço é listrado em diagonais tan/teal, então flanco e gradiente se
    cancelam; e o teal sombrio é da mesma família do céu com bruma, o que
    fura qualquer classificador céu-vs-rocha. O que sobrevive à listra:
    contar pares (x, x+3) — claro à esquerda do escuro = espigões com a
    face direita na sombra = sol pela ESQUERDA.
    """
    faixa = placa[25:75, 95:265]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = L(faixa)
    tan = (r - b > 30)
    teal = (b >= r - 10) & (lum < 195) & ~tan
    d = 3
    tan_teal = int((tan[:, :-d] & teal[:, d:]).sum())   # claro à esq
    teal_tan = int((teal[:, :-d] & tan[:, d:]).sum())   # claro à dir
    razao = tan_teal / max(1, teal_tan)
    if 0.87 <= razao <= 1.15:
        v = "AMBÍGUO"
    else:
        v = "DIREITA ✅" if razao < 1.0 else "ESQUERDA 🔴"
    return v, (f"pares claro-esq {tan_teal} vs claro-dir {teal_tan} "
               f"(razão {razao:.2f})")


def nuvens_bandas() -> tuple[str, str]:
    dLs = []
    for nome in ("nuvens_lenta", "nuvens_rapida"):
        arq = CEN / "base" / "derivados" / f"{nome}.png"
        rgba = np.array(Image.open(arq).convert("RGBA"))
        mask = rgba[..., 3] > 0
        lum = L(rgba[..., :3].astype(int))
        rot, n = _rotular(mask)
        tam = np.bincount(rot.ravel())[1:]
        for comp in range(1, n + 1):
            if tam[comp - 1] >= 40:
                dLs.append(_lados(lum, mask, rot, comp))
    media = float(np.mean(dLs))
    return _veredito(media), (f"{len(dLs)} blobs, ΔL médio {media:+.1f} "
                              f"(mín {min(dLs):+.1f}, máx {max(dLs):+.1f})")


def _dobrar(faixa: np.ndarray, mask: np.ndarray) -> tuple[int, float]:
    """Período por autocorrelação + ΔL alinhado ao CENTRO do elemento.

    A fase da dobra é arbitrária — comparar o pico de L com per/2 sem
    alinhar mede a fase, não a luz. Alinha-se rolando a dobra para que o
    pico de DENSIDADE da máscara (o corpo do elemento) fique no centro;
    aí sim: L médio do lado direito − lado esquerdo do corpo.
    """
    lum = L(faixa)
    with np.errstate(invalid="ignore"):
        col = np.nanmean(np.where(mask, lum, np.nan), axis=0)
    col = np.nan_to_num(col, nan=np.nanmean(col[~np.isnan(col)]))
    dens = mask.sum(axis=0).astype(float)
    c0 = col - col.mean()
    ac = np.correlate(c0, c0, "full")[len(c0) - 1:]
    per = int(np.argmax(ac[8:80]) + 8)          # período plausível 8..80px
    reps = len(col) // per
    dobra_l = col[:reps * per].reshape(reps, per).mean(axis=0)
    dobra_d = dens[:reps * per].reshape(reps, per).mean(axis=0)
    rolo = per // 2 - int(np.argmax(dobra_d))
    dobra_l = np.roll(dobra_l, rolo)
    meio = per // 2
    dL = float(dobra_l[meio:].mean() - dobra_l[:meio].mean())
    return per, dL


def floresta(placa: np.ndarray) -> tuple[str, str]:
    faixa = placa[58:105]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    copa = (g >= r) & (g > b)                   # verdes das copas
    per, dL = _dobrar(faixa, copa)
    return _veredito(dL), f"período {per}px, realce {'dir' if dL > 0 else 'esq'} ΔL={dL:+.1f}"


def juncos(placa: np.ndarray) -> tuple[str, str]:
    faixa = placa[182:198]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    junco = ~((b > 120) & (b > r + 20)) & (g > r)
    per, dL = _dobrar(faixa, junco)
    return _veredito(dL), f"período {per}px, realce {'dir' if dL > 0 else 'esq'} ΔL={dL:+.1f}"


def troncos(placa: np.ndarray) -> tuple[str, str]:
    faixa = placa[92:111]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = L(faixa)
    tronco = (r > g) & (g >= b) & (r - b > 25) & (r < 200)
    rot, n = _rotular(tronco)
    tam = np.bincount(rot.ravel())[1:]
    dLs = [_lados(lum, tronco, rot, c)
           for c in range(1, n + 1) if tam[c - 1] >= 12]
    media = float(np.mean(dLs))
    return _veredito(media), f"{len(dLs)} troncos, ΔL médio {media:+.1f}"


def pedras(placa: np.ndarray) -> tuple[str, str]:
    # a pedra musgosa do rio (única pedra franca da placa)
    faixa = placa[176:196, 40:100]   # pedra espelhada junto com a placa
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = L(faixa)
    pedra = ~((b > 120) & (b > r + 20))
    rot, n = _rotular(pedra)
    tam = np.bincount(rot.ravel())[1:]
    comp = int(np.argmax(tam)) + 1
    dL = _lados(lum, pedra, rot, comp)
    return _veredito(dL), f"blob {tam[comp - 1]}px, ΔL={dL:+.1f}"


def medidas_recessao(placa: np.ndarray) -> None:
    faixa = placa[0:78]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = L(faixa)
    nuvem = (r > 170) & (g > 180) & (b - r < 45) & (r - b < 30)
    ceu = (b >= r + 30) & (lum > 150) & ~nuvem
    verde = (g >= r) & (g > b) & ~ceu
    rocha = ~(nuvem | ceu | verde)
    horiz = faixa[60:75][ceu[60:75]]
    cor = horiz.reshape(-1, 3).mean(axis=0) / 255.0
    meio = float(lum[rocha].mean() / 255.0)
    print(f"\n  medidas p/ recessão (§B, medir não chutar):")
    print(f"    cor_horizonte = vec3({cor[0]:.3f}, {cor[1]:.3f}, {cor[2]:.3f})")
    print(f"    meio_tom      = {meio:.3f}")


if __name__ == "__main__":
    placa = np.array(Image.open(
        CEN / "base" / "placa_base.png").convert("RGB"))
    print("AUDITORIA DE LUZ — sol congelado: superior-DIREITO\n")
    print(f"  {'banda':<12} {'veredito':<12} detalhe")
    for nome, fn in (("montanhas", montanhas), ("nuvens", nuvens_bandas),
                     ("floresta", floresta), ("juncos", juncos),
                     ("troncos", troncos), ("pedras", pedras)):
        v, det = fn(placa) if nome != "nuvens" else fn()
        print(f"  {nome:<12} {v:<12} {det}")
    medidas_recessao(placa)
