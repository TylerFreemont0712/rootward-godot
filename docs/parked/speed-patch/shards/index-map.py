def index_map(bolts, battle):
    return [{**bolt, 'power': bolt['power'] + 2 * i} for i, bolt in enumerate(bolts)]
