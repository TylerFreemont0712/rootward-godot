def amplify(bolts, battle):
    # One pass over the volley: every bolt gains 3 power.
    return [dict(bolt, power=bolt["power"] + 3) for bolt in bolts]
