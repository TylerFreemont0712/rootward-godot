def max_subarray_plus(bolts, battle):
    # Maximum subarray, divide and conquer: the best run lies in the left half, in the right half, or across the
    # middle. Across the middle it is the best stretch ending at the cut on the left plus the best starting there on the
    # right. A bolt scores its power minus 3, as in Kadane, so weak bolts count against a run. The best run fuses into
    # one bolt of its whole power, 2 stronger for every level of the recursion. O(n log n) against Kadane's O(n).
    if not bolts:
        return bolts

    def best(lo, hi):  # (score, first, last, levels) of the best run inside bolts[lo:hi]
        if hi - lo == 1:
            return (bolts[lo]["power"] - 3, lo, lo, 0)
        mid = (lo + hi) // 2
        left, right = best(lo, mid), best(mid, hi)
        total, reach_left, first = 0, None, mid - 1
        for i in range(mid - 1, lo - 1, -1):
            total += bolts[i]["power"] - 3
            if reach_left is None or total > reach_left:
                reach_left, first = total, i
        total, reach_right, last = 0, None, mid
        for i in range(mid, hi):
            total += bolts[i]["power"] - 3
            if reach_right is None or total > reach_right:
                reach_right, last = total, i
        pick = left
        if reach_left + reach_right > pick[0]:
            pick = (reach_left + reach_right, first, last, 0)
        if right[0] > pick[0]:
            pick = right
        return (pick[0], pick[1], pick[2], max(left[3], right[3]) + 1)

    _, first, last, levels = best(0, len(bolts))
    run = bolts[first:last + 1]
    strongest = run[0]
    for bolt in run:
        if bolt["power"] > strongest["power"]:
            strongest = bolt
    fused = dict(strongest, power=sum(bolt["power"] for bolt in run) + 2 * levels)
    return bolts[:first] + [fused] + bolts[last + 1:]
