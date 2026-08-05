#!/usr/bin/env python3
"""Transformações DESTRUTIVAS da placa base — uma só vez, com registro.

A placa base não é dogma (regra permanente do v3.2 §A): é asset como outro
e pode estar errada. Quando está, o remédio é uma transformação
determinística de custo zero. Este arquivo é o lugar único delas, e cada
uma grava um selo em placa_base.json — rodar de novo é recusado, porque
aplicar o mesmo deslocamento duas vezes destrói a placa em silêncio.

Histórico:
  espelhada       (v3.2 §B) — a auditoria mediu luz pela ESQUERDA em 4
                  bandas; aplicada direto no arquivo, fora deste script.
  maciço_descido  (v3.4 §B) — o cume ficava 12px ACIMA do topo do castelo,
                  invertendo a hierarquia da referência (lá o castelo fica
                  19px acima do pico). Desce 20px.

    python3 ferramentas/cenario_v2/transformar_placa.py --baixar-macico
"""

import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent.parent
CEN = RAIZ / "reino-por-conquista-godot" / "assets_v2" / "cenario"
PLACA = CEN / "base" / "placa_base.png"
PARAMS = CEN / "base" / "placa_base.json"

# Até onde a transformação mexe. NÃO é a fatia de fundo (78): medido, o
# maciço continua em cor de rocha até y≈92 e só então a mata assume. Cortar
# em 78 partia a montanha no meio e deixava borda dura (salto de luminância
# passou de 4,2 para 22,0 na junção — a §B.4 pega isso). Em 104 o corte cai
# sob copa densa (68% de árvore já em y=98).
FUNDO_FIM = 104         # o maciço vai em cor de rocha até y≈92; 78 o partia
DESCE = 20
# O maciço central é DETECTADO, não chutado: colunas fixas (100..262)
# arrastaram junto a borda da serra lateral e deixaram costura vertical.
# A serra lateral tem crista em y≈60..73; o maciço, em y≈32..52. O corte
# em 54 separa os dois com folga dos dois lados (medido).
CRISTA_LIMITE = 54
# Paleta da ROCHA, medida no miolo do maciço (y34..70, x145..225): 4 cores
# cobrem 77% dos pixels não-céu de lá.
PALETA_ROCHA = ((220, 207, 145), (100, 164, 164), (147, 211, 191),
                (106, 195, 202))


def _selo_ler() -> dict:
    return json.loads(PARAMS.read_text()) if PARAMS.exists() else {}


def extensao_registrada() -> tuple | None:
    """A extensão do maciço gravada no selo, para quem só deriva."""
    e = _selo_ler().get("macico_extensao")
    return (e["x0"], e["x1"]) if e else None


