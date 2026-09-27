def filter_weak(bolts, battle):
    # A filter with a predicate (power >= 3). What fails it is not thrown away: the strongest survivor absorbs it.
    kept = [dict(bolt) for bolt in bolts if bolt["power"] >= 3]
    if not kept:
        return bolts
    dropped = sum(bolt["power"] for bolt in bolts if bolt["power"] < 3)
    best = 0
    for i in range(1, len(kept)):
        if kept[i]["power"] > kept[best]["power"]:
            best = i
    kept[best]["power"] += dropped
    return kept
