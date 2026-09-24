def adapt(bolts, battle):
    foes = battle["foes"]
    if not foes or not foes[0]["weak"]:
        return bolts
    element = foes[0]["weak"][0]
    return [{**bolt, "element": element} for bolt in bolts]
