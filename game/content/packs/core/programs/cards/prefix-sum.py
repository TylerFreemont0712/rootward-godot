def prefix_sum(bolts, battle):
    # Running totals: each bolt carries the sum of every bolt up to and including it.
    total = 0
    out = []
    for bolt in bolts:
        total += bolt["power"]
        out.append(dict(bolt, power=total))
    return out
