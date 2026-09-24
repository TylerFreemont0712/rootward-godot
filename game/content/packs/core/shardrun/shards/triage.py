def triage(bolts, battle):
    return [{**bolt, "target": "strongest"} for bolt in bolts]
