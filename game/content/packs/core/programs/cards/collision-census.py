def collision_census(bolts, battle):
    # A bounded, deliberately direct census: compare attacks among the first 24 bolts.
    original = [dict(bolt) for bolt in bolts]
    result = [dict(bolt) for bolt in original]
    attacks = []
    for i, bolt in enumerate(original[:24]):
        if not bolt.get("block", False) and not bolt.get("stash", False):
            attacks.append(i)
            if len(attacks) == 24:
                break

    for i in attacks:
        collisions = 0
        for j in attacks:
            if i != j and original[i]["power"] == original[j]["power"] and original[i]["element"] == original[j]["element"]:
                collisions += 1
        result[i]["power"] += min(collisions, 3)
    return result
