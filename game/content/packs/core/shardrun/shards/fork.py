def fork(bolts, battle):
    split = []
    for bolt in bolts:
        # Two copies of every bolt, each weaker than the original.
        split.append({**bolt, "power": bolt["power"] * 0.6})
        split.append({**bolt, "power": bolt["power"] * 0.6})
    return split
