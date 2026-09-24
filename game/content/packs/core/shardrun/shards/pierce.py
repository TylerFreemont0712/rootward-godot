def pierce(bolts, battle):
    return [{**bolt, "pierce": True, "power": max(1, bolt["power"] - 1)} for bolt in bolts]
