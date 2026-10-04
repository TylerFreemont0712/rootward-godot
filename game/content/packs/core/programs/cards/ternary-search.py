def ternary_search(bolts, battle):
    # Ternary search: on a volley that rises then falls, compare the two third-points and throw away the third that cannot hold the peak. O(log n).
    # The peak bolt doubles.
    if not bolts:
        return bolts
    lo, hi = 0, len(bolts) - 1
    while hi - lo > 2:
        third = (hi - lo) // 3
        m1, m2 = lo + third, hi - third
        if bolts[m1]["power"] < bolts[m2]["power"]:
            lo = m1 + 1
        else:
            hi = m2 - 1
    peak = lo
    for i in range(lo + 1, hi + 1):
        if bolts[i]["power"] > bolts[peak]["power"]:
            peak = i
    result = [dict(bolt) for bolt in bolts]
    result[peak]["power"] *= 2
    return result
