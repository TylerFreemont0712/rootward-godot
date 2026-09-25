def salvo(bolts, battle):
    # A rising run of six bolts, after whatever came before.
    rising = [{"power": p, "element": "none"} for p in range(1, 7)]
    return bolts + rising
