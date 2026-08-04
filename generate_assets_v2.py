#!/usr/bin/env python3
"""
generate_assets_v2.py — assets Pro do PixelLab para o projeto Godot.

Cobre os quatro grupos do overhaul, cada um no endpoint próprio da API v2:

  ui        POST /generate-ui-v2            molduras 9-slice, botões, barras (síncrono)
  tileset   POST /create-tileset            terreno contínuo Wang/Pro   (assíncrono)
  objeto    POST /map-objects               árvores, casas, baús        (assíncrono)
  objeto1d  POST /create-1-direction-object variação barata de objeto   (assíncrono)
  heroi     POST /create-character-v3       personagem com 8 rotações   (assíncrono)

Tudo cai em reino-por-conquista-godot/assets_v2/{ui,characters,tilesets,objects}
com canal alfa. Os assíncronos são acompanhados por polling até concluir.

  export PIXELLAB_SECRET="..."
  python3 generate_assets_v2.py --saldo            # cota restante, sem gastar
  python3 generate_assets_v2.py --listar           # o catálogo e o custo em gerações
  python3 generate_assets_v2.py --grupo ui         # gera um grupo
  python3 generate_assets_v2.py --apenas painel_pergaminho
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
from io import BytesIO
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
BASE = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
DESTINO = RAIZ / "reino-por-conquista-godot" / "assets_v2"

# identidade visual única: é o que faz UI, mundo e personagens parecerem o mesmo jogo
PALETA = "weathered parchment, dark oak brown, aged gold, iron grey, deep blood red"
ESTILO_MUNDO = ("grim low-fantasy medieval, no magic, iron age, worn materials, "
                "muted earthy palette with warm gold accents")

# ------------------------------------------------------------------ catálogo
# Cada entrada: (grupo, endpoint, parâmetros). Os textos vêm da lore do jogo:
# pergaminho, madeira e ouro — a mesma linguagem do tema atual, agora em pixel art.
CATALOGO = {
    # ---------- UI (9-slice, botões, HUD) ----------
    "painel_pergaminho": dict(grupo="ui", tipo="ui", size=(256, 256),
        desc="medieval parchment panel frame for a game UI window, aged yellowed paper "
             "stretched on a dark oak wood border with iron corner rivets, empty center, "
             "symmetrical, seamless 9-slice frame, thick readable border"),
    "painel_madeira": dict(grupo="ui", tipo="ui", size=(256, 256),
        desc="dark oak wood panel frame for a game inventory window, carved planks with "
             "iron nails at the corners and a thin gold inlay line, empty center, "
             "symmetrical 9-slice frame"),
    "botao_madeira": dict(grupo="ui", tipo="ui", size=(192, 64),
        desc="medieval wooden button for a game menu, horizontal oak plank with beveled "
             "edges, gold trim and two iron rivets, empty center for text, "
             "clean readable silhouette"),
    "botao_madeira_apertado": dict(grupo="ui", tipo="ui", size=(192, 64),
        desc="medieval wooden button in PRESSED state, same oak plank but darker and "
             "recessed, inset shadow at the top, gold trim dimmed, empty center for text"),
    "moldura_retrato": dict(grupo="ui", tipo="ui", size=(128, 128),
        desc="ornate square portrait frame for a medieval game HUD, dark iron and gold "
             "filigree border, empty transparent center, symmetrical"),
    "barra_hud": dict(grupo="ui", tipo="ui", size=(256, 48),
        desc="medieval progress bar frame for a game HUD, empty horizontal iron and gold "
             "trough with riveted ends, hollow center to be filled"),
    "quadro_inventario": dict(grupo="ui", tipo="ui", size=(128, 128),
        desc="single inventory slot for a medieval game, square dark leather pad inside a "
             "riveted iron border, slightly inset, empty center"),

    # ---------- TILESETS (terreno) ----------
    "campo_terra": dict(grupo="tilesets", tipo="tileset", tile=(32, 32),
        lower="lush green medieval grassland with small wildflowers and clumps of grass",
        upper="packed dirt road and bare brown earth with pebbles and wheel ruts",
        transicao="grass thinning into dirt with scattered tufts and small stones"),
    "grama_pedra": dict(grupo="tilesets", tipo="tileset", tile=(32, 32),
        lower="green meadow grass with tiny flowers",
        upper="grey mountain rock shelf with cracks and moss patches",
        transicao="loose scree and small boulders between grass and rock"),

    # ---------- OBJETOS DE CENÁRIO ----------
    "arvore_carvalho": dict(grupo="objects", tipo="objeto", size=(128, 160),
        desc="large old oak tree with thick gnarled trunk and dense green canopy, "
             "medieval countryside, " + ESTILO_MUNDO),
    "arvore_pinheiro": dict(grupo="objects", tipo="objeto", size=(112, 160),
        desc="tall dark pine tree with layered branches, northern medieval forest, " + ESTILO_MUNDO),
    "casa_camponesa": dict(grupo="objects", tipo="objeto", size=(160, 160),
        desc="small medieval peasant cottage, timber frame with wattle-and-daub walls and "
             "a thatched straw roof, wooden door, stone chimney, " + ESTILO_MUNDO),
    "torre_castelo": dict(grupo="objects", tipo="objeto", size=(160, 192),
        desc="medieval stone keep tower with crenellated top, arrow slits, wooden gate and "
             "a red banner, " + ESTILO_MUNDO),
    "bau_tesouro": dict(grupo="objects", tipo="objeto", size=(96, 96),
        desc="closed medieval treasure chest, dark wood with iron bands and a heavy padlock, "
             + ESTILO_MUNDO),
    "poco_pedra": dict(grupo="objects", tipo="objeto", size=(96, 112),
        desc="stone village well with wooden roof, rope and bucket, moss on the stones, " + ESTILO_MUNDO),
    "barril_carga": dict(grupo="objects", tipo="objeto", size=(80, 80),
        desc="wooden barrel with iron hoops, medieval market cargo, " + ESTILO_MUNDO),
    "fogueira_acampamento": dict(grupo="objects", tipo="objeto", size=(96, 96),
        desc="campfire with stacked logs inside a ring of stones, warm embers, " + ESTILO_MUNDO),

    # ---------- PERSONAGEM COM 8 ROTAÇÕES ----------
    "heroi_jogador": dict(grupo="characters", tipo="heroi", size=(64, 64),
        desc="medieval mercenary captain, leather and mail armor, dark green cloak, "
             "sword at the hip, determined face, " + ESTILO_MUNDO),
}

# preço estimado em USD por asset, da tabela oficial de preços do PixelLab.
# (A cota "generations" do trial é consumida primeiro; os créditos em dólar
#  entram como fallback. É o valor em dólar que importa para orçar o lote.)
CUSTO = {
    "ui": 0.095,        # generate-ui-v2, até 256×256
    "tileset": 0.0099,  # create-tileset, tiles 32×32
    "objeto": 0.0099,   # map-objects, por objeto
    "objeto1d": 0.095,  # create-1-direction-object, até 168×168
    "heroi": 0.041,     # create-character-v3, 64×64 (8 rotações)
}


def cabecalho() -> dict:
    seg = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not seg:
        raise SystemExit("❌ Falta PIXELLAB_SECRET no ambiente.")
    return {"Authorization": f"Bearer {seg}", "content-type": "application/json"}


def erro(resp) -> str:
    mapa = {401: "chave inválida", 402: "SEM COTA/CRÉDITOS — recarregue em pixellab.ai",
            422: "parâmetros recusados", 429: "limite de concorrência", 529: "limite de taxa"}
    try:
        det = resp.json()
        det = det.get("detail") or det.get("error") or json.dumps(det)[:200]
        if isinstance(det, list):
            det = json.dumps(det)[:200]
    except Exception:
        det = resp.text[:200]
    return f"{mapa.get(resp.status_code, f'HTTP {resp.status_code}')} — {det}"


def saldo() -> dict:
    import requests
    r = requests.get(f"{BASE}/balance", headers=cabecalho(), timeout=40)
    if not r.ok:
        raise RuntimeError(erro(r))
    return r.json()


def _png(b64: str):
    import PIL.Image
    return PIL.Image.open(BytesIO(base64.b64decode(b64))).convert("RGBA")


def _acha_imagens(no, achadas=None):
    """A v2 aninha as imagens de formas diferentes por endpoint; varre recursivo."""
    achadas = achadas if achadas is not None else []
    if isinstance(no, dict):
        if "base64" in no and isinstance(no["base64"], str) and len(no["base64"]) > 200:
            achadas.append((no.get("direction") or no.get("name") or no.get("id") or "", no["base64"]))
        for k, v in no.items():
            if k != "base64":
                _acha_imagens(v, achadas)
    elif isinstance(no, list):
        for v in no:
            _acha_imagens(v, achadas)
    return achadas


def esperar_job(job_id: str, limite: int = 600) -> dict:
    """Acompanha um job assíncrono até concluir."""
    import requests
    inicio = time.time()
    while time.time() - inicio < limite:
        time.sleep(6)
        r = requests.get(f"{BASE}/background-jobs/{job_id}", headers=cabecalho(), timeout=60)
        if not r.ok:
            raise RuntimeError(erro(r))
        info = r.json()
        estado = str(info.get("status", "")).lower()
        if estado in ("completed", "succeeded", "success", "done", "finished"):
            return info
        if estado in ("failed", "error", "cancelled"):
            raise RuntimeError(f"job falhou: {json.dumps(info)[:220]}")
        print(f"      … {estado or 'processando'} ({int(time.time() - inicio)}s)", end="\r", flush=True)
    raise RuntimeError("tempo esgotado no job " + job_id)


def buscar(caminho: str) -> dict:
    import requests
    r = requests.get(f"{BASE}{caminho}", headers=cabecalho(), timeout=120)
    if not r.ok:
        raise RuntimeError(erro(r))
    return r.json()


# --------------------------------------------------------------- geradores
def gerar_ui(spec: dict, seed: int):
    """POST /generate-ui-v2 — síncrono."""
    import requests
    w, h = spec["size"]
    corpo = {"description": spec["desc"], "image_size": {"width": w, "height": h},
             "no_background": True, "color_palette": PALETA, "seed": seed}
    r = requests.post(f"{BASE}/generate-ui-v2", json=corpo, headers=cabecalho(), timeout=300)
    if not r.ok:
        raise RuntimeError(erro(r))
    dados = r.json()
    imgs = _acha_imagens(dados)
    if not imgs:
        # alguns retornos são assíncronos: cai no polling
        job = dados.get("background_job_id")
        if job:
            imgs = _acha_imagens(esperar_job(job))
    if not imgs:
        raise RuntimeError(f"sem imagem: {json.dumps(dados)[:200]}")
    return [("", _png(imgs[0][1]))], dados


def gerar_tileset(spec: dict, seed: int):
    """POST /create-tileset — assíncrono, modo 'pro'."""
    import requests
    tw, th = spec["tile"]
    corpo = {
        "lower_description": spec["lower"], "upper_description": spec["upper"],
        "transition_description": spec.get("transicao", ""),
        "tile_size": {"width": tw, "height": th},
        "mode": "pro", "view": "high top-down",
        "outline": "selective outline", "shading": "medium shading", "detail": "highly detailed",
        "transition_size": 0.5, "raggedness": 0.35, "seed": seed,
    }
    r = requests.post(f"{BASE}/create-tileset", json=corpo, headers=cabecalho(), timeout=180)
    if not r.ok:
        raise RuntimeError(erro(r))
    envio = r.json()
    tid = envio.get("tileset_id") or envio.get("id")
    job = envio.get("background_job_id")
    resultado = esperar_job(job) if job else envio
    if tid:
        try:
            resultado = buscar(f"/tilesets/{tid}")
        except Exception:
            pass
    imgs = _acha_imagens(resultado)
    if not imgs:
        raise RuntimeError(f"tileset sem imagem: {json.dumps(resultado)[:200]}")
    return [(n, _png(b)) for n, b in imgs], envio


def gerar_objeto(spec: dict, seed: int):
    """POST /map-objects — assíncrono."""
    import requests
    w, h = spec["size"]
    corpo = {"description": spec["desc"], "image_size": {"width": w, "height": h},
             "view": "side", "outline": "selective outline", "shading": "medium shading",
             "detail": "highly detailed", "seed": seed}
    r = requests.post(f"{BASE}/map-objects", json=corpo, headers=cabecalho(), timeout=180)
    if not r.ok:
        raise RuntimeError(erro(r))
    envio = r.json()
    oid, job = envio.get("object_id"), envio.get("background_job_id")
    resultado = esperar_job(job) if job else envio
    if oid:
        try:
            resultado = buscar(f"/map-objects/{oid}")
        except Exception:
            pass
    imgs = _acha_imagens(resultado)
    if not imgs:
        raise RuntimeError(f"objeto sem imagem: {json.dumps(resultado)[:200]}")
    return [("", _png(imgs[0][1]))], envio


def gerar_heroi(spec: dict, seed: int):
    """POST /create-character-v3 — assíncrono, 8 rotações."""
    import requests
    w, h = spec["size"]
    corpo = {"description": spec["desc"], "image_size": {"width": w, "height": h},
             "view": "side", "no_background": True, "outline": "selective outline",
             "detail": "highly detailed", "enhance_prompt": True, "seed": seed}
    r = requests.post(f"{BASE}/create-character-v3", json=corpo, headers=cabecalho(), timeout=180)
    if not r.ok:
        raise RuntimeError(erro(r))
    envio = r.json()
    cid, job = envio.get("character_id"), envio.get("background_job_id")
    resultado = esperar_job(job) if job else envio
    if cid:
        resultado = buscar(f"/characters/{cid}")
    imgs = _acha_imagens(resultado)
    if not imgs:
        raise RuntimeError(f"personagem sem imagens: {json.dumps(resultado)[:200]}")
    return [(n or str(i), im) for i, (n, im) in enumerate((n, _png(b)) for n, b in imgs)], envio


GERADORES = {"ui": gerar_ui, "tileset": gerar_tileset, "objeto": gerar_objeto, "heroi": gerar_heroi}


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera os assets Pro do jogo (PixelLab v2).")
    ap.add_argument("--grupo", choices=["ui", "tilesets", "objects", "characters"])
    ap.add_argument("--apenas", metavar="ID")
    ap.add_argument("--tudo", action="store_true")
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--saldo", action="store_true")
    ap.add_argument("--forcar", action="store_true")
    ap.add_argument("--destino", default=str(DESTINO))
    args = ap.parse_args()

    if args.saldo:
        s = saldo()
        sub = s.get("subscription") or {}
        print(json.dumps(s, indent=1))
        cr = s.get("credits") or {}
        print(f"\n➡️  créditos: US$ {cr.get('usd', 0):.2f}"
              f" · cota do plano: {sub.get('generations', 0)} de {sub.get('total', 0)}")
        usd = float(cr.get("usd") or 0)
        if usd > 0:
            print(f"   dá para ~{int(usd / 0.095)} assets de UI Pro"
                  f" ou ~{int(usd / 0.0099)} objetos/tiles")
        return 0

    if args.apenas:
        ids = [args.apenas]
    elif args.grupo:
        ids = [k for k, v in CATALOGO.items() if v["grupo"] == args.grupo]
    elif args.tudo or args.listar:
        ids = list(CATALOGO)
    else:
        ap.error("escolha --grupo, --apenas, --tudo, --listar ou --saldo")

    faltando = [i for i in ids if i not in CATALOGO]
    if faltando:
        print("❌ desconhecidos:", ", ".join(faltando), file=sys.stderr)
        return 2

    if args.listar:
        print(f"{'ID':<26} {'GRUPO':<12} {'TIPO':<9} {'US$':>8}  DESCRIÇÃO")
        print("-" * 106)
        total = 0.0
        for i in ids:
            s = CATALOGO[i]
            c = CUSTO[s["tipo"]]
            total += c
            d = s.get("desc") or s.get("lower", "")
            print(f"{i:<26} {s['grupo']:<12} {s['tipo']:<9} {c:>8.4f}  {d[:42]}…")
        print(f"\n{len(ids)} assets · custo estimado ≈ US$ {total:.2f}")
        try:
            sub = saldo().get("subscription") or {}
            print(f"cota disponível agora: {sub.get('generations')} de {sub.get('total')}")
        except Exception:
            pass
        return 0

    base = Path(args.destino)
    feitos, pulados, falhas = 0, 0, []
    print(f"🎨 {len(ids)} assets Pro · destino {base}\n")
    for n, pid in enumerate(ids, 1):
        spec = CATALOGO[pid]
        pasta = base / spec["grupo"]
        pasta.mkdir(parents=True, exist_ok=True)
        alvo = pasta / f"{pid}.png"
        if alvo.exists() and not args.forcar:
            print(f"[{n}/{len(ids)}] ⏭️  {pid} — já existe")
            pulados += 1
            continue
        seed = abs(hash(pid)) % 100000
        try:
            imagens, envio = GERADORES[spec["tipo"]](spec, seed)
            for idx, (nome, img) in enumerate(imagens):
                destino_img = alvo if idx == 0 else pasta / f"{pid}_{nome or idx}.png"
                img.save(destino_img)
            feitos += 1
            print(f"[{n}/{len(ids)}] ✅ {pid} → {len(imagens)} arquivo(s) em {spec['grupo']}/")
            time.sleep(1.5)
        except Exception as e:
            falhas.append((pid, str(e)[:170]))
            print(f"[{n}/{len(ids)}] ❌ {pid} — {str(e)[:170]}", file=sys.stderr)
            if "SEM COTA" in str(e):
                print("\n⛔ Cota esgotada — parando para não desperdiçar chamadas.", file=sys.stderr)
                break

    print(f"\n📊 {feitos} gerados, {pulados} pulados, {len(falhas)} falhas")
    try:
        st = saldo()
        cr = st.get("credits") or {}
        sub = st.get("subscription") or {}
        print(f"   saldo: US$ {cr.get('usd', 0):.4f} · cota {sub.get('generations', 0)}/{sub.get('total', 0)}")
    except Exception:
        pass
    return 1 if falhas else 0


if __name__ == "__main__":
    raise SystemExit(main())
