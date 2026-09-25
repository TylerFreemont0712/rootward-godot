def round_robin(bolts, battle):
    # Deal the bolts to the foes in turn: bolt i goes to foe i mod (number of foes).
    count = len(battle["foes"])
    if count == 0:
        return bolts
    return [dict(bolt, foe=i % count) for i, bolt in enumerate(bolts)]
