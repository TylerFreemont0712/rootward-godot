def break_loop_plus(bolts, battle):
    # Hit the front foe with each bolt in turn; the moment it falls, break out of the loop. The bolts after the kill
    # are never touched, and the loop's work is only the bolts it used.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    remaining = foes[0]["hp"] + foes[0].get("shield", 0)
    result = list(bolts)
    for i, bolt in enumerate(bolts):
        result[i] = dict(bolt, foe=0)
        remaining -= bolt["power"]
        if remaining <= 0:
            if len(foes) > 1:
                for j in range(i + 1, len(bolts)):
                    result[j] = dict(bolts[j], foe=1)
            break
    return result
