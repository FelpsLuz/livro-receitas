# ============================================================
# BARRAMENTO DE EVENTOS — registrar como autoload "Eventos".
#
# Só a UI escuta. O núcleo nunca conecta nada: ele apenas anuncia, através
# de scripts/sinais.gd. Assim a interface para de perguntar a cada quadro se
# alguma coisa aconteceu, e o núcleo continua rodando nos testes sem autoload.
# ============================================================
extends Node

## Fila de recrutamento
signal tropa_pronta(info: Dictionary)      # {tipo, restantes}
signal fila_vazia()

## Geopolítica dos NPCs
signal guerra_npc(info: Dictionary)        # {a, b}
signal conquista_npc(info: Dictionary)     # {vencedor, perdedor}
signal pacto_npc(info: Dictionary)         # {a, b, tipo}

## Terra e povo
signal cidadao_ascendeu(info: Dictionary)  # {nome, riqueza}
signal pressao_alta(info: Dictionary)      # {terra, pressao}

## Intriga e taverna
signal rumor_comprado(info: Dictionary)    # {reino, bem, verdadeiro}
signal intriga_plantada(info: Dictionary)  # {reino, tipo}
signal preso(info: Dictionary)             # {meses, motivo}
