def permutations(bolts, battle):
    # Permutations: every order of the first 6 bolts (6! = 720; 12! would be 479 million). Order matters because bolts
    # are dealt round robin: place 0 to foe 0, place 1 to foe 1, and so on. Keep the order that kills the most foes.
    import itertools
    foes = battle.get("foes", [])
    if not foes or not bolts:
        return bolts
    count = min(6, len(bolts))
    need = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    best, best_kills = [], -1
    for order in itertools.permutations(range(count)):
        totals = [0] * len(foes)
        for place, i in enumerate(order):
            totals[place % len(foes)] += bolts[i]["power"]
        kills = sum(totals[f] >= need[f] for f in range(len(foes)))
        if kills > best_kills:
            best, best_kills = order, kills
    order = list(best) + list(range(count, len(bolts)))
    return [dict(bolts[i], foe=place % len(foes)) for place, i in enumerate(order)]
