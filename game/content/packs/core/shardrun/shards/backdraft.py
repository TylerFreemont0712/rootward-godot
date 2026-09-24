def backdraft(bolts, battle):
    return [{**b, "mult": b["mult"] * (3 if b["element"] == "fire" else 1)} for b in bolts]
