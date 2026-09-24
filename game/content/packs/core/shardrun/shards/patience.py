def patience(bolts, battle):
    bonus = (battle["turn"] - 1) * 3
    return [{**bolt, "power": bolt["power"] + bonus} for bolt in bolts]
