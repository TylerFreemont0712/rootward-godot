def counting_sort(bolts, battle):
    # Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order.
    # O(n + k), where k is the strongest power: fast while powers are small, slow when one bolt is huge.
    top = 0
    for bolt in bolts:
        top = max(top, bolt["power"])
    buckets = []
    for power in range(top + 1):
        buckets.append([])
    for bolt in bolts:
        buckets[bolt["power"]].append(dict(bolt))
    result = []
    for bucket in buckets:
        for bolt in bucket:
            result.append(bolt)
    return result
