def memo_table(bolts, battle):
    seen = set()
    out = []
    for bolt in bolts:
        out.append({**bolt, 'power': bolt['power'] + (4 if bolt['element'] in seen else 0)})
        seen.add(bolt['element'])
    return out
