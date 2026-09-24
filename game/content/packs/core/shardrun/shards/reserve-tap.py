def reserve_tap(bolts, battle):
    bonus = battle["me"]["block"] // 4
    return [{**b, "mult": b["mult"] + bonus} if not b["ward"] else b for b in bolts]
