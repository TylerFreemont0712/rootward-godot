def last_stand(bolts, battle):
    factor = 4 if battle["me"]["hp"] * 2 <= battle["me"]["max"] else 1
    return [{**b, "mult": b["mult"] * factor} for b in bolts]
