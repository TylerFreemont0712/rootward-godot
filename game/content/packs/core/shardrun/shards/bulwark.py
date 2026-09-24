def bulwark(bolts, battle):
    return [{**bolt, "ward": True, "power": bolt["power"] * 0.75} for bolt in bolts]
