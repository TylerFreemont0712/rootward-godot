def ward_plus(bolts, battle):
    if not bolts:
        return bolts
    # The first bolt turns inward and becomes block; the rest fly on.
    first = {**bolts[0], "ward": True, "power": bolts[0]["power"] + 5}
    return [first] + bolts[1:]
