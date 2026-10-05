def radix_sort(bolts, battle):
    # Four stable hexadecimal passes cover every power from 0 through the game's 9,999 cap.
    result = [dict(bolt) for bolt in bolts]
    for shift in (0, 4, 8, 12):
        buckets = [[] for _ in range(16)]
        for bolt in result:
            buckets[(bolt["power"] >> shift) & 15].append(bolt)
        result = [bolt for bucket in buckets for bolt in bucket]
    return result
