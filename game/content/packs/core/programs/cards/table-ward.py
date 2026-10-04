def table_ward(bolts, battle):
    # Read the table's last row (what the latest program landed) and turn a share of it into block, never below 3.
    rows = battle.get("dp", [])
    last = rows[-1] if rows else 0
    return bolts + [{"power": max(3, last // 3), "element": "none", "block": True}]
