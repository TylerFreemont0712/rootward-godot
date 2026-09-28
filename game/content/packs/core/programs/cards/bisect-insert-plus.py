def bisect_insert_plus(bolts, battle):
    # bisect: halve the range until the place is found (O(log n)), then insert there. A sorted volley stays sorted.
    out = list(bolts)
    for _ in range(3):
        lo, hi = 0, len(out)
        while lo < hi:
            mid = (lo + hi) // 2
            if out[mid]["power"] <= 8:
                lo = mid + 1
            else:
                hi = mid
        out.insert(lo, {"power": 8, "element": "none"})
    return out
