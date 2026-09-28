def chill_plus(bolts, battle):
    # Every bolt becomes frost, and 2 stronger.
    return [dict(bolt, element="frost", power=bolt["power"] + 2) for bolt in bolts]
