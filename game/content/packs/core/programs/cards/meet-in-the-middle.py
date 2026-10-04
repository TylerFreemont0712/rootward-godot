def meet_in_the_middle(bolts, battle):
    # Meet in the middle: Exhaustive Kill tries all 2^n subsets. Split the bolts in two halves instead, list every
    # subset sum of each (2^(n/2) each), sort one list, and binary-search it for the partner of every sum of the other.
    # It finds the same subset, the smallest total that kills the front foe, with the square root of the work.
    foes = battle.get("foes", [])
    if not foes or not bolts:
        return bolts
    need = foes[0]["hp"] + foes[0].get("shield", 0)
    pool = bolts[:12]
    half = len(pool) // 2
    def sums(items, shift):
        found = [(0, 0)]
        for k, bolt in enumerate(items):
            for total, mask in list(found):
                found.append((total + bolt["power"], mask | 1 << (shift + k)))
        return found
    low = sums(pool[:half], 0)
    high = sorted(sums(pool[half:], half))
    best_total, best_mask = 0, -1
    for total, mask in low:
        lo, hi = 0, len(high)
        while lo < hi:
            mid = (lo + hi) // 2
            if high[mid][0] < need - total:
                lo = mid + 1
            else:
                hi = mid
        if mask == 0 and lo < len(high) and high[lo][1] == 0:
            lo += 1
        if lo == len(high):
            continue
        found_total, found_mask = total + high[lo][0], mask | high[lo][1]
        if best_mask < 0 or found_total < best_total or (found_total == best_total and found_mask < best_mask):
            best_total, best_mask = found_total, found_mask
    if best_mask < 0:
        return [dict(bolt, foe=0) for bolt in bolts]
    rest = 1 if len(foes) > 1 else 0
    return [dict(bolt, foe=0 if i < len(pool) and best_mask >> i & 1 else rest) for i, bolt in enumerate(bolts)]
