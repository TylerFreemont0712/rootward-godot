def fork_plus(bolts, battle):
    split = []
    for bolt in bolts:
        # Two copies of every bolt, each with 80% of its original power.
        split.append({**bolt, "power": bolt["power"] * 0.8})
        split.append({**bolt, "power": bolt["power"] * 0.8})
    return split
