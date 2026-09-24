def siphon(bolts, battle):
    if not bolts:
        return bolts
    weakest = 0
    for index, bolt in enumerate(bolts):
        if bolt["power"] < bolts[weakest]["power"]:
            weakest = index
    warded = []
    for index, bolt in enumerate(bolts):
        if index == weakest:
            warded.append({**bolt, "ward": True, "power": bolt["power"] * 2})
        else:
            warded.append(bolt)
    return warded
