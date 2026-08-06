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


# ---------------------------------------------------------------
# ÍCONES DE INTERFACE
# ---------------------------------------------------------------
# `/generate-ui-v2`, não pixflux. Pixflux devolve pixel art, e a interface
# deixou de ser pixel art — ver docs/INTERFACE.md.
#
# UMA COR SÓ, e é a regra que faz vinte ícones parecerem um conjunto:
# o ícone não pode competir com o número que está do lado dele. Quem tinge
# para alerta ou ganho é a interface, em runtime; o arquivo nasce
# monocromático no latão do tema.
#
# Custa ~US$ 0,095 por ícone — 10x uma chamada de sprite. É o preço de um
# endpoint que devolve alfa binário e silhueta limpa sem tratamento.
ICONE_ESTILO = ("flat minimal icon, single solid color silhouette, clean "
                "geometric shape, thick uniform stroke, no gradient, no "
                "shadow, no frame, no text, no border box, centered, "
                "medieval fantasy resource icon for a management game UI")
ICONE_PALETA = "single warm brass gold #E8B04B on transparent background"
ICONE_LADO = 192

## O que cada ícone DESENHA. A chave é o nome que Icones.TODOS usa.
ICONES = {
    "moedas": "a small stack of three round coins",
    "trigo": "a bundled sheaf of wheat",
    "madeira": "two stacked cut logs seen from the end",
    "espada": "an upright straight sword",
    "escudo": "a heater shield",
    "arco": "a longbow with its string",
    "lanca": "an upright spear with a leaf blade",
    "pao": "a round rustic loaf of bread",
    "cerveja": "a foaming tankard",
    "pergaminho": "a partly unrolled scroll",
    "gema": "a faceted gemstone",
    "coroa": "a simple five point crown",
    "ferro": "an iron ingot bar",
    "sal": "an open sack of salt",
    "tecidos": "a folded bolt of cloth",
    "cavalos": "a horse head in profile",
    "espiao": "a hooded head in profile",
    "neblina": "three stacked horizontal fog bands",
    "populacao": "three simple human figures side by side",
    "moral": "a raised banner on a pole",
    "ampulheta": "an hourglass",
    "cerco": "a trebuchet arm",
    "renome": "a laurel wreath around a star",
    "calendario": "a calendar page grid",
    "felicidade": "a simple smiling face",
    "tropa": "three upright spears in formation",
    "alianca": "two clasped hands",
    "carta": "a sealed letter with a wax seal",
    "correntes": "three chain links",
    "caveira": "a skull",
    "louros": "a laurel wreath",
    "forca": "a flexed arm",
    "carisma": "a speaking mouth with sound lines",
    "gestao": "a balance scale",
    "intriga": "a dagger behind a mask",
    "lorde": "a crowned head in profile",
    "som": "a bell with sound waves",
    "mudo": "a bell with a slash through it",
    # ícones de ABA: um por seção da interface. Reaproveitar os de recurso
    # nas abas confundiria — a aba Mercado com a moeda do HUD faria o
    # jogador ler "ouro" onde a interface diz "seção".
    "terra": "a plowed field with furrows",
    "mapa": "an unrolled map with a route line",
    "mercado": "a market stall with an awning",
    "familia": "two adult figures and a child",
}


## Tier 0 da API aceita 8 jobs simultâneos. Disparar os 38 de uma vez
## devolve 429 nos 30 últimos — e o 429 não custa nada, mas também não
## gera nada. A fila abaixo mantém a janela cheia sem estourar.
CONCORRENTES = 8


def gerar_icones_em_lote(nomes: list[str], jobs_arq: Path) -> None:
    """Mantém 8 jobs no ar até a lista acabar, colhendo conforme terminam."""
    import time as _t
    fila = [n for n in nomes if not (CRU / f"icone_{n}.png").exists()]
    ativos: dict = {}
    if jobs_arq.exists():
        ativos = {k: v for k, v in json.loads(jobs_arq.read_text()).items()
                  if not (CRU / f"icone_{k}.png").exists()}
        fila = [n for n in fila if n not in ativos]
    feitos = 0
    tentativas: dict = {}
    while fila or ativos:
        while fila and len(ativos) < CONCORRENTES:
            nome = fila.pop(0)
            novo = pedir_icones([nome], tentativas.get(nome, 0))
            if novo:
                ativos.update(novo)
            else:
                fila.append(nome)   # 429: devolve para o fim e espera
                break
        jobs_arq.write_text(json.dumps(ativos, indent=1))
        _t.sleep(8)
        faltam, refazer = colher_icones(ativos)
        feitos += len(ativos) - len(faltam) - len(refazer)
        ativos = {k: v for k, v in ativos.items() if k in faltam}
        for nome in refazer:
            tentativas[nome] = tentativas.get(nome, 0) + 1
            if tentativas[nome] <= 3:
                fila.append(nome)
            else:
                print(f"  ❌ {nome}: 4 tentativas, todas vazias — desisto")
        print(f"    [{feitos} prontos · {len(ativos)} no ar · "
              f"{len(fila)} na fila]", flush=True)
    print(f"\n{feitos} ícones gerados")


