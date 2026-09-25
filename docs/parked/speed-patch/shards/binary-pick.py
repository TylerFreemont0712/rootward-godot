def binary_pick(bolts, battle):
    lo, hi = 0, len(bolts)
    while lo < hi:
        mid = (lo + hi) // 2
        if bolts[mid]['power'] < 8:
            lo = mid + 1
        else:
            hi = mid
    return [{**bolts[lo], 'power': bolts[lo]['power'] + 3}] if lo < len(bolts) else []
