def blood_price(bolts, battle):
    return [{**b, "mult": b["mult"] * 4} for b in bolts]
