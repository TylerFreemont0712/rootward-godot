def monte_carlo(bolts, battle):
    # A Monte Carlo method answers with random samples. The seed comes from the turn and the bolts, so the same
    # volley always rolls the same dice: what the preview shows is what the cast does.
    seed = battle.get("turn", 1)
    for bolt in bolts:
        seed = (seed * 31 + bolt["power"]) & 0xFFFFFFFF
    rolls = []
    for _ in range(8):
        seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
        rolls.append({"power": (seed >> 16) % 6 + 1, "element": "none"})
    return bolts + rolls
