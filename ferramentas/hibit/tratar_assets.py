#!/usr/bin/env python3
"""Trata a arte crua do PixelLab e grava em res://assets/sprites/.

    python3 ferramentas/hibit/tratar_assets.py

Lê de ferramentas/hibit/cru/ e escreve em
reino-por-conquista-godot/assets/sprites/. Não chama API: dá para rodar
quantas vezes quiser, ajustando limiar, sem gastar um centavo.

--------------------------------------------------------------------
O CHROMA KEY NÃO PODE SER POR IGUALDADE
--------------------------------------------------------------------
O prompt pediu fundo "#FF00FF". O modelo NÃO devolve #FF00FF: devolve o
magenta que ele achou parecido, e um diferente por imagem —

    arbusto  (221, 71,171)      pedra    (174, 46,151)
    árvore   (253, 99,138)      tronco   (196, 53,145)

Um `if cor == (255,0,255)` recortaria zero pixels em todas as quatro. Por
isso a chave é MEDIDA em cada imagem (a cor modal do anel de borda) e o
corte é por DISTÂNCIA, em três passadas:

  1. INUNDAÇÃO a partir da borda, com limiar frouxo. Pega o fundo contíguo
     sem tocar em cor parecida que esteja DENTRO do sprite.
  2. VARREDURA global pela mesma chave, com limiar apertado. Pega o fundo
     ilhado — o vão entre dois galhos, que a inundação não alcança.
  3. DESCASCA da franja: pixel opaco encostado em transparente e ainda
     puxando para a chave é anti-alias de borda. Numa arte de 32px, três
     pixels de franja rosa são 10% da silhueta.
  4. FAMÍLIA DE MATIZ. A árvore veio com 123px de #971765 numa faixa sob o
     tronco: o modelo desenhou a SOMBRA no matiz do fundo que a gente pediu.
     Está a 132 de distância da chave — longe demais para as passadas 1 a 3 —
     mas é magenta saturado, e nada nesta arte (verde e marrom, matiz 25–130°)
     é magenta. Cortar por família de matiz é seguro AQUI e o relatório diz
     quanto foi cortado, para o dia em que um sprite tiver uma flor roxa.

O alfa sai BINÁRIO (0 ou 255). Alfa parcial em pixel art com filtro Nearest
não suaviza nada — só produz borda suja que aparece contra qualquer fundo.
"""

from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
CRU = Path(__file__).resolve().parent / "cru"
DEST = RAIZ / "reino-por-conquista-godot" / "assets" / "sprites"

# Distâncias em RGB (euclidiana, 0..441). Medidas contra as quatro imagens:
# o fundo varia ~12 de ruído interno, e a cor mais próxima de sprite real
# (a madeira rosada do tronco) fica a ~95 da chave.
LIM_INUNDACAO = 78     # frouxo: só precisa não vazar para dentro do sprite
LIM_ILHA = 55          # apertado: fundo ilhado, sem vizinho para confirmar
LIM_FRANJA = 118       # anti-alias: mais frouxo, mas só na borda do alfa
# Família de matiz: janela ASSIMÉTRICA em volta da chave.
#
# Simétrica não serve. Quando o modelo escurece o magenta do fundo, ele o
# empurra para o VIOLETA — a sombra da pedra saiu em rgb(135,12,149), a 294°,
# enquanto a chave está a 336°. Uma janela de ±55° pegaria isso, mas o outro
# lado chegaria a 31° e comeria o tronco laranja da árvore, que vive a ~35°.
#
# Então a janela abre 58° para o lado do violeta e só 14° para o lado do
# vermelho. O piso de croma existe para não comer cinza: cinza tem matiz
# instável e croma perto de zero.
MATIZ_VIOLETA = 58.0      # sentido decrescente a partir da chave
MATIZ_VERMELHO = 14.0     # sentido crescente
LIM_CROMA = 0.30

_verdes = 0
_vermelhos = 0


