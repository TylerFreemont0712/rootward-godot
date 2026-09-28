def divide(bolts, battle):
    # Recursion: split the volley in half and divide each half. Every level of the split adds 1 to every bolt
    # below it (2 with `import math`), so each bolt ends up about log2(n) stronger. O(n log n): every level touches
    # every bolt.
    step = 2 if "math" in battle.get("imports", []) else 1
    if len(bolts) <= 1:
        return [dict(bolt) for bolt in bolts]
    middle = len(bolts) // 2
    halves = divide(bolts[:middle], battle) + divide(bolts[middle:], battle)
    return [dict(bolt, power=bolt["power"] + step) for bolt in halves]
