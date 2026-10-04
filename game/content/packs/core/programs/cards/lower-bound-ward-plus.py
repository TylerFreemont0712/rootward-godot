def lower_bound_ward_plus(bolts, battle):
    # bisect_left on the sorted index: the smallest banked bolt that still covers the biggest incoming attack becomes block.
    # Exact defence: no bigger ward than the attack needs. The attack is damage times hits.
    index = battle.get("index", [])
    threat = 0
    for foe in battle.get("foes", []):
        intent = foe.get("intent", {})
        threat = max(threat, intent.get("damage", 0) * intent.get("hits", 1))
    result = list(bolts)
    if threat > 0 and index:
        lo, hi = 0, len(index)
        while lo < hi:
            mid = (lo + hi) // 2
            if index[mid]["power"] < threat:
                lo = mid + 1
            else:
                hi = mid
        pick = min(lo, len(index) - 1)
        result.append(dict(index[pick], block=True, from_index=True))
    if threat > 0:
        result.append({"power": 2, "element": "none", "block": True})
    return result
