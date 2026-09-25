def binary_execute(bolts, battle):
    # For each foe (weakest first), binary search for the smallest bolt that kills it: O(log n) per foe. It only
    # works on a volley sorted weakest first; on any other order it looks in the wrong half.
    foes = battle["foes"]
    pool = list(bolts)
    order = sorted(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i]["shield"])
    chosen = []
    for i in order:
        if not pool:
            break
        need = foes[i]["hp"] + foes[i]["shield"]
        lo, hi = 0, len(pool)
        while lo < hi:
            mid = (lo + hi) // 2
            if pool[mid]["power"] < need:
                lo = mid + 1
            else:
                hi = mid
        pick = lo if lo < len(pool) else len(pool) - 1
        chosen.append(dict(pool.pop(pick), foe=i))
    return chosen
