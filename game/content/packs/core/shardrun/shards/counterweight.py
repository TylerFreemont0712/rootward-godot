def counterweight(bolts, battle):
    factor = 1 + sum(1 for b in bolts if b["ward"])
    return [{**b, "mult": b["mult"] * factor} if not b["ward"] else b for b in bolts]
