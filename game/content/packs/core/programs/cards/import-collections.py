from collections import OrderedDict

def import_collections(bolts, battle):
    groups = OrderedDict()
    for bolt in bolts:
        key = (bolt["element"], bolt.get("foe", 0), bolt.get("block", False))
        if key not in groups:
            groups[key] = dict(bolt)
        else:
            groups[key]["power"] += bolt["power"]
    return list(groups.values())
