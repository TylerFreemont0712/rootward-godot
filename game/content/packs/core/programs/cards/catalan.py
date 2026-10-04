def catalan(bolts, battle):
    # Bottom up: catalan[m] = sum of catalan[i] * catalan[m - 1 - i], built from catalan[0] = 1 to the turn's number
    # (1, 2, 5, 14, 42). The table stops at 5, so the bolt is never larger than 42.
    n = min(max(battle.get("turn", 1), 0), 5)
    catalan = [1]
    for m in range(1, n + 1):
        total = 0
        for i in range(m):
            total += catalan[i] * catalan[m - 1 - i]
        catalan.append(total)
    return bolts + [{"power": catalan[n], "element": "none"}]
