def task_scheduler_plus(bolts, battle):
    # Task scheduling with a cooldown of one: always take the element with the most bolts left that is not the one
    # just used. Only a spacer inserted when no task is eligible is marked idle for Handoff Ward.
    names, rows = [], []
    for bolt in bolts:
        if bolt["element"] not in names:
            names.append(bolt["element"])
            rows.append([])
        rows[names.index(bolt["element"])].append(bolt)
    used = [0] * len(names)
    result, last, left = [], -1, len(bolts)
    while left > 0:
        pick = -1
        for k in range(len(names)):
            if k != last and used[k] < len(rows[k]):
                if pick < 0 or len(rows[k]) - used[k] > len(rows[pick]) - used[pick]:
                    pick = k
        if pick < 0:
            result.append({"power": 2, "element": "none", "idle": True})
            last = -1
            continue
        result.append(dict(rows[pick][used[pick]]))
        used[pick] += 1
        left -= 1
        last = pick
    return result
