"""Concept-only Python sketches for v0.2 card ideas.

These functions are not registered in the game. They follow the Program card shape so design traces can be checked
without adding game content or changing the sandbox.
"""


def cold_cache(bolts, battle):
    """A no-op body; card metadata would discount the next successfully prepared Program cast by 1 mana."""
    return [dict(bolt) for bolt in bolts]


def parity_lattice(bolts, battle):
    """Ward every third attack bolt when its power fits under this card's 12-block ceiling."""
    already = int(battle.get("me", {}).get("block", 0))
    already += sum(int(bolt["power"]) for bolt in bolts if bolt.get("block"))
    room = max(0, 12 - already)
    attack_number = 0
    result = []
    for bolt in bolts:
        if bolt.get("block") or bolt.get("stash"):
            result.append(dict(bolt))
            continue
        attack_number += 1
        copy = dict(bolt)
        power = int(bolt["power"])
        if attack_number % 3 == 0 and 0 < power <= room:
            copy["block"] = True
            room -= power
        result.append(copy)
    return result


def collision_census(bolts, battle):
    """Give repeated attack bolts a small capped bonus; only the first 24 bolts are compared."""
    window = bolts[:24]
    result = []
    for i, bolt in enumerate(window):
        copy = dict(bolt)
        if bolt.get("block") or bolt.get("stash"):
            result.append(copy)
            continue
        matches = sum(
            1
            for j, other in enumerate(window)
            if i != j
            and not other.get("block")
            and not other.get("stash")
            and int(other["power"]) == int(bolt["power"])
            and other.get("element", "none") == bolt.get("element", "none")
        )
        copy["power"] = int(bolt["power"]) + min(3, matches)
        result.append(copy)
    result.extend(dict(bolt) for bolt in bolts[24:])
    return result


def deadline_mint(bolts, battle):
    """Add one capped bolt at the living foe with the earliest damaging attack intent."""
    living = [foe for foe in battle.get("foes", []) if int(foe.get("hp", 0)) > 0]
    candidates = []
    for index, foe in enumerate(living):
        intent = foe.get("intent", {})
        if intent.get("kind") != "attack":
            continue
        threat = max(0, int(intent.get("damage", 0)) * int(intent.get("hits", 1)))
        if threat > 0:
            candidates.append((int(intent.get("tempo", 10**9)), -threat, index, threat))
    if not candidates:
        return [dict(bolt) for bolt in bolts]
    _, _, target, threat = min(candidates)
    result = [dict(bolt) for bolt in bolts]
    result.append({"power": min(8, threat), "element": "none", "foe": target})
    return result


def radix_sort(bolts, battle):
    """Stable weakest-first radix sort for the game's 0..9999 bolt-power range."""
    result = [dict(bolt) for bolt in bolts]
    for shift in (0, 4, 8, 12):
        buckets = [[] for _ in range(16)]
        for bolt in result:
            digit = (int(bolt["power"]) >> shift) & 15
            buckets[digit].append(bolt)
        result = [bolt for bucket in buckets for bolt in bucket]
    return result


def boundary_guard(bolts, battle):
    """In each Recurse body, ward its weakest attack if at least two attacks are present."""
    result = [dict(bolt) for bolt in bolts]
    attacks = [i for i, bolt in enumerate(bolts) if not bolt.get("block") and not bolt.get("stash")]
    if len(attacks) < 2:
        return result
    weakest = min(attacks, key=lambda i: (int(bolts[i]["power"]), i))
    result[weakest]["block"] = True
    return result


def exact_prefix(bolts, battle):
    """Move an exact front-foe kill subset among the first 12 attacks to the front, if one exists."""
    living = [foe for foe in battle.get("foes", []) if int(foe.get("hp", 0)) > 0]
    if not living:
        return [dict(bolt) for bolt in bolts]
    need = int(living[0].get("hp", 0)) + int(living[0].get("shield", 0))
    candidates = [
        i
        for i, bolt in enumerate(bolts)
        if not bolt.get("block")
        and not bolt.get("stash")
        and int(bolt.get("foe", 0)) == 0
    ][:12]
    if need <= 0 or not candidates:
        return [dict(bolt) for bolt in bolts]
    paths = [None] * (need + 1)
    paths[0] = ()
    for index in candidates:
        power = int(bolts[index]["power"])
        if power <= 0 or power > need:
            continue
        for total in range(need, power - 1, -1):
            prior = paths[total - power]
            if prior is not None and paths[total] is None:
                paths[total] = prior + (index,)
    if paths[need] is None:
        return [dict(bolt) for bolt in bolts]
    selected = set(paths[need])
    return (
        [dict(bolt) for i, bolt in enumerate(bolts) if i in selected]
        + [dict(bolt) for i, bolt in enumerate(bolts) if i not in selected]
    )
