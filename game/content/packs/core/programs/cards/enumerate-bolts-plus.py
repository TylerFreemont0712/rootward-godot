def enumerate_bolts_plus(bolts, battle):
    # enumerate() pairs every item with its index, so a loop never has to count by hand.
    return [dict(bolt, power=bolt["power"] + i + 1) for i, bolt in enumerate(bolts)]
