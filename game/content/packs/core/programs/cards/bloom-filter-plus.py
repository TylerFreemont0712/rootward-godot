def bloom_filter_plus(bolts, battle):
    # Swap the Bloom filter for an exact hash set of the weak elements: the same one pass, but never a false positive.
    weak = set()
    for foe in battle.get("foes", []):
        for element in foe.get("weak", []):
            weak.add(element)
    if not weak:
        return bolts
    result = []
    for bolt in bolts:
        if bolt["element"] in weak:
            result.append(dict(bolt, power=bolt["power"] + 2))
        else:
            result.append(dict(bolt))
    return result
