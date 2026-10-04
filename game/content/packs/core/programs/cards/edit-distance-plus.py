def edit_distance_plus(bolts, battle):
    # Edit distance between two sorted sequences: the bolts' powers and the foes' HP. table[i][j] is the fewest edits
    # (swap one value for another, drop a bolt, drop a foe) turning the first i bolts into the first j foes. Walking
    # it back pairs bolts with foes in order; a paired bolt flies at its foe. A bolt with no foe to pair with becomes block instead.
    foes = battle.get("foes", [])
    if not foes:
        return list(bolts)
    mine = sorted((i for i, bolt in enumerate(bolts) if not bolt.get("block")), key=lambda i: (bolts[i]["power"], i))
    need = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    order = sorted(range(len(foes)), key=lambda j: (need[j], j))
    n, m = len(mine), len(order)
    table = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        table[i][0] = i
    for j in range(1, m + 1):
        table[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            swap = 0 if bolts[mine[i - 1]]["power"] == need[order[j - 1]] else 1
            table[i][j] = min(table[i - 1][j - 1] + swap, table[i - 1][j] + 1, table[i][j - 1] + 1)
    aim, i, j = {}, n, m
    while i > 0 and j > 0:
        swap = 0 if bolts[mine[i - 1]]["power"] == need[order[j - 1]] else 1
        if table[i][j] == table[i - 1][j - 1] + swap:
            aim[mine[i - 1]] = order[j - 1]
            i -= 1
            j -= 1
        elif table[i][j] == table[i - 1][j] + 1:
            i -= 1
        else:
            j -= 1
    result = []
    for k, bolt in enumerate(bolts):
        if bolt.get("block"):
            result.append(dict(bolt))
        elif k in aim:
            result.append(dict(bolt, foe=aim[k]))
        else:
            result.append(dict(bolt, block=True))
    return result
