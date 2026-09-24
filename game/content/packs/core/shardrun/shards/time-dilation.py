def time_dilation(bolts, battle):
    bonus = min(25, battle["turn"] ** 2)
    return [{**b, "mult": b["mult"] + bonus} for b in bolts]
