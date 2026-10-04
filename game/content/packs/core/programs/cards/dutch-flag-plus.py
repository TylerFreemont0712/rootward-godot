def dutch_flag_plus(bolts, battle):
    # Dijkstra's three regions grow in place: exact, greater, then smaller than the pivot value.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    need = foes[0]["hp"] + foes[0].get("shield", 0)
    result = [dict(bolt) for bolt in bolts]
    low, scan, high = 0, 0, len(result) - 1
    while scan <= high:
        if result[scan]["power"] == need:
            result[low], result[scan] = result[scan], result[low]
            low += 1
            scan += 1
        elif result[scan]["power"] > need:
            scan += 1
        else:
            result[scan], result[high] = result[high], result[scan]
            high -= 1
    for i in range(low):
        result[i]["pivot"] = True
        result[i]["power"] += 1
    return result
