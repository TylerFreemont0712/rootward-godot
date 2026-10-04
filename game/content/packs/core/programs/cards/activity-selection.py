def activity_selection(bolts, battle):
    # Earliest deadline first: finish one foe before spending bolts on the next.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    order = sorted(range(len(foes)), key=lambda i: (foes[i].get("intent", {}).get("tempo", 0), 0))
    remaining = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    result, current = [], 0
    for bolt in sorted(bolts, key=lambda bolt: -bolt["power"]):
        while current + 1 < len(order) and remaining[order[current]] <= 0:
            current += 1
        target = order[current]
        result.append(dict(bolt, foe=target))
        remaining[target] -= bolt["power"]
    return result
