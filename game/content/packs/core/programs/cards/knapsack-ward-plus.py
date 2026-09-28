def knapsack_ward_plus(bolts, battle):
    # Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
    # one bolt at a time (0/1 knapsack): O(n x H) for H = 16 plus the largest bolt. The smallest reachable total of 16
    # or more becomes block, its bolts found by walking the table back; with none, every bolt guards.
    if not bolts:
        return bolts
    goal = 16
    cap = goal + max(bolt["power"] for bolt in bolts)
    reach = [-1] * (cap + 1)
    reach[0] = len(bolts)
    for i, bolt in enumerate(bolts):
        for s in range(cap, bolt["power"] - 1, -1):
            if reach[s] == -1 and reach[s - bolt["power"]] != -1 and bolt["power"] > 0:
                reach[s] = i
    total = next((s for s in range(goal, cap + 1) if reach[s] != -1), -1)
    if total < 0:
        return [dict(bolt, block=True) for bolt in bolts]
    chosen = set()
    while total > 0:
        i = reach[total]
        chosen.add(i)
        total -= bolts[i]["power"]
    return [dict(bolt, block=True) if i in chosen else dict(bolt) for i, bolt in enumerate(bolts)]
