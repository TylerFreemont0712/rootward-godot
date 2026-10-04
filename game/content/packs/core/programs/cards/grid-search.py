def grid_search(bolts, battle):
    # Grid search: try every cell of a 4 x 4 grid, one loop inside another. Cell (i, j) becomes a bolt of power
    # i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
    out = [dict(bolt) for bolt in bolts]
    for i in range(4):
        for j in range(4):
            out.append({"power": i * j // 2 + 1, "element": "none"})
    return out
