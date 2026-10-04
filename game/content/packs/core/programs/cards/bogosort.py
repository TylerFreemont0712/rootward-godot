def bogosort(bolts, battle):
    # Bogosort: shuffle, check, repeat. A seeded LCG stands in for chance (the preview must equal the cast), and a
    # fixed number of tries stops the joke: after that, the arrangement with the fewest bolts out of place is kept.
    head, rest = bolts[:6], bolts[6:]
    seed = (battle.get("turn", 1) * 7919 + sum(bolt["power"] * (i + 1) for i, bolt in enumerate(head))) & 0xFFFFFFFF
    order = list(head)
    best, best_descents = list(head), -1
    for attempt in range(120):
        descents = 0
        for i in range(len(order) - 1):
            if order[i]["power"] > order[i + 1]["power"]:
                descents += 1
        if best_descents < 0 or descents < best_descents:
            best, best_descents = list(order), descents
        if descents == 0:
            break
        for i in range(len(order) - 1, 0, -1):
            seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
            j = (seed >> 16) % (i + 1)
            order[i], order[j] = order[j], order[i]
    return [dict(bolt) for bolt in best + rest]
