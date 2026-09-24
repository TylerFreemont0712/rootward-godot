def kindle_plus(bolts, battle):
    return [{**bolt, "element": "fire", "power": bolt["power"] + 3} for bolt in bolts]
