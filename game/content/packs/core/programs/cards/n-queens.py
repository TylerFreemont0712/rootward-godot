def n_queens(bolts, battle):
    # N-Queens by backtracking: a queen on every row of an 6 x 6 board, none sharing a column or a diagonal. The
    # squares each queen attacks are bitmasks, so a branch that has no free square is never walked: it is pruned.
    size = 6
    full = (1 << size) - 1
    solutions = 0
    def place(cols, left, right, row):
        nonlocal solutions
        if row == size:
            solutions += 1
            return
        free = full & ~(cols | left | right)
        while free:
            bit = free & -free
            free ^= bit
            place(cols | bit, ((left | bit) << 1) & full, (right | bit) >> 1, row + 1)
    place(0, 0, 0, 0)
    return [dict(bolt) for bolt in bolts] + [{"power": 7, "element": "none"} for _ in range(solutions)]
