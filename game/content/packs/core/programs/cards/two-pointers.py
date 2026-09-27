def two_pointers(bolts, battle):
    # Two indexes, one from each end, walking toward each other: every step fuses the pair they point at. O(n).
    out = []
    i, j = 0, len(bolts) - 1
    while i < j:
        out.append(dict(bolts[j], power=bolts[i]["power"] + bolts[j]["power"]))
        i += 1
        j -= 1
    if i == j:
        out.append(dict(bolts[i]))
    return out