def mascara_macico(faixa: np.ndarray, quieto: bool = False,
                   extensao: tuple | None = None):
    """Máscara LIMPA do maciço, por PALETA EXATA de céu.

    Duas máscaras já falharam aqui, e vale registrar as duas:
      1. a de montanha_central.png é CARREGADORA de véu (imperfeição não
         custa nada quando se pinta por cima) — usada para MOVER deixou
         1791px de resíduo;
      2. inundação de céu com teste `b-r>25 & L>150` engoliu os cumes: o
         teal sombrio (100,164,164) passa no teste de azul e fica conectado
         ao céu, então os picos saíam da máscara e ficavam para trás como
         fantasma. É a MESMA armadilha que a auditoria de luz documentou.

    Arte em pixel tem céu de pouquíssimas cores chapadas — aqui 4, medidas
    das linhas do topo. Correspondência EXATA não tem como confundir teal
    de rocha com azul de céu. Depois, cada coluna é preenchida do primeiro
    pixel de rocha para baixo: buraco interno vira maciço, e a árvore sai
    de novo no fim para ficar parada enquanto a montanha anda.
    """
    topo = faixa[0:14].reshape(-1, 3)
    cores, n = np.unique(topo, axis=0, return_counts=True)
    paleta = cores[n >= 40]
    if len(paleta) < 2:
        sys.exit("céu com paleta suspeita — abortando em vez de destruir a placa")
    ceu = np.zeros(faixa.shape[:2], bool)
    for c in paleta:
        ceu |= (faixa == c).all(axis=2)
    lum_pal = 0.2126 * paleta[:, 0] + 0.7152 * paleta[:, 1] + 0.0722 * paleta[:, 2]
    nuvem = np.zeros_like(ceu)
    for c in paleta[lum_pal > 230]:            # as claras da paleta são nuvem
        nuvem |= (faixa == c).all(axis=2)

    r, g, b = (faixa[..., k].astype(int) for k in range(3))
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    arvore = (g >= r) & (g > b) & (g - b > 12) & (lum < 160)

    # A ROCHA tem paleta própria, medida no miolo do maciço. Usá-la em vez
    # de "tudo que não é céu, da crista para baixo" importa: aquela versão
    # marcava também o céu AO LADO dos picos dentro da janela de colunas, e
    # deslocá-lo deixava uma borda vertical visível em x0 e x1.
    rocha = np.zeros(faixa.shape[:2], bool)
    for c in PALETA_ROCHA:
        rocha |= (faixa == np.array(c)).all(axis=2)

    W = faixa.shape[1]
    crista = np.array([np.nonzero(rocha[:, x])[0].min()
                       if rocha[:, x].any() else 999 for x in range(W)])

    def _corpo(x0: int, x1: int):
        """SÓ rocha, mais fechamento de 1px para tapar buraco de dither.

        Duas decisões medidas aqui:

        1. SÓ ROCHA, sem preencher a coluna. Preencher da primeira à
           última rocha parecia mais seguro e não era: as FENDAS DE CÉU
           entre os picos entram no preenchimento e, deslocadas, recebem
           nuvem de 20 linhas acima — retângulo claro de bordas verticais.
           A fenda é céu e continua céu.
        2. LARGURA CHEIA, não a janela x0..x1. O maciço não acaba em x0:
           suas saias descem e se fundem com as serras laterais na mesma
           paleta de rocha. Recortar em x0 deslocava a saia de dentro e
           deixava a de fora parada — costura vertical exatamente em x0.
           A cordilheira é uma peça só e desce inteira. x0..x1 continua
           servindo para MEDIR o cume (critério §B.4), não para cortar.
        """
        m = rocha.copy()          # LARGURA CHEIA: ver nota abaixo
        _ = (x0, x1)
        d = m.copy()
        d[1:, :] |= m[:-1, :]; d[:-1, :] |= m[1:, :]
        d[:, 1:] |= m[:, :-1]; d[:, :-1] |= m[:, 1:]
        e = d.copy()
        e[1:, :] &= d[:-1, :]; e[:-1, :] &= d[1:, :]
        e[:, 1:] &= d[:, :-1]; e[:, :-1] &= d[:, 1:]
        return e

    # A extensão pode vir DADA (do selo em placa_base.json). Detectar de
    # novo depois de o maciço descer não funciona: o corte de crista que
    # separava maciço (32..52) de serra lateral (60..73) deixa de separar
    # quando o maciço passa a 52..72. Extensão é propriedade estabelecida
    # no momento da transformação — quem transformou registra, quem deriva
    # lê. Sem selo, detecta.
    if extensao is not None:
        x0, x1 = int(extensao[0]), int(extensao[1])
        pico = x0 + int(np.argmin(crista[x0:x1 + 1]))
        return _corpo(x0, x1), nuvem, ceu, (x0, x1, int(crista[pico]), pico)

    # O maciço é o RUN MAIS LONGO de colunas com crista alta — não o run
    # que contém o pico global. Realce claro de copa de árvore escapa do
    # teste de verde e vira uma coluna de crista altíssima; ancorar no
    # mínimo global fazia o detector eleger essa árvore (x=291..291) e o
    # véu de recessão sumia. Árvore dá run de 1–3 colunas; maciço, de ~90.
    alto = crista <= CRISTA_LIMITE
    melhor, atual = (0, -1, -1), -1
    for x in range(W + 1):
        dentro = x < W and alto[x]
        if dentro and atual < 0:
            atual = x
        elif not dentro and atual >= 0:
            if x - atual > melhor[0]:
                melhor = (x - atual, atual, x - 1)
            atual = -1
    if melhor[0] < 20:
        sys.exit(f"maciço não encontrado (maior run {melhor[0]} colunas) — "
                 f"abortando em vez de mover a coisa errada")
    x0, x1 = melhor[1], melhor[2]
    pico = x0 + int(np.argmin(crista[x0:x1 + 1]))
    if not quieto:
        print(f"   maciço detectado: x={x0}..{x1}, cume y={crista[pico]} em x={pico}")
    return _corpo(x0, x1), nuvem, ceu, (x0, x1, int(crista[pico]), pico)


