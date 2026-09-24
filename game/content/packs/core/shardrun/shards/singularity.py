def singularity(bolts, battle):
    count = len(bolts)
    if count == 0:
        return bolts
    return [{"power": 4 * count, "element": "none", "target": "strongest", "pierce": True, "ward": False, "mult": count}]
