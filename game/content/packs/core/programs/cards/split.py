def split(bolts, battle):
    # Divide until the base case: a bolt under 4 power is small enough; anything bigger splits into two halves, and
    # each half is divided the same way.
    def pieces(bolt):
        if bolt["power"] < 4:
            return [dict(bolt)]
        half = bolt["power"] // 2
        return pieces(dict(bolt, power=bolt["power"] - half)) + pieces(dict(bolt, power=half))

    out = []
    for bolt in bolts:
        out += pieces(bolt)
    return out
