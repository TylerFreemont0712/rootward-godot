def exponential_search(bolts, battle):
    # Galloping: look at bolt 1, 2, 4, 8 ... until one is strong enough, then binary-search only the last gap. O(log i) when the answer is bolt i.
    # It needs a volley sorted weakest first.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    order = [0]
    pool, chosen = list(bolts), []
    for i in order:
        if not pool:
            break
        need = foes[i]["hp"] + foes[i].get("shield", 0)
        bound = 1
        while bound < len(pool) and pool[bound]["power"] < need:
            bound *= 2
        lo, hi = bound // 2, min(bound + 1, len(pool))
        while lo < hi:
            mid = (lo + hi) // 2
            if pool[mid]["power"] < need:
                lo = mid + 1
            else:
                hi = mid
        pick = lo if lo < len(pool) else len(pool) - 1
        chosen.append(dict(pool.pop(pick), foe=i))
    return chosen
