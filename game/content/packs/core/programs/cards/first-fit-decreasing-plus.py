def first_fit_decreasing_plus(bolts, battle):
    # First-fit decreasing packs large items before small ones, tracking space in each bin.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    remaining = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    result = []
    for bolt in sorted(bolts, key=lambda bolt: -bolt["power"]):
        target = 0
        for i, space in enumerate(remaining):
            if space > 0 and bolt["power"] <= space + 1:
                target = i
                break
        remaining[target] -= bolt["power"]
        result.append(dict(bolt, foe=target))
    return result
