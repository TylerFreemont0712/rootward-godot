def tithe(bolts, battle):
    return [{**bolt, "power": bolt["power"] // 2, "mult": bolt["mult"] * 2} for bolt in bolts]
