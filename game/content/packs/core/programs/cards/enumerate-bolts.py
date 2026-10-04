def enumerate_bolts(bolts, battle):
    # enumerate() pairs every item with its index, so a loop never has to count by hand.
    return [dict(bolt, power=bolt["power"] + i) for i, bolt in enumerate(bolts)]
