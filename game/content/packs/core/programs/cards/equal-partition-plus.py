def equal_partition_plus(bolts, battle):
    # Exact 0/1 subset-sum finds the closest split through 1,024 total power. Above that, a deterministic
    # strongest-first greedy balance bounds work. The larger side attacks; the smaller can become block. Only an exact
    # split keeps the upgraded +40% bonus.
    pool = [i for i, bolt in enumerate(bolts) if bolt.get("power", 0) > 0 and not bolt.get("block") and not bolt.get("stash")]
    if len(pool) < 2:
        return [dict(bolt) for bolt in bolts]
    total = sum(bolts[i]["power"] for i in pool)
    smaller = set()
    if total <= 1024:
        target = total // 2

        # A bounded 64-bit bitset updates and saves at most nine words per bolt, plus one backtracking check; height 20
        # bills this bounded work through total power 1,024.
        reachable = 1
        mask = (1 << (target + 1)) - 1
        history = [reachable]
        for i in pool:
            power = bolts[i]["power"]
            reachable = (reachable | (reachable << power)) & mask
            history.append(reachable)

        smaller_total = reachable.bit_length() - 1
        if smaller_total <= 0:
            return [dict(bolt) for bolt in bolts]
        remaining = smaller_total
        for position in range(len(pool) - 1, -1, -1):
            i = pool[position]
            if (history[position] >> remaining) & 1:
                continue
            smaller.add(i)
            remaining -= bolts[i]["power"]
    else:
        # Above the exact-DP limit, process strongest-first and always place the next bolt on the lighter side.
        sides = [[], []]
        side_totals = [0, 0]
        for i in sorted(pool, key=lambda index: (-bolts[index]["power"], index)):
            side = 0 if side_totals[0] <= side_totals[1] else 1
            sides[side].append(i)
            side_totals[side] += bolts[i]["power"]
        smaller_side = 0 if side_totals[0] <= side_totals[1] else 1
        smaller.update(sides[smaller_side])
        smaller_total = side_totals[smaller_side]
    smaller_indices = [i for i in pool if i in smaller]
    larger_indices = [i for i in pool if i not in smaller]
    smaller_lead = max(smaller_indices, key=lambda i: bolts[i]["power"])
    larger_lead = max(larger_indices, key=lambda i: bolts[i]["power"])
    larger_total = total - smaller_total

    large_attack = dict(bolts[larger_lead], power=larger_total)
    small_attack = dict(bolts[smaller_lead], power=smaller_total)
    if smaller_total == larger_total:
        # Preserve the forge's stronger bonus on both sides of an exact split.
        large_attack["power"] = large_attack["power"] * 7 // 5
        small_attack["power"] = small_attack["power"] * 7 // 5
        result = [large_attack, small_attack]
    else:
        threat = max(
            (
                foe.get("intent", {}).get("damage", 0) * foe.get("intent", {}).get("hits", 1)
                for foe in battle.get("foes", [])
                if foe.get("intent", {}).get("kind", "attack") == "attack"
            ),
            default=0,
        )
        have = battle.get("me", {}).get("block", 0)
        have += sum(bolt.get("power", 0) for bolt in bolts if bolt.get("block"))
        block_power = min(smaller_total, max(0, threat - have))
        result = [large_attack]
        if block_power > 0:
            small_block = dict(bolts[smaller_lead], power=block_power, block=True)
            excess = smaller_total - block_power
            if excess > 0:
                # Keep residual offensive power in the large output without adding another bolt.
                large_attack["power"] += excess
            result = [large_attack, small_block]
        else:
            result.append(small_attack)

    pool_set = set(pool)
    result.extend(dict(bolt) for i, bolt in enumerate(bolts) if i not in pool_set)
    return result
