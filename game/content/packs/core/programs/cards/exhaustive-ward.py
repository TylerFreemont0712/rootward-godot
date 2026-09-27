def exhaustive_ward(bolts, battle):
    # Every subset of the first ten bolts as a bitmask (2^n of them): keep the one whose total reaches 12 with the
    # least to spare. Those become your block; the rest still fly. If none reaches 12, all ten guard.
    pool = bolts[:10]
    best, best_total = -1, -1
    for mask in range(1, 1 << len(pool)):
        total = 0
        for i in range(len(pool)):
            if mask >> i & 1:
                total += pool[i]["power"]
        if total >= 12 and (best_total < 0 or total < best_total):
            best, best_total = mask, total
    if best < 0:
        best = (1 << len(pool)) - 1
    return [dict(bolt, block=True) if i < len(pool) and best >> i & 1 else dict(bolt) for i, bolt in enumerate(bolts)]
