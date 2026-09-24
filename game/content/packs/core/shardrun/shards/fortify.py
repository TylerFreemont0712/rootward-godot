def fortify(bolts, battle):
    factor = 1 + sum(1 for b in bolts if not b["ward"])
    return [{**b, "mult": b["mult"] * factor} if b["ward"] else b for b in bolts]
