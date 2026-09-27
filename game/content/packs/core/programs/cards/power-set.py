def power_set(bolts, battle):
    # Every subset of the first three bolts is a bitmask: bit i set means bolt i is in it. Masks 1 to 2^3 - 1 are the
    # seven non-empty subsets; each becomes a bolt of its sum, with its strongest bolt's element.
    head, rest = bolts[:3], bolts[3:]
    out = []
    for mask in range(1, 1 << len(head)):
        chosen = [head[i] for i in range(len(head)) if mask >> i & 1]
        strongest = chosen[0]
        for bolt in chosen:
            if bolt["power"] > strongest["power"]:
                strongest = bolt
        out.append({"power": sum(bolt["power"] for bolt in chosen), "element": strongest["element"]})
    return out + rest
