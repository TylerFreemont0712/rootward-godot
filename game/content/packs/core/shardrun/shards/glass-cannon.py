def glass_cannon(bolts, battle):
    return [{**b, "power": b["power"] * 2, "mult": b["mult"] * 2} for b in bolts if not b["ward"]]
