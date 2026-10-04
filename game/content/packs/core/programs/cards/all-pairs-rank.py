def all_pairs_rank(bolts, battle):
    # All pairs: every bolt is compared with every other bolt, n x n comparisons. A bolt's rank is how many bolts are
    # strictly weaker than it, and that rank is added to its power. (Sorting would find the same ranks in O(n log n).)
    out = []
    for bolt in bolts:
        weaker = 0
        for other in bolts:
            if other["power"] < bolt["power"]:
                weaker += 1
        out.append(dict(bolt, power=bolt["power"] + weaker))
    return out
