def pairwise_loop(bolts, battle):
    out = []
    for bolt in bolts:
        power = bolt['power']
        for other in bolts:
            power += 1 if other['power'] > 0 else 0
        out.append({**bolt, 'power': power})
    return out
