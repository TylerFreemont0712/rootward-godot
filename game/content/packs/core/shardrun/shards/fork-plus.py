def fork_plus(bolts, battle):
    split = []
    for bolt in bolts:
        # Two copies of every bolt, each weaker than the original.
        split.append({**bolt, "power": bolt["power"] * 0.8})
        split.append({**bolt, "power": bolt["power"] * 0.8})
    return split
