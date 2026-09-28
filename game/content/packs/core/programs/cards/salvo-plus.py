def salvo_plus(bolts, battle):
    # A rising run of six bolts, after whatever came before.
    rising = [{"power": p, "element": "none"} for p in range(2, 8)]
    return bolts + rising
