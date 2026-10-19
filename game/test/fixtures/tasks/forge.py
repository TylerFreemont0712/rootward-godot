def forge(materials):
    materials = sorted(materials)
    if materials == ["iron", "wood"]:
        return "hammer"
    if materials == ["iron", "iron"]:
        return "gear"
    if materials == ["wood", "wood"]:
        return "stick"
    return "nothing"
