#!/usr/bin/env python3
"""Deriva da placa base os insumos da camada de vida (addendum v3.1, §E/§G).

Zero API: tudo aqui é recorte e máscara sobre o cache. Saídas em
assets_v2/cenario/base/derivados/:

  ceu_limpo.png       400×47  céu sem nuvens (preenchido por vizinho na linha)
  nuvens_lenta.png    400×47  RGBA — nuvens grandes (deriva 0.7 px/s)
  nuvens_rapida.png   400×47  RGBA — nuvens pequenas (deriva 1.5 px/s)
  margem_variantes.png 240×20 RGBA — 5 touceiras de junco 48px (água removida)
  margem_clareira.png  48×20  RGB  — trecho esparso, cobre a base p/ clareira

Rodar de novo é idempotente: mesma placa → mesmos arquivos.
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
CEN = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario"
SAIDA = CEN / "base" / "derivados"

CEU_FIM = 47                 # bandas: montanhas começam em 47 — acima é só céu
MARGEM_TOPO, MARGEM_FIM = 180, 200   # topos dos juncos invadem o fim do rio

# janelas de 48px medidas na placa (densidade de junco por bloco).
# A placa foi ESPELHADA (v3.2 §B) — janelas espelhadas junto: x' = 352 − x.
TOUCEIRAS = [(352, False), (222, False), (202, True), (12, False), (0, True)]
CLAREIRA_X = 272             # bloco mais esparso do motivo (era 80)


def _rotular(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """Rotulagem 4-conexa em numpy puro (sem scipy garantido)."""
    H, W = mask.shape
    rot = np.zeros((H, W), int)
    prox = 0
    for i in range(H):
        for j in range(W):
            if mask[i, j] and rot[i, j] == 0:
                prox += 1
                pilha = [(i, j)]
                rot[i, j] = prox
                while pilha:
                    a, b = pilha.pop()
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        na, nb = a + da, b + db
                        if 0 <= na < H and 0 <= nb < W and \
                                mask[na, nb] and rot[na, nb] == 0:
                            rot[na, nb] = prox
                            pilha.append((na, nb))
    return rot, prox


def nuvens(placa: np.ndarray) -> None:
    ceu = placa[:CEU_FIM]
    r, g, b = (ceu[..., k].astype(int) for k in range(3))
    # nuvem = claro e quase neutro; céu = azul saturado (b >> r). O pico da
    # serra fura a banda do céu e a face iluminada dele é TAN (amarelada,
    # r-b grande) — nuvem de verdade é creme, r-b pequeno.
    nuvem = (r > 170) & (g > 180) & (b - r < 45) & (r - b < 30)

    # céu limpo: cada pixel de nuvem herda o vizinho não-nuvem mais próximo
    # NA MESMA LINHA — preserva o degradê horizontal por banda do céu
    limpo = ceu.copy()
    for y in range(CEU_FIM):
        cols = np.nonzero(~nuvem[y])[0]
        if len(cols) == 0:
            continue
        ruins = np.nonzero(nuvem[y])[0]
        for x in ruins:
            limpo[y, x] = ceu[y, cols[np.abs(cols - x).argmin()]]

    rot, n = _rotular(nuvem)
    tam = np.bincount(rot.ravel())[1:]
    lenta = np.zeros_like(nuvem)
    rapida = np.zeros_like(nuvem)
    mediana = float(np.median(tam[tam > 8])) if (tam > 8).any() else 0
    for comp in range(1, n + 1):
        if tam[comp - 1] <= 8:
            continue                      # migalha: some no céu limpo
        alvo = lenta if tam[comp - 1] >= mediana else rapida
        alvo |= rot == comp

    SAIDA.mkdir(parents=True, exist_ok=True)
    Image.fromarray(limpo).save(SAIDA / "ceu_limpo.png")
    for nome, m in (("nuvens_lenta", lenta), ("nuvens_rapida", rapida)):
        rgba = np.dstack([ceu, (m * 255).astype(np.uint8)])
        Image.fromarray(rgba, "RGBA").save(SAIDA / f"{nome}.png")
    print(f"  ☁️  nuvens: {int(lenta.any(axis=0).sum())}px lentas, "
          f"{int(rapida.any(axis=0).sum())}px rápidas (colunas cobertas)")


def margem(placa: np.ndarray) -> None:
    faixa = placa[MARGEM_TOPO:MARGEM_FIM]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    agua = (b > 120) & (b > r + 20)      # azul/ciano — vira alpha 0

    tiras = []
    for x0, espelha in TOUCEIRAS:
        seg = faixa[:, x0:x0 + 48]
        sa = ~agua[:, x0:x0 + 48]
        rgba = np.dstack([seg, (sa * 255).astype(np.uint8)])
        if espelha:
            rgba = rgba[:, ::-1]
        tiras.append(rgba)
    Image.fromarray(np.concatenate(tiras, axis=1), "RGBA").save(
        SAIDA / "margem_variantes.png")
    Image.fromarray(faixa[:, CLAREIRA_X:CLAREIRA_X + 48]).save(
        SAIDA / "margem_clareira.png")
    print("  🌾 margem: 5 touceiras RGBA + 1 clareira RGB")


def fundo(placa: np.ndarray) -> None:
    """Extrai o maciço central como camada RGBA — o CARREGADOR do véu de
    recessão atmosférica (v3.2 §B tentativa 1). A camada é desenhada POR
    CIMA da fatia intacta com o shader de recessão: máscara imperfeita
    não abre buraco, só deixa de recessar um pixel ou outro.

    A DIREÇÃO da luz já foi corrigida pelo espelho global da placa (a
    auditoria mediu luz pela esquerda em 4 bandas — flip por banda
    racharia as árvores que cruzam fatias). O véu aqui cuida do outro
    problema medido: os cremes do maciço entre os valores mais claros do
    quadro, puxando a montanha para FRENTE.

    As serras laterais ficam assadas no fundo de propósito: já nascem em
    bruma, sem tan, sem direcionalidade medível — véu nelas é redundante.
    """
    faixa = placa[0:78]
    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    nuvem = (r > 170) & (g > 180) & (b - r < 45) & (r - b < 30)

    # crista: primeiro pixel "não-céu" descendo do topo, nas linhas 0..55
    # onde o céu ainda é claro (L>195). O tan é inequívoco; os CUMES teal
    # (família do céu com bruma) entram pelo teto de luminância.
    escuro = (lum < 195) & ~nuvem
    crista = np.full(400, 999)
    for x in range(88, 272):
        col = np.nonzero(escuro[:55, x])[0]
        if len(col):
            crista[x] = col.min()
    xs_ok = np.nonzero(crista < 999)[0]
    for x in range(xs_ok.min(), xs_ok.max() + 1):
        if crista[x] == 999:
            viz = crista[max(0, x - 6):x + 7]
            crista[x] = viz[viz < 999].min() if (viz < 999).any() else 999
    arvore = (g >= r) & (g > b) & (g - b > 12) & (lum < 160)
    maciço = np.zeros_like(escuro)
    for x in range(400):
        if crista[x] < 999:
            maciço[max(0, crista[x] - 1):78, x] = True
    maciço &= ~arvore & ~nuvem
    rgba = np.dstack([faixa, (maciço * 255).astype(np.uint8)])
    Image.fromarray(rgba, "RGBA").save(SAIDA / "montanha_central.png")
    print(f"  ⛰️  maciço {int(maciço.sum())}px (carregador do véu de recessão)")


def skyline(placa: np.ndarray) -> None:
    """Emite skyline.json: para cada coluna, o Y do primeiro pixel não-céu.

    É a medida que decide onde o castelo pode pousar (v3.3 §B.2) — fica em
    arquivo para o blockout na Godot consumir a MESMA medida, em vez de
    reimplementar detecção de céu em GDScript e divergir.
    """
    from collections import deque
    r, g, b = (placa[..., k].astype(int) for k in range(3))
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    nuvem = (r > 170) & (g > 180) & (b - r < 45) & (r - b < 30)
    azul = (b - r > 25) & (lum > 150) & ~nuvem
    H, W = azul.shape
    ceu = np.zeros_like(azul)
    vis = np.zeros_like(azul)
    fila = deque((0, x) for x in range(W) if azul[0, x] or nuvem[0, x])
    for y, x in fila:
        vis[y, x] = True
    while fila:
        y, x = fila.popleft()
        ceu[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not vis[ny, nx] \
                    and (azul[ny, nx] or nuvem[ny, nx]):
                vis[ny, nx] = True
                fila.append((ny, nx))
    linha = [int(np.nonzero(~ceu[:, x])[0].min()) for x in range(W)]
    (SAIDA / "skyline.json").write_text(json.dumps({"skyline": linha}))
    print(f"  📐 skyline: topo mais alto y={min(linha)} em x={linha.index(min(linha))}")


if __name__ == "__main__":
    placa = np.array(Image.open(CEN / "base" / "placa_base.png").convert("RGB"))
    nuvens(placa)
    margem(placa)
    fundo(placa)
    skyline(placa)
    print(f"✅ derivados em {SAIDA}")
