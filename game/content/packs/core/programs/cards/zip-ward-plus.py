def zip_ward_plus(bolts, battle):
    out = []
    for bolt in bolts:
        if bolt.get("block", False):
            out.append(dict(bolt))
        else:
            out.append(dict(bolt, power=(bolt["power"] + 1) // 2))
            out.append(dict(bolt, power=bolt["power"] // 2 + 2, block=True))
    return out
