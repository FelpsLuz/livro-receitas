#!/usr/bin/env python3
"""De mockup do Gemini a asset usável (PROMPTS_CIDADE_MEDIEVAL §5).

A saída do gerador é render em ALTA resolução com estética de pixel: a
grade não é uniforme e as bordas têm anti-aliasing. Não serve em 1×. A
ordem do pipeline é inegociável — quantizar antes de reduzir gera lixo,
porque a quantização fixa cores de pixels que ainda vão ser mesclados:

  1. recorte de moldura e de proporção (16:9)
  2. redução para a resolução nativa por BOX (média de área), nunca bicúbica
  3. paleta de 54 cores derivada do estágio 6 da estação
  4. quantização de todos os estágios COM A MESMA paleta, sem dither
  5. gravação em PNG-8 INDEXADO — o índice é o que a Fase 2 usa para casar
     cor de céu por igualdade exata, sem tolerância

O passo 3 agrupa a cor em rampas de OKLab (oklab.py): o mockup traz
milhares de cores por causa do anti-aliasing, e k-means nelas devolveria
paleta lamacenta.

    python3 ferramentas/cenario_v3/processar_estagios.py <dir> --estacao verao
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from oklab import oklab_para_srgb, srgb_para_oklab  # noqa: E402

ARTE = RAIZ / "reino-por-conquista-godot" / "assets"
SAIDA = ARTE / "estagios"
PALETAS = ARTE / "paletas"
NATIVO = (480, 270)
PALETA_ALVO = 54
PALETA_LARGURA = 64      # a tira gravada tem 64 colunas mesmo com 54 cores

# A ordem dos arquivos do gerador não é a ordem narrativa: ela vem por
# --ordem. Os nomes de saída são posicionais e vazios de semântica de
# propósito: "estagio_04" não promete nada sobre o que há na imagem, e é o
# índice que o jogo usa para casar com o nível de terra.
NOMES = [f"estagio_{i:02d}" for i in range(1, 7)]


def _tirar_moldura(im: Image.Image) -> Image.Image:
    """A E6 veio com moldura dourada — a §1 proíbe moldura em qualquer
    imagem. Detectada por borda amarelada, não por margem fixa."""
    a = np.array(im.convert("RGB")).astype(int)
    dourado = (a[..., 0] > 140) & (a[..., 0] > a[..., 2] + 40)
    H, W = dourado.shape
    t, b, l, r = 0, H - 1, 0, W - 1
    while t < H // 4 and dourado[t].mean() > 0.3:
        t += 1
    while b > 3 * H // 4 and dourado[b].mean() > 0.3:
        b -= 1
    while l < W // 4 and dourado[:, l].mean() > 0.3:
        l += 1
    while r > 3 * W // 4 and dourado[:, r].mean() > 0.3:
        r -= 1
    if (t, l) == (0, 0) and (b, r) == (H - 1, W - 1):
        return im
    # Recortar e pronto DESLOCA o conteúdo: o recorte 16:9 seguinte cai
    # noutro lugar e a E6 saiu 2px fora de registro com as outras cinco,
    # quebrando o "montanha, rio, sol e nuvens idênticos" da §7. Repõe-se
    # o tamanho replicando a borda adjacente — que ali é céu chapado.
    nucleo = np.array(im.convert("RGB"))[t:b + 1, l:r + 1]
    cheio = np.empty((H, W, 3), np.uint8)
    cheio[t:b + 1, l:r + 1] = nucleo
    for y in range(t):
        cheio[y] = cheio[t]
    for y in range(b + 1, H):
        cheio[y] = cheio[b]
    for x in range(l):
        cheio[:, x] = cheio[:, l]
    for x in range(r + 1, W):
        cheio[:, x] = cheio[:, r]
    print(f"    moldura removida ({t},{l})..({b},{r}) e borda reposta — "
          f"geometria preservada")
    return Image.fromarray(cheio)


def _recortar_169(im: Image.Image) -> Image.Image:
    alvo = NATIVO[0] / NATIVO[1]
    w, h = im.size
    if w / h > alvo:
        nova = int(round(h * alvo))
        e = (w - nova) // 2
        return im.crop((e, 0, e + nova, h))
    nova = int(round(w / alvo))
    t = (h - nova) // 2
    return im.crop((0, t, w, t + nova))


def _ordenar(caminhos: list[Path], ordem: str | None) -> list[Path]:
    """A ordem narrativa vem EXPLÍCITA (--ordem), não inferida.

    Tentei duas métricas automáticas e as duas erram onde importa:
    densidade de detalhe põe a E6 antes da E4 (a moldura e o céu mais
    limpo derrubam a conta), e massa de pedra não separa E4/E5/E6 porque
    a rocha da montanha entra na mesma faixa de cinza. Identificação
    visual é decisiva aqui, e um argumento explícito é mais honesto que
    um heurístico que erra em silêncio.
    """
    if ordem:
        idx = [int(v) for v in ordem.split(",")]
        por_sufixo = {}
        for c in caminhos:
            n = "".join(ch for ch in c.stem.split("(")[-1] if ch.isdigit())
            por_sufixo[int(n) if n else 0] = c
        faltando = [i for i in idx if i not in por_sufixo]
        if faltando:
            sys.exit(f"--ordem cita índices inexistentes: {faltando}")
        return [por_sufixo[i] for i in idx]
    return sorted(caminhos)


def _paleta(img: np.ndarray, n: int) -> np.ndarray:
    """Rampa em OKLab: agrupa por matiz, mantém as mais FREQUENTES, e
    completa com degraus intermediários onde há vão de luminosidade."""
    cs, ns = np.unique(img.reshape(-1, 3), axis=0, return_counts=True)
    lab = srgb_para_oklab(cs)
    croma = np.hypot(lab[:, 1], lab[:, 2])
    matiz = np.degrees(np.arctan2(lab[:, 2], lab[:, 1])) % 360
    grupos: dict[str, list[int]] = {}
    for i in range(len(cs)):
        chave = "neutro" if croma[i] < 0.02 else f"h{int(matiz[i] // 30)}"
        grupos.setdefault(chave, []).append(i)

    def reduzir(limiar: float) -> list[int]:
        fora: list[int] = []
        for g in grupos.values():
            eleitos: list[int] = []
            for i in sorted(g, key=lambda k: -int(ns[k])):
                if all(np.linalg.norm(lab[i] - lab[j]) >= limiar for j in eleitos):
                    eleitos.append(i)
            fora += eleitos
        return fora

    lo, hi, melhor = 0.0, 0.6, list(range(len(cs)))
    for _ in range(30):
        meio = (lo + hi) / 2
        m = reduzir(meio)
        if len(m) > n:
            lo = meio
        else:
            hi = meio
            melhor = m
        if n - 4 <= len(m) <= n:
            melhor = m
            break
    return cs[np.array(sorted(melhor))]


def _tabela(paleta: np.ndarray) -> list[int]:
    """A tabela de 256 entradas do PNG-8. As não usadas ficam pretas."""
    t: list[int] = []
    for c in paleta:
        t += [int(c[0]), int(c[1]), int(c[2])]
    return t + [0] * (768 - len(t))


def _indices(rgb: np.ndarray, paleta: np.ndarray) -> np.ndarray:
    """Índice de paleta por pixel, por busca binária em chave inteira.

    Só funciona porque a imagem JÁ foi quantizada: toda cor presente está
    na paleta. Se aparecer uma que não está, isto levanta erro em vez de
    escolher a mais próxima em silêncio — a Fase 2 depende de igualdade
    exata de cor e um vizinho aproximado ali vaza o flood fill.
    """
    def chave(a):
        a = a.astype(np.int64)
        return (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]

    kp = chave(paleta)
    ordem = np.argsort(kp)
    ki = chave(rgb)
    pos = np.searchsorted(kp[ordem], ki)
    pos = np.clip(pos, 0, len(kp) - 1)
    idx = ordem[pos]
    fora = paleta[idx].reshape(rgb.shape) != rgb
    if fora.any():
        n = int(fora.any(axis=-1).sum())
        raise SystemExit(f"{n}px com cor fora da paleta — quantização falhou")
    return idx.astype(np.uint8)


def _gravar(idx: np.ndarray, paleta: np.ndarray, caminho: Path) -> None:
    """PNG-8 indexado com a paleta NA ORDEM dada.

    `Image.convert("P")` não serve: ele refaz a paleta por conta própria e
    reordena as entradas. Com seis arquivos que precisam compartilhar
    índice, isso destrói a única garantia que interessa.
    """
    im = Image.fromarray(idx, "P")
    im.putpalette(_tabela(paleta))
    im.save(caminho, optimize=False)


def _quantizar(img: np.ndarray, paleta: np.ndarray) -> np.ndarray:
    lab_p = srgb_para_oklab(paleta)
    h, w, _ = img.shape
    lab_i = srgb_para_oklab(img.reshape(-1, 3))
    # em blocos, para não estourar memória com 480*270 x N
    saida = np.empty((h * w, 3), np.uint8)
    passo = 20000
    for i in range(0, len(lab_i), passo):
        bloco = lab_i[i:i + passo]
        d = ((bloco[:, None, :] - lab_p[None, :, :]) ** 2).sum(axis=2)
        saida[i:i + passo] = paleta[d.argmin(axis=1)]
    return saida.reshape(h, w, 3)


def processar(origem: Path, estacao: str, ordem: str | None) -> None:
    arquivos = sorted(origem.glob("*.png"))
    arquivos = [a for a in arquivos if "Gemini" in a.name]
    if len(arquivos) != 6:
        sys.exit(f"esperava 6 estágios, achei {len(arquivos)}")
    ordenados = _ordenar(arquivos, ordem)

    nativos = []
    for nome, arq in zip(NOMES, ordenados):
        im = _recortar_169(_tirar_moldura(Image.open(arq)))
        nat = im.convert("RGB").resize(NATIVO, Image.BOX)
        nativos.append((nome, np.array(nat)))
        print(f"  {nome:18} ← {arq.name}")

    # a paleta sai do E6 DESTA estação (§5.2): usar uma global para as 4
    # estações foi o erro que achatou a cena anterior
    paleta = _paleta(nativos[-1][1], PALETA_ALVO)
    print(f"  paleta de {estacao}: {len(paleta)} cores (alvo {PALETA_ALVO})")

    dest = SAIDA / estacao
    dest.mkdir(parents=True, exist_ok=True)
    PALETAS.mkdir(parents=True, exist_ok=True)

    # a tira de paleta: 64×1 indexado, as cores reais nas primeiras N colunas
    tira = np.zeros((1, PALETA_LARGURA), np.uint8)
    tira[0, :len(paleta)] = np.arange(len(paleta), dtype=np.uint8)
    _gravar(tira, paleta, PALETAS / f"{estacao}.png")

    for nome, arr in nativos:
        q = _quantizar(arr, paleta)
        _gravar(_indices(q, paleta), paleta, dest / f"{nome}.png")
        u = len(np.unique(q.reshape(-1, 3), axis=0))
        print(f"    {nome}: {u} cores")
    (dest / "meta.json").write_text(json.dumps(
        {"nativo": list(NATIVO), "paleta": len(paleta),
         "paleta_arquivo": f"assets/paletas/{estacao}.png",
         "cores": ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in paleta],
         "estagios": NOMES}, indent=1))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("origem", type=Path)
    ap.add_argument("--estacao", default="verao")
    ap.add_argument("--ordem", default=None,
                    help="índices dos arquivos na ordem E1..E6, ex: 6,1,2,3,4,5")
    a = ap.parse_args()
    processar(a.origem, a.estacao, a.ordem)
