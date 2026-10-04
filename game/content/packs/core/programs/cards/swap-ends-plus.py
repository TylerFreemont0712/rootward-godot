def swap_ends_plus(bolts, battle):
    # Python swaps two items without a temporary: a, b = b, a.
    result = [dict(bolt) for bolt in bolts]
    if len(result) > 1:
        result[0], result[-1] = result[-1], result[0]
    if result:
        result[0]["power"] += 1
    return result
