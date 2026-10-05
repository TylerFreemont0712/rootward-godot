def parity_lattice(bolts, battle):
    # Count attacks only. Existing wards and stashed bolts remain in place and never change the every-third cadence.
    result = [dict(bolt) for bolt in bolts]
    attacks = 0
    gained = 0
    for bolt in result:
        if bolt.get("block", False) or bolt.get("stash", False):
            continue
        attacks += 1
        if attacks % 3 == 0:
            if gained + bolt["power"] > 12:
                break
            bolt["block"] = True
            gained += bolt["power"]
    return result
