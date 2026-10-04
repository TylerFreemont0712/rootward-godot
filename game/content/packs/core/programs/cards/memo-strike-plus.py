def memo_strike_plus(bolts, battle):
    # Earlier hits are a cached answer: reuse the most familiar target.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    target = max(range(len(foes)), key=lambda i: foes[i].get("hits", 0))
    bonus = min(6, max(0, foes[target].get("hits", 0)))
    return [dict(bolt, power=bolt["power"] + bonus, foe=target) for bolt in bolts]
