def knapsack_strike_plus(bolts, battle):
    # Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
    # one bolt at a time (0/1 knapsack): O(n x H) for H the front foe's HP. Take the smallest reachable total that
    # kills it, walk the table back to find its bolts, and aim them; the rest go at the weakest other foe.
    foes = battle["foes"]
    if not foes or not bolts:
        return bolts
    need = foes[0]["hp"] + foes[0]["shield"]
    cap = need + max(bolt["power"] for bolt in bolts)
    reach = [-1] * (cap + 1)
    reach[0] = len(bolts)
    for i, bolt in enumerate(bolts):
        for s in range(cap, bolt["power"] - 1, -1):
            if reach[s] == -1 and reach[s - bolt["power"]] != -1 and bolt["power"] > 0:
                reach[s] = i
    total = next((s for s in range(need, cap + 1) if reach[s] != -1), -1)
    if total < 0:
        return [dict(bolt, foe=0) for bolt in bolts]
    chosen = set()
    while total > 0:
        i = reach[total]
        chosen.add(i)
        total -= bolts[i]["power"]
    others = [i for i in range(1, len(foes))]
    rest = min(others, key=lambda i: foes[i]["hp"] + foes[i]["shield"]) if others else 0
    return [dict(bolt, foe=0 if i in chosen else rest) for i, bolt in enumerate(bolts)]
