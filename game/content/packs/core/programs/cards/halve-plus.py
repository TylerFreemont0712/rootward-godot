def halve_plus(bolts, battle):
    # The divide step by itself: the volley is cut at ceil(n / 2) and the card after this one runs on each half.
    # The cut is a rule, so a card can find it without being told: the first bolt of the right half is bolts[half].
    half = (len(bolts) + 1) // 2
    return [dict(bolt, power=bolt["power"] + (1 if i in (0, half) else 0)) for i, bolt in enumerate(bolts)]
