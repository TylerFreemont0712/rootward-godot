def closest_pair(bolts, battle):
    # Closest pair, divide and conquer, on a line of powers. Sort the bolts by power, split in half and find the closest
    # pair in each half; a closer pair that straddles the cut must lie within that gap of it (the strip), and in the
    # strip each bolt needs comparing only with the few after it. A pair is (gap, first place, second place), and the
    # smallest wins, so ties go to the pair nearest the front. The two fuse into one bolt of double their total.
    def pair_of(a, b):
        return (abs(a[0] - b[0]), min(a[1], b[1]), max(a[1], b[1]))

    def closest(items):  # items are (power, place), sorted
        if len(items) <= 3:
            best = None
            for a in range(len(items)):
                for b in range(a + 1, len(items)):
                    pair = pair_of(items[a], items[b])
                    if best is None or pair < best:
                        best = pair
            return best
        middle = len(items) // 2
        best = min(closest(items[:middle]), closest(items[middle:]))
        cut = items[middle][0]
        strip = [item for item in items if abs(item[0] - cut) <= best[0]]
        for a in range(len(strip)):
            for b in range(a + 1, len(strip)):
                if strip[b][0] - strip[a][0] > best[0]:
                    break
                best = min(best, pair_of(strip[a], strip[b]))
        return best

    items = sorted((bolt["power"], i) for i, bolt in enumerate(bolts))
    if len(items) < 2:
        return bolts
    pairs = [closest(items)]
    second = {pair[1]: pair[2] for pair in pairs}
    gone = set(second.values())
    out = []
    for i, bolt in enumerate(bolts):
        if i in gone:
            continue
        if i in second:
            other = bolts[second[i]]
            stronger = other if other["power"] > bolt["power"] else bolt
            out.append(dict(stronger, power=2 * (bolt["power"] + other["power"])))
        else:
            out.append(bolt)
    return out
