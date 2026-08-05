"""Teste de não-override da spec §D: falha se qualquer chamada divergir.

Duas verificações, ambas de verdade:
1. ESTÁTICA — varre o código do pipeline atrás de montagem local dos campos
   congelados ("view":, "outline":, "shading":, "detail":) fora de
   estilo_cena.py. Quem quiser estilo pede a corpo_base(); não monta o seu.
2. DINÂMICA — chama corpo_base() e confere campo a campo contra ESTILO_CENA,
   e que o SUFIXO_LUZ está no prompt. Se alguém "melhorar" o corpo_base um
   dia, o teste acusa aqui.

    python3 ferramentas/cenario_v2/teste_estilo_congelado.py
"""

import re
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

from estilo_cena import ESTILO_CENA, SUFIXO_LUZ, corpo_base  # noqa: E402

falhas: list[str] = []

# ---- 1. estática: ninguém monta estilo localmente ----
CAMPOS = ('"view"', '"outline"', '"shading"', '"detail"')
for arquivo in AQUI.glob("*.py"):
    if arquivo.name in ("estilo_cena.py", Path(__file__).name):
        continue
    texto = arquivo.read_text(encoding="utf-8")
    for campo in CAMPOS:
        for m in re.finditer(re.escape(campo) + r"\s*:", texto):
            linha = texto[: m.start()].count("\n") + 1
            falhas.append(f"{arquivo.name}:{linha} monta {campo} localmente")

# ---- 2. dinâmica: o corpo canônico é fiel ao dicionário congelado ----
corpo = corpo_base("teste", 128, 128)
for k in ("view", "outline", "shading", "detail"):
    if corpo.get(k) != ESTILO_CENA[k]:
        falhas.append(f"corpo_base()[{k}] = {corpo.get(k)!r} != {ESTILO_CENA[k]!r}")
if corpo.get("seed") != ESTILO_CENA["seed"]:
    falhas.append("corpo_base() sem seed padrão da placa")
if corpo_base("teste", 1, 1, seed=7)["seed"] != 7:
    falhas.append("corpo_base() ignora seed por objeto")
if SUFIXO_LUZ not in corpo["description"]:
    falhas.append("SUFIXO_LUZ ausente do prompt")
if "upper right" not in SUFIXO_LUZ:
    falhas.append("a luz não vem do canto superior direito")

try:
    ESTILO_CENA["view"] = "high top-down"          # type: ignore[index]
    falhas.append("ESTILO_CENA aceitou escrita — não está congelado")
except TypeError:
    pass

if falhas:
    print("❌ ESTILO NÃO CONGELADO:")
    for f in falhas:
        print("   -", f)
    sys.exit(1)
print("✅ estilo congelado: estática e dinâmica ok")
