def amplify(bolts, battle):
    return [{**bolt, "power": bolt["power"] + 3} for bolt in bolts]
