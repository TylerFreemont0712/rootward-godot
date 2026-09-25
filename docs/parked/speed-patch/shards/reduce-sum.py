def reduce_sum(bolts, battle):
    if not bolts:
        return []
    return [{**bolts[0], 'power': sum(bolt['power'] for bolt in bolts)}]
