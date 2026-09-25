def kindle(bolts, battle):
    # Every bolt becomes fire, and 1 stronger.
    return [dict(bolt, element="fire", power=bolt["power"] + 1) for bolt in bolts]
