def stable_partition(bolts, battle):
    front, rest = [], []
    for bolt in bolts:
        group = front if bolt["power"] >= 6 and not bolt.get("block", False) else rest
        group.append(dict(bolt))
    return front + rest
