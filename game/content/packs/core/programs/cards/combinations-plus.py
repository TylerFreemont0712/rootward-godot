def combinations_plus(bolts, battle):
    # Combinations: choose 3 of the first 7 bolts, in every way, order ignored (7 choose 3 = 35). Each trio becomes
    # one bolt of half its sum, with its strongest bolt's element. The rest of the volley follows.
    head, rest = bolts[:7], bolts[7:]
    if len(head) < 3:
        return bolts
    out = []
    for a in range(len(head)):
        for b in range(a + 1, len(head)):
            for c in range(b + 1, len(head)):
                strongest = head[a]
                for bolt in (head[b], head[c]):
                    if bolt["power"] > strongest["power"]:
                        strongest = bolt
                total = head[a]["power"] + head[b]["power"] + head[c]["power"]
                out.append({"power": total // 2 + 1, "element": strongest["element"]})
    return out + [dict(bolt) for bolt in rest]
