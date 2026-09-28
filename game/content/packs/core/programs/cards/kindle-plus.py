def kindle_plus(bolts, battle):
    # Every bolt becomes fire, and 2 stronger.
    return [dict(bolt, element="fire", power=bolt["power"] + 2) for bolt in bolts]
