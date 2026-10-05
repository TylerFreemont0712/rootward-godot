def bogosort(bolts, battle):
    # A seeded LCG makes the preview match the cast. Check the initial order and up to 120 shuffles; keep the attempt
    # with the fewest descents. A completed sort gets a small volley bonus, while reaching the cap still rewards its
    # strongest bolt.
    head, rest = bolts[:6], bolts[6:]
    seed = (battle.get("turn", 1) * 7919 + sum(bolt["power"] * (i + 1) for i, bolt in enumerate(head))) & 0xFFFFFFFF
    order = list(head)
    best, best_descents = list(head), -1
    sorted_successfully = False
    for shuffles in range(121):
        descents = 0
        for i in range(len(order) - 1):
            if order[i]["power"] > order[i + 1]["power"]:
                descents += 1
        if best_descents < 0 or descents < best_descents:
            best, best_descents = list(order), descents
        if descents == 0:
            sorted_successfully = True
            break
        if shuffles == 120:
            break
        for i in range(len(order) - 1, 0, -1):
            seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
            j = (seed >> 16) % (i + 1)
            order[i], order[j] = order[j], order[i]
    result = [dict(bolt) for bolt in best]
    if sorted_successfully:
        for bolt in result:
            bolt["power"] += 1
    elif result:
        strongest = max(range(len(result)), key=lambda i: result[i]["power"])
        result[strongest]["power"] += 3
    return result + [dict(bolt) for bolt in rest]
