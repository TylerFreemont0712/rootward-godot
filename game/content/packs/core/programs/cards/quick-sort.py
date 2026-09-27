def quick_sort(bolts, battle):
    # Pick the first bolt as the pivot, split the rest into weaker and not weaker, sort each side the same way.
    # About n log n on a shuffled volley; on one already sorted every split leaves one side empty: n².
    if len(bolts) <= 1:
        return bolts
    pivot, rest = bolts[0], bolts[1:]
    weaker = [bolt for bolt in rest if bolt["power"] < pivot["power"]]
    stronger = [bolt for bolt in rest if bolt["power"] >= pivot["power"]]
    return quick_sort(weaker, battle) + [pivot] + quick_sort(stronger, battle)
