def bisect_insert(bolts, battle):
    # bisect: halve the range until the place is found (O(log n)), then insert there. A sorted volley stays sorted.
    out = list(bolts)
    for _ in range(2):
        lo, hi = 0, len(out)
        while lo < hi:
            mid = (lo + hi) // 2
            if out[mid]["power"] <= 7:
                lo = mid + 1
            else:
                hi = mid
        out.insert(lo, {"power": 7, "element": "none"})
    return out
