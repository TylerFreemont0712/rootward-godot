def tabulate_plus(bolts, battle):
    # The "house robber" table, bottom up: best(i) = max(best(i-1), best(i-2) + power(i)). Each bolt becomes
    # best(i). Two variables carry the table, one pass: O(n). The table never shrinks, so the volley comes out sorted.
    out = []
    before, best = 0, 0
    for bolt in bolts:
        take = before + bolt["power"]
        before, best = best, max(best, take)
        out.append(dict(bolt, power=best + 1))
    return out
