def chill(bolts, battle):
    # Every bolt becomes frost, and 1 stronger.
    return [dict(bolt, element="frost", power=bolt["power"] + 1) for bolt in bolts]
