def temper(bolts, battle):
    tempered = []
    for bolt in bolts:
        power = bolt["power"]
        left_over = power % 5
        if left_over != 0:
            power = power + (5 - left_over)
        tempered.append({**bolt, "power": power})
    return tempered
