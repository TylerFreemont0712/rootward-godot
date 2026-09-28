def round_robin_plus(bolts, battle):
    # Deal the bolts to the foes in turn, skipping a foe whose dealt bolts already cover its HP; when every foe
    # is covered, deal on as before.
    foes = battle["foes"]
    count = len(foes)
    if count == 0:
        return bolts
    left = [foe["hp"] + foe["shield"] for foe in foes]
    out = []
    turn = 0
    for bolt in bolts:
        for _ in range(count):
            if left[turn % count] > 0:
                break
            turn += 1
        target = turn % count
        left[target] -= bolt["power"]
        out.append(dict(bolt, foe=target))
        turn += 1
    return out
