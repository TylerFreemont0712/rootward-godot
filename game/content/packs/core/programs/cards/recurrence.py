def recurrence(bolts, battle):
    # Read the two preceding rows instead of recursively recomputing the recurrence.
    rows = battle.get("dp", [])
    if battle.get("turn", 1) < 2 or not rows:
        return bolts
    total = rows[-1] + (rows[-2] if len(rows) > 1 else 0)
    power = total // 2
    return bolts + [{"power": power, "element": "none"}]
