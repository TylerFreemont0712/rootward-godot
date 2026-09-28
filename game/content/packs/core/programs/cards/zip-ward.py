def zip_ward(bolts, battle):
    out = []
    for bolt in bolts:
        if bolt.get("block", False):
            out.append(dict(bolt))
        else:
            out.append(dict(bolt, power=(bolt["power"] + 1) // 2))
            out.append(dict(bolt, power=bolt["power"] // 2 + 0, block=True))
    return out
