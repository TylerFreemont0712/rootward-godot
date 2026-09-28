def sweep_plus(bolts, battle):
    # Every bolt becomes one bolt per foe, at two thirds of its power: n bolts times m foes.
    count = len(battle["foes"])
    return [dict(bolt, power=max(1, bolt["power"] * 2 // 3), foe=i) for bolt in bolts for i in range(count)]
