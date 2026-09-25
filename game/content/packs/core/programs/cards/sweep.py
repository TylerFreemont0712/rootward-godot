def sweep(bolts, battle):
    # Every bolt becomes one bolt per foe, at half power: n bolts times m foes.
    count = len(battle["foes"])
    return [dict(bolt, power=max(1, bolt["power"] // 2), foe=i) for bolt in bolts for i in range(count)]
