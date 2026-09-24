def lazy_fork(bolts, battle):
    split = []
    for i in range(len(bolts) - 1):
        split.append({**bolts[i], "power": bolts[i]["power"] * 0.6})
        split.append({**bolts[i], "power": bolts[i]["power"] * 0.6})
    return split
