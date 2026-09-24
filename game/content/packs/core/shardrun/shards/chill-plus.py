def chill_plus(bolts, battle):
    return [{**bolt, "element": "frost", "power": bolt["power"] + 3} for bolt in bolts]
