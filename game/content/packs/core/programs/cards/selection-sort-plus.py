def selection_sort_plus(bolts, battle):
    # Selection sort: scan everything left for the weakest, swap it to the front, repeat. It scans the whole rest
    # every time, so a volley that is already sorted costs as much as a shuffled one (bubble sort stops early).
    out = [dict(bolt) for bolt in bolts]
    for start in range(len(out) - 1):
        pick = start
        for i in range(start + 1, len(out)):
            if out[i]["power"] > out[pick]["power"]:
                pick = i
        out[start], out[pick] = out[pick], out[start]
    return out
