def chain_lightning_plus(bolts, battle):
    count = len(battle["foes"])
    if count == 0:
        return bolts
    out = []
    target = 0
    for bolt in bolts:
        if bolt.get("block", False):
            out.append(dict(bolt))
        else:
            power = bolt["power"] + (4 if bolt["element"] == "spark" else 0)
            out.append(dict(bolt, power=power, element="spark", foe=target % count))
            target += 1
    return out
