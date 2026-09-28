def release(bolts, battle):
    # Half of what the fight's programs have landed so far, as one bolt. `global total` keeps the count.
    half = battle.get("globals", {}).get("total", 0) // 2
    if half <= 0:
        return bolts
    return bolts + [{"power": half, "element": "none"}]