def ok(cond: bool, nome: str, obs: str = "") -> bool:
    global _verdes, _vermelhos
    print(f"  {'✅' if cond else '❌'} {nome}" + (f" — {obs}" if obs else ""))
    if cond:
        _verdes += 1
    else:
        _vermelhos += 1
    return cond


def _chave_da_borda(a: np.ndarray) -> np.ndarray:
    """A cor de fundo é a MODA do anel de 2px da borda.

    Moda e não média: média de duas cores de fundo com ruído devolve uma
    cor que não existe na imagem, e todo o corte fica descentrado. (Mesma
    lição que derrubou quatro tentativas de preenchimento no cenário v2.)
    """
    anel = np.concatenate([
        a[:2].reshape(-1, 3), a[-2:].reshape(-1, 3),
        a[:, :2].reshape(-1, 3), a[:, -2:].reshape(-1, 3)])
    contagem = collections.Counter(map(tuple, anel))
    return np.array(contagem.most_common(1)[0][0], dtype=float)


def _dist(a: np.ndarray, chave: np.ndarray) -> np.ndarray:
    return np.sqrt(((a.astype(float) - chave) ** 2).sum(axis=-1))


def _hsv(a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Matiz em graus e croma normalizado (0..1)."""
    f = a.astype(float) / 255.0
    mx = f.max(axis=-1)
    mn = f.min(axis=-1)
    dif = mx - mn
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    h = np.zeros_like(mx)
    seguro = dif > 1e-6
    idx = seguro & (mx == r)
    h[idx] = (60.0 * ((g[idx] - b[idx]) / dif[idx])) % 360.0
    idx = seguro & (mx == g)
    h[idx] = (60.0 * ((b[idx] - r[idx]) / dif[idx]) + 120.0) % 360.0
    idx = seguro & (mx == b)
    h[idx] = (60.0 * ((r[idx] - g[idx]) / dif[idx]) + 240.0) % 360.0
    croma = np.where(mx > 1e-6, dif / np.maximum(mx, 1e-6), 0.0)
    return h, croma


def _despicar(saida: np.ndarray, limiar: float = 96.0) -> int:
    """Troca pixel interior ÚNICO que não tem parente entre os 8 vizinhos.

    Conservador de propósito. Uma versão por componente conexo foi testada e
    reprovada: com `area_max=5` ela trocava 119px na árvore e 67 na pedra —
    em pixel art quase todo realce é um aglomerado pequeno e "destoante",
    então o critério apagava o SOMBREAMENTO junto com o ruído. Aqui só cai
    o pixel que está sozinho de verdade.

    A troca é pela MODA dos vizinhos, nunca pela média — média de duas cores
    de granito devolve um cinza que não existe na paleta da arte.
    """
    H, W, _ = saida.shape
    opaco = saida[..., 3] == 255
    rgb = saida[..., :3].astype(int)
    trocas = 0
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if not opaco[y, x]:
                continue
            vizinhos = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if (dy or dx) and opaco[y + dy, x + dx]:
                        vizinhos.append(tuple(rgb[y + dy, x + dx]))
            if len(vizinhos) < 6:
                continue
            cor = rgb[y, x]
            if any(sum((int(v[i]) - int(cor[i])) ** 2 for i in range(3))
                   < limiar * limiar for v in vizinhos):
                continue
            saida[y, x, :3] = collections.Counter(vizinhos).most_common(1)[0][0]
            trocas += 1
    return trocas


def _cortar_ilhas_magenta(saida: np.ndarray, area_max: int = 8) -> int:
    """Última rede: ilha MINÚSCULA de magenta cravada no interior.

    A pedra ficou com um trio de rgb(135,12,149) no meio do granito, longe
    da borda do alfa e sem conexão com o fundo — nenhuma das passadas
    anteriores alcança. O teste é o mesmo da verificação (vermelho e azul
    altos com o verde afundado) mais um teto de área: um elemento de arte
    roxo de verdade não cabe em 8 pixels, e se couber o relatório mostra.

    Corta em vez de trocar porque, no interior de um sprite opaco, um furo
    de 3px sob um pixel de contorno não aparece; uma cor inventada aparece.
    """
    H, W, _ = saida.shape
    opaco = saida[..., 3] == 255
    rgb = saida[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    alvo = opaco & (r > 120) & (b > 90) & (g < np.minimum(r, b) * 0.72)
    visto = np.zeros((H, W), bool)
    cortados = 0
    ys, xs = np.nonzero(alvo)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if visto[y0, x0]:
            continue
        grupo = [(y0, x0)]
        visto[y0, x0] = True
        pilha = [(y0, x0)]
        while pilha and len(grupo) <= area_max:
            y, x = pilha.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and alvo[ny, nx] \
                            and not visto[ny, nx]:
                        visto[ny, nx] = True
                        grupo.append((ny, nx))
                        pilha.append((ny, nx))
        if len(grupo) > area_max:
            continue
        for (y, x) in grupo:
            saida[y, x] = (0, 0, 0, 0)
        cortados += len(grupo)
    return cortados


def recortar(im: Image.Image) -> tuple[Image.Image, dict]:
    rgba = np.array(im.convert("RGBA"))
    rgb = rgba[..., :3]
    H, W, _ = rgb.shape
    chave = _chave_da_borda(rgb)
    d = _dist(rgb, chave)

    # ---- 1. inundação a partir da borda ----
    fundo = np.zeros((H, W), bool)
    pilha = []
    for x in range(W):
        for y in (0, H - 1):
            if d[y, x] < LIM_INUNDACAO and not fundo[y, x]:
                fundo[y, x] = True
                pilha.append((y, x))
    for y in range(H):
        for x in (0, W - 1):
            if d[y, x] < LIM_INUNDACAO and not fundo[y, x]:
                fundo[y, x] = True
                pilha.append((y, x))
    while pilha:
        y, x = pilha.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not fundo[ny, nx] \
                    and d[ny, nx] < LIM_INUNDACAO:
                fundo[ny, nx] = True
                pilha.append((ny, nx))
    n_inundacao = int(fundo.sum())

    # ---- 2. fundo ilhado (vão entre galhos) ----
    ilhas = (d < LIM_ILHA) & ~fundo
    fundo |= ilhas
    n_ilhas = int(ilhas.sum())

    # ---- 3. descasca da franja de anti-alias ----
    n_franja = 0
    for _ in range(3):
        vizinho_vazio = np.zeros((H, W), bool)
        vizinho_vazio[1:] |= fundo[:-1]
        vizinho_vazio[:-1] |= fundo[1:]
        vizinho_vazio[:, 1:] |= fundo[:, :-1]
        vizinho_vazio[:, :-1] |= fundo[:, 1:]
        franja = vizinho_vazio & ~fundo & (d < LIM_FRANJA)
        if not franja.any():
            break
        n_franja += int(franja.sum())
        fundo |= franja

    # ---- 4. família de matiz da chave (ver o cabeçalho) ----
    h, croma = _hsv(rgb)
    h_chave, _ = _hsv(chave.reshape(1, 1, 3).astype(np.uint8))
    # A família de matiz só vale CONECTADA AO FUNDO. Solta, ela reprovou:
    # a túnica do aldeão tem sombreado avermelhado dentro da janela, e a
    # passada global comia 107px de um sprite que só tem ~150 — sobrava 5%
    # de silhueta. A sombra magenta da árvore, que é o alvo real, ENCOSTA no
    # fundo; o sombreado de uma roupa não encosta.
    rel = (h - float(h_chave[0, 0]) + 180.0) % 360.0 - 180.0
    elegivel = (rel > -MATIZ_VIOLETA) & (rel < MATIZ_VERMELHO) \
        & (croma > LIM_CROMA) & ~fundo
    n_familia = 0
    pilha = []
    ys, xs = np.nonzero(elegivel)
    for y, x in zip(ys.tolist(), xs.tolist()):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and fundo[ny, nx]:
                pilha.append((y, x))
                break
    while pilha:
        y, x = pilha.pop()
        if fundo[y, x] or not elegivel[y, x]:
            continue
        fundo[y, x] = True
        n_familia += 1
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and elegivel[ny, nx] \
                    and not fundo[ny, nx]:
                pilha.append((ny, nx))

    saida = rgba.copy()
    saida[..., 3] = np.where(fundo, 0, 255)      # alfa BINÁRIO
    saida[fundo, :3] = 0                          # cor zerada onde é vazio

    # ---- 5. mancha isolada no INTERIOR ----
    # A pedra ficou com 3px de rgb(135,12,149) no meio do granito cinza:
    # fundo que vazou para dentro, longe da borda do alfa e a 42° de matiz
    # da chave — fora do alcance das passadas 1 a 4.
    #
    # Aqui se SUBSTITUI, não se corta: são pixels interiores, e cortar
    # abriria buraco no sprite. A cor nova é a MODA dos 8 vizinhos opacos,
    # nunca a média — média de duas cores de granito devolve um cinza que
    # não existe na paleta da arte.
    n_mancha = _despicar(saida)
    n_mancha += _cortar_ilhas_magenta(saida)

    restante = int((~fundo & (d < LIM_FRANJA)).sum())
    return Image.fromarray(saida, "RGBA"), {
        "chave": tuple(int(v) for v in chave),
        "inundacao": n_inundacao, "ilhas": n_ilhas, "franja": n_franja,
        "familia": n_familia, "mancha": n_mancha,
        "fundo_total": int(fundo.sum()), "px": H * W,
        "residuo": restante,
    }


def _import_pixelart(caminho: Path) -> None:
    """Escreve o .import com os parâmetros de pixel art.

    Três chaves importam, e as três defaults da Godot estão erradas para
    este uso:

      compress/mode=0            Lossless. O default (VRAM comprimido)
                                 aplica compressão com perda por bloco — num
                                 sprite de 32px isso muda cor de pixel, e
                                 pixel art não tem onde esconder isso.
      process/fix_alpha_border   false. Ele sangra a cor do sprite para
                                 dentro dos pixels transparentes, para o
                                 filtro linear não puxar preto na borda. Com
                                 Nearest não existe esse problema, e o
                                 sangramento ALTERA os pixels de borda que
                                 acabamos de recortar com cuidado.
      detect_3d/compress_to=0    desliga a heurística que recomprime a
                                 textura sozinha se ela for usada em 3D.
    """
    uid = "uid://" + _uid_de(caminho)
    caminho.with_suffix(caminho.suffix + ".import").write_text(
        f'''[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{caminho.name}-{_md5(caminho)}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/sprites/{caminho.name}"
dest_files=["res://.godot/imported/{caminho.name}-{_md5(caminho)}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
''')


def _md5(caminho: Path) -> str:
    import hashlib
    return hashlib.md5(str(caminho.name).encode()).hexdigest()


def _uid_de(caminho: Path) -> str:
    """UID determinístico a partir do nome — a Godot exige um, e um estável
    evita que cada reimportação gere um id novo e suje o diff."""
    import hashlib
    h = hashlib.md5(("hibit:" + caminho.name).encode()).digest()
    alfabeto = "abcdefghijklmnopqrstuvwxyz0123456789"
    n = int.from_bytes(h[:8], "big")
    saida = ""
    for _ in range(12):
        saida += alfabeto[n % len(alfabeto)]
        n //= len(alfabeto)
    return saida


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sem-import", action="store_true",
                    help="não reescreve os .import (deixa a Godot gerar)")
    a = ap.parse_args()

    if not CRU.exists():
        sys.exit("nada em ferramentas/hibit/cru/ — rode gerar_assets.py antes")
    DEST.mkdir(parents=True, exist_ok=True)

    print("\n=== TRATAMENTO ===\n")
    print("── tilesets (opacos, só copiados) ──")
    for p in sorted(CRU.glob("*_atlas.png")):
        im = Image.open(p).convert("RGBA")
        destino = DEST / p.name
        im.save(destino)
        a_min = int(np.array(im)[..., 3].min())
        ok(im.size == (128, 128) and a_min == 255, p.stem,
           f"{im.size[0]}×{im.size[1]} · alfa mínimo {a_min} (deve ser opaco)")
        if not a.sem_import:
            _import_pixelart(destino)

    # Os personagens vêm de /create-character-with-4-directions com alfa já
    # BINÁRIO e fundo transparente — passar chroma key neles seria procurar
    # um fundo magenta que não existe e, pior, cortar a roupa por matiz.
    print("\n── personagens (já transparentes, só copiados) ──")
    for p in sorted(CRU.glob("aldeao_*.png")):
        im = Image.open(p).convert("RGBA")
        arr = np.array(im)
        parcial = int(((arr[..., 3] > 0) & (arr[..., 3] < 255)).sum())
        if parcial:
            arr[..., 3] = np.where(arr[..., 3] > 127, 255, 0)
            im = Image.fromarray(arr, "RGBA")
        destino = DEST / p.name
        im.save(destino)
        if not a.sem_import:
            _import_pixelart(destino)
        cob = int((np.array(im)[..., 3] == 255).sum()) * 100 // (im.size[0] * im.size[1])
        ok(cob >= 5, p.stem, f"{im.size[0]}×{im.size[1]} · {cob}% de silhueta"
                             f" · {parcial}px parciais binarizados")

    print("\n── props (chroma key) ──")
    for p in sorted(CRU.glob("prop_*.png")):
        im = Image.open(p)
        cortada, r = recortar(im)
        destino = DEST / p.name
        cortada.save(destino)
        if not a.sem_import:
            _import_pixelart(destino)
        frac = r["fundo_total"] * 100 // r["px"]
        print(f"  {p.stem:22} chave {str(r['chave']):16} "
              f"fundo {frac:2d}% (borda {r['inundacao']} + ilha {r['ilhas']} "
              f"+ franja {r['franja']} + matiz {r['familia']}) "
              f"· manchas {r['mancha']}")

    print("\n=== VERIFICAÇÃO ===\n")
    for p in sorted(DEST.glob("*.png")):
        arr = np.array(Image.open(p).convert("RGBA"))
        alfa = arr[..., 3]
        parcial = int(((alfa > 0) & (alfa < 255)).sum())
        ok(parcial == 0, f"{p.stem}: alfa binário", f"{parcial}px parciais")

    for p in sorted(list(DEST.glob("prop_*.png")) + list(DEST.glob("aldeao_*.png"))):
        arr = np.array(Image.open(p).convert("RGBA"))
        opaco = arr[..., 3] == 255
        if not opaco.any():
            ok(False, f"{p.stem}: sobrou sprite", "recorte comeu tudo")
            continue
        rgb = arr[..., :3][opaco].astype(int)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        # magenta remanescente: vermelho e azul altos com verde afundado
        mag = int((((r > 120) & (b > 90) & (g < np.minimum(r, b) * 0.72))).sum())
        ok(mag == 0, f"{p.stem}: sem magenta residual", f"{mag}px")
        cobertura = int(opaco.sum()) * 100 // opaco.size
        ok(8 <= cobertura <= 92, f"{p.stem}: silhueta plausível",
           f"{cobertura}% do quadro é sprite")

    if not a.sem_import:
        n = len(list(DEST.glob("*.png.import")))
        print()
        ok(n == len(list(DEST.glob("*.png"))),
           ".import escrito para todo PNG", f"{n} arquivos")

    print("\n" + "=" * 50)
    print(f"{_verdes} verdes · {_vermelhos} vermelhos")
    return 1 if _vermelhos else 0


if __name__ == "__main__":
    sys.exit(main())
