def pairwise_plus(bolts, battle):
    # Two nested loops over the volley: every pair (i, j) with i < j fuses. n(n-1)/2 new bolts, O(n^2) work.
    # A single bolt has no pair, so it makes nothing.
    out = []
    for i in range(len(bolts)):
        for j in range(i + 1, len(bolts)):
            a, b = bolts[i], bolts[j]
            power = a["power"] + b["power"]
            if a["element"] != b["element"]:
                power = power * 2
            stronger = a if a["power"] >= b["power"] else b
            out.append({"power": power, "element": stronger["element"]})
    return out
