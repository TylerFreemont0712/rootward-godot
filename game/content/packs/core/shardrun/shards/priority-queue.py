def priority_queue(bolts, battle):
    ordered = sorted(bolts, key=lambda bolt: bolt["power"], reverse=True)
    if ordered:
        ordered[0] = {**ordered[0], "target": "strongest"}
    return ordered
