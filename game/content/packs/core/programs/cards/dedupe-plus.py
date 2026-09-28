def dedupe_plus(bolts, battle):
    # A set answers "seen before?" in O(1), so one pass removes every repeat. Each survivor gains 3.
    seen = set()
    out = []
    for bolt in bolts:
        if bolt["power"] not in seen:
            seen.add(bolt["power"])
            out.append(dict(bolt, power=bolt["power"] + 3))
    return out
