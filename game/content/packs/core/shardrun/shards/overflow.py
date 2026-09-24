def overflow(bolts, battle):
    spilled = []
    for bolt in bolts:
        power = bolt["power"]
        while power > 20:
            spilled.append({**bolt, "power": 20})
            power = power - 20
        spilled.append({**bolt, "power": power})
    return spilled
