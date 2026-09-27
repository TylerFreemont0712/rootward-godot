def bubble_sort(bolts, battle):
    # Repeated passes, each swapping neighbours that are out of order; after pass k the k strongest are in place.
    # A pass with no swap means the volley is sorted, and it stops early.
    out = list(bolts)
    for end in range(len(out) - 1, 0, -1):
        swapped = False
        for i in range(end):
            if out[i]["power"] > out[i + 1]["power"]:
                out[i], out[i + 1] = out[i + 1], out[i]
                swapped = True
        if not swapped:
            break
    return out
