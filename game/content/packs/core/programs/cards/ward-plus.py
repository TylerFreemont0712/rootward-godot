def ward_plus(bolts, battle):
    # A linear search for the strongest bolt; it becomes your shield, 4 stronger.
    if not bolts:
        return bolts
    best = 0
    for i in range(1, len(bolts)):
        if bolts[i]["power"] > bolts[best]["power"]:
            best = i
    out = [dict(bolt) for bolt in bolts]
    out[best] = dict(out[best], power=out[best]["power"] + 4, block=True)
    return out
