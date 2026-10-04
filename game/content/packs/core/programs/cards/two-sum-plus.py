def two_sum_plus(bolts, battle):
    # Remember each complement once, so a pair is found in one pass without reusing a bolt.
    pool, result = list(bolts), []
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    for target in range(min(2, len(foes))):
        seen, pair = {}, None
        need = foes[target]["hp"] + foes[target].get("shield", 0)
        for i, bolt in enumerate(pool):
            other = seen.get(need - bolt["power"])
            if other is not None:
                pair = (other, i)
                break
            if bolt["power"] not in seen:
                seen[bolt["power"]] = i
        if pair is not None:
            a, b = pair
            result.append(dict(pool[a], power=need, foe=target))
            pool = [bolt for i, bolt in enumerate(pool) if i != a and i != b]
        else:
            strongest = []
            for i in range(len(pool)):
                strongest.append(i)
                strongest.sort(key=lambda j: -pool[j]["power"])
                strongest = strongest[:2]
            result.extend(dict(pool[i], foe=target) for i in strongest)
            pool = [bolt for i, bolt in enumerate(pool) if i not in strongest]
    return result + pool
