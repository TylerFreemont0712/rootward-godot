def counting_sort_plus(bolts, battle):
    # Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order. O(n + k).
    # k is capped at 64: bolts stronger than that skip the counting and are sorted the ordinary way after the rest.
    top = 0
    for bolt in bolts:
        top = max(top, min(bolt["power"], 64))
    buckets = []
    for power in range(top + 1):
        buckets.append([])
    huge = []
    for bolt in bolts:
        if bolt["power"] > 64:
            huge.append(dict(bolt))
        else:
            buckets[bolt["power"]].append(dict(bolt))
    result = []
    for bucket in buckets:
        for bolt in bucket:
            result.append(bolt)
    return result + sorted(huge, key=lambda bolt: bolt["power"])
