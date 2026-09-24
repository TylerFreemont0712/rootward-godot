def rebuke(bolts, battle):
    return [{**b, "ward": False, "mult": b["mult"] * 2} if b["ward"] else b for b in bolts]
