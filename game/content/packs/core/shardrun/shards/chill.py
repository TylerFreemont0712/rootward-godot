def chill(bolts, battle):
    return [{**bolt, "element": "frost", "power": bolt["power"] + 1} for bolt in bolts]
