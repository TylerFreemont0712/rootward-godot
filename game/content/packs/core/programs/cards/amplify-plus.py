def amplify_plus(bolts, battle):
    # One pass over the volley: every bolt gains 4 power.
    return [dict(bolt, power=bolt["power"] + 4) for bolt in bolts]
