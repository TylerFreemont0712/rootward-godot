def run_length_plus(bolts, battle):
    out = []
    for bolt in bolts:
        same = out and all(out[-1].get(key, default) == bolt.get(key, default)
                           for key, default in (("element", "none"), ("foe", 0), ("block", False)))
        if same:
            out[-1]["power"] += bolt["power"] + 2
        else:
            out.append(dict(bolt))
    return out
