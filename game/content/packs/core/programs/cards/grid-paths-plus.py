def grid_paths_plus(bolts, battle):
    # Paths across a 5 x 5 grid: each corner is reached from the square above or the one on its left, so
    # paths(r, c) = paths(r - 1, c) + paths(r, c - 1). Naive recursion solves the same square again and again
    # (exponential). With functools.cache in force every square is solved once and then looked up.
    def paths(r, c):
        if r == 0 or c == 0:
            return 1
        total = 0
        for dr, dc in ((1, 0), (0, 1)):
            total += paths(r - dr, c - dc)
        return total

    if "functools" in battle.get("imports", []):
        import functools

        paths = functools.cache(paths)
    return bolts + [{"power": paths(5, 5) // 10, "element": "none"}]
