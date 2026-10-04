def sort_by_key_plus(bolts, battle):
    # sorted(key=...) compares the keys, here a tuple: element first (none, fire, frost, spark), then power.
    # The sort is stable: bolts with equal keys stay in the order they came in.
    elements = ["none", "fire", "frost", "spark"]
    def key(bolt):
        rank = elements.index(bolt["element"]) if bolt["element"] in elements else len(elements)
        return (rank, bolt["power"])
    return [dict(bolt) for bolt in sorted(bolts, key=key)]
