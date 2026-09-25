def charge(bolts, battle):
    # Every bolt becomes spark, and 1 stronger.
    return [dict(bolt, element="spark", power=bolt["power"] + 1) for bolt in bolts]