def pedir_icones(nomes: list[str], tentativa: int = 0) -> dict:
    """Dispara os jobs e devolve {nome: job_id}. NÃO espera.

    `tentativa` desloca a semente: repetir um pedido com a MESMA semente
    devolve a mesma imagem, então um ícone que veio vazio só muda se a
    semente mudar.
    """
    jobs = {}
    for nome in nomes:
        corpo = {
            "description": "%s, %s" % (ICONES[nome], ICONE_ESTILO),
            "image_size": {"width": ICONE_LADO, "height": ICONE_LADO},
            "color_palette": ICONE_PALETA,
            "no_background": True,
            "seed": 4242 + tentativa * 1000,
        }
        c, d = _post("/generate-ui-v2", corpo)
        if c in (200, 202):
            _registrar("icone_" + nome, d)
            jobs[nome] = str(d.get("background_job_id") or "")
            print(f"  ⟳ {nome:14} {jobs[nome][:8]}")
        else:
            print(f"  ❌ {nome:14} HTTP {c} {str(d.get('erro'))[:120]}")
    return jobs


def colher_icones(jobs: dict) -> tuple[list[str], list[str]]:
    """Baixa os que já terminaram.

    Devolve (ainda_no_ar, refazer): o primeiro são os jobs que continuam
    rodando, o segundo os que terminaram mas entregaram lixo e precisam de
    um pedido NOVO — repolar o mesmo job devolveria o mesmo lixo para sempre.
    """
    faltam, refazer = [], []
    for nome, job in jobs.items():
        destino = CRU / f"icone_{nome}.png"
        if destino.exists():
            continue
        c, d = _get(f"/background-jobs/{job}")
        lr = d.get("last_response")
        if str(d.get("status", "")).lower() != "completed" or not isinstance(lr, dict):
            faltam.append(nome)
            continue
        imgs = lr.get("images") or []
        b64 = str(imgs[0].get("base64", "")) if imgs else ""
        if not b64:
            print(f"  ❌ {nome}: terminou sem imagem")
            refazer.append(nome)
            continue
        _salvar_b64(b64, destino)
        # o gerador às vezes devolve 192×192 de alfa zero — um "sucesso"
        # que é um arquivo vazio. Sem esta checagem ele entra no projeto e
        # só aparece como um buraco no HUD, sem nada acusando.
        if _vazio(destino):
            print(f"  ❌ {nome}: veio TRANSPARENTE — descartado, vai repetir")
            destino.unlink()
            refazer.append(nome)
            continue
        print(f"  ✅ {nome}")
    return faltam, refazer


