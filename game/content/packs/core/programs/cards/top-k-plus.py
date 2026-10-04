def top_k_plus(bolts, battle):
    # Keep only k candidates in a min-heap; its root is the weakest survivor.
    import heapq
    heap, discarded = [], 0
    for i, bolt in enumerate(bolts):
        heapq.heappush(heap, (bolt["power"], -i, i))
        if len(heap) > 5:
            power, _, _ = heapq.heappop(heap)
            discarded += power
    result = []
    while heap:
        _, _, i = heapq.heappop(heap)
        result.append(dict(bolts[i]))
    if result:
        result[0]["power"] += discarded
    return result
