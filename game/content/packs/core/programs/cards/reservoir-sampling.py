def reservoir_sampling(bolts, battle):
    # Algorithm R: keep 3 items from a stream in one pass, without knowing its length. Item i replaces a kept one
    # with chance 3 / (i + 1), so every bolt is equally likely to stay. The seed makes the preview the cast.
    seed = battle.get("turn", 1)
    for bolt in bolts:
        seed = (seed * 31 + bolt["power"]) & 0xFFFFFFFF
    reservoir = []
    for i in range(len(bolts)):
        if i < 3:
            reservoir.append(i)
        else:
            seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
            j = (seed >> 16) % (i + 1)
            if j < 3:
                reservoir[j] = i
    return [dict(bolts[i], power=bolts[i]["power"] * 2) for i in sorted(reservoir)]
