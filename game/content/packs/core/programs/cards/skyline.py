def skyline(bolts, battle):
    # The skyline problem, divide and conquer: the skyline of a volley is the skyline of its left half merged with the
    # skyline of its right half. Merging is one comparison: a right tower shorter than the left half's tallest is hidden
    # behind it and fuses into it, adding half its power; the rest stay visible. A tower holds what it has absorbed so far, and
    # passes it on if it is hidden in its turn.
    if not bolts:
        return bolts

    def skyline(lo, hi):  # the visible towers of bolts[lo:hi], as [place, absorbed]
        if hi - lo == 1:
            return [[lo, 0]]
        mid = (lo + hi) // 2
        left, right = skyline(lo, mid), skyline(mid, hi)
        tallest = bolts[left[-1][0]]["power"]
        for tower in right:
            power = bolts[tower[0]]["power"]
            if power < tallest:
                left[-1][1] += power // 2 + tower[1]
            else:
                left.append(tower)
        return left

    return [dict(bolts[place], power=bolts[place]["power"] + absorbed) for place, absorbed in skyline(0, len(bolts))]
