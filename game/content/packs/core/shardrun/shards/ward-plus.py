def ward_plus(bolts, battle):
    if not bolts:
        return bolts
    # The first bolt becomes a ward with 5 extra power; the other bolts stay unchanged.
    first = {**bolts[0], "ward": True, "power": bolts[0]["power"] + 5}
    return [first] + bolts[1:]
