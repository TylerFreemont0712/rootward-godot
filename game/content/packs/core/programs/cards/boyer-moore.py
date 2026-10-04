def boyer_moore(bolts, battle):
    # Boyer-Moore majority vote: one pass and one counter find the only element that could hold more than half the
    # volley, without counting each element. A second pass confirms it. If one does, every bolt becomes that element.
    candidate, count = None, 0
    for bolt in bolts:
        if count == 0:
            candidate, count = bolt["element"], 1
        elif bolt["element"] == candidate:
            count += 1
        else:
            count -= 1
    votes = 0
    for bolt in bolts:
        if bolt["element"] == candidate:
            votes += 1
    if votes * 2 <= len(bolts):
        return bolts
    return [dict(bolt, element=candidate, power=bolt["power"] + 1) for bolt in bolts]
