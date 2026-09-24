def transduce(bolts, battle):
    return [{**b, "power": 4, "mult": b["mult"] * b["power"] / 4} if b["power"] > 4 else b for b in bolts]
