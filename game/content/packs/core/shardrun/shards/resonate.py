def resonate(bolts, battle):
    return [{**bolt, "mult": bolt["mult"] * 2} for bolt in bolts]
