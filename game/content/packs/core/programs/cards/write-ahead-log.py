def write_ahead_log(bolts, battle):
    # Write-ahead logging: record the change before applying it. Every weak bolt (under 4 power) is logged into the index instead of flying.
    # A ward is a defence, not a weak attack, so it is left alone.
    result = []
    for bolt in bolts:
        if bolt["power"] < 4 and not bolt.get("block", False):
            result.append(dict(bolt, stash=True))
        else:
            result.append(dict(bolt))
    return result
