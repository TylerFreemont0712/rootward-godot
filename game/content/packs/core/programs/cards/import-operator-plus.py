from operator import add

def import_operator_plus(bolts, battle):
    return [dict(bolt, power=add(bolt["power"], 0 if bolt.get("block", False) else 1)) for bolt in bolts]
