def range_query_plus(bolts, battle):
    # A range scan: two binary searches bound the bolts with power in [need // 3, need] for each foe, so the range is read in O(log n + k).
    # It needs a volley sorted weakest first. Bolts no foe asked for are stashed in the index.
    foes = battle.get("foes", [])
    if not foes:
        return bolts

    def first_at_least(pool, target):
        lo, hi = 0, len(pool)
        while lo < hi:
            mid = (lo + hi) // 2
            if pool[mid]["power"] < target:
                lo = mid + 1
            else:
                hi = mid
        return lo

    pool, result = list(bolts), []
    for i, foe in enumerate(foes):
        need = foe["hp"] + foe.get("shield", 0)
        low = first_at_least(pool, need // 3)
        high = first_at_least(pool, need + 1)
        if low < high:
            for bolt in pool[low:high]:
                result.append(dict(bolt, foe=i))
            pool = pool[:low] + pool[high:]
    for bolt in pool:
        result.append(dict(bolt, stash=True))
    return result
