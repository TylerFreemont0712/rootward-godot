def sieve(bolts, battle):
    return [bolt for bolt in bolts if bolt["power"] >= 3 or bolt["ward"]]
