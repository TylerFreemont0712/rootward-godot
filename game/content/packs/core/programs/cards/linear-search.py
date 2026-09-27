def linear_search(bolts, battle):
    # For each foe (weakest first), scan every bolt for the weakest that kills it alone: n checks per foe, O(n·m),
    # and no need for a sorted volley. The bolts not chosen go at the front foe.
    foes = battle["foes"]
    pool = list(bolts)
    order = sorted(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i]["shield"])
    chosen = []
    for i in order:
        need = foes[i]["hp"] + foes[i]["shield"]
        pick = -1
        for k in range(len(pool)):
            if pool[k]["power"] >= need and (pick < 0 or pool[k]["power"] < pool[pick]["power"]):
                pick = k
        if pick >= 0:
            chosen.append(dict(pool.pop(pick), foe=i))
    return chosen + [dict(bolt, foe=0) for bolt in pool]
