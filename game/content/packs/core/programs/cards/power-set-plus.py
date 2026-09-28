def power_set_plus(bolts, battle):
    # Every subset of the first four bolts is a bitmask: bit i set means bolt i is in it. Masks 1 to 2^4 - 1 are the
    # fifteen non-empty subsets; each becomes a bolt of its sum, with its strongest bolt's element.
    head, rest = bolts[:4], bolts[4:]
    out = []
    for mask in range(1, 1 << len(head)):
        chosen = [head[i] for i in range(len(head)) if mask >> i & 1]
        strongest = chosen[0]
        for bolt in chosen:
            if bolt["power"] > strongest["power"]:
                strongest = bolt
        out.append({"power": sum(bolt["power"] for bolt in chosen), "element": strongest["element"]})
    return out + rest
