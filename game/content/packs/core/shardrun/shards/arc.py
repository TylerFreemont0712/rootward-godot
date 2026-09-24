def arc(bolts, battle):
    return [{**bolt, "element": "spark", "power": bolt["power"] + 1} for bolt in bolts]
