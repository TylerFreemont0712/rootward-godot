def cartesian_product_plus(bolts, battle):
    # The Cartesian product enumerates every pair, in bolt order then foe order.
    result = []
    for bolt in bolts:
        for i in range(len(battle.get("foes", []))):
            result.append(dict(bolt, power=bolt["power"] // 2, foe=i))
    return result
