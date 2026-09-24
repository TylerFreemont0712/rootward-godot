def superconductor(bolts, battle):
    return [{**b, "element": "spark", "pierce": True, "mult": b["mult"] * 3} if b["element"] == "frost" else b for b in bolts]
