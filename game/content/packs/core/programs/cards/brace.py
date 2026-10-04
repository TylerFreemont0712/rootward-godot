def brace(bolts, battle):
    # Greedy covering, smallest first: turn the weakest bolts into block, one by one, until the block covers what is
    # coming (the biggest intent). The bolts that matter least are sacrificed. Block you already have counts.
    threats = [foe.get("intent", {}).get("damage", 0) * foe.get("intent", {}).get("hits", 1) for foe in battle.get("foes", [])]
    goal = max(threats, default=0)
    have = battle.get("me", {}).get("block", 0) + sum(bolt["power"] for bolt in bolts if bolt.get("block"))
    result = [dict(bolt) for bolt in bolts]
    for i in sorted(range(len(bolts)), key=lambda i: bolts[i]["power"]):
        if have >= goal:
            break
        if bolts[i]["power"] > 0 and not bolts[i].get("block"):
            result[i]["block"] = True
            have += bolts[i]["power"]
    return result
