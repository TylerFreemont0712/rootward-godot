def exhaustive_kill(bolts, battle):
    # Brute force over subsets: every bitmask of the first 12 bolts is one subset, 2^n of them. Keep the subset
    # that kills the front foe with the smallest total; those bolts hit it, the rest hit the next foe.
    foes = battle["foes"]
    if not foes or not bolts:
        return bolts
    need = foes[0]["hp"] + foes[0]["shield"]
    pool = bolts[:12]
    best, best_total = -1, -1
    for mask in range(1, 1 << len(pool)):
        total = 0
        for i in range(len(pool)):
            if mask >> i & 1:
                total += pool[i]["power"]
        if total >= need and (best_total < 0 or total < best_total):
            best, best_total = mask, total
    if best < 0:
        return [dict(bolt, foe=0) for bolt in bolts]
    rest = 1 if len(foes) > 1 else 0
    return [dict(bolt, foe=0 if i < len(pool) and best >> i & 1 else rest) for i, bolt in enumerate(bolts)]
