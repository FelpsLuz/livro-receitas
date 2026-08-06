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

Notas de API (conferidas em https://api.pixellab.ai/v2/llms.txt e no openapi.json)
---------------------------------------------------------------------------------
* Base: https://api.pixellab.ai/v2 — autentique com PIXELLAB_SECRET no ambiente,
  enviado como "Authorization: Bearer <secret>".
* POST /create-image-pixflux (padrão aqui): SÍNCRONO, devolve {usage, image} na hora.
* POST /create-character-v3 (--api v3): ASSÍNCRONO — devolve background_job_id, que
  é consultado em GET /background-jobs/{id} até concluir; entrega o personagem com
  8 rotações, que gravamos como <id>_<direcao>.png.
* Códigos que importam: 401 chave inválida, 402 SEM CRÉDITOS, 422 parâmetros,
  429/529 limite de taxa.
* Transparência: no_background=True. Estilo: outline="selective outline" (sel-out),
  shading, detail, view.
* O SDK Python 1.0.5 (pip install pixellab) fala com a /v1 e hoje QUEBRA ao ler a
  resposta (valida usage.type=='usd', mas a API devolve 'generations'), por isso
  este script chama a REST v2 diretamente.
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
# Assinatura de estilo repetida em TODO prompt. Um jogo com arte de IA vira
# colcha de retalhos quando cada asset pede um estilo diferente — este texto
# é o que faz o lanceiro e o rei parecerem do mesmo mundo.
ESTILO_BASE = ("64x64 pixel art portrait, medieval fantasy, warm saturated palette, "
               "rich greens and terracotta and cream, golden daylight, soft warm shadows, "
               "crisp dark selective outline (sel-out), clean readable silhouette, "
               "charming storybook medieval, detailed but not noisy, "
               "clean transparent background")

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
    "cla_lobos": "burly northern clan chieftain, MALE, long braided BLOND hair and thick blond beard, "
                 "grey wolf-pelt hood over his head, iron ring mail, huge spear, snow-dusted shoulders, "
                 "no pink or red hair",
    "cla_corvos": "silent scout woman, black hood, one clouded blind eye, dark grey leathers, "
                  "recurve bow, raven feathers braided in her hair",
    "cla_estepe": "nomad horse-lord, long drooping moustache, topknot, red war paint across the face, "
                  "lamellar armor of bone and leather, curved saber",
    "cla_machados": "old northern axeman, ice-white long beard, horned helm, "
                    "blue-grey mail under a heavy cloak, two-handed axe resting on his shoulder",
    # ---- AS OITO TROPAS ----
    # O id é sempre "tropa_" + a chave de Dados.TROPAS, para a UI achar a arte
    # por cálculo e não por tabela paralela que envelhece.
    # Cada prompt carrega o CONTRA-JOGO da unidade: quem tem lança aparece
    # segurando lança contra cavalo, e o jogador aprende a regra olhando.
    "tropa_campones": "ragged peasant levy, straw hat, patched brown tunic, "
                      "wooden pitchfork, frightened hunched posture, no armor",
    "tropa_lanceiro": "disciplined militia spearman, conical nasal helm, tall kite shield "
                      "planted forward, quilted gambeson over mail, very long braced spear "
                      "angled up as if set against a charging horse",
    "tropa_espadachim": "heavy infantry swordsman, closed kettle helm, thick padded coat "
                        "under mail hauberk, broad round shield held high, arming sword, "
                        "planted defensive stance like a wall",
    "tropa_barbaro": "wild raider berserker, bare scarred chest with fur mantle, braided hair, "
                     "no shield at all, two heavy axes raised, screaming charge, reckless",
    "tropa_arqueiro": "lean longbow archer, leather cap and green hood, bracer on forearm, "
                      "full quiver on hip, drawing a tall yew longbow, calm aiming eye",
    "tropa_explorador": "light scout runner, no armor, dusty grey travel cloak and hood, "
                        "coiled rope and small spyglass at belt, unarmed, crouched low "
                        "and watching, built for speed not fighting",
    "tropa_cav_leve": "light cavalry rider on a lean fast brown horse, open helm, "
                      "leather lamellar, short lance couched, cloak streaming, mid-gallop",
    "tropa_arq_cavalo": "horse archer on a small steppe pony, fur-trimmed cap, lamellar of "
                        "bone and leather, twisting in the saddle to loose a recurve bow "
                        "backwards, quiver at the saddle",
    "tropa_cav_pesada": "heavy armored knight on a massive barded warhorse, full closed "
                        "great helm, plate and mail, long lance couched, horse in steel "
                        "barding, overwhelming mass, banner on the lance",
    "inimigo_bandido": "road bandit, dirty rags and mismatched armor pieces, hood, "
                       "rusty falchion, crooked sneer",

    # ---- BASES GENÉRICAS PARA LORDES GERADOS EM JOGO ----
    # Um cidadão que enriquece vira Lorde DURANTE a partida: não existe PNG
    # dele, e não dá para chamar a API no meio do jogo. Estas duas bases são
    # recoloridas em tempo de execução (retratos.gd) para dar a cada lorde um
    # rosto distinto sem gerar nada novo.
    "lorde_generico": "neutral minor nobleman portrait, plain but well-made tunic with a "
                      "wide collar, short beard, calm neutral expression, simple chain of "
                      "office, NO crown, NO heraldry, plain undecorated clothing in a "
                      "single flat color that is easy to recolor",
    "lorde_generica": "neutral minor noblewoman portrait, plain but well-made gown with a "
                      "wide collar, hair pinned up, calm neutral expression, simple chain "
                      "of office, NO crown, NO heraldry, plain undecorated clothing in a "
                      "single flat color that is easy to recolor",

    # ---- TAVERNA: cada um destes VENDE alguma coisa no jogo ----
    "informante": "furtive informant in a tavern corner, deep hood over half his face, "
                  "ink-stained fingers, whispering behind a raised hand, coin purse and "
                  "folded notes on the table, eyes on the door",
    "cartografo": "drunken old cartographer, ink-smudged spectacles, wine-stained shirt, "
                  "unrolled trade-route map weighted with tankards, quill behind the ear, "
                  "pointing at a road on the parchment",
    "mercenario_lanca": "hulking mercenary spearman for hire, missing an ear, boiled leather "
                        "and mismatched mail, spear resting on his shoulder, arms folded, "
                        "sizing up the buyer, bored expression",
    "mercenario_arco": "mercenary archer woman for hire, short practical hair, ranger leathers, "
                       "unstrung bow across her knees, counting coins on the table, "
                       "unimpressed half-smile",
}

