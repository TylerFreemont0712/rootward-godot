def lcs_plus(bolts, battle):
    # Longest common subsequence of this volley's powers and the last program's landed volley (the diff behind
    # `git diff`). table[i][j] is the LCS length of the first i bolts and the first j landed powers; walking it back
    # from the corner finds which bolts matched. Ward bolts are not attacks, so they are left out.
    last = battle.get("last_volley", [])
    mine = [i for i, bolt in enumerate(bolts) if not bolt.get("block")]
    if not mine or not last:
        return list(bolts)
    table = [[0] * (len(last) + 1) for _ in range(len(mine) + 1)]
    for i in range(1, len(mine) + 1):
        for j in range(1, len(last) + 1):
            if bolts[mine[i - 1]]["power"] == last[j - 1]:
                table[i][j] = table[i - 1][j - 1] + 1
            else:
                table[i][j] = max(table[i - 1][j], table[i][j - 1])
    matched, i, j = set(), len(mine), len(last)
    while i > 0 and j > 0:
        if bolts[mine[i - 1]]["power"] == last[j - 1]:
            matched.add(mine[i - 1])
            i -= 1
            j -= 1
        elif table[i - 1][j] >= table[i][j - 1]:
            i -= 1
        else:
            j -= 1
    return [dict(bolt, power=bolt["power"] + 3) if k in matched else dict(bolt) for k, bolt in enumerate(bolts)]
