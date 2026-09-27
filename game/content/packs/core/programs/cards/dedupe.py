def dedupe(bolts, battle):
    # A set answers "seen before?" in O(1), so one pass removes every repeat. Each survivor gains 2.
    seen = set()
    out = []
    for bolt in bolts:
        if bolt["power"] not in seen:
            seen.add(bolt["power"])
            out.append(dict(bolt, power=bolt["power"] + 2))
    return out
