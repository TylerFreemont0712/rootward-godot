def vengeance(bolts, battle):
    me = battle["me"]
    if me["hp"] * 2 > me["max"]:
        return bolts
    return [{**bolt, "power": bolt["power"] + 4} for bolt in bolts]
