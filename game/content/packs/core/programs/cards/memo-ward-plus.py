def memo_ward_plus(bolts, battle):
    # Remember the best answer so far: the table holds what every program landed this fight, and the ward is as large
    # as the biggest row, never below 6.
    best = max(battle.get("dp", []), default=0)
    return bolts + [{"power": max(6, best), "element": "none", "block": True}]
