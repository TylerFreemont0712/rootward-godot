def confluence(bolts, battle):
    factor = max(1, len({b["element"] for b in bolts if b["element"] != "none"}))
    return [{**b, "mult": b["mult"] * factor} for b in bolts]
