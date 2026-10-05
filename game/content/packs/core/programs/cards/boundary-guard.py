def boundary_guard(bolts, battle):
    # A recursive call gets its own small boundary: sacrifice its weakest attack when there are at least two.
    result = [dict(bolt) for bolt in bolts]
    attacks = [i for i, bolt in enumerate(result) if not bolt.get("block") and not bolt.get("stash")]
    if len(attacks) < 2:
        return result
    weakest = min(attacks, key=lambda i: result[i]["power"])
    result[weakest]["block"] = True
    return result
