def lookup_plus(bolts, battle):
    # A lower bound finds the first indexed power large enough; never take a slot twice.
    index = battle.get("index", [])
    foes = battle.get("foes", [])
    if not index:
        return bolts
    need = foes[0]["hp"] + foes[0].get("shield", 0) if foes else 0
    lo, hi = 0, len(index)
    while lo < hi:
        mid = (lo + hi) // 2
        if index[mid]["power"] < need:
            lo = mid + 1
        else:
            hi = mid
    used, result = set(), list(bolts)
    for _ in range(2):
        pick = lo
        while pick < len(index) and pick in used:
            pick += 1
        if pick == len(index):
            pick = len(index) - 1
            while pick >= 0 and pick in used:
                pick -= 1
        if pick < 0:
            break
        used.add(pick)
        result.append(dict(index[pick], from_index=True))
    return result
