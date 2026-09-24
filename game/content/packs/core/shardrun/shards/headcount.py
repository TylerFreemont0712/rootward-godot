def headcount(bolts, battle):
    bonus = 2 * len(battle["foes"])
    return [{**bolt, "power": bolt["power"] + bonus} for bolt in bolts]
