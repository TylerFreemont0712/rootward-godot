def load_balance(bolts, battle):
    # Longest-processing-time scheduling: sort the jobs biggest first and give each to the machine with the most work
    # left. Here the work left is a foe's HP after the bolts already aimed at it.
    foes = battle["foes"]
    if not foes:
        return bolts
    left = [foe["hp"] + foe["shield"] for foe in foes]
    out = []
    for bolt in sorted(bolts, key=lambda bolt: -bolt["power"]):
        target = max(range(len(foes)), key=lambda i: left[i])
        left[target] -= bolt["power"]
        out.append(dict(bolt, foe=target))
    return out
