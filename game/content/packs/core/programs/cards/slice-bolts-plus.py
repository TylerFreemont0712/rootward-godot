def slice_bolts_plus(bolts, battle):
    # bolts[:4] is a slice: a new list of the first four items, whatever the length (a short list gives them all).
    return [dict(bolt, power=bolt["power"] + 3) for bolt in bolts[:4]]
