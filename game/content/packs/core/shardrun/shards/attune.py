def attune(bolts, battle):
    if not bolts:
        return bolts
    best = max(bolt["mult"] for bolt in bolts)
    return [{**bolt, "mult": best} for bolt in bolts]
