def tally(bolts, battle):
    return [{**bolt, "power": bolt["power"] + len(bolts)} for bolt in bolts]
