def median_of_medians_plus(bolts, battle):
    # Median of medians: selection in guaranteed O(n). Cut the powers into groups of five, take each group's median,
    # then the median of those medians as the pivot: at least three tenths of the powers lie on each side of it, so the
    # side we recurse into is always much smaller, however the volley is ordered. The middle rank, n // 2, is the same
    # median Quickselect finds. The first bolt of that power is the pivot, and every bolt at or above it flies at the
    # toughest foe, the rest at the weakest.
    foes = battle.get("foes", [])
    if not foes or not bolts:
        return bolts

    def select(values, k):  # the k-th smallest of values, counting from 0
        if len(values) <= 5:
            return sorted(values)[k]
        medians = []
        for start in range(0, len(values), 5):
            group = sorted(values[start:start + 5])
            medians.append(group[len(group) // 2])
        pivot = select(medians, len(medians) // 2)
        lower = [v for v in values if v < pivot]
        equal = [v for v in values if v == pivot]
        if k < len(lower):
            return select(lower, k)
        if k < len(lower) + len(equal):
            return pivot
        return select([v for v in values if v > pivot], k - len(lower) - len(equal))

    median = select([bolt["power"] for bolt in bolts], len(bolts) // 2)
    toughest = max(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i].get("shield", 0))
    weakest = min(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i].get("shield", 0))
    out, marked = [], False
    for bolt in bolts:
        aimed = dict(bolt, foe=toughest if bolt["power"] >= median else weakest)
        if not marked and bolt["power"] == median:
            aimed["pivot"] = True
            aimed["power"] += 3
            marked = True
        out.append(aimed)
    return out
