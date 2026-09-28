def stable_partition_plus(bolts, battle):
    front, rest = [], []
    for bolt in bolts:
        group = front if bolt["power"] >= 4 and not bolt.get("block", False) else rest
        group.append(dict(bolt))
    return front + rest
