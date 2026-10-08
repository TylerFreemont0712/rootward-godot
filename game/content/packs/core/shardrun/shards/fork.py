def fork(bolts, battle):
    split = []
    for bolt in bolts:
        # Two copies of every bolt, each with 60% of its original power.
        split.append({**bolt, "power": bolt["power"] * 0.6})
        split.append({**bolt, "power": bolt["power"] * 0.6})
    return split
