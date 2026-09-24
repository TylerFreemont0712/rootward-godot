def kindle(bolts, battle):
    return [{**bolt, "element": "fire", "power": bolt["power"] + 1} for bolt in bolts]
