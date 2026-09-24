def mirror_power(bolts, battle):
    peak = max((b["power"] for b in bolts), default=0)
    return [{**b, "power": peak} for b in bolts]
