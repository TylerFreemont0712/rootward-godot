def merge_sort(bolts, battle):
    # Split in half, sort each half the same way, then merge the two sorted halves.
    if len(bolts) <= 1:
        return bolts
    middle = len(bolts) // 2
    left = merge_sort(bolts[:middle], battle)
    right = merge_sort(bolts[middle:], battle)
    merged, i, j = [], 0, 0
    while i < len(left) and j < len(right):
        if left[i]["power"] <= right[j]["power"]:
            merged.append(left[i])
            i += 1
        else:
            merged.append(right[j])
            j += 1
    return merged + left[i:] + right[j:]
