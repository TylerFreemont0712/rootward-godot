def crosslink(bolts, battle):
    linked = []
    for bolt in bolts:
        kin = 0
        for other in bolts:
            if other is not bolt and other["element"] == bolt["element"]:
                kin += 1
        linked.append({**bolt, "mult": bolt["mult"] + kin})
    return linked
