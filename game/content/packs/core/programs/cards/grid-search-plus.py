def grid_search_plus(bolts, battle):
    # Grid search: try every cell of a 5 x 5 grid, one loop inside another. Cell (i, j) becomes a bolt of power
    # i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
    out = [dict(bolt) for bolt in bolts]
    for i in range(5):
        for j in range(5):
            out.append({"power": i * j // 2 + 1, "element": "none"})
    return out
