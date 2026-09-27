def hash_aim(bolts, battle):
    # One pass over the foes builds a dict (element -> the first foe weak to it); each bolt then looks its target up
    # in O(1). O(n + m), where scanning every foe for every bolt would be O(n·m).
    weak_to = {}
    for i, foe in enumerate(battle["foes"]):
        for element in foe["weak"]:
            if element not in weak_to:
                weak_to[element] = i
    return [dict(bolt, foe=weak_to.get(bolt["element"], 0)) for bolt in bolts]
