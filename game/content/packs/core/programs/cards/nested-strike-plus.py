def nested_strike_plus(bolts, battle):
    # One loop inside another: every foe receives bolts until its remaining HP reaches zero.
    result = []
    for i, foe in enumerate(battle.get("foes", [])):
        remaining = foe["hp"] + foe.get("shield", 0)
        for bolt in bolts:
            if remaining <= 0:
                break
            result.append(dict(bolt, foe=i))
            remaining -= bolt["power"]
    return result