def _vazio(caminho: Path) -> bool:
    """True se o PNG não tem pixel opaco nenhum."""
    try:
        from PIL import Image
        import numpy as np
        a = np.array(Image.open(caminho).convert("RGBA"))
        return bool((a[..., 3] > 127).sum() == 0)
    except Exception:
        return False


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--saldo", action="store_true")
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--grupo", choices=["tileset", "props", "personagem"])
    ap.add_argument("--tudo", action="store_true")
    ap.add_argument("--icones", action="store_true",
                    help="dispara os jobs de ícone e grava jobs_icones.json")
    ap.add_argument("--colher-icones", action="store_true")
    ap.add_argument("--retratos", action="store_true",
                    help="os nove bustos de tropa (opacos, sem recorte)")
    ap.add_argument("--eventos", action="store_true",
                    help="as dez ilustrações de modal (opacas)")
    ap.add_argument("--interpolados", action="store_true",
                    help="os 3 degraus que faltam entre os 6 provados")
    ap.add_argument("--estagios", action="store_true",
                    help="os seis quadros da terra, em cadeia")
    ap.add_argument("--forca", type=int, default=0,
                    help="fixa init_image_strength em todos os degraus; "
                         "0 (padrão) usa FORCA_POR_ESTAGIO")
    ap.add_argument("--recolher", action="store_true",
                    help="busca tilesets já pagos (ids.json) sem gerar de novo")
    ap.add_argument("--variantes", type=int, default=1,
                    help="quantas versões de cada imagem gerar (seeds "
                         "diferentes), para escolher a melhor")
    a = ap.parse_args()

    JOBS = Path(__file__).resolve().parent / "jobs_icones.json"
    if a.icones:
        CRU.mkdir(parents=True, exist_ok=True)
        antes = saldo()
        print(f"saldo antes: US$ {antes:.4f}")
        gerar_icones_em_lote(list(ICONES.keys()), JOBS)
        print(f"saldo depois: US$ {saldo():.4f} (gasto {antes - saldo():.4f})")
        return

    if a.retratos:
        antes = saldo()
        print(f"saldo antes: US$ {antes:.4f}")
        gerar_retratos_tropa()
        print(f"saldo depois: US$ {saldo():.4f} (gasto {antes - saldo():.4f})")
        return

    if a.eventos:
        antes = saldo()
        print(f"saldo antes: US$ {antes:.4f}")
        gerar_eventos()
        print(f"saldo depois: US$ {saldo():.4f} (gasto {antes - saldo():.4f})")
        return

    if a.interpolados:
        antes = saldo()
        print(f"saldo antes: US$ {antes:.4f}")
        gerar_interpolados()
        print(f"saldo depois: US$ {saldo():.4f} (gasto {antes - saldo():.4f})")
        return

    if a.estagios:
        antes = saldo()
        print(f"saldo antes: US$ {antes:.4f}")
        gerar_estagios(forca=a.forca)
        print(f"saldo depois: US$ {saldo():.4f} (gasto {antes - saldo():.4f})")
        return

    if a.colher_icones:
        jobs = json.loads(JOBS.read_text())
        faltam, refazer = colher_icones(jobs)
        print(f"\nfaltam {len(faltam)}: {', '.join(faltam[:12])}")
        if refazer:
            print(f"refazer {len(refazer)}: {', '.join(refazer)}")
        return

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



# ===============================================================
# RETRATOS DE TROPA — nove unidades, um quadro cada
# ===============================================================
# OPACOS de propósito, sem recorte. O retrato aparece dentro de uma moldura
# de 52px na linha do quartel; ele é um QUADRO, não um sprite solto no
# terreno. Nada tem que ser recortado, então não há chroma key para errar —
# que é onde os personagens deste projeto já se perderam uma vez (o fundo
# magenta tingiu a túnica e o recorte comeu o personagem junto).
#
# Enquadramento igual nos nove: busto, de frente, ombros cortados na base.
# É o enquadramento repetido que faz nove quadros lerem como um ELENCO em
# vez de nove ilustrações avulsas — e é o que deixa o jogador comparar
# unidade com unidade percorrendo a coluna.
RETRATO_LADO = 64
# CORPO INTEIRO, e não busto. O primeiro pedido descrevia "bust shot,
# cropped at the chest" e o gerador devolveu figura inteira mesmo assim — e
# fez bem: as nove unidades se distinguem pela ARMA e pela MONTARIA, e um
# corte no peito esconde exatamente as duas. Três das nove são cavalaria;
# num busto, as três seriam o mesmo rosto com elmos diferentes.
RETRATO_ENQUADRE = (
    "full body standing figure facing the viewer, feet near the bottom edge, "
    "centered, plain flat dark neutral background, no text, no frame, "
    "no border, no ground shadow")

RETRATOS_TROPA = {
    "campones": "a poor peasant levy, bare head, patched brown tunic, "
                "holding a wooden pitchfork",
    "lanceiro": "a spearman in a padded gambeson and simple iron kettle "
                "helmet, upright spear shaft beside him",
    "espadachim": "a swordsman in a mail hauberk and open-faced helmet, "
                  "sword raised to his shoulder",
    "barbaro": "a fierce northern barbarian, bare chest, fur cloak, braided "
               "beard, war axe on his shoulder",
    "arqueiro": "an archer in a green hood and leather jerkin, longbow held "
                "across his body",
    "explorador": "a light scout in a hooded grey cloak, keen watchful eyes, "
                  "no armour",
    "cav_leve": "a light horseman in a leather vest and light helmet, "
                "mounted, javelin in hand",
    "arq_cavalo": "a horse archer in a fur-trimmed steppe coat, mounted, "
                  "short recurve bow drawn",
    "cav_pesada": "a heavy knight in full plate armour with a closed visor "
                  "and a plume, mounted, lance upright",
}


