def pop_bolt_plus(bolts, battle):
    # list.pop() removes and returns the last item in O(1). A lone bolt has no first one to give its power to.
    result = [dict(bolt) for bolt in bolts]
    if len(result) < 2:
        return result
    last = result.pop()
    result[0]["power"] += last["power"] + 1
    return result
