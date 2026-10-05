def heapify(bolts, battle):
    # Bottom-up heapify: sift each parent down, last parent first. Most nodes are near the leaves and barely move, so
    # the whole build is O(n), cheaper than sorting. The strongest bolt ends up first; the rest are in heap order.
    out = list(bolts)
    n = len(out)
    for start in range(n // 2 - 1, -1, -1):
        root = start
        while 2 * root + 1 < n:
            child = 2 * root + 1
            if child + 1 < n and out[child + 1]["power"] > out[child]["power"]:
                child += 1
            if out[child]["power"] <= out[root]["power"]:
                break
            out[root], out[child] = out[child], out[root]
            root = child
    if out:
        # The heap root is the strongest bolt; make that payoff immediate without disturbing heap order.
        out[0] = dict(out[0], power=out[0]["power"] + 2)
    return out
