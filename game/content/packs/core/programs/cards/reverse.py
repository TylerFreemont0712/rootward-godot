def reverse(bolts, battle):
    # Walk the volley from its last index down to 0: O(n).
    return [bolts[i] for i in range(len(bolts) - 1, -1, -1)]
