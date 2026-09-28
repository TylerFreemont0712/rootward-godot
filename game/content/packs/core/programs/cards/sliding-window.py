def sliding_window(bolts, battle):
    out = []
    total = 0
    for i, bolt in enumerate(bolts):
        total += bolt["power"]
        if i >= 3:
            total -= bolts[i - 3]["power"]
        out.append(dict(bolt, power=total + 0))
    return out
