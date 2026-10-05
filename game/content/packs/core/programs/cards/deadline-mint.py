def deadline_mint(bolts, battle):
    # Pick the lowest-tempo attack. On a tempo tie, prefer more total damage; exact ties keep the first foe.
    result = [dict(bolt) for bolt in bolts]
    best = None
    for i, foe in enumerate(battle.get("foes", [])):
        intent = foe.get("intent", {})
        damage = intent.get("damage", 0)
        hits = intent.get("hits", 0)
        if foe.get("hp", 0) <= 0 or intent.get("kind") != "attack" or damage <= 0 or hits <= 0:
            continue
        total = damage * hits
        tempo = intent.get("tempo", 0)
        if best is None or tempo < best[0] or (tempo == best[0] and total > best[1]):
            best = (tempo, total, i)

    if best is not None and len(result) < 128:
        result.append({"power": min(best[1], 8), "element": "none", "foe": best[2]})
    return result
