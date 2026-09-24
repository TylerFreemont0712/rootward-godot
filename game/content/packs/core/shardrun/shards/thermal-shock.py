def thermal_shock(bolts, battle):
    return [{**b, "element": "fire", "mult": b["mult"] * 4} if b["element"] == "frost" else b for b in bolts]
