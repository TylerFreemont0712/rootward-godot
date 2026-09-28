def quick_sort_plus(bolts, battle):
    # The pivot is the median of the first, middle and last bolts, so a sorted volley splits in half too:
    # n log n on any input. Split the rest into weaker and not weaker, sort each side the same way.
    if len(bolts) <= 1:
        return bolts
    ends = sorted([0, len(bolts) // 2, len(bolts) - 1], key=lambda i: bolts[i]["power"])
    middle = ends[1]
    pivot, rest = bolts[middle], bolts[:middle] + bolts[middle + 1:]
    weaker = [bolt for bolt in rest if bolt["power"] < pivot["power"]]
    stronger = [bolt for bolt in rest if bolt["power"] >= pivot["power"]]
    return quick_sort_plus(weaker, battle) + [pivot] + quick_sort_plus(stronger, battle)
