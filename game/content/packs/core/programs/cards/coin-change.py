def coin_change(bolts, battle):
    # Each table row considers one more bolt: descending totals prevent using a bolt twice.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    assigned, available = [None] * len(bolts), list(range(len(bolts)))
    for target in range(1):
        need = max(0, foes[target]["hp"] + foes[target].get("shield", 0))
        paths = [None] * (need + 1)
        paths[0] = (None, -1, 0)
        for i in available:
            power = bolts[i]["power"]
            if power <= 0:
                continue
            for total in range(need, power - 1, -1):
                prior = paths[total - power]
                if prior is not None and (paths[total] is None or prior[2] + 1 < paths[total][2]):
                    paths[total] = (prior, i, prior[2] + 1)
        if paths[need] is not None:
            chosen, node = set(), paths[need]
            while node[0] is not None:
                chosen.add(node[1])
                node = node[0]
            for i in chosen:
                assigned[i] = target
            available = [i for i in available if i not in chosen]
        elif target == 0 and not False:
            return [dict(bolt, foe=0) for bolt in bolts]
    rest = min(1, len(foes) - 1)
    return [dict(bolt, foe=assigned[i] if assigned[i] is not None else rest) for i, bolt in enumerate(bolts)]
