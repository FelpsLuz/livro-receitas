"""BANDAS — o orçamento vertical da cena (spec §1), fonte única de Y.

O bug de layout do v1 tinha causa única: não existia orçamento de Y, e a
faixa de campo perdeu a disputa duas vezes. Aqui cada banda tem começo e fim,
o campo tem MÍNIMO INVIOLÁVEL, e nenhum Y pode ser hardcodado fora deste
módulo (nem no Python do pipeline, nem no GDScript — scripts/bandas.gd será
gerado a partir daqui quando a composição entrar).

Tabela da spec em canvas normalizado 320x180, convertida por razão para o
canvas nativo 400x200: y_real = round(y_tabela / 180 * 200).

ESTES NÚMEROS SÃO HIPÓTESE INICIAL (spec §1 "Como aplicar"): congelam como
constantes só depois do aceite visual N5 contra docs/referencia.png.
"""

CANVAS_W = 400
CANVAS_H = 200

_F = CANVAS_H / 180.0        # 1.111…


def _y(y_tabela: int) -> int:
    return round(y_tabela * _F)


# (início, fim) em Y de arte. Overlaps são intencionais (serra invade céu).
BANDAS = {
    "ceu":       (_y(0),   _y(52)),    # (0, 58)
    "montanhas": (_y(42),  _y(74)),    # (47, 82)
    "floresta":  (_y(70),  _y(96)),    # (78, 107) — terreno permanente
    "muralha":   (_y(88),  _y(104)),   # (98, 116) — topo NUNCA acima de 98
    "campo":     (_y(100), _y(152)),   # (111, 169) — banda dominante
    "rio":       (_y(150), _y(170)),   # (167, 189)
    "margem":    (_y(168), _y(180)),   # (187, 200)
}

# O castelo é a ÚNICA exceção autorizada a quebrar banda (spec §1): base na
# linha da muralha, topo furando serra e céu — é o que dá profundidade.
CASTELO_BASE = _y(104)      # 116
CASTELO_TOPO = _y(40)       # 44

# Mínimo inviolável da banda de campo (spec: 48 em 180 → 53 em 200).
CAMPO_MINIMO = round(48 * _F)


def altura(banda: str) -> int:
    a, b = BANDAS[banda]
    return b - a


def validar() -> list[str]:
    """As invariantes da spec §8, como medida — não como teste que passa vazio."""
    erros: list[str] = []
    if altura("campo") < CAMPO_MINIMO:
        erros.append(f"campo com {altura('campo')}px < mínimo {CAMPO_MINIMO}")
    if BANDAS["muralha"][0] < _y(88):
        erros.append(f"topo da muralha {BANDAS['muralha'][0]} acima de {_y(88)}")
    if BANDAS["floresta"][0] >= BANDAS["muralha"][0]:
        erros.append("floresta não fica visível acima da muralha")
    if BANDAS["margem"][1] != CANVAS_H:
        erros.append("margem frontal não fecha o canvas")
    for banda, (a, b) in BANDAS.items():
        if not (0 <= a < b <= CANVAS_H):
            erros.append(f"banda {banda} fora do canvas: {(a, b)}")
    return erros


# Partição SEM overlap para fatiar a placa base em nós (linhas de corte):
# os overlaps das BANDAS são intenção de composição; para dividir UM PNG em
# Sprite2D moduláveis, cada linha só pode pertencer a uma fatia.
FATIAS = {
    "fundo":    (0,                    BANDAS["floresta"][0]),   # céu+serra
    "floresta": (BANDAS["floresta"][0], BANDAS["campo"][0]),
    "campo":    (BANDAS["campo"][0],    BANDAS["rio"][0]),
    "rio":      (BANDAS["rio"][0],      BANDAS["margem"][0]),
    "margem":   (BANDAS["margem"][0],   CANVAS_H),
}


def gerar_gd(caminho: str) -> None:
    """Emite scripts/bandas.gd — nenhum Y hardcodado fora deste módulo."""
    linhas = [
        "# GERADO por ferramentas/cenario_v2/bandas.py — NÃO EDITAR À MÃO.",
        "# Fonte única do orçamento vertical (spec §1). Para mudar um Y,",
        "# mude bandas.py e rode: python3 ferramentas/cenario_v2/bandas.py --gd",
        "class_name Bandas",
        "",
        f"const CANVAS_W := {CANVAS_W}",
        f"const CANVAS_H := {CANVAS_H}",
        f"const CASTELO_BASE := {CASTELO_BASE}",
        f"const CASTELO_TOPO := {CASTELO_TOPO}",
        f"const CAMPO_MINIMO := {CAMPO_MINIMO}",
        "",
        "const BANDAS := {",
    ]
    for banda, (a, b) in BANDAS.items():
        linhas.append(f'\t"{banda}": Vector2i({a}, {b}),')
    linhas += ["}", "", "const FATIAS := {"]
    for fatia, (a, b) in FATIAS.items():
        linhas.append(f'\t"{fatia}": Vector2i({a}, {b}),')
    linhas += ["}", ""]
    with open(caminho, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    print(f"✅ {caminho} gerado")


if __name__ == "__main__":
    import sys
    problemas = validar()
    for banda, (a, b) in BANDAS.items():
        print(f"  {banda:10} {a:3}..{b:3}  (h={b - a})")
    print(f"  castelo    base {CASTELO_BASE}, topo {CASTELO_TOPO} (quebra banda)")
    print("✅ invariantes ok" if not problemas else f"❌ {problemas}")
    if "--gd" in sys.argv:
        from pathlib import Path
        raiz = Path(__file__).resolve().parent.parent.parent
        gerar_gd(str(raiz / "reino-por-conquista-godot" / "scripts" / "bandas.gd"))
