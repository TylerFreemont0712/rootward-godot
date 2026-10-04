def nearest_neighbour(bolts, battle):
    # The nearest-neighbour heuristic: each bolt flies at the foe whose HP is closest to its power. It looks
    # at one bolt at a time and never plans ahead, so it is fast, usually good, and sometimes silly.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    result = []
    for bolt in bolts:
        best, best_key = 0, None
        for j in range(len(foes)):
            hp = foes[j]["hp"] + foes[j].get("shield", 0)
            key = (0, abs(hp - bolt["power"]))
            if best_key is None or key < best_key:
                best, best_key = j, key
        result.append(dict(bolt, foe=best))
    return result
