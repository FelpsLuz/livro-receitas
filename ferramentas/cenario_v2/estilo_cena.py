"""ESTILO_CENA — o dicionário CONGELADO da spec §D. Fonte única, sem override.

O inventário mediu 8 peças iluminadas pela esquerda e 7 pela direita no
pipeline v1. A causa não era o modelo: era `outline`, `shading`, `detail` e
`view` nunca terem sido travados — cada chamada montava os seus. Aqui existe
UM dicionário, importado por 100% das chamadas, e um teste que falha se
qualquer chamada montar esses campos localmente (`teste_estilo_congelado.py`).

Valores validados contra os enums do OpenAPI em 2026-08-05:
  Outline: single color black outline · single color outline ·
           selective outline · lineless
  Shading: flat/basic/medium/detailed/highly detailed shading
  Detail:  low/medium/highly detailed
  View:    side · low top-down · high top-down
"""

from types import MappingProxyType

# MappingProxyType: imutável de verdade — quem tentar sobrescrever um campo
# leva TypeError em vez de introduzir a divergência silenciosa de sempre.
ESTILO_CENA = MappingProxyType({
    "view": "side",                  # elevação: é a projeção da referência
    "outline": "selective outline",  # sel-out: o padrão dos melhores ativos v1
    "shading": "basic shading",      # rampa curta, sem gradiente
    "detail": "medium detail",
    "seed": 20260805,                # a placa base é DETERMINÍSTICA; objetos
                                     # podem variar seed — nunca o resto
})

# Concatenado em TODO prompt, sem exceção (spec §D). O sol da referência está
# no canto superior DIREITO — o v1 dizia "upper left" e pagou por isso.
SUFIXO_LUZ = "light source from upper right, shadows cast to lower left"

# O DNA de cena: a luz quente da referência. Vai no positivo de toda chamada.
SUFIXO_ESTILO = (
    "lush storybook medieval pixel art, warm golden afternoon sunlight, "
    "rich warm greens, clean pixel clusters, hard shading with a 3-4 tone "
    "ramp, defined silhouettes, charming and inviting"
)

# Sempre no campo negative_description — nunca no prompt positivo, onde os
# tokens entrariam no embedding positivo e aumentariam a chance do defeito.
NEGATIVO = (
    "watercolor, sketch, blurry, anti-aliased, smooth gradient, glow, "
    "soft airbrush shading, photorealistic, text, watermark, ui frame, "
    "neon, dithering noise, grim, dark, desaturated"
)


def prompt_completo(descricao: str) -> str:
    """Todo prompt do pipeline nasce daqui: descrição + estilo + LUZ."""
    return ", ".join([descricao, SUFIXO_ESTILO, SUFIXO_LUZ])


# Correção do 3/4 (addendum v3 §B.1): `view: side` não segurou sozinho — o
# sprite do piloto saiu em leve 3/4. Concatenado em TODO prompt de OBJETO.
# Aceite: topo de telhado visível como superfície = rejeitar e regerar.
SUFIXO_PERSPECTIVA = (
    "strict flat side elevation, orthographic front view, no perspective, "
    "no three-quarter angle, no visible roof top surface, no visible "
    "ground plane, facade parallel to picture plane"
)


def corpo_base(descricao: str, w: int, h: int, seed: int | None = None) -> dict:
    """O corpo de requisição canônico. Nenhuma chamada monta o próprio.

    `seed` pode variar por OBJETO (spec §D permite); os campos de estilo, não.
    """
    return {
        "description": prompt_completo(descricao),
        "negative_description": NEGATIVO,
        "image_size": {"width": w, "height": h},
        "text_guidance_scale": 7.5,
        "view": ESTILO_CENA["view"],
        "outline": ESTILO_CENA["outline"],
        "shading": ESTILO_CENA["shading"],
        "detail": ESTILO_CENA["detail"],
        "seed": ESTILO_CENA["seed"] if seed is None else seed,
    }


def corpo_objeto(descricao: str, w: int, h: int,
                 seed: int | None = None) -> dict:
    """Corpo canônico de OBJETO isolado (addendum v3 §B): corpo_base +
    SUFIXO_PERSPECTIVA no prompt + fundo transparente. Tamanho 1:1 do
    canvas — nunca reescalar (v3 §J)."""
    corpo = corpo_base(", ".join([descricao, SUFIXO_PERSPECTIVA]), w, h,
                       seed=seed)
    corpo["no_background"] = True
    return corpo
