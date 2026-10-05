def threat_index(bolts, battle):
    # Intent checks stay in foe order; each bolt is used at most once, and any unmatched attacks remain attacks.
    result = [dict(bolt) for bolt in bolts]
    used = set()
    checked = 0
    for foe in battle.get("foes", []):
        intent = foe.get("intent", {})
        damage = intent.get("damage", 0) * intent.get("hits", 1)
        if intent.get("kind") != "attack" or damage <= 0:
            continue
        checked += 1
        if checked > 3:
            break
        left, right = 0, len(result)
        while left < right:
            middle = (left + right) // 2
            if result[middle]["power"] < damage:
                left = middle + 1
            else:
                right = middle
        while left < len(result):
            bolt = result[left]
            if left not in used and not bolt.get("block") and not bolt.get("stash"):
                bolt["block"] = True
                used.add(left)
                break
            left += 1
    return result
