def take_max(bolts, battle):
    # Keep a running top three (k = 3, so each step is constant work): O(n). The survivors grow by half.
    best = []
    for bolt in bolts:
        best.append(bolt)
        best.sort(key=lambda b: -b["power"])
        best = best[:3]
    best.reverse()
    return [dict(bolt, power=bolt["power"] * 3 // 2) for bolt in best]