# ===============================================================
# ESTÁGIOS DA TERRA — a MESMA terra, seis vezes
# ===============================================================
# 400×224 e não os 480×270 nativos de antes. Duas restrições do endpoint:
# lado máximo 400, e ambos os lados divisíveis por 4. Em vez de gerar menor e
# ampliar (×1,2 não é fator inteiro — borraria a grade inteira), a grade
# nativa da cena desce até a arte. Zero reamostragem em qualquer ponto.
#
# O QUE FAZ AS SEIS SEREM A MESMA TERRA
# -------------------------------------
# Seis chamadas independentes dariam seis vales diferentes, e a evolução de
# Acampamento a Castelo leria como teletransporte. Duas amarras:
#
#   1. `init_image`: cada estágio nasce do ANTERIOR já pronto. O rio, a
#      colina e a linha do horizonte vêm da imagem, não da descrição.
#   2. A mesma cláusula de câmera em todos os seis, e a mesma semente.
#
# A FORÇA DA CADEIA — o número que decide tudo
# --------------------------------------------
# `init_image_strength` alto = obedece mais a imagem de partida. Medido, com
# a mesma descrição de castelo partindo sempre do acampamento:
#
#   300  a terra NÃO EVOLUI. Os seis quadros saem sendo o acampamento com
#        mudanças de folhagem. Foi a primeira leva inteira, e o defeito só
#        apareceu vendo as seis lado a lado — cada uma isolada parecia certa.
#   200  ainda o acampamento, com uma bandeira a mais.
#   120  o vale se mantém (rio, mata, montanha) e a construção entra, mas
#        devagar: chega a "aldeia com torres", não a castelo.
#    60  o castelo aparece inteiro — E O RIO SOME. Força baixa demais e a
#        imagem de partida deixa de ser referência: vira outro lugar.
#
# Uma força FIXA não resolve, e isso também foi medido. Com 140 nos cinco
# passos, a cadeia anda até o estágio 3 e depois EMPACA: 04, 05 e 06 saem
# sendo a mesma aldeia com telhados trocados. O motivo é que a força não pesa
# a distância que falta — quanto mais a imagem de partida já parece um
# povoado, mais ela ancora, e "aldeia → burgo" precisa de mais liberdade que
# "acampamento → aldeia".
#
# Daí a RAMPA: a força cai a cada degrau. Os primeiros passos são pequenos e
# a imagem manda; os últimos são saltos de escala e a descrição manda. O vale
# sobrevive porque cada passo ainda parte do ANTERIOR — o 70 do último degrau
# olha para uma cidadela, não para o acampamento, e por isso não perde o rio
# como perdeu no teste ancorado.
#
# ---------------------------------------------------------------
# POR QUE A CADEIA EM SÉRIE FOI ABANDONADA
# ---------------------------------------------------------------
# Com seis degraus, encadear cada estágio no ANTERIOR funcionou. Com nove,
# não funcionou de jeito nenhum — duas rampas foram testadas e as duas
# devolveram NOVE QUADROS DE TENDA:
#
#   195 → 70   o castelo do último degrau saiu como o acampamento com uma
#              torrinha no meio
#   170 → 128  idem: no estágio 4, que devia ser vila com capela e campos
#              arados, ainda eram as mesmas três tendas
#
# A primeira leitura foi que a força estava alta. Estava, mas não era essa a
# causa. O problema é ESTRUTURAL: encadeando em série, cada degrau herda do
# anterior o VALE *e a TENDA*, e o gerador não distingue "o que é cenário" de
# "o que é povoado". Nove passos multiplicam a herança em vez de diluí-la — a
# tenda atravessa a escada inteira porque nunca existiu um quadro sem ela
# para partir. Baixar mais a força não salva: aos ~60 a imagem de partida
# deixa de ser referência e o vale se perde junto (medido).
#
# A SAÍDA é separar as duas coisas. Gera-se UMA VEZ o vale VAZIO — sem
# povoado nenhum — e os nove degraus são ancorados NELE, não uns nos outros:
#
#   · a continuidade vem do vale, que é o mesmo arquivo nas nove chamadas
#   · a diferença vem da descrição, que nasce limpa a cada degrau, sem tenda
#     nem muralha herdada para o gerador se agarrar
#
# Custa uma imagem a mais e devolve o controle: mudar o degrau 5 não mexe nos
# degraus 6 a 9, o que na cadeia em série obrigava a refazer tudo abaixo.
ESTAGIO_BASE = ("an empty wide green river valley with no buildings and no "
                "people: a river winding through open meadow, dark pine "
                "forest on both slopes, blue mountain ridges behind")

