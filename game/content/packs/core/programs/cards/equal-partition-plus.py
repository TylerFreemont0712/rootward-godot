def equal_partition_plus(bolts, battle):
    # The partition problem: can the volley be split into two groups of equal sum? Subset-sum DP over half the total:
    # reach[s] remembers the bolt that first made sum s reachable (one bolt at a time, so none is used twice). If half
    # is reachable, walk the table back for one group; the rest are the other. Each group fuses into one bolt and
    # gains 40%. Ward bolts and zero-power bolts stay out; totals past 1024 are too big for the table.
    pool = [i for i, bolt in enumerate(bolts) if bolt["power"] > 0 and not bolt.get("block")]
    total = sum(bolts[i]["power"] for i in pool)
    if len(pool) < 2 or total % 2 == 1 or total > 1024:
        return [dict(bolt) for bolt in bolts]
    target = total // 2
    reach = [-1] * (target + 1)
    reach[0] = len(bolts)
    for i in pool:
        power = bolts[i]["power"]
        for s in range(target, power - 1, -1):
            if reach[s] == -1 and reach[s - power] != -1:
                reach[s] = i
    if reach[target] == -1:
        return [dict(bolt) for bolt in bolts]
    left, s = set(), target
    while s > 0:
        i = reach[s]
        left.add(i)
        s -= bolts[i]["power"]
    fused = []
    for group in ([i for i in pool if i in left], [i for i in pool if i not in left]):
        lead = max(group, key=lambda i: bolts[i]["power"])
        fused.append(dict(bolts[lead], power=target * 7 // 5))
    return fused + [dict(bolt) for i, bolt in enumerate(bolts) if i not in pool]
