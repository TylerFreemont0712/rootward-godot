DP_SUM_LIMIT = 1024


def _best_lethal_subset(bolts, candidates, need):
    items = [i for i in candidates if bolts[i].get("power", 0) > 0]
    total_power = sum(bolts[i]["power"] for i in items)
    if total_power < need:
        return None, -1

    max_power = max(bolts[i]["power"] for i in items)
    # A minimum lethal subset crosses `need` on its last bolt, so it is below need + max bolt power.
    limit = min(total_power, need + max_power - 1, DP_SUM_LIMIT)
    if need <= limit:
        # Each target updates and saves at most 17 64-bit words per bolt; backtracking adds one step per bolt.
        reachable = 1
        mask = (1 << (limit + 1)) - 1
        history = [reachable]
        for i in items:
            power = bolts[i]["power"]
            if power <= limit:
                reachable = (reachable | (reachable << power)) & mask
            history.append(reachable)

        above_need = reachable >> need
        if above_need:
            chosen_total = need + ((above_need & -above_need).bit_length() - 1)
            chosen = set()
            remaining = chosen_total
            for position in range(len(items) - 1, -1, -1):
                if (history[position] >> remaining) & 1:
                    continue
                i = items[position]
                chosen.add(i)
                remaining -= bolts[i]["power"]
            return chosen, chosen_total

    # The target or its minimum lethal sum is beyond the bounded table: take strongest bolts first deterministically.
    chosen, chosen_total = set(), 0
    for i in sorted(items, key=lambda index: (-bolts[index]["power"], index)):
        chosen.add(i)
        chosen_total += bolts[i]["power"]
        if chosen_total >= need:
            return chosen, chosen_total
    return None, -1


def coin_change_plus(bolts, battle):
    # Search the first two foes. Each bounded bitset prefers exact then least-lethal sums through 1,024; larger ranges
    # use strongest-first greedy. Leftovers become block only for an exact kill and only against surviving attack intent.
    foes = battle.get("foes", [])
    if not foes:
        return [dict(bolt) for bolt in bolts]
    candidates = [i for i, bolt in enumerate(bolts) if not bolt.get("block") and not bolt.get("stash")]
    available = list(candidates)
    assigned = {}
    resolved_targets = set()
    unresolved_target = None
    exact_kill = False

    for target in range(min(2, len(foes))):
        need = max(0, foes[target].get("hp", 0) + foes[target].get("shield", 0))
        if need <= 0:
            resolved_targets.add(target)
            continue
        chosen, chosen_total = _best_lethal_subset(bolts, available, need)
        if chosen is None:
            unresolved_target = target
            break

        for i in chosen:
            assigned[i] = target
        available = [i for i in available if i not in chosen]
        resolved_targets.add(target)
        if chosen_total == need:
            exact_kill = True

    warded = set()
    if exact_kill:
        threat = max(
            (
                foe.get("intent", {}).get("damage", 0) * foe.get("intent", {}).get("hits", 1)
                for index, foe in enumerate(foes)
                if index not in resolved_targets and foe.get("intent", {}).get("kind", "attack") == "attack"
            ),
            default=0,
        )
        have = battle.get("me", {}).get("block", 0)
        have += sum(bolt.get("power", 0) for bolt in bolts if bolt.get("block"))
        room = max(0, threat - have)
        for i in sorted((i for i in available if bolts[i].get("power", 0) > 0), key=lambda i: (bolts[i]["power"], i)):
            power = bolts[i]["power"]
            if power <= room:
                warded.add(i)
                room -= power

    rest_target = min(2, len(foes) - 1) if unresolved_target is None else unresolved_target
    result = []
    for i, bolt in enumerate(bolts):
        copy = dict(bolt)
        if i in assigned:
            copy["foe"] = assigned[i]
        elif i in warded:
            copy["block"] = True
        elif i in candidates:
            copy["foe"] = rest_target
        result.append(copy)
    return result