# ---------------------------------------------------------------
# A ÂNCORA HÍBRIDA — e por que as duas puras falharam
# ---------------------------------------------------------------
# Duas arquiteturas foram testadas inteiras, e cada uma falhou pelo motivo
# OPOSTO à outra. É o par de fracassos que aponta a saída.
#
#   SÉRIE PURA (cada degrau nasce do anterior).
#   Funcionou com seis degraus, quebrou com nove: a TENDA atravessa a escada
#   toda. O gerador não separa "cenário" de "povoado", então cada passo herda
#   os dois — e com nove passos a herança se multiplica em vez de diluir.
#   Testado em 195→70 e em 170→128: nove quadros de tenda nas duas.
#
#   VALE PURO (todos os degraus nascem do mesmo vale vazio).
#   Resolve a tenda — cada descrição nasce limpa — e resolve os degraus
#   PEQUENOS: acampamento, paliçada, aldeia e vila saem certos. Mas os
#   GRANDES somem: com 95 o mercado virou duas cabanas, com 85 a vila de
#   pedra virou carroças num campo. Partindo do vazio, encher o vale é
#   distância demais, e a força que o gerador precisaria (~60) é a mesma que
#   já se mediu como o ponto em que o vale deixa de ser referência.
#
# O padrão: o vale vazio é boa partida ENQUANTO O POVOADO É PEQUENO, e má
# partida depois. O anterior é boa partida QUANDO JÁ HÁ POVOADO PARA HERDAR,
# e má partida quando o que há para herdar é uma tenda que devia ter sumido.
#
# Daí o corte em dois trechos:
#
#   0–3   ancorados no VALE VAZIO. Povoado pequeno, distância curta, e
#         nenhuma tenda herdada porque não há de quem herdar.
#   4–8   em SÉRIE a partir do degrau 3. Aqui já existe uma vila de verdade
#         no quadro de partida, então "adicionar mercado" e "refazer em
#         pedra" são passos curtos — que é exatamente o que a cadeia de seis
#         degraus provou saber fazer.
#
# A força cai ao longo dos dois trechos porque o alvo se afasta da partida em
# ambos, só que por razões diferentes: no primeiro trecho o povoado cresce
# sobre o vazio, no segundo a escala cresce sobre o povoado.
CORTE_SERIE = 4
FORCA_POR_ESTAGIO = [130, 118, 108, 100, 120, 105, 90, 78, 68]
ESTAGIO_LADO = (400, 224)
ESTAGIO_CAMERA = (
    "side view landscape panorama seen from across the valley, horizon line "
    "two thirds up, a river curving in from the left, wooded hills on the "
    "right, open sky above, summer daylight")

# NOVE, e cada uma descreve o ALVO em substantivos concretos.
#
# A tentativa de escrever como acréscimo ("as tendas continuam, e agora há
# uma cerca em volta") piorou o resultado, não melhorou: dizer o que fica
# manda o gerador MANTER, e ele mantém — as tendas atravessaram os nove
# quadros. A continuidade é trabalho do `init_image`; a descrição existe para
# puxar na direção contrária, senão nada empurra.
#
# Por isso cada linha nomeia o que a cena É, e nomeia o MATERIAL: "casas de
# madeira com telhado de colmo", "capela de pedra cinza", "muralha de pedra".
# É o substantivo que o gerador pinta.
#
# A ordem segue Dados.NIVEIS_TERRA, degrau a degrau, e a lógica é de
# MATERIAL: lona → madeira → pedra → muralha → castelo. O degrau 6 é o eixo
# da coisa toda — é onde a pedra entra, e sem ele a muralha do 7 apareceria
# sem que nada antes explicasse de onde veio.
ESTAGIOS = [
    ("estagio_01", "a mercenary camp of three canvas tents around a "
                   "campfire, a supply cart, bare trampled earth"),
    ("estagio_02", "a fortified camp: canvas tents ringed by a rough wooden "
                   "palisade with a gate, one log cabin, a dug well"),
    ("estagio_03", "a hamlet of small thatched timber houses, a livestock "
                   "pen, vegetable plots, a wooden palisade around it"),
    ("estagio_04", "a village of timber houses with a wooden chapel and bell "
                   "tower, ploughed strip fields, a wooden bridge over the "
                   "river"),
    ("estagio_05", "a busy market town of packed timber roofs, market stalls "
                   "under striped awnings, a watermill turning on the river, "
                   "craft workshops"),
    ("estagio_06", "a town rebuilt in grey stone: a stone chapel, a stone "
                   "arch bridge over the river, a quarry cut into the "
                   "hillside, carts hauling blocks"),
    ("estagio_07", "a walled town: a grey stone curtain wall with a "
                   "gatehouse and corner towers encircling tiled rooftops"),
    ("estagio_08", "a citadel: tall stone towers along the city wall, a "
                   "cathedral spire above dense tiled roofs, timber docks "
                   "and moored boats on the river"),
    ("estagio_09", "a great stone castle on the hill above a walled city: a "
                   "high keep with banners, concentric walls and round "
                   "towers, a paved road climbing to the gate"),
]


