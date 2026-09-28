def higher_order(bolts, battle):
    # A function that makes functions: map a small lambda over the volley now, and two more are written for later.
    step = lambda bolt: dict(bolt, power=bolt["power"] + 1)
    return list(map(step, bolts))
