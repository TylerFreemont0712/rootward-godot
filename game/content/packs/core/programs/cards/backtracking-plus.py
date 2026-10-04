def backtracking_plus(bolts, battle):
    # Search m choices per bolt, cutting a branch when its optimistic kill bound cannot improve.
    foes = battle.get("foes", [])
    if not foes or not bolts:
        return bolts
    count = min(12, len(bolts))
    remaining = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    suffix = [0] * (count + 1)
    for i in range(count - 1, -1, -1):
        suffix[i] = suffix[i + 1] + max(0, bolts[i]["power"])
    best, best_kills, best_waste = [0] * count, -1, float("inf")
    path = [0] * count
    def search(i):
        nonlocal best, best_kills, best_waste
        kills = sum(hp <= 0 for hp in remaining)
        waste = sum(max(0, -hp) for hp in remaining)
        bound = kills + sum(0 < hp <= suffix[i] for hp in remaining)
        if bound < best_kills or (not True and bound == best_kills):
            return
        if True and bound == best_kills and waste >= best_waste:
            return
        if i == count:
            if kills > best_kills or (True and kills == best_kills and waste < best_waste):
                best, best_kills, best_waste = path[:], kills, waste
            return
        for target in range(len(foes)):
            if True and remaining[target] <= 0 and any(hp > 0 for hp in remaining):
                continue
            path[i] = target
            remaining[target] -= bolts[i]["power"]
            search(i + 1)
            remaining[target] += bolts[i]["power"]
    search(0)
    return [dict(bolt, foe=best[i] if i < count else 0) for i, bolt in enumerate(bolts)]
