def pascal_row_plus(bolts, battle):
    # A table built from smaller answers: each row comes from the one above, every entry the sum of the two over it.
    row = [1]
    for _ in range(6):
        row = [1] + [row[i] + row[i + 1] for i in range(len(row) - 1)] + [1]
    return bolts + [{"power": value, "element": "none"} for value in row]
