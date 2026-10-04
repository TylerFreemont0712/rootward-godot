def list_comprehension(bolts, battle):
    # A comprehension filters (if) and maps (the expression in front) in one pass.
    return [dict(bolt, power=bolt["power"] + 2) for bolt in bolts if bolt["power"] >= 3]
