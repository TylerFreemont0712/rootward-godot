def siege_breaker(bolts, battle):
    ready = bool(battle["foes"]) and battle["foes"][0]["shield"] > 0
    return [{**b, "target": "front", "pierce": True, "mult": b["mult"] * 2} if ready and not b["ward"] else b for b in bolts]
