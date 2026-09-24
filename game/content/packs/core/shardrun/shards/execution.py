def execution(bolts, battle):
    ready = any(f["hp"] * 2 <= f["max"] for f in battle["foes"])
    return [{**b, "target": "weakest", "mult": b["mult"] * 3} if ready and not b["ward"] else b for b in bolts]
