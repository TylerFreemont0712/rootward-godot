def counting_inversions(bolts, battle):
    # Counting inversions with merge sort. When two sorted halves merge, a right bolt that jumps ahead of the left
    # bolts still waiting is weaker than every one of them: that many stronger bolts stood before it.
    # Each bolt gains its count and the volley keeps its order. O(n log n), not the O(n^2) of comparing every pair.
    gain = [0] * len(bolts)

    def sort(places):
        if len(places) <= 1:
            return places
        middle = len(places) // 2
        left, right = sort(places[:middle]), sort(places[middle:])
        merged, i, j = [], 0, 0
        while i < len(left) or j < len(right):
            if j == len(right) or (i < len(left) and bolts[left[i]]["power"] <= bolts[right[j]]["power"]):
                merged.append(left[i])
                i += 1
            else:
                gain[right[j]] += len(left) - i
                merged.append(right[j])
                j += 1
        return merged

    sort(list(range(len(bolts))))
    return [dict(bolt, power=bolt["power"] + gain[i]) for i, bolt in enumerate(bolts)]
