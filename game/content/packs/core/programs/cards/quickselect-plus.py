def quickselect_plus(bolts, battle):
    # Quickselect: partition around a pivot, then recurse into the one side that holds the middle rank. Average O(n).
    foes = battle["foes"]
    if not foes or not bolts:
        return bolts

    def kth(values, k):
        pivot = values[0]
        lower = [v for v in values if v < pivot]
        equal = [v for v in values if v == pivot]
        if k < len(lower):
            return kth(lower, k)
        if k < len(lower) + len(equal):
            return pivot
        return kth([v for v in values if v > pivot], k - len(lower) - len(equal))

    median = kth([bolt["power"] for bolt in bolts], len(bolts) // 2)
    toughest = max(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i]["shield"])
    weakest = min(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i]["shield"])
    return [
        dict(bolt, foe=toughest, power=bolt["power"] + 2) if bolt["power"] >= median else dict(bolt, foe=weakest)
        for bolt in bolts
    ]
