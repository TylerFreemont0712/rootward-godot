def flash_freeze(bolts, battle):
    return [{**b, "element": "frost", "ward": True, "mult": b["mult"] * 3} if b["element"] == "fire" else b for b in bolts]
