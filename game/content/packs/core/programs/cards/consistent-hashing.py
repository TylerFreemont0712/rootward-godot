def consistent_hashing(bolts, battle):
    # Consistent hashing: foes and bolts are hashed onto one ring (0 to 359) and a bolt flies at the next foe clockwise.
    # A foe sits at a point set by its max HP, not by its place in the list, so when one falls only its own bolts move on to the next. None are wasted.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    points = [(foe["max"] * 47 + 13) % 360 for foe in foes]
    remaining = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    ring = sorted(range(len(foes)), key=lambda i: points[i])
    result = []
    for i, bolt in enumerate(bolts):
        spot = (bolt["power"] * 37 + i * 101) % 360
        lo, hi = 0, len(ring)
        while lo < hi:
            mid = (lo + hi) // 2
            if points[ring[mid]] < spot:
                lo = mid + 1
            else:
                hi = mid
        start = lo % len(ring)
        step = 0
        while step < len(ring) - 1 and remaining[ring[(start + step) % len(ring)]] <= 0:
            step += 1
        target = ring[(start + step) % len(ring)]
        power = bolt["power"]
        result.append(dict(bolt, power=power, foe=target))
        remaining[target] -= power
    return result
