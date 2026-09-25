def divide(bolts, battle):
    # Recursion: split the volley in half and divide each half. Every level of the split adds 1 to every bolt
    # below it, so each bolt ends up about log2(n) stronger. O(n log n): every level touches every bolt.
    if len(bolts) <= 1:
        return [dict(bolt) for bolt in bolts]
    middle = len(bolts) // 2
    halves = divide(bolts[:middle], battle) + divide(bolts[middle:], battle)
    return [dict(bolt, power=bolt["power"] + 1) for bolt in halves]
