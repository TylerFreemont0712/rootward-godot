def count_sacks(sacks):
    counts = {}
    for name in sacks:
        counts[name] = counts.get(name, 0) + 1
    return counts