# ---------------------------------------------------------------
# CENAS — ilustrações pequenas para modais e eventos.
# Não são personagens: são QUADROS. Por isso têm um construtor de prompt
# próprio (montar_prompt_cena) — pedir "single character sprite, facing right"
# para um acampamento de cerco devolveria um homem, não um cerco.
# ---------------------------------------------------------------
CENAS = {
    "evento_cerco": "wide scene illustration, medieval siege camp at dusk seen from outside "
                    "the walls, rows of canvas tents, campfires, a siege tower and ladders, "
                    "banners planted in mud, besieged stone keep silhouetted behind",
    "evento_emboscada": "wide scene illustration, ambush on a forest road at dawn, "
                        "overturned supply cart, scattered crates, bandits emerging from "
                        "the treeline with drawn weapons, soldiers caught mid-turn",
    "evento_inverno": "wide scene illustration, medieval village buried in deep snow, "
                      "frozen empty fields, smoke from a single chimney, wolves at the "
                      "treeline, grey-blue winter light, no crops",
    "evento_rebeliao": "wide scene illustration, peasant revolt at night, angry villagers "
                       "with torches pitchforks and scythes marching on a manor gate, "
                       "firelight on furious faces",
    "evento_juramento": "wide scene illustration, feudal oath ceremony in a stone hall, "
                        "a kneeling lord placing his hands between the hands of a seated "
                        "king, courtiers watching from the shadows, banners overhead",
    "evento_coroacao": "wide scene illustration, coronation in a candlelit cathedral, "
                       "iron crown lowered onto a kneeling figure, kneeling crowd, "
                       "shafts of light through high windows",
    # os quatro momentos que ainda apareciam só como texto na interface
    "evento_traicao": "wide scene illustration, night betrayal at a castle gate, two "
                      "guards quietly unbarring the heavy doors while a hooded figure "
                      "hands them a purse of coin, torchlight, armed men waiting outside "
                      "in the dark",
    "evento_saque": "wide scene illustration, raiding party returning home at sunset, "
                    "soldiers leading laden pack horses and carts of grain sacks and "
                    "barrels, smoke rising from a burning village far behind them",
    "evento_fome": "wide scene illustration, famine, interior of an EMPTY stone granary "
                   "at dusk, completely bare wooden shelves, one overturned empty basket "
                   "on the floor, cracked dry earth and a dead withered field through the "
                   "open door, a single gaunt figure sitting with head in hands, grey "
                   "desaturated light, NO food, NO sacks, NO crowd, NO market stall",
    "evento_derrota": "wide scene illustration, aftermath of a lost battle at dusk, "
                      "a fallen banner half buried in churned mud, broken spears and "
                      "abandoned shields, crows circling, empty grey field, no figures",
}

