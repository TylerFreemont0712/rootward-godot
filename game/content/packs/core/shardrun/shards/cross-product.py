def cross_product(bolts, battle):
    return [{**a, "power": (a["power"] + b["power"]) / 2, "mult": a["mult"] + b["mult"]} for a in bolts for b in bolts if a["element"] != b["element"]]
