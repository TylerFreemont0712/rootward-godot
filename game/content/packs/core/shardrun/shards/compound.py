def compound(bolts, battle):
    return [{**bolt, "mult": bolt["mult"] * bolt["mult"]} for bolt in bolts]