GRUPOS = {
    "reis": ["rei_imperio", "rei_touros", "rei_alvorecer", "rei_leoes", "rei_aguias", "rei_rosa"],
    "npcs": ["taverneiro", "capitao", "espiao"],
    "taverna": ["informante", "cartografo", "mercenario_lanca", "mercenario_arco"],
    "bases": ["lorde_generico", "lorde_generica"],
    "barbaros": ["cla_lobos", "cla_corvos", "cla_estepe", "cla_machados"],
    # espelha as chaves de Dados.TROPAS: a UI monta o id por cálculo
    "tropas": ["tropa_campones", "tropa_lanceiro", "tropa_espadachim", "tropa_barbaro",
               "tropa_arqueiro", "tropa_explorador", "tropa_cav_leve", "tropa_arq_cavalo",
               "tropa_cav_pesada", "inimigo_bandido"],
    "cenas": list(CENAS),
}
GRUPOS["tudo"] = [i for g in ("reis", "npcs", "taverna", "bases", "barbaros", "tropas", "cenas")
                  for i in GRUPOS[g]]

TOM = {  # a personalidade da lore vira pose e expressão
    "cruel": "cruel arrogant expression, chin raised, one hand resting on a weapon",
    "orgulhoso": "proud defiant stance, shoulders squared, direct challenging gaze",
    "calculista": "composed measured expression, hands clasped, evaluating look",
    "honrado": "upright honest bearing, calm steady gaze, open stance",
    "ganancioso": "greedy amused expression, counting coins, leaning forward",
    "romantica": "warm confident smile, relaxed elegant posture",
}


def montar_prompt_cena(pid: str) -> str:
    """Prompt de ILUSTRAÇÃO (modal/evento), não de personagem.

    Um quadro pede enquadramento e profundidade; pedir "single character
    sprite, facing right" para um acampamento de cerco devolve um homem
    sozinho em pé. Por isso o construtor é separado.
    """
    return ", ".join([
        CENAS[pid],
        "no text, no ui frame, no border",
        ESTILO_BASE.replace("64x64 pixel art portrait",
                            "pixel art scene illustration, wide framing, "
                            "layered depth with background hills and sky")
                   .replace("clean transparent background",
                            "full illustrated background"),
    ])


def montar_prompt(pid: str, lore: dict, fichas: dict) -> str:
    """Junta lore + aparência + personalidade num prompt de sprite."""
    if pid in CENAS:
        return montar_prompt_cena(pid)
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
    # a assinatura de estilo entra por ÚLTIMO e em todo prompt: é ela que
    # segura a unidade visual entre um rei e um camponês
    partes.append(ESTILO_BASE)
    return ", ".join(p for p in partes if p)


# ------------------------------------------------------------------ geração
def salvar_rotacoes(dados: dict, destino: Path, pid: str) -> int:
    """create-character-v3 devolve o personagem virado para vários lados;
    grava cada rotação como <id>_<direcao>.png e a frontal como <id>.png."""
    from io import BytesIO
    import PIL.Image
    salvos = 0
    rotacoes = dados.get("rotations") or dados.get("images") or []
    if isinstance(rotacoes, dict):
        rotacoes = [{"direction": k, "image": v} for k, v in rotacoes.items()]
    for r in rotacoes:
        b64 = ((r.get("image") or {}).get("base64") if isinstance(r.get("image"), dict)
               else r.get("base64"))
        if not b64:
            continue
        direcao = (r.get("direction") or f"{salvos}").replace(" ", "_")
        img = PIL.Image.open(BytesIO(base64.b64decode(b64))).convert("RGBA")
        img.save(destino / f"{pid}_{direcao}.png")
        if direcao in ("south", "front", "0"):
            img.save(destino / f"{pid}.png")     # a pose que o jogo usa por padrão
        salvos += 1
    if salvos and not (destino / f"{pid}.png").exists():
        # nenhuma veio marcada como frontal: usa a primeira
        primeira = sorted(destino.glob(f"{pid}_*.png"))[0]
        PIL.Image.open(primeira).save(destino / f"{pid}.png")
    return salvos


BASE_V2 = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")


def _cabecalho():
    segredo = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not segredo:
        raise SystemExit("❌ Falta a chave: export PIXELLAB_SECRET=\"sua-chave\"")
    return {"Authorization": f"Bearer {segredo}", "content-type": "application/json"}


def _erro_http(resp) -> str:
    """Traduz os códigos que a API documenta, para a mensagem ser acionável."""
    mapa = {
        401: "chave inválida (401)",
        402: "SEM CRÉDITOS na conta PixelLab (402) — recarregue em pixellab.ai",
        422: "parâmetros recusados (422)",
        429: "limite de concorrência/taxa (429) — espere e tente de novo",
        529: "limite de taxa (529) — espere e tente de novo",
    }
    detalhe = ""
    try:
        j = resp.json()
        detalhe = j.get("detail") or j.get("error") or ""
        if isinstance(detalhe, list):
            detalhe = json.dumps(detalhe)[:180]
    except Exception:
        detalhe = resp.text[:180]
    return f"{mapa.get(resp.status_code, f'HTTP {resp.status_code}')}" + (f" — {detalhe}" if detalhe else "")


