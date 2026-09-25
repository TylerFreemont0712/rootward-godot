def weakest_route(bolts, battle):
    return [{**bolt, 'target': 'weakest'} if not bolt['ward'] else bolt for bolt in bolts]
