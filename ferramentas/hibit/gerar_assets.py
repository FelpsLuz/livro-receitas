#!/usr/bin/env python3
"""Gera a arte Hi-Bit do jogo pela API do PixelLab (v2).

    export PIXELLAB_SECRET="..."
    python3 ferramentas/hibit/gerar_assets.py --listar      # plano e custo
    python3 ferramentas/hibit/gerar_assets.py --saldo
    python3 ferramentas/hibit/gerar_assets.py --grupo tileset
    python3 ferramentas/hibit/gerar_assets.py --tudo

Saída CRUA em ferramentas/hibit/cru/ — o tratamento (chroma key, recorte,
verificação) é do tratar_assets.py, que lê de lá e escreve em
reino-por-conquista-godot/assets/sprites/. Separar as duas etapas é o que
permite re-tratar sem gastar API de novo.

--------------------------------------------------------------------
POR QUE TRÊS TILESETS E NÃO UM
--------------------------------------------------------------------
O prompt pedido descrevia "grama, caminho de terra e borda d'água" numa
folha só. O endpoint /create-tileset não faz isso: ele gera a transição
WANG entre DOIS materiais (`lower_description` × `upper_description`), que
é justamente o formato que o MapaV2 já consome — grade 4×4, 16 combinações
dos 4 cantos. Uma folha multi-material teria que ser fatiada à mão e não
teria as transições.

Então o pedido vira três chamadas, e o resultado é MELHOR que o pedido:
grama×terra, grama×pedra e areia×água, com borda de verdade entre cada par.
Os três nomes casam com MapaV2.ATLAS, que já existia.

--------------------------------------------------------------------
POR QUE FUNDO MAGENTA E NÃO no_background
--------------------------------------------------------------------
A API tem `no_background=true`, e ele funciona — mas erra a borda em sprite
pequeno: come pixel de contorno e deixa franja semitransparente, que numa
arte de 32px é uma fração enorme da silhueta. Pedir fundo magenta chapado e
recortar por chroma key dá controle sobre o limiar e mantém o alfa BINÁRIO,
que é o que pixel art quer. Foi o que o pedido especificou, e está certo.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.pixellab.ai/v2"
RAIZ = Path(__file__).resolve().parent.parent.parent
CRU = Path(__file__).resolve().parent / "cru"
GASTO = Path(__file__).resolve().parent / "gasto.json"
IDS = Path(__file__).resolve().parent / "ids.json"

MAGENTA = "solid magenta #FF00FF background"
ESTILO = ("Stardew Valley aesthetic, hi-bit pixel art, vibrant earthy "
          "colors, flat lighting, clean readable silhouette")

# ---------------------------------------------------------------
# O PLANO
# ---------------------------------------------------------------
# Cada tileset é um par de materiais. `lower` é o material do bit 0 da
# máscara Wang e `upper` o do bit 1 — no MapaV2, `dentro()` devolvendo true
# significa UPPER. Por isso a grama é sempre o upper nos dois primeiros:
# `pintar_wang` pergunta "este canto é grama?".
TILESETS = [
    {
        "nome": "campo_terra_atlas",
        "lower_description": "dry dirt path, packed earth, small pebbles",
        "upper_description": "lush green summer grass with small blades",
        "transition_description": "soft irregular edge where grass meets dirt",
    },
    {
        "nome": "grama_pedra_atlas",
        "lower_description": "grey cobblestone road, fitted stones",
        "upper_description": "lush green summer grass with small blades",
        "transition_description": "grass creeping over the stone edge",
    },
    {
        "nome": "praia_agua_atlas",
        "lower_description": "clear shallow blue river water with ripples",
        "upper_description": "pale sandy river shore",
        "transition_description": "wet sand and light foam at the water edge",
    },
]

# Props e personagem: pixflux, fundo magenta, recorte depois.
# O tamanho é o da ARTE final; o tratamento não reescala.
IMAGENS = [
    {
        "nome": "prop_arvore_carvalho", "w": 64, "h": 80,
        "d": ("2D top-down RPG prop, a healthy oak tree with round leafy "
              "canopy and short trunk, seen from a high top-down angle"),
    },
    {
        "nome": "prop_pedra", "w": 48, "h": 40,
        "d": ("2D top-down RPG prop, a grey stone boulder with moss patches, "
              "seen from a high top-down angle"),
    },
    {
        "nome": "prop_arbusto", "w": 32, "h": 32,
        "d": "2D top-down RPG prop, a small round green bush",
    },
    {
        "nome": "prop_tronco", "w": 40, "h": 32,
        "d": "2D top-down RPG prop, a fallen mossy log lying on the ground",
    },
]

# ---------------------------------------------------------------
# PERSONAGEM: por que NÃO é pixflux com fundo magenta
# ---------------------------------------------------------------
# A primeira tentativa gerou três pixflux 32x48 pedindo fundo magenta, um
# por direção. Falhou de duas formas, e as duas só apareceram medindo:
#
#   1. O FUNDO TINGIU O PERSONAGEM. A túnica saiu em rgb(91,52,85) e as
#      botas em rgb(43,22,48) — roxo, não marrom. O modelo puxa a paleta do
#      sujeito para a do fundo que a gente pediu. Aí o chroma key por
#      família de matiz comia o personagem junto com o fundo: sobravam 5%
#      de silhueta. Não havia limiar que separasse os dois, porque não eram
#      coisas diferentes.
#   2. TRÊS CHAMADAS INDEPENDENTES = TRÊS PESSOAS. Sem vínculo entre elas,
#      cabelo, roupa e altura mudavam de uma direção para a outra.
#
# `/create-character-with-4-directions` resolve os dois: devolve as quatro
# rotações do MESMO personagem, com fundo transparente e alfa já BINÁRIO
# (medido: 0 pixels parciais). Nenhum chroma key é necessário.
#
# O canvas sai ~40% maior que o pedido (32x48 → 48x68) para caber animação
# depois. Isso é bom, não ruim: o espaço já está reservado.
PERSONAGENS = [
    {
        "nome": "aldeao", "w": 32, "h": 48,
        "d": ("medieval villager in a brown tunic, leather belt and simple "
              "boots"),
    },
]


# ---------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------
def _chave() -> str:
    k = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not k:
        sys.exit("PIXELLAB_SECRET ausente no ambiente.")
    return k


def _post(caminho: str, corpo: dict, tempo: int = 300) -> tuple[int, dict]:
    req = urllib.request.Request(
        BASE + caminho,
        data=json.dumps(corpo).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + _chave()},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=tempo) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode()[:400]
        return e.code, {"erro": detalhe}


def _get(caminho: str, tempo: int = 120) -> tuple[int, dict]:
    req = urllib.request.Request(
        BASE + caminho,
        headers={"Authorization": "Bearer " + _chave()})
    try:
        with urllib.request.urlopen(req, timeout=tempo) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, {"erro": e.read().decode()[:400]}


def saldo() -> float:
    _, d = _get("/balance")
    return float(d.get("credits", {}).get("usd", 0.0))


# ---------------------------------------------------------------
# GASTO — o registro é do valor REAL que a resposta informa
# ---------------------------------------------------------------
def _registrar(rotulo: str, resposta: dict) -> float:
    uso = resposta.get("usage") or {}
    real = float(uso.get("usd", 0.0))
    dados = {"total_usd": 0.0, "chamadas": []}
    if GASTO.exists():
        dados = json.loads(GASTO.read_text())
    dados["chamadas"].append({"rotulo": rotulo, "usd": real})
    dados["total_usd"] = sum(c["usd"] for c in dados["chamadas"])
    GASTO.parent.mkdir(parents=True, exist_ok=True)
    GASTO.write_text(json.dumps(dados, indent=1))
    return real


def _salvar_b64(b64: str, destino: Path) -> int:
    if b64.startswith("data:"):
        b64 = b64.split(",", 1)[1]
    dados = base64.b64decode(b64)
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_bytes(dados)
    return len(dados)


def _extrair(d: dict) -> str:
    """A imagem vem em `image.base64` na maioria dos endpoints."""
    img = d.get("image")
    if isinstance(img, dict):
        return str(img.get("base64", ""))
    if isinstance(img, str):
        return img
    return ""


# ---------------------------------------------------------------
# GERAÇÃO
# ---------------------------------------------------------------
# A tabela Wang do MapaV2, espelhada aqui. Máscara: NW=1, NE=2, SW=4, SE=8;
# bit ligado = material UPPER. O valor é (coluna, linha) no atlas 4×4.
#
# É a partir dela que o atlas é MONTADO, e não o contrário: a API devolve os
# 16 tiles com a máscara de cantos explícita em cada um, então dá para pôr
# cada tile na célula que o MapaV2 vai procurar. O layout fica correto por
# CONSTRUÇÃO — sem depender de a API e a engine terem escolhido a mesma
# convenção, que é onde este tipo de integração costuma quebrar em silêncio.
WANG = {
    0: (0, 3), 1: (3, 3), 2: (0, 2), 3: (1, 2),
    4: (0, 0), 5: (3, 2), 6: (2, 3), 7: (3, 1),
    8: (1, 3), 9: (0, 1), 10: (1, 0), 11: (2, 2),
    12: (3, 0), 13: (2, 0), 14: (1, 1), 15: (2, 1),
}
BIT = {"NW": 1, "NE": 2, "SW": 4, "SE": 8}


def montar_atlas(resposta: dict, destino: Path) -> bool:
    """Os 16 tiles viram uma folha 4×4 na ordem do MapaV2."""
    from PIL import Image
    import io

    ts = resposta.get("tileset") or {}
    tiles = ts.get("tiles") or []
    if len(tiles) != 16:
        print(f"    ❌ esperava 16 tiles, vieram {len(tiles)}")
        return False
    lado = int(ts.get("tile_size", {}).get("width", 32))
    folha = Image.new("RGBA", (lado * 4, lado * 4), (0, 0, 0, 0))
    postos = set()
    for t in tiles:
        mascara = 0
        for canto, bit in BIT.items():
            if str(t.get("corners", {}).get(canto)) == "upper":
                mascara |= bit
        cx, cy = WANG[mascara]
        b64 = str(t.get("image", {}).get("base64", ""))
        if b64.startswith("data:"):
            b64 = b64.split(",", 1)[1]
        im = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")
        if im.size != (lado, lado):
            im = im.resize((lado, lado), Image.NEAREST)
        folha.paste(im, (cx * lado, cy * lado))
        postos.add(mascara)
    if len(postos) != 16:
        print(f"    ❌ só {len(postos)} máscaras distintas — atlas incompleto")
        return False
    destino.parent.mkdir(parents=True, exist_ok=True)
    folha.save(destino)
    print(f"    ✅ atlas {lado * 4}×{lado * 4} · 16 máscaras distintas")
    return True


def gerar_tileset(spec: dict, seed: int | None = None) -> bool:
    corpo = {
        "lower_description": spec["lower_description"],
        "upper_description": spec["upper_description"],
        "transition_description": spec["transition_description"],
        "tile_size": {"width": 32, "height": 32},
        "view": "high top-down",
        "outline": "selective outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "text_guidance_scale": 8.0,
    }
    if seed is not None:
        corpo["seed"] = seed
    print(f"  ⟳ {spec['nome']}: {spec['upper_description'][:34]}… × "
          f"{spec['lower_description'][:28]}…")
    codigo, d = _post("/create-tileset", corpo)
    if codigo not in (200, 202):
        print(f"    ❌ HTTP {codigo}: {str(d.get('erro'))[:220]}")
        return False
    _registrar(spec["nome"], d)

    if codigo == 202:
        tid = str(d.get("tileset_id"))
        # o id vai para disco ANTES do poll: se a sessão cair no meio, o
        # trabalho já foi pago e `--recolher` o busca sem gerar de novo
        ids = {}
        if IDS.exists():
            ids = json.loads(IDS.read_text())
        ids[spec["nome"]] = tid
        IDS.write_text(json.dumps(ids, indent=1))
        print(f"    tileset {tid} — aguardando", end="", flush=True)
        return _colher(spec["nome"], tid)

    (CRU / f"{spec['nome']}.json").write_text(json.dumps(d))
    return montar_atlas(d, CRU / f"{spec['nome']}.png")


def _colher(nome: str, tid: str, tentativas: int = 90) -> bool:
    """Busca um tileset já pago até ele ficar pronto."""
    for _ in range(tentativas):
        c, d = _get(f"/tilesets/{tid}")
        if c == 200:
            ts = d.get("tileset") or {}
            if ts.get("tiles"):
                print()
                (CRU / f"{nome}.json").write_text(json.dumps(d))
                return montar_atlas(d, CRU / f"{nome}.png")
            estado = str(d.get("metadata", {}).get("status", "")).lower()
            if estado in ("failed", "error"):
                print(f"\n    ❌ job falhou: {d.get('metadata')}")
                return False
        print(".", end="", flush=True)
        time.sleep(6)
    print("\n    ❌ tempo esgotado (o id ficou em ids.json para --recolher)")
    return False


def gerar_imagem(spec: dict, magenta: bool = True,
                 seed: int | None = None, sufixo: str = "") -> bool:
    partes = [spec["d"], ESTILO]
    if magenta:
        partes.append(MAGENTA)
    corpo = {
        "description": ", ".join(partes),
        "image_size": {"width": spec["w"], "height": spec["h"]},
        "view": "high top-down",
        "outline": "single color black outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "text_guidance_scale": 8.5,
        "no_background": False,
    }
    if spec.get("direcao"):
        corpo["direction"] = spec["direcao"]
    if seed is not None:
        corpo["seed"] = seed
    nome = spec["nome"] + sufixo
    print(f"  ⟳ {nome} ({spec['w']}×{spec['h']})")
    codigo, d = _post("/create-image-pixflux", corpo)
    if codigo != 200:
        print(f"    ❌ HTTP {codigo}: {str(d.get('erro'))[:220]}")
        return False
    real = _registrar(nome, d)
    b64 = _extrair(d)
    if not b64:
        print(f"    ❌ resposta sem imagem: {list(d.keys())}")
        return False
    n = _salvar_b64(b64, CRU / f"{nome}.png")
    print(f"    ✅ {n // 1024} KB · US$ {real:.4f}")
    return True


# ---------------------------------------------------------------
def gerar_personagem(spec: dict, seed: int = 4242) -> bool:
    """4 rotações do MESMO personagem, transparentes. Ver a nota acima."""
    corpo = {
        "description": spec["d"] + ", " + ESTILO,
        "image_size": {"width": spec["w"], "height": spec["h"]},
        "view": "high top-down",
        "outline": "single color black outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "text_guidance_scale": 8.0,
        "seed": seed,
    }
    print(f"  ⟳ {spec['nome']} ({spec['w']}×{spec['h']}, 4 direções)")
    codigo, d = _post("/create-character-with-4-directions", corpo)
    if codigo != 200:
        print(f"    ❌ HTTP {codigo}: {str(d.get('erro'))[:220]}")
        return False
    _registrar(spec["nome"], d)
    cid = str(d.get("character_id"))
    ids = json.loads(IDS.read_text()) if IDS.exists() else {}
    ids[spec["nome"]] = cid
    IDS.write_text(json.dumps(ids, indent=1))
    print(f"    personagem {cid} — aguardando", end="", flush=True)

    for _ in range(60):
        time.sleep(6)
        c2, d2 = _get(f"/characters/{cid}")
        if c2 == 200 and str(d2.get("status", "")).lower() == "completed":
            print()
            return _baixar_rotacoes(spec["nome"], cid)
        print(".", end="", flush=True)
    print("\n    ❌ tempo esgotado (id em ids.json)")
    return False


def _baixar_rotacoes(nome: str, cid: str) -> bool:
    """O ZIP do personagem traz Idle/rotations/<direcao>.png."""
    import io
    import zipfile
    req = urllib.request.Request(
        f"{BASE}/characters/{cid}/zip",
        headers={"Authorization": "Bearer " + _chave()})
    with urllib.request.urlopen(req, timeout=180) as r:
        bruto = r.read()
    z = zipfile.ZipFile(io.BytesIO(bruto))
    achados = 0
    for membro in z.namelist():
        if not membro.endswith(".png"):
            continue
        direcao = Path(membro).stem
        CRU.mkdir(parents=True, exist_ok=True)
        (CRU / f"{nome}_{direcao}.png").write_bytes(z.read(membro))
        achados += 1
    print(f"    ✅ {achados} rotações")
    return achados >= 4


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--saldo", action="store_true")
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--grupo", choices=["tileset", "props", "personagem"])
    ap.add_argument("--tudo", action="store_true")
    ap.add_argument("--recolher", action="store_true",
                    help="busca tilesets já pagos (ids.json) sem gerar de novo")
    ap.add_argument("--variantes", type=int, default=1,
                    help="quantas versões de cada imagem gerar (seeds "
                         "diferentes), para escolher a melhor")
    a = ap.parse_args()

    if a.recolher:
        ids = json.loads(IDS.read_text()) if IDS.exists() else {}
        if not ids:
            sys.exit("ids.json vazio — nada para recolher")
        CRU.mkdir(parents=True, exist_ok=True)
        for nome, tid in ids.items():
            print(f"  ⟳ recolhendo {nome} ({tid})", end="", flush=True)
            _colher(nome, tid)
        return

    if a.saldo:
        print(f"saldo: US$ {saldo():.4f}")
        return

    if a.listar:
        print(f"{len(TILESETS)} tilesets Wang 32px (assíncronos)")
        for t in TILESETS:
            print(f"   {t['nome']:22} {t['upper_description'][:30]}… × "
                  f"{t['lower_description'][:24]}…")
        print(f"{len(IMAGENS)} props + {len(PERSONAGENS)} personagens "
              f"(pixflux, fundo magenta)")
        for i in IMAGENS + PERSONAGENS:
            print(f"   {i['nome']:22} {i['w']}×{i['h']}")
        print(f"\nsaldo atual: US$ {saldo():.4f}")
        return

    CRU.mkdir(parents=True, exist_ok=True)
    antes = saldo()
    print(f"saldo antes: US$ {antes:.4f}\n")

    if a.tudo or a.grupo == "tileset":
        print("── TILESETS ──")
        for t in TILESETS:
            gerar_tileset(t)
    if a.tudo or a.grupo == "props":
        print("── PROPS ──")
        for i in IMAGENS:
            for v in range(a.variantes):
                gerar_imagem(i, seed=1000 + v * 137,
                             sufixo="" if v == 0 else f"_v{v}")
    if a.tudo or a.grupo == "personagem":
        print("── PERSONAGENS ──")
        for i in PERSONAGENS:
            gerar_personagem(i)

    depois = saldo()
    print(f"\nsaldo depois: US$ {depois:.4f} · gasto nesta rodada: "
          f"US$ {antes - depois:.4f}")


if __name__ == "__main__":
    main()
