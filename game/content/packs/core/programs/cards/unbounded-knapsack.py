def unbounded_knapsack(bolts, battle):
    # Unbounded knapsack: every bolt can be copied as often as you like. count[t] is the fewest copies that sum to t,
    # pick[t] the bolt that made it, filled for each total in turn (the 0/1 knapsack went bolt by bolt instead). The
    # copies that sum exactly to the front foe's HP are appended, aimed at it. Without an exact sum nothing is added.
    foes = battle.get("foes", [])
    if not foes:
        return list(bolts)
    need = foes[0]["hp"] + foes[0].get("shield", 0)
    items = [i for i, bolt in enumerate(bolts) if bolt["power"] > 0 and not bolt.get("block")]
    if need <= 0 or need > 1200 or not items:
        return list(bolts)
    count, pick = [-1] * (need + 1), [-1] * (need + 1)
    count[0] = 0
    for total in range(1, need + 1):
        for i in items:
            power = bolts[i]["power"]
            if power <= total and count[total - power] != -1 and (count[total] == -1 or count[total - power] + 1 < count[total]):
                count[total] = count[total - power] + 1
                pick[total] = i
    if count[need] == -1:
        return list(bolts)
    copies, total = [], need
    while total > 0:
        i = pick[total]
        copies.append(dict(bolts[i], power=bolts[i]["power"] + 0, foe=0))
        total -= bolts[i]["power"]
    return list(bolts) + copies
