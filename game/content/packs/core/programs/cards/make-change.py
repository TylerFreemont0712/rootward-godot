def make_change(bolts, battle):
    # Greedy change: take the largest coin that still fits, again and again. With coins of 5 and 1 greedy is always
    # optimal; with coins of 4 and 3 it would not be (6 is 3 + 3, not 4 + 1 + 1).
    if not bolts:
        return bolts
    best = 0
    for i in range(1, len(bolts)):
        if bolts[i]["power"] > bolts[best]["power"]:
            best = i
    amount = bolts[best]["power"]
    coins = []
    for coin in (5, 1):
        while amount >= coin:
            coins.append(dict(bolts[best], power=coin + 1))
            amount -= coin
    return bolts[:best] + coins + bolts[best + 1:]
