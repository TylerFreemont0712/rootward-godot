def selection_sort_plus(bolts, battle):
    # Selection sort: scan the unsorted suffix for its weakest bolt, swap it to the front, then repeat. It scans the
    # whole suffix every time, so even an already sorted volley takes quadratic work.
    out = [dict(bolt) for bolt in bolts]
    for start in range(len(out) - 1):
        pick = start
        for i in range(start + 1, len(out)):
            if out[i]["power"] < out[pick]["power"]:
                pick = i
        out[start], out[pick] = out[pick], out[start]
    return out
