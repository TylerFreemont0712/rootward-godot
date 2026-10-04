def range_source_plus(bolts, battle):
    # range(start, stop, step) counts from start in steps, stopping before stop: 2, 4, 6, 8 here.
    return bolts + [{"power": power, "element": "none"} for power in range(3, 15, 3)]