def gerar_retratos_tropa(seed: int = 4242) -> None:
    """Os nove bustos. Opacos: nada aqui passa por chroma key."""
    CRU.mkdir(parents=True, exist_ok=True)
    for chave, desc in RETRATOS_TROPA.items():
        destino = CRU / f"tropa_{chave}.png"
        if destino.exists():
            print(f"  · tropa_{chave} já existe")
            continue
        corpo = {
            "description": "%s, %s, %s" % (desc, RETRATO_ENQUADRE, ESTILO),
            "image_size": {"width": RETRATO_LADO, "height": RETRATO_LADO},
            "view": "side",
            "outline": "single color black outline",
            "shading": "basic shading",
            "detail": "highly detailed",
            "text_guidance_scale": 8.5,
            "no_background": False,
            "seed": seed,
        }
        print(f"  ⟳ tropa_{chave}", end="", flush=True)
        c, d = _post("/create-image-pixflux", corpo)
        if c != 200:
            print(f"\n    ❌ HTTP {c}: {str(d.get('erro'))[:200]}")
            continue
        real = _registrar("tropa_" + chave, d)
        b64 = _extrair(d)
        if not b64:
            print("\n    ❌ resposta sem imagem")
            continue
        _salvar_b64(b64, destino)
        anterior_b64 = b64
        print(f"  ✅ US$ {real:.4f}")


# ---------------------------------------------------------------
# A ESPINHA DORSAL — seis quadros provados, três interpolados
# ---------------------------------------------------------------
# Cinco arquiteturas foram testadas para gerar os nove de uma vez, e todas
# falharam no MESMO ponto: os degraus grandes (mercado, cidade, cidadela)
# saíam como campo vazio. O padrão, depois de tudo:
#
#   Qualquer imagem de partida que seja PAISAGEM AMPLA puxa para o vazio, em
#   qualquer força que ainda preserve o vale. O gerador pinta o que a
#   partida já é; um vale com dois celeiros continua um vale com dois
#   celeiros, e a descrição não o enche.
#
# O único run que produziu cidade murada e castelo de verdade foi a cadeia de
# SEIS, e o que a fez funcionar não foi a força — foi a partida: cada degrau
# partia de um quadro que JÁ ERA POVOADO, então "adensar" era um passo curto.
#
# Daí a estratégia final: as seis provadas viram a ESPINHA DORSAL da escada
# de nove, e só os três degraus que faltam são gerados — cada um a partir do
# VIZINHO DE BAIXO, que é o passo curto que se sabe funcionar.
#
#   1 Acampamento    ← provado 01
#   2 Paliçada       ← GERADO a partir do 1
#   3 Aldeia         ← provado 02
#   4 Vila           ← provado 03
#   5 Burgo          ← provado 04
#   6 Vila de Pedra  ← GERADO a partir do 5
#   7 Cidade Murada  ← provado 05
#   8 Cidadela       ← GERADO a partir do 7
#   9 Castelo        ← provado 06
#
# Os três novos ficam entre dois quadros conhecidos, então cada um tem um
# antes e um depois para não destoar — o que nenhuma das cinco tentativas
# anteriores teve.
INTERPOLADOS = {
    "estagio_02": ("estagio_01", 150,
                   "a mercenary camp of canvas tents now enclosed by a rough "
                   "wooden palisade fence with a gate, a log cabin and a dug "
                   "well beside the tents"),
    # 85 e não 115: a 115 a pedra simplesmente não entrava — o quadro saía
    # como o 05 com uma casa a mais. "Refazer em pedra" troca o MATERIAL de
    # tudo que já está lá, que é um passo maior do que acrescentar prédio, e
    # por isso pede mais licença que os outros dois interpolados.
    "estagio_06": ("estagio_05", 85,
                   "the same village rebuilt in grey stone: a stone chapel, "
                   "a stone arch bridge over the river, a quarry cut into "
                   "the hillside, carts hauling stone blocks"),
    "estagio_08": ("estagio_07", 125,
                   "the same walled town grown into a citadel: tall stone "
                   "towers along the wall, a cathedral spire above dense "
                   "tiled roofs, timber docks and moored boats on the river"),
}


