def reverse_plus(bolts, battle):
    # In place: two pointers swap the ends and walk inward. O(n) time, no second list.
    i, j = 0, len(bolts) - 1
    while i < j:
        bolts[i], bolts[j] = bolts[j], bolts[i]
        i += 1
        j -= 1
    return bolts
