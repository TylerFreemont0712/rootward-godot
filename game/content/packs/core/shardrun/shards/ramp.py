def ramp(bolts, battle):
    return [{**bolt, "power": bolt["power"] + index * 2} for index, bolt in enumerate(bolts)]
