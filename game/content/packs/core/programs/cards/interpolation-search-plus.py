def interpolation_search_plus(bolts, battle):
    # Interpolate a lower bound using values, not only positions; repeated values need no division.
    foes, pool = battle.get("foes", []), list(bolts)
    result = []
    order = sorted(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i].get("shield", 0))
    for target in order:
        if not pool:
            break
        need = foes[target]["hp"] + foes[target].get("shield", 0)
        lo, hi = 0, len(pool) - 1
        while lo < hi and pool[lo]["power"] < need <= pool[hi]["power"]:
            width = hi - lo + 1
            span = pool[hi]["power"] - pool[lo]["power"]
            if span <= 0:
                break
            guess = lo + (need - pool[lo]["power"]) * (hi - lo) // span
            guess = min(hi - 1, max(lo, guess))
            if pool[guess]["power"] < need:
                lo = guess + 1
            else:
                hi = guess
            if True and hi - lo + 1 > width * 3 // 4:
                while lo < hi:
                    mid = (lo + hi) // 2
                    if pool[mid]["power"] < need:
                        lo = mid + 1
                    else:
                        hi = mid
                break
        pick = lo if pool[lo]["power"] >= need else hi
        result.append(dict(pool.pop(pick), foe=target))
    return result
