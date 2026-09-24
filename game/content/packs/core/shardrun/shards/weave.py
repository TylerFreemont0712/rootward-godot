def weave(bolts, battle):
    return [{**b, "ward": i % 2 == 0, "mult": b["mult"] * (2 if i % 2 == 0 else 1)} for i, b in enumerate(bolts)]
