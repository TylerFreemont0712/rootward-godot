def branch_and_bound_plus(bolts, battle):
    # Branch and bound: each bolt is in or out of the guard, a tree of choices. A branch is cut when even every
    # bolt left could not reach the damage the foes intend (the bound); the search stops once the best is exact.
    need = 0
    for foe in battle.get("foes", []):
        need += foe.get("intent", {}).get("damage", 0) * foe.get("intent", {}).get("hits", 1)
    pool = bolts[:12]
    if need <= 0 or not pool:
        return bolts
    weight = [max(0, bolt["power"]) for bolt in pool]
    reach = [0] * (len(pool) + 1)
    for i in range(len(pool)):
        reach[i + 1] = reach[i] + weight[i]
    best = [-1, 0]
    def search(i, total, mask):
        if best[0] == need:
            return
        if total >= need:
            if best[0] < 0 or total < best[0]:
                best[0], best[1] = total, mask
            return
        if total + reach[i] < need:
            return
        for take in range(2):
            if take:
                search(i - 1, total + weight[i - 1], mask | 1 << (i - 1))
            else:
                search(i - 1, total, mask)
    search(len(pool), 0, 0)
    guard = best[1] if best[0] >= 0 else (1 << len(pool)) - 1
    return [dict(bolt, block=True) if i < len(pool) and guard >> i & 1 else dict(bolt) for i, bolt in enumerate(bolts)]
