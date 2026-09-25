def fork(bolts, battle):
    # Every bolt splits in two, each with 60% of its power (at least 1).
    out = []
    for bolt in bolts:
        part = max(1, bolt["power"] * 6 // 10)
        out.append(dict(bolt, power=part))
        out.append(dict(bolt, power=part))
    return out
