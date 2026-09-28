def hash_merge_plus(bolts, battle):
    # One pass with a hash map (element -> bolt): same-element bolts fuse, +2 for each bolt swallowed. Everything
    # after this card has fewer bolts to work through.
    groups = {}
    for bolt in bolts:
        key = bolt["element"]
        if key in groups:
            groups[key] = dict(groups[key], power=groups[key]["power"] + bolt["power"] + 2)
        else:
            groups[key] = dict(bolt)
    return list(groups.values())
