import bisect


def import_bisect(bolts, battle):
    # Runs after every source card: each bolt goes into its sorted place (bisect.insort), weakest first.
    ordered = []
    for bolt in bolts:
        bisect.insort(ordered, bolt, key=lambda kept: kept["power"])
    return ordered
