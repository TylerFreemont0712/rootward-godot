def charge_plus(bolts, battle):
    # Every bolt becomes spark, and 2 stronger.
    return [dict(bolt, element="spark", power=bolt["power"] + 2) for bolt in bolts]
