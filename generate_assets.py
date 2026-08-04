#!/usr/bin/env python3
"""
generate_assets.py — gera os sprites de "Reino por Conquista" com a API do PixelLab.

Como funciona
-------------
1. LÊ a lore do jogo (reino-por-conquista/js/lore.js e js/data.js) para descobrir
   quem existe: os seis soberanos, os NPCs, os chefes bárbaros e as tropas.
2. Monta o prompt de cada personagem juntando o que a lore diz (nome, descrição,
   personalidade, no que crê, o que teme) com traços visuais curados.
3. Chama o PixelLab com fundo TRANSPARENTE e salva os PNG em
   reino-por-conquista-godot/assets/sprites/ (ou seja, res://assets/sprites/).

Uso
---
    export PIXELLAB_SECRET="sua-chave"          # pegue em pixellab.ai
    python3 generate_assets.py --listar          # só mostra o elenco e o custo
    python3 generate_assets.py --simular         # pipeline completo SEM gastar API
    python3 generate_assets.py --grupo reis      # gera só os reis
    python3 generate_assets.py --tudo            # gera o elenco inteiro
    python3 generate_assets.py --apenas rei_touros --tamanho 64

Notas de API (extraídas do SDK oficial pixellab 1.0.5 instalado)
----------------------------------------------------------------
* Autenticação: PIXELLAB_SECRET no ambiente → header "Authorization: Bearer <secret>".
* O SDK 1.0.5 fala com https://api.pixellab.ai/v1 e expõe generate_image_pixflux
  (texto→pixel art) e generate_image_bitforge (com imagem de estilo de referência).
  O endpoint /v2/create-character-v3 NÃO existe neste SDK; se a sua conta já tiver
  acesso à v2, use --api v2 e o script chama o REST diretamente via requests.
* Transparência: no_background=True.
* Estilo: outline="selective outline" (o sel-out), shading, detail, view, direction.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
LORE_JS = RAIZ / "reino-por-conquista" / "js" / "lore.js"
DATA_JS = RAIZ / "reino-por-conquista" / "js" / "data.js"
CLANS_JS = RAIZ / "reino-por-conquista" / "js" / "clans.js"
SAIDA = RAIZ / "reino-por-conquista-godot" / "assets" / "sprites"

# ---------------------------------------------------------------- estilo comum
# Um estilo único mantém o elenco coeso — é o que separa "assets avulsos" de
# um jogo com identidade. Contorno seletivo + sombreado médio + vista lateral.
ESTILO = dict(
    outline="selective outline",
    shading="medium shading",
    detail="highly detailed",
    view="side",
    isometric=False,
    no_background=True,          # PNG com fundo transparente
    text_guidance_scale=9.0,
    coverage_percentage=88.0,
)
NEGATIVO = (
    "blurry, anti-aliased, smooth gradients, 3d render, photo, watermark, text, "
    "signature, modern clothing, guns, magic, fantasy monsters, glowing effects, "
    "multiple characters, cropped head, cut off limbs"
)
# a lore é explícita: "Era do Aço, sem magia" — o prompt precisa reforçar isso
AMBIENTACAO = (
    "grim low-fantasy medieval world with no magic, iron age warfare, "
    "worn leather and riveted steel, muted earthy palette with one strong accent color"
)


# ---------------------------------------------------------- leitura da lore
def _bloco(texto: str, chave: str) -> str:
    """Devolve o trecho do objeto JS que começa em `chave:` (sem parser pesado)."""
    m = re.search(rf"^\s*{re.escape(chave)}:\s*\{{", texto, re.M)
    if not m:
        return ""
    i, prof = m.end() - 1, 0
    for j in range(i, len(texto)):
        if texto[j] == "{":
            prof += 1
        elif texto[j] == "}":
            prof -= 1
            if prof == 0:
                return texto[i:j + 1]
    return ""


def _campo(bloco: str, campo: str) -> str:
    m = re.search(rf"{campo}:\s*'((?:[^'\\]|\\.)*)'", bloco)
    return (m.group(1).replace("\\'", "'") if m else "").strip()


def ler_lore() -> dict:
    """Extrai voz/crença/medo de cada personagem do códice (js/lore.js)."""
    if not LORE_JS.exists():
        print(f"⚠️  lore não encontrada em {LORE_JS}", file=sys.stderr)
        return {}
    txt = LORE_JS.read_text(encoding="utf-8")
    lore = {}
    for pid in re.findall(r"^\s{4}(\w+):\s*\{", txt, re.M):
        b = _bloco(txt, pid)
        if not b:
            continue
        lore[pid] = {k: _campo(b, k) for k in ("voz", "crenca", "medo", "contas")}
    return lore


def ler_dados() -> dict:
    """Nome, descrição e personalidade dos reis (js/data.js) e chefes (js/clans.js)."""
    fichas = {}
    if DATA_JS.exists():
        txt = DATA_JS.read_text(encoding="utf-8")
        # reis: bloco rei: { id: 'rei_x', nome: '...', genero: 'm', personalidade: '...', desc: '...' }
        for m in re.finditer(
            r"rei:\s*\{\s*id:\s*'(\w+)',\s*nome:\s*'([^']+)',\s*genero:\s*'(\w)',\s*"
            r"personalidade:\s*'(\w+)',\s*\n?\s*desc:\s*'((?:[^'\\]|\\.)*)'", txt):
            pid, nome, genero, pers, desc = m.groups()
            fichas[pid] = dict(nome=nome, genero=genero, personalidade=pers,
                               desc=desc.replace("\\'", "'"))
        # NPCs simples: { id: 'taverneiro', nome: '...', genero, personalidade, desc }
        for m in re.finditer(
            r"\{\s*id:\s*'(taverneiro|capitao|espiao)',\s*nome:\s*'([^']+)',\s*"
            r"genero:\s*'(\w)',\s*personalidade:\s*'(\w+)',\s*\n?\s*desc:\s*'((?:[^'\\]|\\.)*)'", txt):
            pid, nome, genero, pers, desc = m.groups()
            fichas[pid] = dict(nome=nome, genero=genero, personalidade=pers,
                               desc=desc.replace("\\'", "'"))
    if CLANS_JS.exists():
        txt = CLANS_JS.read_text(encoding="utf-8")
        for m in re.finditer(
            r"id:\s*'(cla_\w+)',\s*nome:\s*'([^']+)',\s*lider:\s*'([^']+)',\s*\n?\s*"
            r"desc:\s*'((?:[^'\\]|\\.)*)',\s*\n?\s*personalidade:\s*'(\w+)'", txt):
            pid, cla, lider, desc, pers = m.groups()
            fichas[pid] = dict(nome=lider, genero="f" if pid == "cla_corvos" else "m",
                               personalidade=pers, desc=f"{desc} Chefe dos {cla}.")
    return fichas


# ------------------------------------------------ traços visuais por personagem
# A lore diz quem a pessoa É; isto diz como ela PARECE. Escrito à mão porque
# aparência é decisão de arte, não algo que se deduza de um texto de fundo.
APARENCIA = {
    "rei_imperio": "middle-aged emperor, close-cropped dark hair, full beard, deep facial scar, "
                   "black and dark-green lacquered plate armor, crown of iron thorns, heavy fur mantle, cold stare",
    "rei_touros": "grizzled outlaw warlord in his fifties, shaved head, stubble, no crown, "
                  "patched black leather and swamp-stained furs, bull-skull pauldron, notched cleaver on his back",
    "rei_alvorecer": "elegant scheming king, neat shoulder-length auburn hair, clean-shaven, "
                     "golden silk brocade robe over light mail, rings on every finger, thin smile, ledger in hand",
    "rei_leoes": "stern battle-commander king, long dark hair, thick beard, crimson tabard over polished steel, "
                 "lion crest, campaign maps rolled at his belt, disciplined posture",
    "rei_aguias": "haughty older monarch, long silver-white hair, clean-shaven, gaunt face, "
                  "pale silver plate and ermine cloak, tall thin crown, suspicious narrowed eyes",
    "rei_rosa": "calculating queen, long dark braided hair, deep blue and rose gown over fine mail, "
                "silver tiara, poised, holding a single blue rose",
    "taverneiro": "heavyset balding innkeeper, thick moustache, stained apron over brown tunic, "
                  "rolled sleeves, wooden tankard in hand, sly grin",
    "capitao": "veteran mercenary woman, dark hair in a tight bun, scar across cheek, "
               "practical grey steel half-armor, worn sword, arms crossed, unimpressed expression",
    "espiao": "hooded spy, face half in shadow, dark charcoal cloak, leather gloves, "
              "daggers at the belt, sealed letter tucked in his sleeve",
    "cla_lobos": "northern clan chieftain, long braided blond hair and beard, wolf-pelt hood, "
                 "iron ring mail, huge spear, snow-dusted shoulders",
    "cla_corvos": "silent scout woman, black hood, one clouded blind eye, dark grey leathers, "
                  "recurve bow, raven feathers braided in her hair",
    "cla_estepe": "nomad horse-lord, long drooping moustache, topknot, red war paint across the face, "
                  "lamellar armor of bone and leather, curved saber",
    "cla_machados": "old northern axeman, ice-white long beard, horned helm, "
                    "blue-grey mail under a heavy cloak, two-handed axe resting on his shoulder",
    # tropas e inimigos das cenas de batalha
    "tropa_campones": "ragged peasant levy, straw hat, patched tunic, wooden pitchfork, frightened posture",
    "tropa_lanceiro": "disciplined spearman, conical helm, kite shield, gambeson and mail, long spear",
    "tropa_arqueiro": "lean archer, leather cap, green hood, quiver on hip, drawing a longbow",
    "tropa_cavaleiro": "armored knight on foot, closed helm, surcoat over full mail, longsword and heater shield",
    "inimigo_bandido": "road bandit, dirty rags and mismatched armor pieces, hood, rusty falchion, crooked sneer",
}

GRUPOS = {
    "reis": ["rei_imperio", "rei_touros", "rei_alvorecer", "rei_leoes", "rei_aguias", "rei_rosa"],
    "npcs": ["taverneiro", "capitao", "espiao"],
    "barbaros": ["cla_lobos", "cla_corvos", "cla_estepe", "cla_machados"],
    "tropas": ["tropa_campones", "tropa_lanceiro", "tropa_arqueiro", "tropa_cavaleiro", "inimigo_bandido"],
}
GRUPOS["tudo"] = [i for g in ("reis", "npcs", "barbaros", "tropas") for i in GRUPOS[g]]

TOM = {  # a personalidade da lore vira pose e expressão
    "cruel": "cruel arrogant expression, chin raised, one hand resting on a weapon",
    "orgulhoso": "proud defiant stance, shoulders squared, direct challenging gaze",
    "calculista": "composed measured expression, hands clasped, evaluating look",
    "honrado": "upright honest bearing, calm steady gaze, open stance",
    "ganancioso": "greedy amused expression, counting coins, leaning forward",
    "romantica": "warm confident smile, relaxed elegant posture",
}


def montar_prompt(pid: str, lore: dict, fichas: dict) -> str:
    """Junta lore + aparência + personalidade num prompt de sprite."""
    partes = ["full body character sprite, single character, centered, facing right"]
    partes.append(APARENCIA.get(pid, "medieval character"))
    f = fichas.get(pid, {})
    if f.get("personalidade") in TOM:
        partes.append(TOM[f["personalidade"]])
    l = lore.get(pid, {})
    if l.get("crenca"):
        # a crença guia a leitura silenciosa do personagem (postura, olhar)
        partes.append("character whose bearing suggests: " + l["crenca"][:110].rstrip(".,"))
    partes.append(AMBIENTACAO)
    return ", ".join(p for p in partes if p)


# ------------------------------------------------------------------ geração
def cliente_v1():
    import pixellab
    segredo = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not segredo:
        raise SystemExit(
            "❌ Falta a chave. Rode:  export PIXELLAB_SECRET=\"sua-chave\"\n"
            "   (pegue em https://www.pixellab.ai — Account → API)")
    return pixellab.Client(secret=segredo)


def gerar_v1(cli, prompt: str, tamanho: int, seed: int):
    """SDK oficial (pixellab 1.0.5) → POST /v1/generate-image-pixflux."""
    r = cli.generate_image_pixflux(
        description=prompt,
        negative_description=NEGATIVO,
        image_size={"width": tamanho, "height": tamanho},
        seed=seed,
        **ESTILO,
    )
    return r.image.pil_image(), getattr(getattr(r, "usage", None), "usd", None)


def gerar_v2(prompt: str, tamanho: int, seed: int):
    """REST v2 (/v2/create-character-v3) para contas com acesso à v2."""
    import requests
    segredo = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not segredo:
        raise SystemExit("❌ Falta PIXELLAB_SECRET no ambiente.")
    base = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
    corpo = {
        "description": prompt,
        "negative_description": NEGATIVO,
        "image_size": {"width": tamanho, "height": tamanho},
        "seed": seed,
        "transparent_background": True,
        **{k: v for k, v in ESTILO.items() if k != "no_background"},
    }
    resp = requests.post(f"{base}/create-character-v3", json=corpo,
                         headers={"Authorization": f"Bearer {segredo}"}, timeout=180)
    resp.raise_for_status()
    dados = resp.json()
    # a v2 pode devolver a imagem em campos diferentes conforme o modelo
    b64 = (dados.get("image", {}) or {}).get("base64") or dados.get("image_base64")
    if not b64:
        raise RuntimeError(f"resposta sem imagem: {json.dumps(dados)[:300]}")
    from io import BytesIO
    import PIL.Image
    return PIL.Image.open(BytesIO(base64.b64decode(b64))), (dados.get("usage") or {}).get("usd")


def gerar_simulado(prompt: str, tamanho: int, seed: int):
    """Placeholder local: valida TODO o pipeline sem gastar crédito nem rede."""
    import PIL.Image
    import PIL.ImageDraw
    img = PIL.Image.new("RGBA", (tamanho, tamanho), (0, 0, 0, 0))
    d = PIL.ImageDraw.Draw(img)
    h = (seed * 2654435761) % 360
    import colorsys
    r, g, b = [int(c * 255) for c in colorsys.hsv_to_rgb(h / 360, 0.55, 0.75)]
    m = tamanho // 8
    d.ellipse([m * 2, m, m * 6, m * 4], fill=(r, g, b, 255), outline=(30, 22, 14, 255))
    d.rectangle([m * 2, m * 4, m * 6, tamanho - m], fill=(r // 2, g // 2, b // 2, 255),
                outline=(30, 22, 14, 255))
    return img, 0.0


def diagnostico() -> int:
    """Antes de gastar crédito: a chave existe? a rede deixa? a conta tem saldo?"""
    print("🔎 Diagnóstico do PixelLab\n")
    falhou = False

    segredo = os.environ.get("PIXELLAB_SECRET", "").strip()
    if segredo:
        print(f"  ✅ chave  PIXELLAB_SECRET definida ({len(segredo)} caracteres)")
    else:
        print("  ❌ chave  PIXELLAB_SECRET ausente — defina nas variáveis do ambiente")
        falhou = True

    try:
        import requests
        r = requests.get("https://api.pixellab.ai/v1/balance",
                         headers={"Authorization": f"Bearer {segredo}"} if segredo else {},
                         timeout=25)
        print(f"  ✅ rede   api.pixellab.ai respondeu (HTTP {r.status_code})")
        if r.status_code == 200:
            try:
                print(f"  ✅ saldo  {json.dumps(r.json())[:120]}")
            except Exception:
                pass
        elif r.status_code in (401, 403):
            print("  ⚠️  a rede chega, mas a chave foi recusada — confira o valor")
            falhou = True
    except Exception as e:
        msg = str(e)
        if "403" in msg or "CONNECT" in msg or "ProxyError" in msg:
            print("  ❌ rede   bloqueada pela política do ambiente")
            print("           Libere 'api.pixellab.ai' em claude.ai/code → ícone de nuvem →")
            print("           engrenagem do ambiente → Network access: Custom → Allowed domains")
            print("           (marque também 'include default list of common package managers')")
        else:
            print(f"  ❌ rede   {msg[:150]}")
        falhou = True

    print("\n" + ("❌ Ainda não dá para gerar — resolva os itens acima."
                  if falhou else "✅ Tudo pronto: rode  python3 generate_assets.py --grupo reis"))
    return 1 if falhou else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera os sprites do jogo com o PixelLab.")
    ap.add_argument("--grupo", choices=sorted(GRUPOS), help="conjunto a gerar")
    ap.add_argument("--tudo", action="store_true", help="gera o elenco inteiro")
    ap.add_argument("--apenas", metavar="ID", help="gera um personagem só")
    ap.add_argument("--tamanho", type=int, default=64, help="lado do sprite (padrão 64)")
    ap.add_argument("--api", choices=["v1", "v2"], default="v1",
                    help="v1 = SDK oficial (padrão); v2 = REST create-character-v3")
    ap.add_argument("--simular", action="store_true",
                    help="não chama a API: gera placeholders para testar o pipeline")
    ap.add_argument("--listar", action="store_true", help="mostra o elenco e sai")
    ap.add_argument("--diagnostico", action="store_true",
                    help="checa chave, rede e saldo antes de gerar qualquer coisa")
    ap.add_argument("--forcar", action="store_true", help="regera mesmo se o PNG já existe")
    ap.add_argument("--saida", default=str(SAIDA), help="pasta de destino")
    args = ap.parse_args()

    if args.diagnostico:
        return diagnostico()

    lore, fichas = ler_lore(), ler_dados()
    print(f"📖 Lore lida: {len(lore)} personagens no códice, {len(fichas)} fichas em data/clans.")

    if args.apenas:
        ids = [args.apenas]
    elif args.grupo:
        ids = GRUPOS[args.grupo]
    elif args.tudo:
        ids = GRUPOS["tudo"]
    elif args.listar:
        ids = GRUPOS["tudo"]
    else:
        ap.error("escolha --grupo, --tudo, --apenas ou --listar")

    desconhecidos = [i for i in ids if i not in APARENCIA]
    if desconhecidos:
        print(f"❌ sem aparência definida para: {', '.join(desconhecidos)}", file=sys.stderr)
        return 2

    if args.listar:
        print(f"\n{'ID':<18} {'NOME':<24} PROMPT (início)")
        print("-" * 100)
        for pid in ids:
            nome = fichas.get(pid, {}).get("nome", "—")
            print(f"{pid:<18} {nome:<24} {montar_prompt(pid, lore, fichas)[:56]}…")
        print(f"\n{len(ids)} sprites. Custo real depende da sua conta PixelLab "
              f"(a resposta traz usage.usd por imagem).")
        return 0

    destino = Path(args.saida)
    destino.mkdir(parents=True, exist_ok=True)
    cli = None
    if not args.simular and args.api == "v1":
        cli = cliente_v1()

    modo = "SIMULAÇÃO (sem API)" if args.simular else f"PixelLab {args.api}"
    print(f"🎨 Gerando {len(ids)} sprites {args.tamanho}×{args.tamanho} — modo: {modo}")
    print(f"📁 Destino: {destino}\n")

    feitos, pulados, falhas, custo = 0, 0, [], 0.0
    for n, pid in enumerate(ids, 1):
        alvo = destino / f"{pid}.png"
        if alvo.exists() and not args.forcar:
            print(f"[{n}/{len(ids)}] ⏭️  {pid} — já existe (use --forcar para refazer)")
            pulados += 1
            continue
        prompt = montar_prompt(pid, lore, fichas)
        seed = abs(hash(pid)) % 100000
        try:
            if args.simular:
                img, usd = gerar_simulado(prompt, args.tamanho, seed)
            elif args.api == "v2":
                img, usd = gerar_v2(prompt, args.tamanho, seed)
            else:
                img, usd = gerar_v1(cli, prompt, args.tamanho, seed)
            img.convert("RGBA").save(alvo)          # PNG com canal alfa
            custo += usd or 0.0
            feitos += 1
            print(f"[{n}/{len(ids)}] ✅ {pid} → {alvo.name}" + (f"  (US$ {usd:.4f})" if usd else ""))
            if not args.simular:
                time.sleep(1.0)                      # gentileza com a API
        except Exception as e:
            falhas.append((pid, str(e)[:160]))
            print(f"[{n}/{len(ids)}] ❌ {pid} — {str(e)[:160]}", file=sys.stderr)

    print(f"\n📊 {feitos} gerados, {pulados} pulados, {len(falhas)} falhas"
          + (f", custo US$ {custo:.4f}" if custo else ""))
    if falhas:
        for pid, err in falhas:
            print(f"   ❌ {pid}: {err}", file=sys.stderr)
    if feitos:
        print("\n👉 No Godot: os PNG entram sozinhos em res://assets/sprites/.")
        print("   Retratos.textura() carrega o arquivo se existir e só desenha o")
        print("   retrato procedural como reserva. Abra a cena de galeria para conferir:")
        print("   godot --path reino-por-conquista-godot res://cenas/galeria_sprites.tscn")
    return 1 if falhas else 0


if __name__ == "__main__":
    raise SystemExit(main())
