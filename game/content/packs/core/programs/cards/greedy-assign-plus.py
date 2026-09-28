def greedy_assign_plus(bolts, battle):
    # Greedy: strongest bolts first, weakest foes first; keep adding bolts to a foe until they would kill it, then
    # move on. Fast and usually good, not always optimal. The sort makes it O(n log n).
    foes = battle["foes"]
    if not foes:
        return bolts
    strongest = sorted(bolts, key=lambda bolt: -bolt["power"])
    order = sorted(range(len(foes)), key=lambda i: foes[i]["hp"] + foes[i]["shield"])
    out = []
    k = 0
    for i in order:
        need = foes[i]["hp"] + foes[i]["shield"]
        while need > 0 and k < len(strongest):
            out.append(dict(strongest[k], foe=i, power=strongest[k]["power"] + 1))
            need -= strongest[k]["power"]
            k += 1
    for bolt in strongest[k:]:
        out.append(dict(bolt, foe=order[-1], power=bolt["power"] + 1))
    return out
