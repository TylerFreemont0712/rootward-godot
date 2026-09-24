def alternating_current(bolts, battle):
    return [{**b, "mult": b["mult"] * (3 if i > 0 and b["element"] != bolts[i - 1]["element"] else 1)} for i, b in enumerate(bolts)]
