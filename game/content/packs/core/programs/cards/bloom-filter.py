def bloom_filter(bolts, battle):
    # A Bloom filter: each weak element sets two bits of a small array, and a bolt "might" match when both of its bits are set.
    # It never misses a real match, but a false positive can slip through: here the turn picks one bolt that gains the bonus wrongly.
    def bloom_hash(element, seed):
        h = seed
        for ch in element:
            h = (h * 31 + ord(ch)) % 32
        return h

    bits = [False] * 32
    marked = False
    for foe in battle.get("foes", []):
        for element in foe.get("weak", []):
            bits[bloom_hash(element, 3)] = True
            bits[bloom_hash(element, 7)] = True
            marked = True
    if not marked or not bolts:
        return bolts
    might = []
    for bolt in bolts:
        might.append(bits[bloom_hash(bolt["element"], 3)] and bits[bloom_hash(bolt["element"], 7)])
    start = (battle.get("turn", 1) * 7 + 3) % len(bolts)
    for step in range(len(bolts)):
        slot = (start + step) % len(bolts)
        if not might[slot]:
            might[slot] = True
            break
    result = []
    for i, bolt in enumerate(bolts):
        if might[i]:
            result.append(dict(bolt, power=bolt["power"] + 2))
        else:
            result.append(dict(bolt))
    return result
