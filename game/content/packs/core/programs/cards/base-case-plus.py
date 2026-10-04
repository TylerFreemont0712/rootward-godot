def base_case_plus(bolts, battle):
    # A small subproblem is solved directly: the base case of a recursive algorithm.
    if len(bolts) > 3:
        return bolts
    return [dict(bolt, power=bolt["power"] * 2) for bolt in bolts]
