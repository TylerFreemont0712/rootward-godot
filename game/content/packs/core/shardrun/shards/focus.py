def focus(bolts, battle):
    if not bolts:
        return []
    total = 0
    for bolt in bolts:
        total += bolt["power"]
    return [{**bolts[0], "power": total}]
