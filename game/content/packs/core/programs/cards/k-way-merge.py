def k_way_merge(bolts, battle):
    # A heap stores only the head of each rising run: merging k sorted streams costs log k per bolt.
    import heapq
    runs = []
    for i, bolt in enumerate(bolts):
        if not runs or bolt["power"] < runs[-1][-1][1]["power"]:
            runs.append([])
        runs[-1].append((i, bolt))
    heap = []
    for r, run in enumerate(runs):
        heapq.heappush(heap, (run[0][1]["power"], run[0][0], r, 0))
    result = []
    while heap:
        _, _, r, pos = heapq.heappop(heap)
        result.append(dict(runs[r][pos][1], power=runs[r][pos][1]["power"] + len(runs)))
        pos += 1
        if pos < len(runs[r]):
            i, bolt = runs[r][pos]
            heapq.heappush(heap, (bolt["power"], i, r, pos))
    strongest_first = False
    return list(reversed(result)) if strongest_first else result
