def swap_ends(bolts, battle):
    # Python swaps two items without a temporary: a, b = b, a.
    result = [dict(bolt) for bolt in bolts]
    if len(result) > 1:
        result[0], result[-1] = result[-1], result[0]
    return result