def gerar_interpolados(seed: int = 4242) -> None:
    """Os três degraus que faltam, cada um a partir do vizinho de baixo."""
    CRU.mkdir(parents=True, exist_ok=True)
    for nome in sorted(INTERPOLADOS):
        destino = CRU / f"{nome}.png"
        if destino.exists():
            print(f"  \u00b7 {nome} j\u00e1 existe")
            continue
        de, forca, desc = INTERPOLADOS[nome]
        partida = CRU / f"{de}.png"
        if not partida.exists():
            print(f"  \u274c {nome}: falta a partida {de}.png")
            continue
        corpo = {
            "description": "%s, %s, %s" % (desc, ESTAGIO_CAMERA, ESTILO),
            "image_size": {"width": ESTAGIO_LADO[0], "height": ESTAGIO_LADO[1]},
            "view": "side", "outline": "selective outline",
            "shading": "detailed shading", "detail": "highly detailed",
            "text_guidance_scale": 8.0, "seed": seed,
            "init_image": {"type": "base64",
                           "base64": base64.b64encode(
                               partida.read_bytes()).decode()},
            "init_image_strength": forca,
        }
        print(f"  \u27f3 {nome} \u2190 {de} @{forca}", end="", flush=True)
        c, d = _post("/create-image-pixflux", corpo, tempo=600)
        if c != 200:
            print(f"\n    \u274c HTTP {c}: {str(d.get('erro'))[:250]}")
            continue
        real = _registrar(nome, d)
        b64 = _extrair(d)
        if not b64:
            print("\n    \u274c resposta sem imagem")
            continue
        _salvar_b64(b64, destino)
        print(f"  \u2705 US$ {real:.4f}")


def gerar_estagios(seed: int = 4242, forca: int = 0) -> None:
    """Os quadros da terra, todos ancorados no MESMO vale vazio.

    `forca` em 0 usa FORCA_POR_ESTAGIO. Um valor explícito fixa o mesmo
    número em todos os degraus — serve para experimentar, não para produzir.
    """
    CRU.mkdir(parents=True, exist_ok=True)
    # ---- o vale, uma vez só ----
    base = CRU / "estagio_base.png"
    if not base.exists():
        corpo = {
            "description": "%s, %s, %s" % (ESTAGIO_BASE, ESTAGIO_CAMERA, ESTILO),
            "image_size": {"width": ESTAGIO_LADO[0], "height": ESTAGIO_LADO[1]},
            "view": "side", "outline": "selective outline",
            "shading": "detailed shading", "detail": "highly detailed",
            "text_guidance_scale": 8.0, "seed": seed,
        }
        print("  \u27f3 estagio_base (o vale vazio)", end="", flush=True)
        c, d = _post("/create-image-pixflux", corpo, tempo=600)
        if c != 200:
            print(f"\n    \u274c HTTP {c}: {str(d.get('erro'))[:250]}")
            return
        real = _registrar("estagio_base", d)
        b64 = _extrair(d)
        if not b64:
            print("\n    \u274c resposta sem imagem")
            return
        _salvar_b64(b64, base)
        print(f"  \u2705 US$ {real:.4f}")
    vale_b64 = base64.b64encode(base.read_bytes()).decode()
    anterior_b64 = ""

    for i, (nome, desc) in enumerate(ESTAGIOS):
        destino = CRU / f"{nome}.png"
        if destino.exists():
            print(f"  \u00b7 {nome} j\u00e1 existe")
            # relê: o trecho em SÉRIE precisa deste quadro como partida.
            # Sem isto, retomar um run parcial faz o primeiro degrau do
            # trecho serial cair de volta no vale vazio — e cair em silêncio,
            # porque o resultado ainda é uma imagem plausível.
            anterior_b64 = base64.b64encode(destino.read_bytes()).decode()
            continue
        corpo = {
            "description": "%s, %s, %s" % (desc, ESTAGIO_CAMERA, ESTILO),
            "image_size": {"width": ESTAGIO_LADO[0], "height": ESTAGIO_LADO[1]},
            "view": "side",
            "outline": "selective outline",
            "shading": "detailed shading",
            "detail": "highly detailed",
            "text_guidance_scale": 8.0,
            "no_background": False,
            "seed": seed,
        }
        em_serie = i >= CORTE_SERIE and anterior_b64 != ""
        partida = anterior_b64 if em_serie else vale_b64
        corpo["init_image"] = {"type": "base64", "base64": partida}
        corpo["init_image_strength"] = (
            forca if forca else FORCA_POR_ESTAGIO[min(i, len(FORCA_POR_ESTAGIO) - 1)])
        de = ESTAGIOS[i - 1][0] if em_serie else "vale"
        print(f"  ⟳ {nome} ({ESTAGIO_LADO[0]}×{ESTAGIO_LADO[1]}) ← {de} "
              f"@{corpo['init_image_strength']}", end="", flush=True)
        c, d = _post("/create-image-pixflux", corpo, tempo=600)
        if c != 200:
            print(f"\n    ❌ HTTP {c}: {str(d.get('erro'))[:250]}")
            continue   # um degrau que falha não derruba os outros
        real = _registrar(nome, d)
        b64 = _extrair(d)
        if not b64:
            print("\n    ❌ resposta sem imagem")
            return
        _salvar_b64(b64, destino)
        anterior_b64 = b64
        print(f"  ✅ US$ {real:.4f}")



