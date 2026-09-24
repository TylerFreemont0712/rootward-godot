def entrench(bolts, battle):
    factor = min(5, battle["turn"])
    return [{**b, "mult": b["mult"] * factor} if b["ward"] else b for b in bolts]