def baixar_macico(descer: int = DESCE) -> None:
    selo = _selo_ler()
    if selo.get("maciço_descido"):
        sys.exit(f"🛑 já aplicado ({selo['maciço_descido']}). Aplicar de novo "
                 f"desceria mais {descer}px e destruiria a placa.")

    placa = np.array(Image.open(PLACA).convert("RGB"))
    faixa = placa[0:FUNDO_FIM].copy()
    macico, nuvem, ceu, ext = mascara_macico(faixa)

    # DESLOCAMENTO POR FOOTPRINT: cada pixel do maciço recebe o conteúdo
    # de `descer` linhas acima dele. Nada é preenchido, nada é inventado.
    #   - o topo vira céu de verdade (o que estava 20 linhas acima do cume
    #     É céu), sem paleta poluída — tentativas com vizinho, mediana e
    #     moda já falharam de três jeitos diferentes aqui;
    #   - a BASE continua contínua por construção: o último pixel do
    #     footprint recebe montanha de 20 linhas acima, também montanha.
    #     Recortar e colar deixava borda dura na junção com a mata (salto
    #     de luminância 4,2 → 22,0 cortando em 78; → 94,2 cortando em 104).
    nova = placa.copy()
    ys, xs = np.nonzero(macico)
    nova[ys, xs] = placa[np.maximum(0, ys - descer), xs]

    # SELO ANTES DA IMAGEM, de propósito. Na ordem inversa, uma exceção
    # entre o save e o selo deixa a placa alterada e destravada — e a
    # execução seguinte desce mais 20px (aconteceu, e só o backup salvou).
    # Falhar depois do selo trava a segunda aplicação, que é o lado seguro:
    # a placa se recupera com `git checkout`.
    selo["maciço_descido"] = (
        f"2026-08-05: maciço central descido {descer}px (v3.4 §B.2). O cume ficava 12px ACIMA do topo do "
        f"castelo — hierarquia invertida contra a referência, onde o "
        f"castelo fica 19px acima do pico. Máscara por PALETA EXATA de "
        f"céu (inundação engolia o teal do cume); extensão do maciço "
        f"detectada pela crista, não fixada; "
        f"buraco preenchido com a mediana de céu de cada linha. "
        f"placa_modelo.png preserva a saída crua do modelo.")
    selo["macico_extensao"] = {"x0": ext[0], "x1": ext[1],
                               "cume_y": ext[2] + descer, "cume_x": ext[3]}
    PARAMS.write_text(json.dumps(selo, indent=1, ensure_ascii=False))
    Image.fromarray(nova).save(PLACA)
    print(f"✅ maciço descido {descer}px · {int(macico.sum())}px movidos")
    print(f"   selo gravado em {PARAMS.name} — rodar de novo será recusado")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--baixar-macico", action="store_true")
    ap.add_argument("--px", type=int, default=DESCE)
    args = ap.parse_args()
    if args.baixar_macico:
        baixar_macico(args.px)
    else:
        ap.error("nada a fazer: passe --baixar-macico")