# ===============================================================
# ILUSTRAÇÕES DE EVENTO — as dez faixas dos modais
# ===============================================================
# 128×128 porque é o que `Retratos.LADO_EVENTO` promete, e o layout já está
# construído em cima disso (`_faixa` mostra a 110–120px de altura com aspecto
# preservado). Mudar o número aqui mexeria em `principal.gd`; o contrato veio
# primeiro.
#
# OPACAS. Como os retratos, são QUADROS: aparecem dentro do modal com o texto
# embaixo, não recortadas sobre o painel. Nada a recortar, nada a errar.
#
# A lista é FECHADA e espelha `Retratos.EVENTOS`. Um evento com typo tem que
# continuar devolvendo null — se `ilustracao()` inventasse arte para qualquer
# string, o erro só apareceria como imagem errada no modal, que é o tipo de
# defeito que ninguém liga ao typo que o causou.
EVENTO_LADO = 128
EVENTO_ENQUADRE = (
    "single dramatic scene, medieval, wide composition, strong readable "
    "silhouette, no text, no frame, no border, no user interface")

EVENTOS = {
    "cerco": "a besieged castle gate under attack, siege ladders against the "
             "wall, a trebuchet, smoke rising",
    "coroacao": "a crown being lowered onto a kneeling lord in a cathedral, "
                "banners and candlelight",
    "derrota": "a broken banner lying in the mud of a lost battlefield, "
               "scattered shields, crows overhead",
    "emboscada": "armed men bursting from a dark forest onto a narrow road, "
                 "a toppled cart",
    # "empty granary with bare shelves" devolveu um celeiro ABASTECIDO: o
    # gerador pinta o substantivo (celeiro, prateleira) e ignora o adjetivo
    # que o nega. A fome tem que estar no que se VÊ, não no que se nega —
    # daí campo morto, gente caída e o saco virado.
    "fome": "a dead withered wheat field under a harsh sky, cracked bare "
            "earth, an overturned empty sack, gaunt ragged peasants sitting "
            "on the ground with empty bowls, a crow on a bare branch",
    "inverno": "a snowbound village under heavy grey sky, frozen river, "
               "smoke from one lone chimney",
    "juramento": "a knight kneeling and laying his sword at a lord's feet, "
                 "witnesses in a torchlit hall",
    "rebeliao": "angry peasants with torches and pitchforks massed before a "
                "manor gate at night",
    "saque": "soldiers carrying off sacks and chests from a burning village",
    "traicao": "a hooded figure passing a dagger behind a nobleman's back in "
               "a shadowed corridor",
}


def gerar_eventos(seed: int = 4242) -> None:
    """As dez faixas de modal. Opacas, sem recorte."""
    CRU.mkdir(parents=True, exist_ok=True)
    for chave, desc in EVENTOS.items():
        destino = CRU / f"evento_{chave}.png"
        if destino.exists():
            print(f"  · evento_{chave} já existe")
            continue
        corpo = {
            "description": "%s, %s, %s" % (desc, EVENTO_ENQUADRE, ESTILO),
            "image_size": {"width": EVENTO_LADO, "height": EVENTO_LADO},
            "view": "side",
            "outline": "selective outline",
            "shading": "detailed shading",
            "detail": "highly detailed",
            "text_guidance_scale": 8.0,
            "no_background": False,
            "seed": seed,
        }
        print(f"  ⟳ evento_{chave}", end="", flush=True)
        c, d = _post("/create-image-pixflux", corpo, tempo=600)
        if c != 200:
            print(f"\n    ❌ HTTP {c}: {str(d.get('erro'))[:200]}")
            continue
        real = _registrar("evento_" + chave, d)
        b64 = _extrair(d)
        if not b64:
            print("\n    ❌ resposta sem imagem")
            continue
        _salvar_b64(b64, destino)
        anterior_b64 = b64
        print(f"  ✅ US$ {real:.4f}")


if __name__ == "__main__":
    main()
