def fast_power_plus(bolts, battle):
    # Exponentiation by squaring: 2 ** k in about log2(k) multiplications, not k. Square the base every round and
    # multiply it into the answer whenever the matching bit of k is set. Here k = 4: the strongest bolt
    # (the first, if two tie) is doubled four times.
    if not bolts:
        return bolts
    factor, base, k = 1, 2, 4
    while k > 0:
        if k & 1:
            factor *= base
        base *= base
        k >>= 1
    strongest = 0
    for i, bolt in enumerate(bolts):
        if bolt["power"] > bolts[strongest]["power"]:
            strongest = i
    return [dict(bolt, power=bolt["power"] * factor) if i == strongest else bolt for i, bolt in enumerate(bolts)]
