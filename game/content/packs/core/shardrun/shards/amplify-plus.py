def amplify_plus(bolts, battle):
    return [{**bolt, "power": bolt["power"] + 5} for bolt in bolts]
