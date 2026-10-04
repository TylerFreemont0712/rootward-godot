def list_comprehension_plus(bolts, battle):
    # A comprehension filters (if) and maps (the expression in front) in one pass.
    return [dict(bolt, power=bolt["power"] + 3) for bolt in bolts if bolt["power"] >= 3]
