def apex(bolts, battle):
    if not bolts:
        return bolts
    best = bolts[0]
    for bolt in bolts:
        if bolt["power"] > best["power"]:
            best = bolt
    return [{**best, "power": best["power"] + 3}]
