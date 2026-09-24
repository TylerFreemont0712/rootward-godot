def frontload(bolts, battle):
    return [{**b, "mult": b["mult"] * (4 if i == 0 else 0.5)} for i, b in enumerate(bolts)]
