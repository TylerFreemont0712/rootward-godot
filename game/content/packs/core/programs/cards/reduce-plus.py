def reduce_plus(bolts, battle):
    # A fold: one accumulator carried across the volley, one bolt out. The strongest bolt's element survives.
    if not bolts:
        return bolts
    total = 0
    strongest = bolts[0]
    for bolt in bolts:
        total += bolt["power"]
        if bolt["power"] > strongest["power"]:
            strongest = bolt
    return [{"power": total + total // 4, "element": strongest["element"]}]
