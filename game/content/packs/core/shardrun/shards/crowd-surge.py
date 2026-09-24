def crowd_surge(bolts, battle):
    factor = max(1, len(battle["foes"]))
    return [{**b, "mult": b["mult"] * factor} if not b["ward"] else b for b in bolts]
