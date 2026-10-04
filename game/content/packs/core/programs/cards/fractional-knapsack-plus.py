def fractional_knapsack_plus(bolts, battle):
    # Fractional knapsack: the strongest bolt goes to the front foe, and a bolt that holds more than the foe needs is
    # cut in two (what it needs, and a remainder, 1 stronger). Greedy by value is exactly optimal when you may cut.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    order = sorted((i for i in range(len(bolts)) if not bolts[i].get("block")), key=lambda i: -bolts[i]["power"])
    result = [dict(bolt) for bolt in bolts if bolt.get("block")]
    for rank, i in enumerate(order[: len(foes)]):
        need = foes[rank]["hp"] + foes[rank].get("shield", 0)
        bolt = bolts[i]
        if 0 < need < bolt["power"]:
            rest = dict(bolt, power=bolt["power"] - need + 1)
            rest.pop("foe", None)
            result.append(dict(bolt, power=need, foe=rank))
            result.append(rest)
        else:
            result.append(dict(bolt, foe=rank))
    for i in order[len(foes):]:
        result.append(dict(bolts[i]))
    return result
