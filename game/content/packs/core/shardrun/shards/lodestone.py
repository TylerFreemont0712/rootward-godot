def lodestone(bolts, battle):
    return [{**b, "target": "back", "mult": b["mult"] * 2} if i == len(bolts) - 1 else b for i, b in enumerate(bolts)]
