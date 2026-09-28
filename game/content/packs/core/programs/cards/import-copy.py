from copy import copy

def import_copy(bolts, battle):
    for bolt in reversed(bolts):
        if not bolt.get("block", False):
            echo = copy(bolt)
            echo["power"] = (echo["power"] + 1) // 2
            return bolts + [echo]
    return bolts
