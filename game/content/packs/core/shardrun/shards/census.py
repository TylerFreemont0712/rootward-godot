def census(bolts, battle):
    ordered = sorted(bolts, key=lambda bolt: bolt["power"])
    return [{**bolt, "power": bolt["power"] + place} for place, bolt in enumerate(ordered)]
