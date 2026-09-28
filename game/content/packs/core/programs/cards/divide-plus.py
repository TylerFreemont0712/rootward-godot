def divide_plus(bolts, battle):
    # Recursion: split the volley in half and divide each half. Every level of the split adds 2 to every bolt
    # below it (3 with `import math`), so each bolt ends up about log2(n) stronger. O(n log n): every level touches
    # every bolt.
    step = 3 if "math" in battle.get("imports", []) else 2
    if len(bolts) <= 1:
        return [dict(bolt) for bolt in bolts]
    middle = len(bolts) // 2
    halves = divide_plus(bolts[:middle], battle) + divide_plus(bolts[middle:], battle)
    return [dict(bolt, power=bolt["power"] + step) for bolt in halves]
