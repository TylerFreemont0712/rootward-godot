def increase_key(bolts, battle):
    # Increase-key: raise the weakest bolt to one less than the strongest, then sift it up while it beats its parent. On a heap
    # (Heapify makes one) the sift takes only O(log n) steps; finding the weakest is a scan.
    if not bolts:
        return bolts
    out = [dict(bolt) for bolt in bolts]
    low, high = 0, 0
    for i in range(1, len(out)):
        if out[i]["power"] < out[low]["power"]:
            low = i
        if out[i]["power"] > out[high]["power"]:
            high = i
    out[low]["power"] = max(out[low]["power"], out[high]["power"] - 1)
    i = low
    while i > 0 and out[(i - 1) // 2]["power"] < out[i]["power"]:
        parent = (i - 1) // 2
        out[parent], out[i] = out[i], out[parent]
        i = parent
    return out