def _usd(dados) -> float | None:
    """A API devolve usage como {type:'usd'|'generations', usd|generations: n}."""
    u = dados.get("usage") or {}
    return u.get("usd") if u.get("type") == "usd" else None


def _imagem_de(dados):
    from io import BytesIO
    import PIL.Image
    b64 = (dados.get("image") or {}).get("base64") or dados.get("image_base64")
    if not b64:
        raise RuntimeError(f"resposta sem imagem: {json.dumps(dados)[:220]}")
    return PIL.Image.open(BytesIO(base64.b64decode(b64)))


def gerar_v2(prompt: str, tamanho: int, seed: int):
    """POST /v2/create-image-pixflux — síncrono, devolve a imagem na hora.

    É o caminho padrão: uma pose por personagem, barato e direto.
    (O SDK Python 1.0.5 ainda valida usage.type=='usd' e quebra com a resposta
    atual da API, que usa 'generations' — por isso falamos REST direto.)
    """
    import requests
    corpo = {
        "description": prompt,
        "negative_description": NEGATIVO,
        "image_size": {"width": tamanho, "height": tamanho},
        "seed": seed,
        "text_guidance_scale": ESTILO["text_guidance_scale"],
        "outline": ESTILO["outline"],
        "shading": ESTILO["shading"],
        "detail": ESTILO["detail"],
        "view": ESTILO["view"],
        "isometric": False,
        "no_background": True,                       # fundo transparente
    }
    resp = requests.post(f"{BASE_V2}/create-image-pixflux", json=corpo,
                         headers=_cabecalho(), timeout=300)
    if not resp.ok:
        raise RuntimeError(_erro_http(resp))
    dados = resp.json()
    return _imagem_de(dados), _usd(dados)


def gerar_v3(prompt: str, tamanho: int, seed: int, espera: int = 300):
    """POST /v2/create-character-v3 — personagem com 8 rotações (assíncrono).

    Devolve background_job_id; a gente faz polling em /background-jobs/{id} e,
    quando termina, baixa o personagem em /characters/{id}. Custa bem mais que
    o pixflux, mas entrega o personagem virado para os 8 lados.
    """
    import requests
    corpo = {
        "description": prompt,
        "image_size": {"width": tamanho, "height": tamanho},
        "view": ESTILO["view"],
        "no_background": True,
        "outline": ESTILO["outline"],
        "detail": ESTILO["detail"],
        "seed": seed,
        "enhance_prompt": True,        # a própria API enriquece a descrição
    }
    resp = requests.post(f"{BASE_V2}/create-character-v3", json=corpo,
                         headers=_cabecalho(), timeout=120)
    if not resp.ok:
        raise RuntimeError(_erro_http(resp))
    envio = resp.json()
    job = envio.get("background_job_id")
    personagem = envio.get("character_id")
    if not job:
        raise RuntimeError(f"sem background_job_id: {json.dumps(envio)[:200]}")
    inicio = time.time()
    while time.time() - inicio < espera:
        time.sleep(5)
        st = requests.get(f"{BASE_V2}/background-jobs/{job}", headers=_cabecalho(), timeout=60)
        if not st.ok:
            raise RuntimeError(_erro_http(st))
        info = st.json()
        estado = (info.get("status") or "").lower()
        if estado in ("completed", "succeeded", "success", "done"):
            det = requests.get(f"{BASE_V2}/characters/{personagem}", headers=_cabecalho(), timeout=120)
            if not det.ok:
                raise RuntimeError(_erro_http(det))
            return det.json(), _usd(envio)     # dicionário com as rotações
        if estado in ("failed", "error", "cancelled"):
            raise RuntimeError(f"job falhou: {json.dumps(info)[:200]}")
    raise RuntimeError(f"tempo esgotado esperando o job {job}")


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
    ap.add_argument("--api", choices=["pixflux", "v3"], default="pixflux",
                    help="pixflux = 1 pose, síncrono e barato (padrão); "
                         "v3 = create-character-v3, personagem com 8 rotações")
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

    desconhecidos = [i for i in ids if i not in APARENCIA and i not in CENAS]
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
            elif args.api == "v3":
                dados, usd = gerar_v3(prompt, args.tamanho, seed)
                salvar_rotacoes(dados, destino, pid)
                feitos += 1
                custo += usd or 0.0
                print(f"[{n}/{len(ids)}] ✅ {pid} — personagem com rotações salvo")
                continue
            else:
                img, usd = gerar_v2(prompt, args.tamanho, seed)
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
